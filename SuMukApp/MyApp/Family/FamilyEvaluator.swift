import Foundation
import CoreGraphics

/// Geometry produced from one family, in math coordinates (y up).
nonisolated enum RenderedFamily: Sendable {
    case segments(points: [CGPoint], ink: InkStyle)     // pairs: [p0, q0, p1, q1, …]
    case circles(centers: [CGPoint], radii: [Double], ink: InkStyle)
    case polyline(points: [CGPoint], ink: InkStyle)
    /// Dots. `sizes` are radii in math units; `nil` means a fixed on-screen dot.
    case points(points: [CGPoint], sizes: [Double]?, ink: InkStyle)

    var ink: InkStyle {
        switch self {
        case .segments(_, let i), .circles(_, _, let i), .polyline(_, let i), .points(_, _, let i): return i
        }
    }

    var bounds: CGRect? {
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        func take(_ p: CGPoint, _ r: Double = 0) {
            minX = min(minX, p.x - r); maxX = max(maxX, p.x + r); minY = min(minY, p.y - r); maxY = max(maxY, p.y + r)
        }
        switch self {
        case .segments(let pts, _), .polyline(let pts, _), .points(let pts, _, _): pts.forEach { take($0) }
        case .circles(let c, let r, _): for (p, rr) in zip(c, r) { take(p, rr) }
        }
        guard minX.isFinite, maxX.isFinite, minY.isFinite, maxY.isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

nonisolated struct RenderedArtwork: Sendable {
    var families: [RenderedFamily] = []
    var canvas: CGSize?
    var elementCount = 0
    var evaluationSeconds: Double = 0

    /// Bounding box of all geometry; with `canvas` set, the canvas rectangle in math coords
    /// (x ∈ [−a, a], y ∈ [−1, 1], a = W/H) is used instead so compositions line up with photos.
    var frame: CGRect {
        if let c = canvas, c.height > 0 {
            let a = c.width / c.height
            return CGRect(x: -a, y: -1, width: 2 * a, height: 2)
        }
        let boxes = families.compactMap(\.bounds)
        guard var box = boxes.first else { return CGRect(x: -1, y: -1, width: 2, height: 2) }
        for b in boxes.dropFirst() { box = box.union(b) }
        if box.width < 1e-6 { box = box.insetBy(dx: -0.5, dy: 0) }
        if box.height < 1e-6 { box = box.insetBy(dx: 0, dy: -0.5) }
        return box
    }
}

/// Evaluates every family of an `Artwork` into points. Pure, `nonisolated`, safe to run off the main actor.
nonisolated enum FamilyEvaluator {
    static func evaluate(_ art: Artwork) throws -> RenderedArtwork {
        let start = Date()
        var out = RenderedArtwork(canvas: art.canvas, elementCount: art.elementCount)
        let letNames = art.lets.map(\.name)
        let letValues = art.lets.map(\.value)
        for family in art.families {
            let ink = family.ink ?? art.ink
            switch family {
            case .segments(let r, let f, let t, _):
                let vars = [r.variable] + letNames
                var compiler = ExpressionCompiler(variables: vars, definitions: art.definitions)
                let fx = try compiler.compile(f.0), fy = try compiler.compile(f.1), tx = try compiler.compile(t.0), ty = try compiler.compile(t.1)
                var slots = [Double](repeating: 0, count: max(compiler_slotCount([fx, fy, tx, ty]), vars.count))
                for (i, v) in letValues.enumerated() { slots[1 + i] = v }
                var pts: [CGPoint] = []; pts.reserveCapacity(r.count * 2)
                for k in r.lower...r.upper {
                    slots[0] = Double(k)
                    let p = CGPoint(x: fx.evaluate(&slots), y: fy.evaluate(&slots))
                    let q = CGPoint(x: tx.evaluate(&slots), y: ty.evaluate(&slots))
                    guard p.x.isFinite, p.y.isFinite, q.x.isFinite, q.y.isFinite else { continue }
                    pts.append(p); pts.append(q)
                }
                out.families.append(.segments(points: pts, ink: ink))
            case .circles(let r, let c, let rad, _):
                let vars = [r.variable] + letNames
                var compiler = ExpressionCompiler(variables: vars, definitions: art.definitions)
                let cx = try compiler.compile(c.0), cy = try compiler.compile(c.1), rr = try compiler.compile(rad)
                var slots = [Double](repeating: 0, count: max(compiler_slotCount([cx, cy, rr]), vars.count))
                for (i, v) in letValues.enumerated() { slots[1 + i] = v }
                var centers: [CGPoint] = [], radii: [Double] = []
                centers.reserveCapacity(r.count); radii.reserveCapacity(r.count)
                for k in r.lower...r.upper {
                    slots[0] = Double(k)
                    let p = CGPoint(x: cx.evaluate(&slots), y: cy.evaluate(&slots))
                    let radius = rr.evaluate(&slots)
                    guard p.x.isFinite, p.y.isFinite, radius.isFinite, radius > 0 else { continue }
                    centers.append(p); radii.append(radius)
                }
                out.families.append(.circles(centers: centers, radii: radii, ink: ink))
            case .curve(let r, let xe, let ye, _):
                let vars = [r.variable] + letNames
                var compiler = ExpressionCompiler(variables: vars, definitions: art.definitions)
                let fx = try compiler.compile(xe), fy = try compiler.compile(ye)
                var slots = [Double](repeating: 0, count: max(compiler_slotCount([fx, fy]), vars.count))
                for (i, v) in letValues.enumerated() { slots[1 + i] = v }
                var pts: [CGPoint] = []; pts.reserveCapacity(r.samples)
                for i in 0..<r.samples {
                    slots[0] = r.lower + (r.upper - r.lower) * Double(i) / Double(max(1, r.samples - 1))
                    let p = CGPoint(x: fx.evaluate(&slots), y: fy.evaluate(&slots))
                    guard p.x.isFinite, p.y.isFinite else { continue }
                    pts.append(p)
                }
                out.families.append(.polyline(points: pts, ink: ink))
            case .points(let r, let at, let sizeExpr, let whenExpr, _):
                let vars = [r.variable] + letNames
                var compiler = ExpressionCompiler(variables: vars, definitions: art.definitions)
                let fx = try compiler.compile(at.0), fy = try compiler.compile(at.1)
                let fs = try sizeExpr.map { try compiler.compile($0) }
                let fw = try whenExpr.map { try compiler.compile($0) }
                var slots = [Double](repeating: 0, count: max(compiler_slotCount([fx, fy] + [fs, fw].compactMap { $0 }), vars.count))
                for (i, v) in letValues.enumerated() { slots[1 + i] = v }
                var pts: [CGPoint] = [], sizes: [Double] = []
                pts.reserveCapacity(r.count)
                for k in r.lower...r.upper {
                    slots[0] = Double(k)
                    if let fw, !(fw.evaluate(&slots) > 0) { continue }
                    let p = CGPoint(x: fx.evaluate(&slots), y: fy.evaluate(&slots))
                    guard p.x.isFinite, p.y.isFinite else { continue }
                    if let fs {
                        let s = fs.evaluate(&slots)
                        guard s.isFinite, s > 0 else { continue }
                        sizes.append(s)
                    }
                    pts.append(p)
                }
                out.families.append(.points(points: pts, sizes: fs == nil ? nil : sizes, ink: ink))
            }
        }
        out.evaluationSeconds = Date().timeIntervalSince(start)
        return out
    }

    private static func compiler_slotCount(_ exprs: [CompiledExpression]) -> Int {
        exprs.map(\.slotCount).max() ?? 0
    }
}
