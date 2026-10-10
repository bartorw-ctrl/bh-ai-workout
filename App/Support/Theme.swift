import SwiftUI
import UIKit

/// Colors from the mockup, with dark-mode equivalents (SPEC design notes).
enum Theme {
    static let ground = Color(light: 0xF3F2EE, dark: 0x111214)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1D20)
    static let line = Color(light: 0xDDDBD4, dark: 0x303237)
    static let ink = Color(light: 0x16171A, dark: 0xF2F1EC)
    static let muted = Color(light: 0x5C5F66, dark: 0xA3A6AD)
    static let accent = Color(light: 0xC2410C, dark: 0xE0611F)
    static let accentSoft = Color(light: 0xFBE3D6, dark: 0x4A2414)
    static let accentSoftText = Color(light: 0x9A3412, dark: 0xFDBA8C)
    static let destructive = Color(light: 0xB42318, dark: 0xF04438)
    static let emptyRing = Color(light: 0xBDBAB1, dark: 0x5A5D63)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Large uppercase condensed screen title used on each tab.
struct ScreenTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 36, weight: .bold).width(.condensed))
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// White rounded card with a hairline border.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 88, minHeight: 48)
            .padding(.horizontal, 4)
            .background(Theme.card.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
