import Foundation
import Observation
import SwiftUI

/// Root editor state. The script text is the single source of truth: sliders, presets and the
/// photo importer all work by rewriting the text, so undo, save and share share one path.
@Observable
final class EditorModel {
    var script: String {
        didSet {
            guard script != oldValue else { return }
            if !programmaticChange { captureTypingUndo(oldValue) }
            scheduleParse()
        }
    }

    /// Set while the model itself rewrites the text (presets, undo/redo, sliders) so typing-undo is not captured.
    private var programmaticChange = false
    private var lastTypingSnapshot: Date = .distantPast

    /// Typing is coalesced into one undo step per pause of 1.5 s (a keystroke-level stack would be useless).
    private func captureTypingUndo(_ previous: String) {
        let now = Date()
        if now.timeIntervalSince(lastTypingSnapshot) > 1.5 {
            undoStack.append(previous)
            if undoStack.count > 100 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        lastTypingSnapshot = now
    }

    private func setProgrammatically(_ text: String) {
        programmaticChange = true
        script = text
        programmaticChange = false
        lastTypingSnapshot = .distantPast
    }
    private(set) var artwork: Artwork?
    private(set) var rendered: RenderedArtwork?
    private(set) var errorMessage: String?
    private(set) var isParsing = false
    private(set) var lastParseSeconds: Double = 0

    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private var parseTask: Task<Void, Never>?
    private var generation = 0

    init(script: String = Presets.ginkgo.script) {
        self.script = script
        scheduleParse(immediately: true)
    }

    // MARK: - parsing pipeline (debounced, off the main actor)

    private func scheduleParse(immediately: Bool = false) {
        parseTask?.cancel()
        generation += 1
        let myGeneration = generation
        let source = script
        isParsing = true
        parseTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(120))
                if Task.isCancelled { return }
            }
            let result = await Task.detached(priority: .userInitiated) { () -> Result<(Artwork, RenderedArtwork), Error> in
                do {
                    let art = try FamilyParser.parse(source)
                    let rendered = try FamilyEvaluator.evaluate(art)
                    return .success((art, rendered))
                } catch {
                    return .failure(error)
                }
            }.value
            guard let self, myGeneration == self.generation else { return }
            self.isParsing = false
            switch result {
            case .success(let (art, rendered)):
                self.artwork = art
                self.rendered = rendered
                self.errorMessage = nil
                self.lastParseSeconds = rendered.evaluationSeconds
            case .failure(let error):
                // keep the last good render on screen; only the banner changes
                self.errorMessage = String(describing: error)
            }
        }
    }

    /// Re-run the pipeline immediately (the "수식 재계산" button).
    func reparseNow() { scheduleParse(immediately: true) }

    /// Short file-like name for the editor header, taken from the first comment line ("// 은행잎 — …" → "은행잎.smk").
    var scriptName: String {
        guard let first = script.split(separator: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }), first.hasPrefix("//") else { return "script.smk" }
        let body = first.dropFirst(2).trimmingCharacters(in: .whitespaces)
        let title = body.components(separatedBy: CharacterSet(charactersIn: "—(:·")).first?.trimmingCharacters(in: .whitespaces) ?? body
        let compact = title.prefix(18)
        return compact.isEmpty ? "script.smk" : "\(compact).smk"
    }

    // MARK: - edits

    /// Bumped whenever the whole text is swapped (preset, import, undo/redo) so the editor view
    /// can reset its scroll position to the top instead of jumping to the end.
    private(set) var scriptVersion = 0

    /// Replace the whole script as one undoable step (preset load, importer, reset).
    func replaceScript(_ text: String) {
        pushUndo()
        setProgrammatically(text)
        scriptVersion += 1
    }

    /// Rewrite the numeric literal of `let name = value …` in place (slider edits).
    func setLetValue(_ name: String, to value: Double, recordUndo: Bool) {
        guard let variable = artwork?.lets.first(where: { $0.name == name }) else { return }
        var lines = script.components(separatedBy: "\n")
        let idx = variable.line - 1
        guard lines.indices.contains(idx) else { return }
        let line = lines[idx]
        guard let eq = line.firstIndex(of: "=") else { return }
        let after = line[line.index(after: eq)...]
        // the literal runs until whitespace or "in"
        let trimmed = after.drop(while: { $0 == " " })
        let literal = trimmed.prefix(while: { !$0.isWhitespace })
        let formatted = Self.format(value)
        let rebuilt = String(line[...eq]) + " " + formatted + String(trimmed.dropFirst(literal.count))
        if recordUndo { pushUndo() }
        lines[idx] = rebuilt
        let text = lines.joined(separator: "\n")
        if text != script { setProgrammatically(text) }
    }

    static func format(_ v: Double) -> String {
        if v == v.rounded(), abs(v) < 1e6 { return String(Int(v)) }
        var s = String(format: "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: - undo

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func pushUndo() {
        undoStack.append(script)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(script)
        setProgrammatically(prev)
        scriptVersion += 1
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(script)
        setProgrammatically(next)
        scriptVersion += 1
    }

    // MARK: - summary

    /// Counts what was actually drawn (a `points … when` family draws fewer dots than its range).
    var summary: String {
        guard let art = artwork, let rendered else { return "" }
        var counts: [String: Int] = [:]
        for f in rendered.families {
            switch f {
            case .segments(let p, _): counts["선분", default: 0] += p.count / 2
            case .circles(let c, _, _): counts["원", default: 0] += c.count
            case .polyline(let p, _): counts["곡선", default: 0] += p.count
            case .points(let p, _, _): counts["점", default: 0] += p.count
            }
        }
        let parts = counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        return "계열 \(art.families.count) · " + parts.joined(separator: " · ") + String(format: " · %.0f ms", lastParseSeconds * 1000)
    }
}
