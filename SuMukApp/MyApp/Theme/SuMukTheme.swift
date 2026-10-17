import SwiftUI
import UIKit

// MARK: - Colour tokens (Design/stitch/ink-glass-dark/sumuk_design_tokens.json)

nonisolated extension Color {
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { @Sendable trait in
            let v = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }

    /// 화선지 — stays light in dark mode so ink keeps its contrast.
    static let paper = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
    /// 종이의 어두운 톤 — cards, wells, editor surface.
    static let paperDeep = dynamic(light: 0xEFE9DC, dark: 0x2C2C2E)
    /// 먹 — drawing ink is always #141414; UI text inverts.
    static let inkDrawing = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)
    static let inkText = dynamic(light: 0x141414, dark: 0xF5F5F7)
    static let inkSoft = dynamic(light: 0x6E6E73, dark: 0x98989D)
    static let inkWash = dynamic(light: 0xD9D4C8, dark: 0x3A3A3C)
    /// 낙관 — the single accent.
    static let vermilion = dynamic(light: 0xC2412B, dark: 0xD94E36)
    static let errorInk = dynamic(light: 0xBA1A1A, dark: 0xFFB4AB)
    /// 청자 — "ready / converged" status (Ink & Glass spec).
    static let celadon = dynamic(light: 0x3F7D6E, dark: 0x4E8B7C)
    /// Chrome background behind cards.
    static let chrome = dynamic(light: 0xFCF9F2, dark: 0x131313)
}

nonisolated extension Font {
    static func suMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static let suMonoScript = Font.system(size: 13, design: .monospaced)
    static let suMonoCaption = Font.system(size: 11, weight: .medium, design: .monospaced)
}

enum SuMukSpacing {
    static let xxs: CGFloat = 4, xs: CGFloat = 8, sm: CGFloat = 12, md: CGFloat = 16, lg: CGFloat = 24, xl: CGFloat = 32
}

enum SuMukRadius {
    static let card: CGFloat = 14, button: CGFloat = 14, thumbnail: CGFloat = 12, banner: CGFloat = 10
}

// MARK: - Components

/// 전각 낙관 — vermilion square seal with white characters.
struct SealStampView: View {
    var text: String = "數墨"
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous).fill(Color.vermilion)
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: max(1, size * 0.04))
                .padding(size * 0.12)
            Text(text)
                .font(.system(size: text.count > 1 ? size * 0.34 : size * 0.55, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: size * 0.5)
                .fixedSize()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Floating telemetry capsule over the canvas.
struct StatusCapsuleView: View {
    let text: String
    var isComputing = false
    var dot: Color = .vermilion

    var body: some View {
        HStack(spacing: 6) {
            if isComputing { ProgressView().controlSize(.mini) }
            else { Circle().fill(dot).frame(width: 5, height: 5) }
            Text(text).font(.suMonoCaption).foregroundStyle(Color.inkText)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

/// "A correction note on the margin of the paper" — script error banner.
struct MarginErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
            Text(message).font(.system(size: 12, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.errorInk)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.errorInk.opacity(0.12), in: RoundedRectangle(cornerRadius: SuMukRadius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SuMukRadius.banner, style: .continuous).stroke(Color.errorInk.opacity(0.3), lineWidth: 0.5))
        .accessibilityLabel("스크립트 오류: \(message)")
    }
}

/// Full-width vermilion CTA (seal-stamp button).
struct VermilionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.white : Color.inkSoft)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(isEnabled ? Color.vermilion : Color.inkWash, in: RoundedRectangle(cornerRadius: SuMukRadius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SuMukRadius.button, style: .continuous).stroke(Color.white.opacity(isEnabled ? 0.25 : 0), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Square secondary button used next to the CTA (share, trash).
struct SquareChromeButtonStyle: ButtonStyle {
    var tint: Color = .inkText
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 52, height: 52)
            .background(Color.paperDeep, in: RoundedRectangle(cornerRadius: SuMukRadius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SuMukRadius.button, style: .continuous).stroke(Color.inkWash, lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Card surface on paperDeep with a hairline.
struct SectionCard: ViewModifier {
    var padding: CGFloat = SuMukSpacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.paperDeep, in: RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous).stroke(Color.inkWash.opacity(0.6), lineWidth: 0.5))
    }
}

extension View {
    func sectionCard(padding: CGFloat = SuMukSpacing.md) -> some View { modifier(SectionCard(padding: padding)) }

    /// Rounded paper frame for canvases and thumbnails.
    func paperFrame(radius: CGFloat = SuMukRadius.card) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.inkDrawing.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

/// Small section header: bold title + optional trailing caption.
struct CardHeader<Trailing: View>: View {
    let icon: String?
    let title: String
    @ViewBuilder var trailing: Trailing

    init(icon: String? = nil, _ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.icon = icon; self.title = title; self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.vermilion) }
            Text(title).font(.subheadline.bold()).foregroundStyle(Color.inkText)
            Spacer()
            trailing.font(.suMonoCaption).foregroundStyle(Color.inkSoft)
        }
    }
}

/// Capsule chip (contour selection, meta tags).
struct ChipView: View {
    let label: String
    var icon: String? = nil
    var selected = false

    var body: some View {
        HStack(spacing: 5) {
            if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            else if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text(label).font(.suMono(12, weight: selected ? .bold : .regular))
        }
        .foregroundStyle(selected ? Color.vermilion : Color.inkSoft)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(selected ? Color.vermilion.opacity(0.18) : Color.paperDeep, in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.vermilion : Color.inkWash, lineWidth: selected ? 1 : 0.5))
    }
}

/// Variable slider row — monospaced name, vermilion slider, vermilion value.
struct ThemedSliderRow<Content: View>: View {
    let name: String
    let value: String
    @ViewBuilder var slider: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(name).font(.suMono(13, weight: .bold)).foregroundStyle(Color.inkText).frame(width: 64, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            slider.tint(.vermilion)
            Text(value).font(.suMono(12, weight: .semibold)).foregroundStyle(Color.vermilion).frame(width: 56, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(minHeight: 36)
    }
}
