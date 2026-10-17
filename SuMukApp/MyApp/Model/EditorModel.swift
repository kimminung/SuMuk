import Foundation
import Observation
import SwiftUI

/// Root editor state. The script text is the single source of truth: sliders, presets and the
/// photo importer all work by rewriting the text, so undo, save and share share one path.
@Observable
final class EditorModel {
    var script: String {
        didSet { if script != oldValue { scheduleParse() } }
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

    // MARK: - edits

    /// Bumped whenever the whole text is swapped (preset, import, undo/redo) so the editor view
    /// can reset its scroll position to the top instead of jumping to the end.
    private(set) var scriptVersion = 0

    /// Replace the whole script as one undoable step (preset load, importer, reset).
    func replaceScript(_ text: String) {
        pushUndo()
        script = text
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
        if text != script { script = text }
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
        script = prev
        scriptVersion += 1
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(script)
        script = next
        scriptVersion += 1
    }

    // MARK: - summary

    var summary: String {
        guard let art = artwork else { return "" }
        let counts = Dictionary(grouping: art.families, by: \.kindName).map { "\($0.key) \($0.value.reduce(0) { $0 + $1.elementCount })" }
        return "계열 \(art.families.count) · " + counts.sorted().joined(separator: " · ") + String(format: " · %.0f ms", lastParseSeconds * 1000)
    }
}
