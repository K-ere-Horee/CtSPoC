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
        /// Loops while `WorldViewModel.screen == .playing` (ADR-084/amendment) — gameplay's
        /// continuous background bed, alongside `reelFight` during an actual fight. See
        /// `FishingSounds.updateAmbienceLoop(active:)`.
        case ambienceLake = "ambience_lake"
        /// Loops while `WorldViewModel.screen` is `.mainMenu`/`.onboarding` (ADR-084) — the menu's
        /// own ambient loop, replacing `ambienceLake` there specifically (menu and gameplay each
        /// have exactly one base ambience, never both, never neither). See
        /// `FishingSounds.updateIdleLoop(active:)`.
        case idle = "idle"
        /// Loops while a fish is actually hooked (`HookPhase.fishOnHook`/`.reeling`), fading out
        /// (not cutting instantly) once the fight ends — see
        /// `FishingSounds.updateReelFightLoop(active:)`.
        case reelFight = "reel_fight"
        /// One-shot, alongside (not replacing) `catchSplash`, the moment a fish is landed — see
        /// `FishingSounds.handle(_:)`'s `.catchFish` case.
        case fishCatched = "fish_catched"

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
            case .idle, .reelFight: return 0.3
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

    /// `fadeDuration` (seconds) > 0 ramps the volume down smoothly before actually stopping,
    /// instead of cutting the loop instantly — used for `reelFight`, which should fade out rather
    /// than abruptly cut off the instant a fight ends. The player's volume is restored to its
    /// normal effective volume once stopped, so the next `startLoop` isn't silently silent.
    func stopLoop(_ sound: Sound, fadeDuration: TimeInterval = 0) {
        guard let player = players[sound], player.isPlaying else { return }
        guard fadeDuration > 0 else {
            player.stop()
            player.currentTime = 0
            return
        }
        let restoreVolume = effectiveVolume(for: sound)
        player.setVolume(0, fadeDuration: fadeDuration)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(fadeDuration))
            player.stop()
            player.currentTime = 0
            player.volume = restoreVolume
        }
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
