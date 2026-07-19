//
//  FishingSounds.swift
//  World
//
//  World-side sound router. Mirrors Rod's FishingHaptics (Rod/Rod/Haptics/FishingHaptics.swift):
//  a single `handle(_:FishingEvent)` switch plus loop-lifecycle helpers keyed to HookPhase — see
//  ADR-040. Sounds are presentation-only and never touch the transport; WorldViewModel calls both
//  this and `send(.fishingEvent(...))` from the same funnel so they can't drift apart.
//

import Shared

@MainActor
final class FishingSounds {

    struct Config {
        /// User decision (ADR-040): the lake ambience plays continuously across the main menu and
        /// gameplay rather than starting only once a session begins.
        var ambiencePlaysInMenu: Bool = true
    }

    private let sounds: SoundManager
    private let config: Config
    private var isReelLoopActive = false

    init(sounds: SoundManager, config: Config = Config()) {
        self.sounds = sounds
        self.config = config
    }

    /// Mirrors `FishingHaptics.handle(_:)`. `.cast` and `.reelTick` are Rod-local events World
    /// never emits (see `castLaunched()` below for the World-side cast trigger); tension-band
    /// events stay haptic-only for now, routed through here for symmetry with the send funnel.
    func handle(_ event: FishingEvent) {
        switch event {
        case .cast, .reelTick:
            break
        case .hookSplash:
            sounds.play(.hookSplash)
        case .fishInterested:
            sounds.startLoop(.fishInterestedLoop)
        case .fishBite:
            sounds.stopLoop(.fishInterestedLoop)
            sounds.play(.fishBite)
        case .fishEscaped, .lineBreak:
            // No dedicated asset yet (ADR-040) — reuse the water splash so an escape/line break
            // still reads as the fish darting off, rather than staying silent.
            sounds.stopLoop(.fishInterestedLoop)
            sounds.stopLoop(.reelLoop)
            sounds.play(.hookSplash)
        case .catchFish:
            sounds.stopLoop(.reelLoop)
            sounds.play(.catchSplash)
        case .reelTensionLow, .reelTensionMedium, .reelTensionHigh:
            break
        }
    }

    /// World never emits a `.cast` FishingEvent (that's generated Rod-side from motion), so the
    /// cast sound is triggered directly from `WorldViewModel.launchHook(solution:)`.
    func castLaunched() {
        sounds.play(.castThrow)
    }

    func uiClick() {
        sounds.play(.uiClick)
    }

    /// Called every tick with whether the player is actively reeling in a reel-legal phase.
    /// Frame-driven rather than event-driven so empty-line retrieves during `.hookInWater` (no
    /// fish on hook yet) also get the reel sound, not just the fight-reeling case.
    func updateReelLoop(active: Bool) {
        guard active != isReelLoopActive else { return }
        isReelLoopActive = active
        if active {
            sounds.startLoop(.reelLoop)
        } else {
            sounds.stopLoop(.reelLoop)
        }
    }

    /// Belt-and-suspenders safety stop, mirroring `FishingHaptics.stopInterest()`/`stopFight()`:
    /// called from `setHookPhase(_:)` so a stale bubble/reel loop can never survive a phase
    /// transition, however it happened (recast, catch, escape, "End Fishing," disconnect fail-safe).
    func handlePhaseChange(_ phase: HookPhase) {
        if phase != .hookInWater {
            sounds.stopLoop(.fishInterestedLoop)
        }
        if phase != .hookInWater, phase != .fishOnHook, phase != .reeling {
            sounds.stopLoop(.reelLoop)
            isReelLoopActive = false
        }
    }

    /// Starts/stops the lake ambience loop as `WorldViewModel.screen` changes, per `Config`.
    func handleScreenChange(isPlaying: Bool) {
        let shouldPlay = isPlaying || config.ambiencePlaysInMenu
        if shouldPlay {
            sounds.startLoop(.ambienceLake)
        } else {
            sounds.stopLoop(.ambienceLake)
        }
    }

    func stopAll() {
        sounds.stopAllLoops()
        isReelLoopActive = false
    }
}
