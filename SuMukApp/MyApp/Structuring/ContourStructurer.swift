import Foundation
import CoreGraphics
import Vision

/// Image → formula, Tier A (PRD FR-5, FR-11 on-device path):
/// Vision contours → arc-length resampling → real Fourier series → chord-family SuMuk Script.
nonisolated struct FourierCurve: Sendable {
    let ax: [Double], bx: [Double], ay: [Double], by: [Double]   // index 0 = constant term
    var harmonics: Int { ax.count - 1 }

    /// Fit a closed polyline (math coords) with `n` harmonics using `m` arc-length samples.
    init(points: [CGPoint], harmonics n: Int, samples m: Int = 512) {
        let P = FourierCurve.resampleClosed(points, count: m)
        var ax = [Double](repeating: 0, count: n + 1), bx = ax, ay = ax, by = ax
        let M = Double(m)
        for h in 0...n {
            var cx = 0.0, sx = 0.0, cy = 0.0, sy = 0.0
            for (i, p) in P.enumerated() {
                let t = 2 * Double.pi * Double(i) / M
                let c = cos(Double(h) * t), s = sin(Double(h) * t)
                cx += p.x * c; sx += p.x * s; cy += p.y * c; sy += p.y * s
            }
            let norm = h == 0 ? 1 / M : 2 / M
            ax[h] = cx * norm; bx[h] = sx * norm; ay[h] = cy * norm; by[h] = sy * norm
        }
        self.ax = ax; self.bx = bx; self.ay = ay; self.by = by
    }

    func point(at t: Double) -> CGPoint {
        var x = ax[0], y = ay[0]
        for h in 1..<ax.count {
            let c = cos(Double(h) * t), s = sin(Double(h) * t)
            x += ax[h] * c + bx[h] * s; y += ay[h] * c + by[h] * s
        }
        return CGPoint(x: x, y: y)
    }

    /// Mean distance between the resampled source and the reconstruction (same parameter).
    func error(against points: [CGPoint], samples m: Int = 256) -> Double {
        let P = FourierCurve.resampleClosed(points, count: m)
        var sum = 0.0
        for (i, p) in P.enumerated() {
            let q = point(at: 2 * Double.pi * Double(i) / Double(m))
            sum += hypot(p.x - q.x, p.y - q.y)
        }
        return sum / Double(m)
    }

    static func resampleClosed(_ pts: [CGPoint], count: Int) -> [CGPoint] {
        guard pts.count > 1 else { return Array(repeating: pts.first ?? .zero, count: count) }
        var closed = pts; closed.append(pts[0])
        var cum: [Double] = [0]
        for i in 1..<closed.count { cum.append(cum[i - 1] + hypot(closed[i].x - closed[i - 1].x, closed[i].y - closed[i - 1].y)) }
        let total = cum.last ?? 1
        var out: [CGPoint] = []; out.reserveCapacity(count)
        var j = 0
        for i in 0..<count {
            let s = total * Double(i) / Double(count)
            while j + 1 < cum.count - 1, cum[j + 1] < s { j += 1 }
            let span = max(cum[j + 1] - cum[j], 1e-12)
            let f = (s - cum[j]) / span
            out.append(CGPoint(x: closed[j].x + (closed[j + 1].x - closed[j].x) * f, y: closed[j].y + (closed[j + 1].y - closed[j].y) * f))
        }
        return out
    }

    /// `x(t) = a0 + a1·cos(t) + b1·sin(t) + …` definitions for the `where` section.
    func definitions(x xName: String, y yName: String) -> String {
        func series(_ a: [Double], _ b: [Double]) -> String {
            var parts = [Self.num(a[0], signed: false)]
            for h in 1..<a.count {
                let n = h == 1 ? "t" : "\(h)t"
                if abs(a[h]) >= 0.00005 { parts.append("\(Self.num(a[h], signed: true))·cos(\(n))") }
                if abs(b[h]) >= 0.00005 { parts.append("\(Self.num(b[h], signed: true))·sin(\(n))") }
            }
            return parts.joined(separator: " ")
        }
        return "\(xName)(t) = \(series(ax, bx))\n\(yName)(t) = \(series(ay, by))"
    }

    static func num(_ v: Double, signed: Bool) -> String {
        var s = String(format: signed ? "%+.4f" : "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: "-", with: "−")
    }
}

nonisolated struct ExtractedContour: Identifiable, Sendable {
    let id: Int
    let points: [CGPoint]      // math coords: x ∈ [−a, a], y ∈ [−1, 1]
    let normalizedArea: Double
}

nonisolated enum ContourStructurer {
    struct Options: Sendable {
        var contrastAdjustment: Float = 1.5
        var detectsDarkOnLight = true
        var maxContours = 12
        var minPoints = 40
    }

    /// Runs `VNDetectContoursRequest` and returns the largest closed contours in math coordinates.
    static func extractContours(from image: CGImage, options: Options = Options()) throws -> (contours: [ExtractedContour], aspect: Double) {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = options.contrastAdjustment
        request.detectsDarkOnLight = options.detectsDarkOnLight
        request.maximumImageDimension = 1024
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let aspect = Double(image.width) / Double(image.height)
        guard let observation = request.results?.first else { return ([], aspect) }
        var result: [ExtractedContour] = []
        for i in 0..<observation.contourCount {
            guard let c = try? observation.contour(at: i), c.pointCount >= options.minPoints else { continue }
            let pts = c.normalizedPoints.map { CGPoint(x: (Double($0.x) * 2 - 1) * aspect, y: Double($0.y) * 2 - 1) }
            result.append(ExtractedContour(id: i, points: pts, normalizedArea: abs(shoelace(pts))))
        }
        result.sort { $0.normalizedArea > $1.normalizedArea }
        return (Array(result.prefix(options.maxContours)), aspect)
    }

    static func shoelace(_ p: [CGPoint]) -> Double {
        guard p.count > 2 else { return 0 }
        var s = 0.0
        for i in 0..<p.count { let j = (i + 1) % p.count; s += p[i].x * p[j].y - p[j].x * p[i].y }
        return s / 2
    }

    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case curve = "곡선", chords = "현 계열", brush = "붓 원 계열"
        var id: String { rawValue }
    }

    /// Emits a SuMuk Script for the selected contours.
    static func script(for contours: [ExtractedContour], aspect: Double, harmonics: Int, mode: Mode, chordCount: Int = 600, chordOffset: Int = 100) -> (script: String, meanError: Double) {
        var families = "", defs = "", errors: [Double] = []
        for (i, c) in contours.enumerated() {
            let n = i + 1
            let fc = FourierCurve(points: c.points, harmonics: harmonics)
            errors.append(fc.error(against: c.points))
            switch mode {
            case .curve:
                families += "// 윤곽 \(n) — 푸리에 곡선 (조화 \(harmonics)개)\ncurve t ∈ [0, 2π] samples 800 {\n  x = x\(n)(t)\n  y = y\(n)(t)\n}\n"
            case .chords:
                families += "// 윤곽 \(n) — 현 계열: A(k)와 A(k+δ)를 잇는다\nsegments k = 1 ... \(chordCount) {\n  from ( x\(n)(2πk/\(chordCount)), y\(n)(2πk/\(chordCount)) )\n  to   ( x\(n)(2π(k+δ)/\(chordCount)), y\(n)(2π(k+δ)/\(chordCount)) )\n}\n"
            case .brush:
                families += "// 윤곽 \(n) — 붓 원 계열\ncircles k = 1 ... \(chordCount) {\n  center ( x\(n)(2πk/\(chordCount)), y\(n)(2πk/\(chordCount)) )\n  radius  0.004 + 0.008·|sin(9·2πk/\(chordCount))|\n}\n"
            }
            defs += fc.definitions(x: "x\(n)", y: "y\(n)") + "\n"
        }
        let header = "// 사진 → 수식 (Vision 윤곽 → 푸리에 \(harmonics)조화 → \(mode.rawValue))\ncanvas \(Int((aspect * 1000).rounded())) × 1000\nink #141414 width 0.45 alpha 0.6\n" + (mode == .chords ? "let δ = \(chordOffset) in [1, \(chordCount / 2)]\n" : "") + "\n"
        let mean = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)
        return (header + families + "where\n" + defs, mean)
    }
}
