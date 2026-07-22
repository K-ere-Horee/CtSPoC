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

    /// Seconds `reelFight` takes to fade out once a fight ends (catch, escape, or line break) —
    /// "matikan perlahan music reel fight" (fade the reel-fight music out gently, not an instant
    /// cut). Applied only by `updateReelFightLoop(active:)`'s own natural stop, not the
    /// belt-and-suspenders safety stops below (an abrupt reset like "End Fishing" mid-fight cuts
    /// instantly, matching every other safety stop in this class).
    private static let reelFightFadeDuration: TimeInterval = 1.5

    private let sounds: SoundManager
    private var isReelLoopActive = false
    private var isAmbienceLoopActive = false
    private var isIdleLoopActive = false
    private var isReelFightLoopActive = false

    init(sounds: SoundManager) {
        self.sounds = sounds
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
        case .fightFlick:
            // Rod -> World only; no dedicated asset needed (ADR-089) — a flick easing tension
            // mid-fight doesn't need its own confirmation sound.
            break
        case .biteAlert, .hookSet:
            // No dedicated asset (ADR-088) — the HUD banner (`BiteAlertView`) and Rod's own big
            // haptic already cover the cue. `fishBite`'s own sound is reserved for the moment the
            // fish is actually hooked (still fired from the `.fishBite` event, now only once
            // `handleHookSetFlick()` succeeds), not every attempt.
            break
        case .fishGaveUp:
            // No dedicated asset (ADR-088) — stops the interest bubble loop so it doesn't keep
            // looping for a fish that's no longer there; Rod's own soft haptic covers the cue.
            sounds.stopLoop(.fishInterestedLoop)
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

    /// Loops `ambience_lake.mp3` while `WorldViewModel.screen == .playing` (ADR-084 amendment) —
    /// gameplay's continuous background bed, alongside `reelFight` during an actual fight. Silent
    /// during `.loading` and at the Main Menu/Onboarding, where `idle` plays instead — the two
    /// never overlap and one of them is always active whenever the other isn't. Frame-driven, same
    /// pattern as `updateReelLoop(active:)`.
    func updateAmbienceLoop(active: Bool) {
        guard active != isAmbienceLoopActive else { return }
        isAmbienceLoopActive = active
        if active {
            sounds.startLoop(.ambienceLake)
        } else {
            sounds.stopLoop(.ambienceLake)
        }
    }

    /// Loops `idle.wav` while `WorldViewModel.screen` is `.mainMenu`/`.onboarding` (ADR-084) — the
    /// menu's own ambient sound, replacing `ambienceLake` there specifically. Also silent during
    /// `.loading` and `.playing`, by the same active-condition computation. Frame-driven, same
    /// pattern as `updateReelLoop(active:)`; `WorldViewModel.tick()` computes the active condition
    /// since this class doesn't track `screen` itself.
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
    /// `idle` is deliberately not touched here (ADR-084) — its lifecycle is purely `screen`-driven
    /// via `updateIdleLoop(active:)`, not `HookPhase`-driven, so a phase transition alone should
    /// never start or stop it.
    func handlePhaseChange(_ phase: HookPhase) {
        if phase != .hookInWater {
            sounds.stopLoop(.fishInterestedLoop)
        }
        if phase != .hookInWater, phase != .fishOnHook, phase != .reeling {
            sounds.stopLoop(.reelLoop)
            isReelLoopActive = false
        }
        if phase != .fishOnHook, phase != .reeling {
            // Instant stop here, not the fade — this is the abrupt-reset safety net (recast,
            // "End Fishing," disconnect fail-safe), not the natural end-of-fight transition,
            // which `updateReelFightLoop(active:)` already fades on its own every tick.
            sounds.stopLoop(.reelFight)
            isReelFightLoopActive = false
        }
    }

    func stopAll() {
        sounds.stopAllLoops()
        isReelLoopActive = false
        isAmbienceLoopActive = false
        isIdleLoopActive = false
        isReelFightLoopActive = false
    }
}
