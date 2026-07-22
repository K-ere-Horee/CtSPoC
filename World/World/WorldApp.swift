//
//  WorldApp.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import AppKit
import SwiftUI

@main
struct WorldApp: App {
    @NSApplicationDelegateAdaptor(WorldAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Launches straight into fullscreen (ADR-086: "langsung otomatis masuk mode full screen") rather
/// than the default windowed launch. `applicationDidFinishLaunching` fires once AppKit's own launch
/// sequence completes, but SwiftUI's `WindowGroup` window can still land a beat after that — a
/// `DispatchQueue.main.async` (next run-loop turn) is the commonly-reliable point to find it
/// already created; `toggleFullScreen(nil)` is the standard AppKit call, so the player keeps the
/// normal fullscreen exit (green button / Control-Command-F) rather than this being a locked mode.
final class WorldAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first,
                !window.styleMask.contains(.fullScreen)
            else { return }
            window.toggleFullScreen(nil)
        }
    }
}
