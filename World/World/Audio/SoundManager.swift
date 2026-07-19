//
//  SoundManager.swift
//  World
//
//  Low-level SFX playback. Mirrors Rod's HapticManager (Rod/Rod/Haptics/HapticManager.swift):
//  one preloaded player per primitive, no gameplay knowledge — see ADR-040.
//

import AVFoundation

@MainActor
final class SoundManager {

    enum Category {
        case ui
        case effects
        case ambience
    }

    /// rawValue matches the bundled resource's filename (without extension) under
    /// `World/World/Assets/SFX/` — both Xcode projects auto-bundle anything placed inside the
    /// synchronized `World/World/` root group, so no pbxproj resource entries are needed.
    enum Sound: String, CaseIterable {
        case uiClick = "ui_click"
        case castThrow = "cast_throw"
        case hookSplash = "hook_splash"
        case fishInterestedLoop = "fish_interested_loop"
        case fishBite = "fish_bite"
        case reelLoop = "reel_loop"
        case catchSplash = "catch_splash"
        case ambienceLake = "ambience_lake"

        var category: Category {
            switch self {
            case .uiClick: return .ui
            case .ambienceLake: return .ambience
            default: return .effects
            }
        }

        var fileExtension: String {
            self == .ambienceLake ? "mp3" : "wav"
        }

        var defaultVolume: Float {
            switch self {
            case .ambienceLake: return 0.35
            case .fishInterestedLoop, .reelLoop: return 0.5
            default: return 0.85
            }
        }
    }

    private var players: [Sound: AVAudioPlayer] = [:]
    private var categoryVolumeMultipliers: [Category: Float] = [.ui: 1, .effects: 1, .ambience: 1]

    init() {
        #if os(iOS)
        configureAudioSession()
        #endif
        preloadPlayers()
    }

    #if os(iOS)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }
    #endif

    private func preloadPlayers() {
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: sound.fileExtension) else {
                continue
            }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = sound.defaultVolume
            player.prepareToPlay()
            players[sound] = player
        }
    }

    private func effectiveVolume(for sound: Sound) -> Float {
        sound.defaultVolume * (categoryVolumeMultipliers[sound.category] ?? 1)
    }

    /// Plays a one-shot from the start, retriggering it if it's already mid-playback — sufficient
    /// here since no one-shot in the gameplay mapping needs true overlapping instances (see
    /// ADR-040).
    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        player.numberOfLoops = 0
        player.volume = effectiveVolume(for: sound)
        player.currentTime = 0
        player.play()
    }

    /// Idempotent — calling this while the loop is already playing is a no-op.
    func startLoop(_ sound: Sound) {
        guard let player = players[sound] else { return }
        guard !player.isPlaying else { return }
        player.numberOfLoops = -1
        player.volume = effectiveVolume(for: sound)
        player.play()
    }

    func stopLoop(_ sound: Sound) {
        guard let player = players[sound], player.isPlaying else { return }
        player.stop()
        player.currentTime = 0
    }

    func stopAllLoops() {
        for sound in Sound.allCases where sound.category != .ui {
            stopLoop(sound)
        }
    }

    func setVolume(_ volume: Float, for category: Category) {
        categoryVolumeMultipliers[category] = volume
        for sound in Sound.allCases where sound.category == category {
            players[sound]?.volume = effectiveVolume(for: sound)
        }
    }
}
