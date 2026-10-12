import SwiftUI

enum Palette {
    static func bg(_ dark: Bool) -> Color { dark ? Color(hex: 0x0F172A) : Color(hex: 0xF8FAFC) }
    static func card(_ dark: Bool) -> Color { dark ? Color(hex: 0x1E293B) : Color.white }
    static func border(_ dark: Bool) -> Color { dark ? Color(hex: 0x334155) : Color(hex: 0xE2E8F0) }
    static func text(_ dark: Bool) -> Color { dark ? Color(hex: 0xF8FAFC) : Color(hex: 0x0F172A) }
    static func muted(_ dark: Bool) -> Color { dark ? Color(hex: 0x94A3B8) : Color(hex: 0x64748B) }
    static func field(_ dark: Bool) -> Color { dark ? Color(hex: 0x0F172A) : Color.white }
    static let accent = Color(hex: 0x6366F1)
    static let accentDeep = Color(hex: 0x4F46E5)
    static let danger = Color(hex: 0xDC2626)
    static let success = Color(hex: 0x34D399)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct CardModifier: ViewModifier {
    let dark: Bool
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Palette.card(dark))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.border(dark), lineWidth: 1)
            )
    }
}

extension View {
    func studioCard(dark: Bool) -> some View {
        modifier(CardModifier(dark: dark))
    }
}

struct StudioButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger, ghost }
    let kind: Kind
    let dark: Bool
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background(configuration.isPressed))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.45)
    }

    private func background(_ pressed: Bool) -> Color {
        switch kind {
        case .primary: return pressed ? Color(hex: 0x3730A3) : Palette.accentDeep
        case .secondary: return pressed ? (dark ? Color(hex: 0x1E293B) : Color(hex: 0xE2E8F0)) : (dark ? Color(hex: 0x334155) : Color(hex: 0xE2E8F0))
        case .danger: return pressed ? Color(hex: 0x7F1D1D) : Palette.danger
        case .ghost: return .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .ghost: return Palette.accent
        case .secondary: return dark ? .white : Color(hex: 0x0F172A)
        default: return .white
        }
    }

    private var border: Color {
        switch kind {
        case .primary: return Palette.accent
        case .secondary: return dark ? Color(hex: 0x475569) : Color(hex: 0xCBD5E1)
        case .danger: return Color(hex: 0xB91C1C)
        case .ghost: return .clear
        }
    }
}
