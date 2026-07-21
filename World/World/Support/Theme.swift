//
//  Theme.swift
//  World
//
//  Shared color and font (Fredoka) tokens for `CreditsView`/`TutorialView` (ADR-087). Originally
//  written for a competing Main Menu/Loading design (`feat/ui-slice`) that wasn't adopted — see
//  `CHECKPOINT.md`'s "Merge PR #7 (feat/ui-slice) into main" entry — trimmed on port to only the
//  tokens `CreditsView`/`TutorialView` actually reference; the dropped `overlay`/`menuButton*`
//  tokens existed solely for that unshipped design.
//

import SwiftUI

extension Color {
    /// Hex initializer supporting "RRGGBB" or "AARRGGBB" (with or without a leading "#").
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)

        let a, r, g, b: UInt64
        switch hexString.count {
        case 8:
            (a, r, g, b) = ((value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff)
        default:
            (a, r, g, b) = (255, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Shared design tokens for `CreditsView`/`TutorialView`.
enum Theme {
    /// Button fill.
    static let buttonFill = Color(hex: "342B21")
    /// Button label color.
    static let buttonLabel = Color(hex: "EBE2D8")
    /// Drop-shadow color behind button labels.
    static let buttonLabelShadow = Color(hex: "574420")
}

extension Font {
    /// Fredoka, registered via `UIAppFonts` in Info.plist (Fonts/Fredoka-Regular.ttf, Fredoka-Bold.ttf).
    static func fredoka(_ size: CGFloat) -> Font {
        .custom("Fredoka-Regular", size: size)
    }

    static func fredokaBold(_ size: CGFloat) -> Font {
        .custom("Fredoka-Bold", size: size)
    }
}

/// A text label with a solid offset shadow copy behind it, matching the game's
/// embossed button-label look (e.g. `EBE2D8` label over a `574420` shadow).
struct ShadowedLabel: View {
    let text: String
    let font: Font
    let color: Color
    let shadowColor: Color
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)

    var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(shadowColor)
                .offset(shadowOffset)
            Text(text)
                .font(font)
                .foregroundStyle(color)
        }
    }
}
