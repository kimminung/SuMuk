import SwiftUI

/// Math ↔ view mapping shared by the canvas and by hit-testing (MathSketch `FitContext` pattern).
nonisolated struct FitContext: Sendable {
    let scale: CGFloat
    let frameCenter: CGPoint
    let viewCenter: CGPoint

    init(frame: CGRect, in rect: CGRect, padding: CGFloat = 0.06) {
        let usable = rect.insetBy(dx: rect.width * padding, dy: rect.height * padding)
        let s = min(usable.width / max(frame.width, 1e-9), usable.height / max(frame.height, 1e-9))
        scale = s.isFinite && s > 0 ? s : 1
        frameCenter = CGPoint(x: frame.midX, y: frame.midY)
        viewCenter = CGPoint(x: rect.midX, y: rect.midY)
    }

    func toView(_ p: CGPoint) -> CGPoint {
        CGPoint(x: viewCenter.x + (p.x - frameCenter.x) * scale, y: viewCenter.y - (p.y - frameCenter.y) * scale)
    }
}

/// Draws a `RenderedArtwork` into a SwiftUI `GraphicsContext` (Canvas path, ≤ ~20k elements).
/// The Metal instanced path for larger families is Phase 4.
nonisolated enum FamilyRenderer {
    static func draw(_ art: RenderedArtwork, in context: inout GraphicsContext, size: CGSize, paper: Color? = nil, padding: CGFloat = 0.06) {
        let rect = CGRect(origin: .zero, size: size)
        if let paper { context.fill(Path(rect), with: .color(paper)) }
        let fit = FitContext(frame: art.frame, in: rect, padding: padding)
        for family in art.families {
            let ink = family.ink
            let (r, g, b) = ink.rgb
            let color = Color(red: r, green: g, blue: b).opacity(ink.alpha)
            let lineWidth = max(0.25, ink.width)
            switch family {
            case .segments(let pts, _):
                var path = Path()
                var i = 0
                while i + 1 < pts.count {
                    path.move(to: fit.toView(pts[i])); path.addLine(to: fit.toView(pts[i + 1])); i += 2
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            case .circles(let centers, let radii, _):
                var path = Path()
                for (c, rad) in zip(centers, radii) {
                    let v = fit.toView(c); let rr = rad * fit.scale
                    guard rr > 0.15 else { continue }
                    path.addEllipse(in: CGRect(x: v.x - rr, y: v.y - rr, width: 2 * rr, height: 2 * rr))
                }
                if ink.fill { context.fill(path, with: .color(color)) }
                else { context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth)) }
            case .polyline(let pts, _):
                guard pts.count > 1 else { continue }
                var path = Path()
                path.move(to: fit.toView(pts[0]))
                for p in pts.dropFirst() { path.addLine(to: fit.toView(p)) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .points(let pts, let sizes, _):
                var path = Path()
                let fixed = max(0.6, lineWidth * 1.4)   // on-screen radius for size-less dots
                for (i, p) in pts.enumerated() {
                    let v = fit.toView(p)
                    let rr = sizes.map { $0[i] * fit.scale } ?? fixed
                    guard rr > 0.15 else { continue }
                    path.addEllipse(in: CGRect(x: v.x - rr, y: v.y - rr, width: 2 * rr, height: 2 * rr))
                }
                context.fill(path, with: .color(color))
            }
        }
    }
}

/// SwiftUI view that paints an artwork on "rice paper".
struct FamilyCanvasView: View {
    let artwork: RenderedArtwork?
    var paper: Color = Color(red: 0.98, green: 0.97, blue: 0.94)
    /// Fraction of the view kept empty around the drawing; 0 for overlays that must match a photo exactly.
    var padding: CGFloat = 0.06

    var body: some View {
        Canvas(opaque: paper != .clear, rendersAsynchronously: true) { context, size in
            if let artwork {
                FamilyRenderer.draw(artwork, in: &context, size: size, paper: paper == .clear ? nil : paper, padding: padding)
            } else if paper != .clear {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let artwork else { return "빈 캔버스" }
        let parts = artwork.families.map { f -> String in
            switch f {
            case .segments(let p, _): return "선분 \(p.count / 2)개"
            case .circles(let c, _, _): return "원 \(c.count)개"
            case .polyline(let p, _): return "곡선 점 \(p.count)개"
            case .points(let p, _, _): return "점 \(p.count)개"
            }
        }
        return "계열 \(artwork.families.count)개: " + parts.joined(separator: ", ")
    }
}
