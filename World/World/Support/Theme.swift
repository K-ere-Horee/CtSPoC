//
//  Theme.swift
//  World
//
//  Shared color and font tokens for the front-end UI (Main Menu, Loading, ...).
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

/// Shared design tokens for the game's front-end screens (Main Menu, Loading Screen).
enum Theme {
    /// Dark scrim placed over full-bleed background art.
    static let overlay = Color(hex: "281E0D").opacity(0.4)

    /// Menu button fill.
    static let buttonFill = Color(hex: "342B21")
    /// Menu button label color.
    static let buttonLabel = Color(hex: "EBE2D8")
    /// Drop-shadow color behind menu button labels.
    static let buttonLabelShadow = Color(hex: "574420")

    /// Main Menu pill-button face (cream card look).
    static let menuButtonFace = Color(hex: "F2E6C8")
    /// Main Menu pill-button border and thick bottom "3D" edge.
    static let menuButtonEdge = Color(hex: "2E2013")
    /// Main Menu pill-button label color.
    static let menuButtonText = Color(hex: "2B1D10")
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
