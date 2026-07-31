# Graph Report - .  (2026-07-31)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1343 nodes · 2422 edges · 147 communities (91 shown, 56 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 192 edges (avg confidence: 0.8)
- Token cost: 117,873 input · 2,463 output

## Graph Freshness
- Built from commit: `023d9980`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AR Fish Preview View
- App Framework Imports
- World Audio Playback
- Rod Haptics Engine
- BLE Central Transport
- World View Model
- Scene Environment Materials
- Rod View Model
- BLE Peripheral Transport
- Fish Species Catalog
- Cast Resolution Logic
- Tutorial & Audio ADRs
- Fish Fight Controller
- Rod State & Calibration Steps
- RodState Coding Keys
- Progression & Onboarding ADRs
- HUD Restyle ADRs
- Rod Motion Interpretation
- Cast/Cutscene Params
- Rod ContentView Fields
- BLE Data Framing
- Rod Motion Input
- Fish Record Store
- Rod Rig Bend/Bone
- Shared Network/Spatial Models
- Fishing Event Types
- Main Menu View
- Theme & Rarity Colors
- Rod Motion Manager
- Rod Rig & NI ADRs
- Water Shader Metal
- Nearby Interaction Session
- Motion Profile Models
- Network Message Contract
- Progression Store
- Transport & Architecture ADRs
- Audio/Haptics Config ADRs
- Transport Error Types
- Hook Phase State Machine
- Catch Cutscene Fish ADRs
- Motion Debug Recorder
- Fishing Line Rope Entity
- HUD Card Design ADRs
- Cast Power Timing ADRs
- Cutscene Camera ADRs
- Rod Yaw Orientation ADRs
- Fishing Line Rope ADRs
- Fish Catch Result
- Fish Species Content ADRs
- Bite/Flick QTE ADRs
- Reel-In & Hook Lift
- Tutorial Step Kinds
- Connection State Enum
- App Icon Assets
- Cutscene & Loading Views
- Catch Resolution Rewards
- Rod State Contracts ADRs
- Pairing & Transport ADRs
- Fight QTE Config ADRs
- Main Menu/UI ADRs
- Fish Info Card View
- Motion Debug Decision
- Line Tension View
- Onboarding View
- Result View
- Tutorial View
- UI Polish ADRs
- Fish Fight Tuning ADRs
- Last Catch Stat Box
- Fish Rarity Enum
- Rod Orientation/Yaw
- Cast Meter View
- Paired Central Store
- Paired Device Store
- Bite Alert View
- Fishing Line Anchor ADRs
- Catch Cutscene Timing ADRs
- Bite Window Haptics ADRs
- World App Delegate
- Motion Debug View
- Catch Cutscene Events
- App Screen States
- Credits View
- Verlet Line ADRs
- Line Tension ADRs
- Cast Zone Colors
- Search Event Types
- Tension Band Enum
- Cast Arming ADRs
- Transport Protocol
- NI Ownership ADRs
- Calibration/Gesture ADRs
- Cutscene Head Offset ADRs
- Result Screen ADRs
- Cutscene Line Removal ADRs
- Cast Distance Config ADRs
- Agent Rules & RodState Doc
- Swift Package Manifest
- Root/Loading Views
- World Audio Subsystem
- Catch Cutscene
- Onboarding & Calibration Guidance
- Fight QTE Flick Prompt
- AR Fish Preview & Sync
- Rod Rig Visual Fixes
- Casting Defers Cutscene
- Fullscreen App Launch
- Cast Resolver Contract
- Gameplay Architecture Contract
- World/Rod Separation
- Shared Swift Package
- RodState Source of Truth
- Motion vs Spatial Data
- RealityKit in World Only
- Rod Reality Independence
- Shared Platform Independence
- Reusable Spatial Controller
- Cast Resolver Boundary
- Rod as Controller, World as Game
- Reel Speed Scaling
- Unified Tension Safe Zone
- CTS Logo (Rod Icon)
- CTS Logo Icon Variant 1
- CTS Logo Icon Variant 2
- CastSolution Model
- FishSpecies Model
- NetworkMessage Model
- Transport Protocol
- FishCatalog
- FishManager (Removed)
- Sky IBL Environment Map
- Water Normal Map Texture
- Loading Screen Image
- CTS Logo (World Menu)
- Main Menu Background Photo
- Roll UI Graphic
- Tutorial Page: Intro
- Tutorial Page: Start Cast
- Tutorial Page: Cast
- Tutorial Page: Wait
- Tutorial Page: Reel Fight
- Tutorial Page: End
- CTS Logo (World App Icon)
- CTS Logo 128x128 Icon
- CTS Logo 16x16 Icon
- Level-Up Banner View

## God Nodes (most connected - your core abstractions)
1. `WorldViewModel` - 90 edges
2. `RodViewModel` - 53 edges
3. `FishFightController` - 42 edges
4. `TransportClient` - 39 edges
5. `TransportHost` - 37 edges
6. `FishPreviewViewModel` - 31 edges
7. `NetworkMessage` - 26 edges
8. `FishSpecies` - 24 edges
9. `FishingEvent` - 24 edges
10. `RodState` - 24 edges

## Surprising Connections (you probably didn't know these)
- `ADR-095: Cast Meter Restyled, Fish Counter Badge Added` --references--> `FishCounterBadgeView (deleted ADR-137)`  [EXTRACTED]
  ARCHITECTURE_DECISIONS.md → World/World/Views/FishCounterBadgeView.swift
- `ADR-100: One Card Design Language Across HUD` --references--> `FishCounterBadgeView (deleted ADR-137)`  [EXTRACTED]
  ARCHITECTURE_DECISIONS.md → World/World/Views/FishCounterBadgeView.swift
- `ADR-037: Fish Tiers and Progression` --references--> `FishCatalog`  [EXTRACTED]
  SOFTWARE_ARCHITECTURE_DOCUMENT.md → World/World/Gameplay/FishCatalog.swift
- `Fish sign UI image` --conceptually_related_to--> `FishCatalog`  [AMBIGUOUS]
  World/World/Assets/Images/fish_sign.png → World/World/Gameplay/FishCatalog.swift
- `Scott celebration image` --conceptually_related_to--> `FishCatalog`  [AMBIGUOUS]
  World/World/Assets/Images/scott_yeah.png → World/World/Gameplay/FishCatalog.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **HUD Card Design Language Consistency Pass** — adr_098, adr_099, adr_100, adr_101, adr_102, adr_103, adr_104, adr_105, adr_132 [INFERRED 0.85]
- **Fishing Line/Rope Anchor Bug Investigation Chain** — adr_106, adr_107, adr_108, adr_109, adr_110, adr_111, adr_112, adr_113, adr_114 [INFERRED 0.85]
- **Catch cutscene design evolution (ADR-045 through ADR-077)** — architecture_decisions_adr_045, architecture_decisions_adr_046, architecture_decisions_adr_047, architecture_decisions_adr_048, architecture_decisions_adr_068, architecture_decisions_adr_069, architecture_decisions_adr_070, architecture_decisions_adr_071, architecture_decisions_adr_072, architecture_decisions_adr_073, architecture_decisions_adr_074, architecture_decisions_adr_075, architecture_decisions_adr_076 [INFERRED 0.85]
- **Fish fight difficulty/tension tuning passes sharing FishFightConfig** — architecture_decisions_adr_039, architecture_decisions_adr_053, architecture_decisions_adr_054, architecture_decisions_adr_060, architecture_decisions_adr_067, architecture_decisions_fishfightconfig, architecture_decisions_fishfightcontroller [INFERRED 0.85]
- **Cast power/direction mechanic iterations from distance-based to oscillating timing meter** — architecture_decisions_adr_032, architecture_decisions_adr_033, architecture_decisions_adr_034, architecture_decisions_adr_050, architecture_decisions_adr_054, architecture_decisions_adr_056, architecture_decisions_adr_057, architecture_decisions_castresolver, architecture_decisions_rodmotioninterpreter [INFERRED 0.85]
- **Flick/QTE Mechanic Iterative Redesign** — checkpoint_adr078, checkpoint_adr088, checkpoint_adr089, checkpoint_adr090, checkpoint_adr091, checkpoint_adr092, checkpoint_adr093, checkpoint_adr094, checkpoint_fishfightcontroller, checkpoint_rodviewmodel [EXTRACTED 0.85]
- **Fishing Line/Rope Physics Debugging Saga** — checkpoint_adr106, checkpoint_adr107, checkpoint_adr108, checkpoint_adr109, checkpoint_adr110, checkpoint_adr112, checkpoint_adr113, checkpoint_adr114, checkpoint_fishinglinerope, checkpoint_rodrigcontroller, checkpoint_worldviewmodel [EXTRACTED 0.85]
- **Unified Dark-Brown Card HUD Design Language Pass** — checkpoint_adr095, checkpoint_adr096, checkpoint_adr097, checkpoint_adr098, checkpoint_adr099, checkpoint_adr100, checkpoint_adr101, checkpoint_adr102, checkpoint_adr103, checkpoint_adr104, checkpoint_adr105, checkpoint_castmeterview, checkpoint_linetensionview, checkpoint_resultview, checkpoint_bitealertview, checkpoint_fishcounterbadgeview, checkpoint_lastcatchstatboxview [EXTRACTED 0.85]
- **Catch The Scott app icon size variants (AppIcon.appiconset)** — world_world_assets_appicon_cts_logo_256x256_1, world_world_assets_appicon_cts_logo_256x256, world_world_assets_appicon_cts_logo_32x32_1, world_world_assets_appicon_cts_logo_32x32, world_world_assets_appicon_cts_logo_512x512_1, world_world_assets_appicon_cts_logo_512x512, world_world_assets_appicon_cts_logo_64x64 [EXTRACTED 0.90]

## Communities (147 total, 56 thin omitted)

### Community 0 - "AR Fish Preview View"
Cohesion: 0.05
Nodes (41): AnchorEntity, Context, Image, Coordinator, FishPreviewARViewContainer, ARView, CaughtSpeciesStore, Set (+33 more)

### Community 1 - "App Framework Imports"
Cohesion: 0.05
Nodes (33): App, AppKit, ARKit, Combine, CoreBluetooth, Identifiable, ImageIO, NearbyInteraction (+25 more)

### Community 2 - "World Audio Playback"
Cohesion: 0.08
Nodes (28): AVAudioPlayer, AVFoundation, FishingSounds, Bool, Float, TimeInterval, Category, ambience (+20 more)

### Community 3 - "Rod Haptics Engine"
Cohesion: 0.09
Nodes (17): CHHapticEngine, CoreHaptics, FightBand, high, low, medium, FishingHaptics, Date (+9 more)

### Community 4 - "BLE Central Transport"
Cohesion: 0.10
Nodes (19): Any, CBCentralManager, CBCentralManagerDelegate, CBPeripheral, CBPeripheralDelegate, NSNumber, QueuedSend, Bool (+11 more)

### Community 5 - "World View Model"
Cohesion: 0.09
Nodes (20): AnimationPlaybackController, EventSubscription, RealityViewContentProtocol, .content, Bool, Date, Double, Entity (+12 more)

### Community 6 - "Scene Environment Materials"
Cohesion: 0.13
Nodes (18): CustomMaterial, Metal, NSColor, UIColor, DockProp, EnvironmentSceneBuilder, platformColor(), ScatterInstance (+10 more)

### Community 7 - "Rod View Model"
Cohesion: 0.11
Nodes (12): .body, .fishingButton, .tutorialControls, RodViewModel, .hasPairedDevice, .pairedDeviceShortID, .reelCalibrationRange, Bool (+4 more)

### Community 8 - "BLE Peripheral Transport"
Cohesion: 0.12
Nodes (14): CBATTRequest, CBCentral, CBMutableCharacteristic, CBPeripheralManager, CBPeripheralManagerDelegate, Bool, CBCharacteristic, CBService (+6 more)

### Community 9 - "Fish Species Catalog"
Cohesion: 0.13
Nodes (19): CaseIterable, FishRarity, FishPickerView, .body, Void, FishCatalog, Set, FishSpecies (+11 more)

### Community 10 - "Cast Resolution Logic"
Cohesion: 0.18
Nodes (13): Sendable, CastConfig, CastMeterConfig, CastResolver, CastSnapshot, CastSolution, CastVector3, .length (+5 more)

### Community 11 - "Tutorial & Audio ADRs"
Cohesion: 0.13
Nodes (19): ADR-040: SoundManager/FishingSounds Audio, ADR-121: Rod Touch-Lock + Symmetric Tension Gauge, ADR-122: Catch Cutscene Audio Ducking, ADR-126: Catch-Cutscene Audio Duck Stuck Fix, ADR-127: AR Fish Preview Screen (Rod-only), ADR-128: World-to-Rod Caught-Species Sync, ADR-129: Fish Preview Export-Quality Audit, ADR-130: Apply Sailfish Baked Transform to 5 Species (+11 more)

### Community 12 - "Fish Fight Controller"
Cohesion: 0.11
Nodes (18): ObservableObject, FightFailure, escaped, lineBreak, FishFightController, .castZone, .caughtSpeciesIDs, .effectiveEscapeDistanceAllowance (+10 more)

### Community 13 - "Rod State & Calibration Steps"
Cohesion: 0.14
Nodes (18): Codable, CalibrationStep, cast, complete, idle, reel, RodAction, casting (+10 more)

### Community 14 - "RodState Coding Keys"
Cohesion: 0.09
Nodes (22): CodingKey, CodingKeys, action, calibrationStep, castHoldDuration, castPower, castSolution, directionX (+14 more)

### Community 15 - "Progression & Onboarding ADRs"
Cohesion: 0.18
Nodes (19): ADR-029: Result Screen, Rod Minimal Interface, Fish Interest, ADR-036: World Main Menu Persisting Scene, ADR-037: Fish Tiers and Progression System, ADR-038: Rod Owns Session Start/End Boundary, ADR-052: Floating Bobber Idle Bob and Interest Dip, ADR-055: Reset Progression Button, ADR-061: Five Playtest Notes Fixes, ADR-063: RodState Short Wire Keys (+11 more)

### Community 16 - "HUD Restyle ADRs"
Cohesion: 0.18
Nodes (18): ADR-095: Cast Meter Restyled, Fish Counter Badge, ADR-096: Fullscreen Gameplay + Floating HUD, ADR-097: Cast Meter/Tension Visuals Swapped Back, ADR-098: Cast Meter Proportional Fill, ADR-099: Line Tension Full-Rectangle Border, ADR-100: Unified Card Design Language, ADR-103: Bite-Window QTE Prompt Restyled, ADR-104: Top HUD Breathing Room (+10 more)

### Community 17 - "Rod Motion Interpretation"
Cohesion: 0.17
Nodes (15): RodMotionPose, RodMotionInterpretation, RodMotionPhase, backswing, casting, charging, followThrough, forwardSwing (+7 more)

### Community 19 - "Rod ContentView Fields"
Cohesion: 0.18
Nodes (11): ContentView, .calibrationButtonTitle, .calibrationInstruction, .developerDetails, .isReelFightActive, .pairedDeviceRow, .startCastingButton, Bool (+3 more)

### Community 20 - "BLE Data Framing"
Cohesion: 0.15
Nodes (9): QueuedSend, CheckedContinuation, Data, Int, Void, BLEFraming, BLEMessageReassembler, Data (+1 more)

### Community 21 - "Rod Motion Input"
Cohesion: 0.24
Nodes (9): .motionInput, Classification, cast, idle, reel, RodMotionInput, RodMotionInterpreter, Double (+1 more)

### Community 23 - "Fish Record Store"
Cohesion: 0.21
Nodes (7): FishRecordStore, .caughtSpeciesIDs, Bool, Double, Int, Set, String

### Community 24 - "Rod Rig Bend/Bone"
Cohesion: 0.21
Nodes (10): BoneWeight, RodRigController, .tipEndPosition, Bool, Double, Entity, Float, ModelEntity (+2 more)

### Community 25 - "Shared Network/Spatial Models"
Cohesion: 0.12
Nodes (8): Foundation, SpatialStatus, failed, ready, searching, unavailable, updating, SessionConfiguration

### Community 26 - "Fishing Event Types"
Cohesion: 0.12
Nodes (16): FishingEvent, biteAlert, cast, catchFish, fightFlick, fishBite, fishEscaped, fishGaveUp (+8 more)

### Community 27 - "Main Menu View"
Cohesion: 0.18
Nodes (14): ButtonStyle, bundleImage(), String, MainMenuView, .backgroundImage, .body, .destructiveActionsRow, .isRodReady (+6 more)

### Community 28 - "Theme & Rarity Colors"
Cohesion: 0.18
Nodes (11): CGSize, FishRarity, .color, Color, Font, ShadowedLabel, .body, CGFloat (+3 more)

### Community 29 - "Rod Motion Manager"
Cohesion: 0.15
Nodes (11): CoreMotion, RodApp, .body, Scene, MotionManager, .isAvailable, MotionSample, Bool (+3 more)

### Community 30 - "Rod Rig & NI ADRs"
Cohesion: 0.14
Nodes (13): ADR-014: Nearby Interaction Session Ownership (referenced), ADR-016: Whole-Rig Rotation Smoothing (referenced), ADR-019: Rod Root Fixed Camera-Relative Offset (referenced), ADR-033: Cast Direction Derived From Live Rig Geometry, ADR-034: Cast Direction Clamped to Forward Cone, ADR-041: Nearby Interaction Not Load-Bearing for V1, ADR-051: Rod Rig Bend Smoothing, Reel Spin, Line Follow, ADR-076: Cutscene-only Fishing Line Entity (+5 more)

### Community 31 - "Water Shader Metal"
Cohesion: 0.22
Nodes (13): float2, geometry_parameters, surface_parameters, thread, accumulateWave(), waterGeometryModifier(), waterHeightField(), waterSurfaceShader() (+5 more)

### Community 32 - "Nearby Interaction Session"
Cohesion: 0.22
Nodes (7): NINearbyObject, NISession, NISessionDelegate, NearbyInteractionManager, Data, Error, Void

### Community 33 - "Motion Profile Models"
Cohesion: 0.31
Nodes (6): MotionPose, MotionProfile, RodOrientation, Bool, Double, TimeInterval

### Community 34 - "Network Message Contract"
Cohesion: 0.15
Nodes (13): NetworkMessage, caughtSpecies, discoveryToken, fishingEvent, hookPhase, .requiresReliableDelivery, state, tutorialState (+5 more)

### Community 35 - "Progression Store"
Cohesion: 0.23
Nodes (7): Counts, ProgressionStore, .level, .progressTowardNextLevel, .unlockedTiers, Int, Set

### Community 36 - "Transport & Architecture ADRs"
Cohesion: 0.17
Nodes (12): ADR-035: CoreBluetooth Transport Migration, ADR-036: World Main Menu, ADR-038: Rod Owns the Session Boundary, ADR-039: Fish Fight Tuning Config, ADR-041: NI Fields Not Consumed by Gameplay, Completed Sprint 0-8 Roadmap (Archived), Archive README, Spatial Controller Architecture (Superseded) (+4 more)

### Community 37 - "Audio/Haptics Config ADRs"
Cohesion: 0.24
Nodes (12): ADR-040: World-Side Audio Mirrors Rod Haptics Router, ADR-053: Timed Left/Right Juking Fight Direction, ADR-060: Rod Haptics Maxed to Intensity Ceiling, ADR-065: Idle Ambience & Fish-Fight Music Loops, ADR-067: fish_catched SFX & Tension Easing, ADR-078: Fight Direction Replaced by Flick QTE, FishFightConfig, FishingHaptics (+4 more)

### Community 38 - "Transport Error Types"
Cohesion: 0.17
Nodes (12): Error, ClientError, encodingFailed, notConnected, notReady, MaterialError, noDefaultLibrary, noMetalDevice (+4 more)

### Community 39 - "Hook Phase State Machine"
Cohesion: 0.17
Nodes (10): HookPhase, .allowsCasting, .allowsReeling, fishOnHook, flying, hookInWater, idle, reeling (+2 more)

### Community 40 - "Catch Cutscene Fish ADRs"
Cohesion: 0.22
Nodes (11): ADR-030: Resistance Scales With Rolled Size, ADR-068: Catch Cutscene Plays Real Animated Fish, ADR-069: Caught Fish Faces Rod, Faster Struggle Clip, ADR-071: New Caught Clip Integrated, ADR-072: Fixed Horizontal Showcase Pose, ADR-073: Caught Fish Vertical Hooked-and-Hanging Pose, catchCutsceneFishAnimationSpeed, catchCutsceneFishOrientation (+3 more)

### Community 41 - "Motion Debug Recorder"
Cohesion: 0.24
Nodes (3): Observation, MotionDebugRecorder, MotionDebugSample

### Community 42 - "Fishing Line Rope Entity"
Cohesion: 0.35
Nodes (8): FishingLineRope, .debugFirstPoint, .debugLastPoint, Entity, Float, Int, ModelEntity, SIMD3

### Community 43 - "HUD Card Design ADRs"
Cohesion: 0.24
Nodes (10): ADR-098: Cast Meter Proportional Fill Over Bordered Track, ADR-099: Line Tension Bar Border Whole Rectangle, ADR-100: One Card Design Language Across HUD, ADR-101: Result Screen Joins Card Design Language, ADR-102: Result Screen Restructured Around Scott Mascot, ADR-103: Bite-Window Prompt Restyled, ADR-104: Top HUD Stack Breathing Room, Bite-Window Prompt Centered, ADR-105: FPS/Connection Readout Moves to Bottom-Leading (+2 more)

### Community 44 - "Cast Power Timing ADRs"
Cohesion: 0.42
Nodes (10): ADR-032: Cast Power Weighted by Backswing Distance, ADR-050: Start Casting Arm Requirement, ADR-054: Cast Hold Timer, Stronger Haptics, Eased Difficulty, ADR-056: Cast Power Drops Flick Bonus, ADR-057: Cast Power Timing Mini-Game, ADR-066: Cast Distance Floor Raised, CastMeterView, CastResolver (+2 more)

### Community 45 - "Cutscene Camera ADRs"
Cohesion: 0.27
Nodes (10): ADR-039: Fight Difficulty Pass (Tug-of-War, Escape, Haptics, Camera), ADR-046: Cutscene Camera Cuts to Hook, ADR-047: Cutscene Holds Fish at Jump Peak, ADR-048: Cutscene Letterboxing, Camera Push-In, Title Flourish, ADR-070: Slow-Motion Envelope During Freeze Phase, ADR-074: Slow-Motion Dip & Hook Stays Attached to Fish, catchCutsceneTimeDilation(elapsed:), CatchCutsceneView (+2 more)

### Community 46 - "Rod Yaw Orientation ADRs"
Cohesion: 0.28
Nodes (9): ADR-079: Rod Root Yaw-Only Rotation, ADR-080: Cast Direction Follows Rod Yaw, ADR-082: Loading Screen, ADR-084: Ambient Sound Redesign, ADR-085: Deferred Start Casting Guard, FishingSounds, LoadingScreenView, SoundManager (+1 more)

### Community 47 - "Fishing Line Rope ADRs"
Cohesion: 0.31
Nodes (10): ADR-106: Procedural Tip-to-Hook Fishing Line, ADR-107: Cast-Line Robust Look-Rotation Fix, ADR-108: Fishing Line Becomes a Verlet Rope, ADR-109: Line In-Water Only, Bobber Hook, ADR-110: Line Anchor Fixed to True Rod Tip, ADR-112: Rope Anchor Bug Investigation, ADR-113: Debug Marker Double-Transform Bug, ADR-114: tipEntity Never Added to Scene Hierarchy (+2 more)

### Community 48 - "Fish Catch Result"
Cohesion: 0.20
Nodes (9): Equatable, FishCatchResult, Outcome, caught, escaped, lineBreak, Bool, Double (+1 more)

### Community 49 - "Fish Species Content ADRs"
Cohesion: 0.22
Nodes (9): ADR-037: Fish Tiers and Progression, ADR-118: Eight Real Fish Species Replace Placeholders, FishCatalog (Shared, merged), FishSpecies, FishSpeciesRange, FishCatalog, Fish sign UI image, Scott celebration image (+1 more)

### Community 50 - "Bite/Flick QTE ADRs"
Cohesion: 0.36
Nodes (9): ADR-023: HookPhase Fish Grab, ADR-078: Flick QTE Fish Fight Mechanic, ADR-088: Bite Window, Flick to Set Hook, Three Attempts, ADR-089: Mid-Fight QTE Prompt Removed, Flick Always Eases Tension, ADR-090: Fight-Flick Detection Excludes .reeling, ADR-091: Flick Cooldown, Follow-Through Double-Count Fix, ADR-092: Bite-Alert Haptic Repeats Continuously, ADR-093: Fight-Flick Relief Grace Window After Hooking (+1 more)

### Community 51 - "Reel-In & Hook Lift"
Cohesion: 0.36
Nodes (9): ADR-031: Cast Distance, Fight Distance, Search-Phase Fixes, ADR-042: Reel-In Stays at Water Height Until Near Dock, ADR-043: Hook Lift Targets Dedicated Point, ADR-044: Dock-Approach Lift Fixed Speed, ADR-045: Catch Cutscene as World Presentation State, driftHookAway(deltaTime:), hookLiftDistance, HookPhase (+1 more)

### Community 52 - "Tutorial Step Kinds"
Cohesion: 0.22
Nodes (9): Int, TutorialStepKind, cast, end, intro, reelFight, startCast, waitForBite (+1 more)

### Community 53 - "Connection State Enum"
Cohesion: 0.22
Nodes (8): ConnectionState, connecting, disconnected, failed, idle, ready, searching, streaming

### Community 54 - "App Icon Assets"
Cohesion: 0.22
Nodes (9): Catch The Scott logo icon (256x256), Catch The Scott logo icon (256x256, variant 1), Catch The Scott logo icon (32x32), Catch The Scott logo icon (32x32, variant 1), Catch The Scott logo icon (512x512), Catch The Scott logo icon (512x512, variant 1), Catch The Scott logo icon (64x64), Pufferfish/fish character mascot icon (sailor outfit) used as frame/UI icon (+1 more)

### Community 55 - "Cutscene & Loading Views"
Cohesion: 0.22
Nodes (7): .body, CatchCutsceneView, .body, CGFloat, Double, LoadingScreenView, .body

### Community 56 - "Catch Resolution Rewards"
Cohesion: 0.25
Nodes (4): .speciesProgressEntries, Double, Int, String

### Community 57 - "Rod State Contracts ADRs"
Cohesion: 0.25
Nodes (8): ADR-033: Launch Heading from Cast Direction, ADR-034: Tip-Position Vector / Cone Clamp, ADR-079: Rod Root Yaw-Only Orientation, ADR-080: Launch Heading Follows Live Rod Yaw, ADR-117: Tutorial Rebuilt, Once Per Progression Cycle, Calibration and Orientation Contract, Casting State and Transform Contract, RodState (Shared model)

### Community 58 - "Pairing & Transport ADRs"
Cohesion: 0.43
Nodes (8): ADR-035: Transport Replaced MultipeerConnectivity to CoreBluetooth, ADR-049: Device Pairing Allowlist Over CoreBluetooth, ADR-062: Forget Paired Mac Recovery Path, BLEFraming, PairedCentralStore, PairedDeviceStore, TransportClient, TransportHost

### Community 59 - "Fight QTE Config ADRs"
Cohesion: 0.36
Nodes (8): ADR-078: Flick QTE Replaces Fight Direction, ADR-089: Mid-Fight QTE Removed, Unconditional Flick, ADR-090: Reeling Misfiring as Flick Fix, ADR-091: Flick Cooldown, ADR-093: Fight-Flick Grace Window, ADR-094: Fight-Flick Detection Disabled Entirely, FishFightConfig (Shared), FishFightController

### Community 60 - "Main Menu/UI ADRs"
Cohesion: 0.32
Nodes (8): ADR-081: Main Menu Restyled, ADR-086: Fullscreen Launch, ADR-087: Merge PR#7 ui-slice into main, ADR-117: Tutorial Rebuilt, Rod-Driven Buttons, MainMenuView, Theme.swift (design tokens), TutorialView, WorldApp / WorldAppDelegate

### Community 61 - "Fish Info Card View"
Cohesion: 0.32
Nodes (7): FishInfoCardView, .body, .lengthText, .rarityBadge, .weightText, String, Void

### Community 62 - "Motion Debug Decision"
Cohesion: 0.39
Nodes (6): MotionDebugDecision, Bool, Double, String, TimeInterval, .emptyDebug

### Community 63 - "Line Tension View"
Cohesion: 0.29
Nodes (7): LineTensionView, .body, .warningLabel, Bool, CGFloat, Float, String

### Community 64 - "Onboarding View"
Cohesion: 0.25
Nodes (7): OnboardingView, .isLastPage, .pageDots, Page, Bool, String, Void

### Community 65 - "Result View"
Cohesion: 0.29
Nodes (6): ResultView, .body, .greeting, .starsRow, .statsCard, String

### Community 66 - "Tutorial View"
Cohesion: 0.36
Nodes (7): CGFloat, Int, String, TutorialStep, TutorialView, .body, .steps

### Community 67 - "UI Polish ADRs"
Cohesion: 0.52
Nodes (7): ADR-081: Main Menu Restyled, Background Photo and Stacked Buttons, ADR-082: Loading Screen Covers Initial Async Asset Load, ADR-084: Ambient Sound Redesigned, ADR-087: Fredoka Font Registration, ADR-095: Cast Meter Restyled, Fish Counter Badge Added, ADR-096: Gameplay Scene Fullscreen, HUD Floating Overlay, ADR-097: Cast Meter and Line Tension Visuals Swapped Back

### Community 68 - "Fish Fight Tuning ADRs"
Cohesion: 0.38
Nodes (7): ADR-119: Species-Scaled Fight Speed + Progress HUD, ADR-120: Run Speed/Bluefin Orientation/Splash Volume, ADR-136: Fish Fight Retuned, ADR-137: Tier Level-Up Banner Removed, FishFightConfig, FishCounterBadgeView (deleted ADR-137), LevelUpBannerView (deleted)

### Community 69 - "Last Catch Stat Box"
Cohesion: 0.33
Nodes (4): Configuration, View, LastCatchStatBoxView, .body

### Community 70 - "Fish Rarity Enum"
Cohesion: 0.29
Nodes (6): FishRarity, common, .displayName, epic, legendary, rare

### Community 71 - "Rod Orientation/Yaw"
Cohesion: 0.48
Nodes (3): RodOrientation, simd_quatf, .catchCutsceneFishOrientation

### Community 72 - "Cast Meter View"
Cohesion: 0.33
Nodes (7): CastMeterView, .body, .isVisible, Bool, CGFloat, Float, TimeInterval

### Community 74 - "Paired Device Store"
Cohesion: 0.47
Nodes (3): PairedDeviceStore, String, UUID

### Community 75 - "Bite Alert View"
Cohesion: 0.40
Nodes (5): BiteAlertView, .body, Bool, CGFloat, Float

### Community 76 - "Fishing Line Anchor ADRs"
Cohesion: 0.60
Nodes (5): ADR-110: Line Anchor Fixed to Rod's True Tip End, ADR-111: rod_line.usdz Doubled Rotation Fix, ADR-112: Rope Anchor Investigation Continues, ADR-113: Debug Marker Double-Transform Bug Fixed, ADR-114: tipEntity Never Added to Scene Hierarchy

### Community 77 - "Catch Cutscene Timing ADRs"
Cohesion: 0.40
Nodes (5): ADR-073: Catch Cutscene Vertical Orientation, ADR-074: Ending Slow-Motion + Hook/Line Attachment, ADR-075: Cutscene Retuned to 5 Seconds, ADR-076: Dedicated Cutscene Line, ADR-077: Cutscene Line Removed

### Community 78 - "Bite Window Haptics ADRs"
Cohesion: 0.47
Nodes (6): ADR-088: Bite Window Flick-to-Hook, ADR-092: Continuous Bite Alert Haptic, FishingEvent (Shared), FishingHaptics, HapticManager, RodViewModel

### Community 79 - "World App Delegate"
Cohesion: 0.40
Nodes (4): Notification, NSApplicationDelegate, NSObject, WorldAppDelegate

### Community 80 - "Motion Debug View"
Cohesion: 0.50
Nodes (4): MotionDebugView, .body, Double, String

### Community 82 - "App Screen States"
Cohesion: 0.40
Nodes (5): Screen, loading, mainMenu, onboarding, playing

### Community 83 - "Credits View"
Cohesion: 0.50
Nodes (4): CreditsEntry, CreditsView, String, Void

### Community 84 - "Verlet Line ADRs"
Cohesion: 0.67
Nodes (4): ADR-106: Procedural Tip-to-Hook Fishing Line, ADR-107: Cast-Line Orientation Fix, Robust Look-Rotation, ADR-108: Fishing Line Becomes Verlet Rope, ADR-109: Line Shown Only In-Water, Hook Becomes Leaning Bobber

### Community 85 - "Line Tension ADRs"
Cohesion: 0.67
Nodes (4): ADR-024: Escape Timer and Reel-Speed Line Break, ADR-026: FishSpecies Data Model and Continuous Line Tension, ADR-027: Line Tension Tracks Fight Duration, ADR-028: Unified Tension Safe Zone

### Community 86 - "Cast Zone Colors"
Cohesion: 0.50
Nodes (4): CastZone, green, red, yellow

### Community 87 - "Search Event Types"
Cohesion: 0.50
Nodes (4): SearchEvent, biteAlert, gaveUp, interested

### Community 88 - "Tension Band Enum"
Cohesion: 0.50
Nodes (4): TensionBand, high, low, medium

### Community 89 - "Cast Arming ADRs"
Cohesion: 0.67
Nodes (3): ADR-050: Cast Must Be Explicitly Armed, ADR-057: Cast Power Oscillation Timing Meter, ADR-061: Cast Meter Starts Instantly on Arm

### Community 91 - "NI Ownership ADRs"
Cohesion: 0.67
Nodes (3): ADR-014: Nearby Interaction Ownership, ADR-021: Debug First, ADR-041: NI Spatial Fields Unused in Gameplay

### Community 92 - "Calibration/Gesture ADRs"
Cohesion: 0.67
Nodes (3): ADR-016: Calibration-Owned Orientation, ADR-018: Gesture Charging and Transform Separation, ADR-019: Controller Root and Hook Simulation Separation

### Community 93 - "Cutscene Head Offset ADRs"
Cohesion: 0.67
Nodes (3): ADR-075: Cutscene Duration & Hook Repositioning, catchCutsceneSettleDuration, caughtFishHeadOffset

### Community 94 - "Result Screen ADRs"
Cohesion: 1.00
Nodes (3): ADR-101: Result Screen Joins Card Design, ADR-102: Result Screen Scott Mascot, ResultView

## Ambiguous Edges - Review These
- `ADR-078: Flick QTE Fish Fight Mechanic` → `ADR-023: HookPhase Fish Grab`  [AMBIGUOUS]
  GAMEPLAY_ARCHITECTURE_V1.md · relation: references
- `ADR-040: World-Side Audio Mirrors Rod Haptics Router` → `ADR-038: Rod Owns Session Start/End Boundary`  [AMBIGUOUS]
  ARCHITECTURE_DECISIONS.md · relation: references
- `ADR-014: Nearby Interaction Ownership` → `ADR-021: Debug First`  [AMBIGUOUS]
  ARCHITECTURE_DECISIONS.md · relation: conceptually_related_to
- `FishCatalog` → `Fish sign UI image`  [AMBIGUOUS]
  World/World/Assets/Images/fish_sign.png · relation: conceptually_related_to
- `FishCatalog` → `Scott celebration image`  [AMBIGUOUS]
  World/World/Assets/Images/scott_yeah.png · relation: conceptually_related_to
- `Catch The Scott logo icon (256x256)` → `Pufferfish/fish character mascot icon (sailor outfit) used as frame/UI icon`  [AMBIGUOUS]
  World/World/Assets.xcassets/Image/FrameIcon.imageset/frame.png · relation: conceptually_related_to
- `Pufferfish/fish character mascot icon (sailor outfit) used as frame/UI icon` → `HandTutor tutorial image (largely blank/transparent, likely a hand gesture illustration on transparent background)`  [AMBIGUOUS]
  World/World/Assets.xcassets/Image/HandTutor.imageset/HandTutor.png · relation: conceptually_related_to

## Knowledge Gaps
- **302 isolated node(s):** `.isReelFightActive`, `.calibrationInstruction`, `.calibrationButtonTitle`, `low`, `medium` (+297 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **56 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `ADR-078: Flick QTE Fish Fight Mechanic` and `ADR-023: HookPhase Fish Grab`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `ADR-040: World-Side Audio Mirrors Rod Haptics Router` and `ADR-038: Rod Owns Session Start/End Boundary`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `ADR-014: Nearby Interaction Ownership` and `ADR-021: Debug First`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `FishCatalog` and `Fish sign UI image`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `FishCatalog` and `Scott celebration image`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Catch The Scott logo icon (256x256)` and `Pufferfish/fish character mascot icon (sailor outfit) used as frame/UI icon`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Pufferfish/fish character mascot icon (sailor outfit) used as frame/UI icon` and `HandTutor tutorial image (largely blank/transparent, likely a hand gesture illustration on transparent background)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._