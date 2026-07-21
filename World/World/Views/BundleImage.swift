//
//  BundleImage.swift
//  World
//

import AppKit
import SwiftUI

/// Loads a loose bundled PNG resource by name (no `Assets.xcassets` entry) — used for
/// `World/World/Assets/Images/*` (ADR-081/ADR-082: main menu and loading screen art). `World.
/// xcodeproj`'s `PBXFileSystemSynchronizedRootGroup` flattens loose files straight into the app
/// bundle's `Resources/` root (confirmed by building the target and inspecting the resulting
/// `.app`, the same mechanism that already makes `Assets/FishCaught/mekong_catfish_caught.usdz`
/// loadable via `Entity(named:)`), which SwiftUI's bare `Image(_:)` string initializer doesn't
/// reliably resolve outside an asset catalog — so this reads the file directly via
/// `Bundle.main.url(forResource:withExtension:)` + `NSImage(contentsOf:)` instead. Falls back to
/// an SF Symbol only if the resource is genuinely missing — a build-configuration problem, not a
/// runtime one, but a blank/crashing screen would be a worse failure mode than a visible gap.
func bundleImage(_ name: String) -> Image {
    guard
        let url = Bundle.main.url(forResource: name, withExtension: "png"),
        let nsImage = NSImage(contentsOf: url)
    else {
        return Image(systemName: "photo")
    }
    return Image(nsImage: nsImage)
}
