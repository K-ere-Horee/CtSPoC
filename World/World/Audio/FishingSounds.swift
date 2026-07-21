//
//  FishingSounds.swift
//  World
//
//  World-side sound router. Mirrors Rod's FishingHaptics (Rod/Rod/Haptics/FishingHaptics.swift):
//  a single `handle(_:FishingEvent)` switch plus loop-lifecycle helpers keyed to HookPhase — see
//  ADR-040. Sounds are presentation-only and never touch the transport; WorldViewModel calls both
//  this and `send(.fishingEvent(...))` from the same funnel so they can't drift apart.
//

import Foundation
import Shared

@MainActor
final class FishingSounds {

    struct Config {
        /// User decision (ADR-040): the lake ambience plays continuously across the main menu and
        /// gameplay rather than starting only once a session begins.
        var ambiencePlaysInMenu: Bool = true
    }

    /// Seconds `reelFight` takes to fade out once a fight ends (catch, escape, or line break) —
    /// "matikan perlahan music reel fight" (fade the reel-fight music out gently, not an instant
    /// cut). Applied only by `updateReelFightLoop(active:)`'s own natural stop, not the
    /// belt-and-suspenders safety stops below (an abrupt reset like "End Fishing" mid-fight cuts
    /// instantly, matching every other safety stop in this class).
    private static let reelFightFadeDuration: TimeInterval = 1.5

    private let sounds: SoundManager
    private let config: Config
    private var isReelLoopActive = false
    private var isIdleLoopActive = false
    private var isReelFightLoopActive = false

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
            sounds.play(.fishCatched)
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

    /// Loops `idle.wav` while the hook has no fish on it (`HookPhase.idle`/`.hookInWater`) — a
    /// state-specific ambient layer distinct from the game-wide lake ambience (`ambienceLake`,
    /// which also plays at the Main Menu, per `Config.ambiencePlaysInMenu`). Frame-driven, same
    /// pattern as `updateReelLoop(active:)`; `WorldViewModel.tick()` computes the active condition
    /// (`screen == .playing && (hookPhase == .idle || hookPhase == .hookInWater)`) since this
    /// class doesn't track `screen`/`hookPhase` itself.
    func updateIdleLoop(active: Bool) {
        guard active != isIdleLoopActive else { return }
        isIdleLoopActive = active
        if active {
            sounds.startLoop(.idle)
        } else {
            sounds.stopLoop(.idle)
        }
    }

    /// Loops `reel_fight.wav` while a fish is actually hooked (`HookPhase.fishOnHook`/`.reeling`)
    /// — fades out over `reelFightFadeDuration` when the fight ends, rather than cutting
    /// instantly, whether it ended by catch, escape, or line break. Frame-driven, same pattern as
    /// `updateReelLoop(active:)`/`updateIdleLoop(active:)`; `WorldViewModel.tick()` computes the
    /// active condition.
    func updateReelFightLoop(active: Bool) {
        guard active != isReelFightLoopActive else { return }
        isReelFightLoopActive = active
        if active {
            sounds.startLoop(.reelFight)
        } else {
            sounds.stopLoop(.reelFight, fadeDuration: Self.reelFightFadeDuration)
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
        if phase != .idle, phase != .hookInWater {
            sounds.stopLoop(.idle)
            isIdleLoopActive = false
        }
        if phase != .fishOnHook, phase != .reeling {
            // Instant stop here, not the fade — this is the abrupt-reset safety net (recast,
            // "End Fishing," disconnect fail-safe), not the natural end-of-fight transition,
            // which `updateReelFightLoop(active:)` already fades on its own every tick.
            sounds.stopLoop(.reelFight)
            isReelFightLoopActive = false
        }
    }

    /// Starts/stops the lake ambience loop as `WorldViewModel.screen` changes, per `Config`. Also
    /// stops the idle/reel-fight loops on returning to the Main Menu — belt-and-suspenders
    /// alongside their own frame-driven stops, since both are gameplay-only.
    func handleScreenChange(isPlaying: Bool) {
        let shouldPlay = isPlaying || config.ambiencePlaysInMenu
        if shouldPlay {
            sounds.startLoop(.ambienceLake)
        } else {
            sounds.stopLoop(.ambienceLake)
        }
        if !isPlaying {
            sounds.stopLoop(.idle)
            isIdleLoopActive = false
            sounds.stopLoop(.reelFight)
            isReelFightLoopActive = false
        }
    }

    func stopAll() {
        sounds.stopAllLoops()
        isReelLoopActive = false
        isIdleLoopActive = false
        isReelFightLoopActive = false
    }
}
