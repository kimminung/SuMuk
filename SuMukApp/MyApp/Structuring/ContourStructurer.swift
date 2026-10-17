import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

// MARK: - Fourier curve

/// Closed curve x(t), y(t) = a0 + Σ aₙ cos(nt) + bₙ sin(nt), fitted to a polyline by a real DFT.
nonisolated struct FourierCurve: Sendable {
    let ax: [Double], bx: [Double], ay: [Double], by: [Double]   // index 0 = constant term
    var harmonics: Int { ax.count - 1 }

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

    /// Mean distance between the resampled source and the reconstruction (canvas height = 2).
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

    func definitions(x xName: String, y yName: String) -> String {
        func series(_ a: [Double], _ b: [Double]) -> String {
            var parts = [ScriptNumber.format(a[0], signed: false)]
            for h in 1..<a.count {
                let n = h == 1 ? "t" : "\(h)t"
                if abs(a[h]) >= 0.00005 { parts.append("\(ScriptNumber.format(a[h], signed: true))·cos(\(n))") }
                if abs(b[h]) >= 0.00005 { parts.append("\(ScriptNumber.format(b[h], signed: true))·sin(\(n))") }
            }
            return parts.joined(separator: " ")
        }
        return "\(xName)(t) = \(series(ax, bx))\n\(yName)(t) = \(series(ay, by))"
    }
}

nonisolated enum ScriptNumber {
    static func format(_ v: Double, signed: Bool, digits: Int = 4) -> String {
        var s = String(format: signed ? "%+.\(digits)f" : "%.\(digits)f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: "-", with: "−")
    }
}

// MARK: - DCT darkness series (closed-form tone field for the dots)

/// Truncated 2D DCT of a darkness grid: D(x,y) = clamp(Σ cₜ · Cᵤ(m) · Cᵥ(n), 0, 1), with the continuous
/// row/column indices m = (1−y)/2·h − ½, n = (x+a)/(2a)·w − ½. Emitted verbatim into the script.
nonisolated struct DarknessSeries: Sendable {
    let h: Int, w: Int
    let u: [Int], v: [Int], c: [Double]   // coefficient already includes the orthonormal scale factors
    let aspect: Double

    init(gray darkness: [Double], h: Int, w: Int, aspect: Double, terms: Int) {
        self.h = h; self.w = w; self.aspect = aspect
        // C = Dh · F · Dwᵀ with orthonormal DCT-II matrices
        func dct(_ n: Int) -> [[Double]] {
            (0..<n).map { k in (0..<n).map { m in
                let base = cos(Double.pi * Double(2 * m + 1) * Double(k) / Double(2 * n)) * sqrt(2 / Double(n))
                return k == 0 ? base / sqrt(2) : base
            } }
        }
        let Dh = dct(h), Dw = dct(w)
        var tmp = [[Double]](repeating: [Double](repeating: 0, count: w), count: h)   // Dh · F
        for i in 0..<h { for j in 0..<w { var s = 0.0; for r in 0..<h { s += Dh[i][r] * darkness[r * w + j] }; tmp[i][j] = s } }
        var coef: [(Int, Int, Double)] = []
        for i in 0..<h { for j in 0..<w { var s = 0.0; for col in 0..<w { s += tmp[i][col] * Dw[j][col] }; coef.append((i, j, s)) } }
        coef.sort { abs($0.2) > abs($1.2) }
        let top = coef.prefix(terms)
        u = top.map(\.0); v = top.map(\.1)
        c = top.map { t in
            let su = (t.0 == 0 ? 1 / sqrt(2) : 1) * sqrt(2 / Double(h))
            let sv = (t.1 == 0 ? 1 / sqrt(2) : 1) * sqrt(2 / Double(w))
            return t.2 * su * sv
        }
    }

    /// `D(x,y) = clamp( … , 0, 1)` as a SuMuk Script definition.
    func definition(name: String = "D") -> String {
        var terms: [String] = []
        for (i, coef) in c.enumerated() {
            let cu = u[i] == 0 ? "" : "·cos(π·\(u[i])·(2·m(y) + 1)/\(2 * h))"
            let cv = v[i] == 0 ? "" : "·cos(π·\(v[i])·(2·n(x) + 1)/\(2 * w))"
            terms.append("\(ScriptNumber.format(coef, signed: true, digits: 4))\(cu)\(cv)")
        }
        return "m(y) = (1 − y)/2·\(h) − 1/2\nn(x) = (x + \(ScriptNumber.format(aspect, signed: false)))/\(ScriptNumber.format(2 * aspect, signed: false))·\(w) − 1/2\n\(name)(x,y) = clamp( \(terms.joined(separator: " ")) , 0, 1)"
    }
}

// MARK: - Photo preparation (upscale → subject cut-out → contours → tone)

nonisolated struct ExtractedContour: Identifiable, Sendable {
    let id: Int
    let points: [CGPoint]      // math coords: x ∈ [−a, a], y ∈ [−1, 1]
    let normalizedArea: Double
    let isSilhouette: Bool     // outline of the lifted subject
}

nonisolated struct PreparedPhoto: Sendable {
    let image: CGImage              // upscaled; background whitened when a subject was found
    let upscale: Double
    let size: CGSize
    let aspect: Double
    let subjectFound: Bool
    let subjectError: String?          // why the cut-out fell back to the original (shown in the UI)
    let contours: [ExtractedContour]   // silhouettes first, then interior contours by area
    let darkness: DarknessSeries
    let timings: [(String, Double)]  // step name, milliseconds
}

nonisolated enum PhotoStructurer {
    struct Options: Sendable {
        var targetLongSide: Double = 2048
        var detectsDarkOnLight = true
        var maxContours = 12
        var minPoints = 60
        var toneTerms = 220
    }

    /// Full on-device preparation. Pure function; call off the main actor.
    static func prepare(_ source: CGImage, options: Options = Options()) throws -> PreparedPhoto {
        var timings: [(String, Double)] = []
        func timed<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
            let t0 = Date(); let r = try body(); timings.append((name, Date().timeIntervalSince(t0) * 1000)); return r
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // 1) upscale (Lanczos) + gentle unsharp mask so thin edges survive contour detection
        let longSide = Double(max(source.width, source.height))
        let factor = min(4, max(1, options.targetLongSide / longSide))   // beyond 4× Lanczos adds nothing but blur
        let upscaled: CGImage = try timed("업스케일") {
            var ci = CIImage(cgImage: source)
            if factor > 1.001 {
                let scale = CIFilter.lanczosScaleTransform()
                scale.inputImage = ci; scale.scale = Float(factor); scale.aspectRatio = 1
                ci = scale.outputImage ?? ci
                let sharpen = CIFilter.unsharpMask()
                sharpen.inputImage = ci; sharpen.radius = 2.0; sharpen.intensity = 0.4
                ci = sharpen.outputImage ?? ci
            }
            guard let cg = context.createCGImage(ci, from: ci.extent) else { throw StructuringError.render }
            return cg
        }
        let W = upscaled.width, H = upscaled.height
        let aspect = Double(W) / Double(H)

        // 2) subject lift (누끼): Vision foreground instance mask → white background.
        //    The request runs on a ≤1536px copy (the model works at low resolution anyway and very large
        //    RGBA buffers fail with kCVReturnInvalidPixelFormat); the mask is scaled back to full size.
        var subjectFound = false
        var subjectError: String? = nil
        var maskCI: CIImage? = nil
        let working: CGImage = timed("누끼") {
            let maskSide = 1536.0
            let down = min(1, maskSide / Double(max(W, H)))
            var maskInput = upscaled
            if down < 1, let small = context.createCGImage(CIImage(cgImage: upscaled).transformed(by: CGAffineTransform(scaleX: down, y: down)), from: CGRect(x: 0, y: 0, width: Double(W) * down, height: Double(H) * down)) {
                maskInput = small
            }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: maskInput, options: [:])
            do { try handler.perform([request]) } catch { subjectError = "마스크 요청 실패: \(error.localizedDescription)"; return upscaled }
            guard let obs = request.results?.first, !obs.allInstances.isEmpty else { subjectError = "전경 피사체를 찾지 못함"; return upscaled }
            let maskBuffer: CVPixelBuffer
            do { maskBuffer = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler) }
            catch { subjectError = "마스크 생성 실패: \(error.localizedDescription)"; return upscaled }
            subjectFound = true
            let mask = CIImage(cvPixelBuffer: maskBuffer)
            let scaled = mask.transformed(by: CGAffineTransform(scaleX: CGFloat(W) / mask.extent.width, y: CGFloat(H) / mask.extent.height))
            maskCI = scaled
            let blend = CIFilter.blendWithMask()
            blend.inputImage = CIImage(cgImage: upscaled)
            blend.backgroundImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
            blend.maskImage = scaled
            guard let out = blend.outputImage, let cg = context.createCGImage(out, from: CGRect(x: 0, y: 0, width: W, height: H)) else { return upscaled }
            return cg
        }

        // 3) contours: silhouette(s) from the mask, interior lines from the whitened image
        var contours: [ExtractedContour] = []
        try timed("윤곽") {
            func toMath(_ p: simd_float2) -> CGPoint { CGPoint(x: (Double(p.x) * 2 - 1) * aspect, y: Double(p.y) * 2 - 1) }
            if let maskCI, let maskCG = context.createCGImage(maskCI, from: CGRect(x: 0, y: 0, width: W, height: H)) {
                let req = VNDetectContoursRequest(); req.detectsDarkOnLight = false; req.contrastAdjustment = 2.0; req.maximumImageDimension = 1024
                try VNImageRequestHandler(cgImage: maskCG, options: [:]).perform([req])
                if let obs = req.results?.first {
                    for i in 0..<obs.contourCount {
                        guard let c = try? obs.contour(at: i), c.pointCount >= options.minPoints else { continue }
                        let pts = c.normalizedPoints.map(toMath)
                        contours.append(ExtractedContour(id: 1000 + i, points: pts, normalizedArea: abs(shoelace(pts)), isSilhouette: true))
                    }
                }
                contours.sort { $0.normalizedArea > $1.normalizedArea }
                contours = Array(contours.prefix(3))
            }
            let req = VNDetectContoursRequest()
            req.detectsDarkOnLight = options.detectsDarkOnLight; req.contrastAdjustment = 1.5; req.maximumImageDimension = 1024
            try VNImageRequestHandler(cgImage: working, options: [:]).perform([req])
            var interior: [ExtractedContour] = []
            if let obs = req.results?.first {
                for i in 0..<obs.contourCount {
                    guard let c = try? obs.contour(at: i), c.pointCount >= options.minPoints else { continue }
                    let pts = c.normalizedPoints.map(toMath)
                    // drop the photo's own border (a contour spanning almost the whole frame says nothing about the subject)
                    let xs = pts.map(\.x), ys = pts.map(\.y)
                    if let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max(),
                       (x1 - x0) > 1.94 * aspect, (y1 - y0) > 1.94 { continue }
                    interior.append(ExtractedContour(id: i, points: pts, normalizedArea: abs(shoelace(pts)), isSilhouette: false))
                }
            }
            interior.sort { $0.normalizedArea > $1.normalizedArea }
            contours += interior.prefix(max(0, options.maxContours - contours.count))
        }

        // 4) tone: darkness grid of the whitened image → truncated DCT series
        let darkness: DarknessSeries = try timed("농담") {
            let gh = 36, gw = max(8, Int((Double(gh) * aspect).rounded()))
            var gray = [Double](repeating: 0, count: gh * gw)
            guard let ctx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: gw, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { throw StructuringError.render }
            ctx.interpolationQuality = .high
            ctx.draw(working, in: CGRect(x: 0, y: 0, width: gw, height: gh))
            if let data = ctx.data?.assumingMemoryBound(to: UInt8.self) {
                // bitmap memory row 0 is the top of the image, which is also DCT row m = 0 (y = +1)
                for r in 0..<gh { for col in 0..<gw { gray[r * gw + col] = 1 - Double(data[r * gw + col]) / 255 } }
            }
            // light 3×3 blur before truncation so Gibbs ringing does not sprinkle dots over white areas
            var smooth = gray
            for r in 0..<gh { for col in 0..<gw {
                var s = 0.0, n = 0.0
                for dr in -1...1 { for dc in -1...1 {
                    let rr = r + dr, cc = col + dc
                    guard rr >= 0, rr < gh, cc >= 0, cc < gw else { continue }
                    let wgt = (dr == 0 && dc == 0) ? 4.0 : ((dr == 0 || dc == 0) ? 2.0 : 1.0)
                    s += gray[rr * gw + cc] * wgt; n += wgt
                } }
                smooth[r * gw + col] = s / n
            } }
            // contrast stretch: thin strokes (line drawings) average out to ~0.1 on a 36-row grid, so scale the
            // 98th percentile to 1 — the threshold slider then means the same thing for photos and sketches
            let sorted = smooth.sorted()
            let p98 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.98))]
            if p98 > 0.02 { let gain = min(1 / p98, 3); smooth = smooth.map { min(1, $0 * gain) } }
            return DarknessSeries(gray: smooth, h: gh, w: gw, aspect: aspect, terms: options.toneTerms)
        }

        return PreparedPhoto(image: working, upscale: factor, size: CGSize(width: W, height: H), aspect: aspect,
                             subjectFound: subjectFound, subjectError: subjectError, contours: contours, darkness: darkness, timings: timings)
    }

    enum StructuringError: Error { case render }

    static func shoelace(_ p: [CGPoint]) -> Double {
        guard p.count > 2 else { return 0 }
        var s = 0.0
        for i in 0..<p.count { let j = (i + 1) % p.count; s += p[i].x * p[j].y - p[j].x * p[i].y }
        return s / 2
    }

    // MARK: script

    /// Tone dots: stochastic stippling — dot k survives when D(X,Y)^γ exceeds a deterministic
    /// pseudo-random threshold mod(0.618034·k, 1), so local dot density is proportional to darkness^γ.
    struct ToneDots: Sendable {
        var count = 6000
        var gamma = 1.0
    }

    /// Emits a SuMuk Script made only of curves (contours) and points (outline dots and/or tone dots).
    /// - outlineDots: when non-nil, each selected contour also becomes a dotted line with that many points.
    static func script(photo: PreparedPhoto, contours: [ExtractedContour], harmonics: Int, curves: Bool, outlineDots: Int?, tone: ToneDots?) -> (script: String, meanError: Double) {
        let a = photo.aspect
        var kinds: [String] = []
        if curves { kinds.append("곡선") }
        if outlineDots != nil { kinds.append("윤곽 점") }
        if tone != nil { kinds.append("농담 점") }
        var text = "// 사진 → 수식 (업스케일 \(String(format: "%.1f", photo.upscale))× → \(photo.subjectFound ? "누끼 → " : "")Vision 윤곽 → 푸리에 \(harmonics)조화 → \(kinds.joined(separator: " + ")))\n"
        text += "canvas \(Int((a * 1000).rounded())) × 1000\nink #141414 width 0.5 alpha 0.8\n"
        var defs = "", errors: [Double] = []
        if let tone {
            text += "let gamma = \(ScriptNumber.format(tone.gamma, signed: false, digits: 2)) in [0.3, 3]   // 작을수록 점이 많아진다\n"
        }
        text += "\n"
        for (i, c) in contours.enumerated() {
            let n = i + 1
            let fc = FourierCurve(points: c.points, harmonics: harmonics)
            errors.append(fc.error(against: c.points))
            let label = "윤곽 \(n)\(c.isSilhouette ? " (피사체 실루엣)" : "")"
            if curves {
                text += "// \(label) — 푸리에 곡선, 조화 \(harmonics)개\ncurve t ∈ [0, 2π] samples 800 {\n  x = x\(n)(t)\n  y = y\(n)(t)\n}\n"
            }
            if let m = outlineDots {
                text += "// \(label) — 곡선 위의 점 \(m)개\npoints k = 1 ... \(m) {\n  at ( x\(n)(2πk/\(m)), y\(n)(2πk/\(m)) )\n}\n"
            }
            defs += fc.definitions(x: "x\(n)", y: "y\(n)") + "\n"
        }
        if let tone {
            let N = tone.count
            let s = hypot(a, 1) / sqrt(Double(N))   // spiral reaches the canvas corners
            text += """
            // 농담 — Vogel 나선 위의 점 \(N)개. 점 k 는 농담 D^gamma 가 유사난수 문턱 mod(0.618034·k, 1) 보다 클 때만 남으므로,
            // 점의 밀도가 어두운 정도에 비례한다(밝은 종이 위 가는 선 그림에는 거의 생기지 않는다)
            points k = 1 ... \(N) {
              at   ( X(k), Y(k) )
              size 0.0025 + 0.004·Dk(k)
              when (Dk(k)^gamma > mod(0.618034·k, 1))·(Dk(k) > 0.08)·(|X(k)| < \(ScriptNumber.format(a, signed: false)))·(|Y(k)| < 1)
            }

            """
            defs += "φ = π·(3 − √5)\nX(k) = \(ScriptNumber.format(s, signed: false, digits: 5))·√k·cos(φ·k)\nY(k) = \(ScriptNumber.format(s, signed: false, digits: 5))·√k·sin(φ·k)\nDk(k) = D(X(k), Y(k))\n"
            defs += photo.darkness.definition(name: "D") + "\n"
        }
        let mean = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)
        return (text + "where\n" + defs, mean)
    }
}
