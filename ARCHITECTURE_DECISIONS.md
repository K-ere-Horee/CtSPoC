# ARCHITECTURE_DECISIONS.md

# CtS PoC - Architecture Decision Record (ADR)

Version: 1.0

This document records architectural decisions that are considered stable
for the Catch the Scott Spatial Controller PoC. Future changes should
preserve these decisions unless there is a compelling technical reason
to revise them.

------------------------------------------------------------------------

# ADR-105 --- FPS/Connection Readout Moves to Bottom-Leading, Joins the Card Language

## Decision

The fps counter and connection-state text — previously two loose, differently-styled `Text` views
stacked top-leading (`fpsIndicator` with its own small dark-pill background; the connection text
with no background at all) — merge into one `statusBox`: a single `VStack` (fps line, connection
line) inside a `Self.panelColor`-filled, white-bordered `RoundedRectangle(cornerRadius: 12)`,
matching the dark-card + white-border language every other HUD surface has used since ADR-098.
`ContentView`'s top-leading overlay changes from `VStack(alignment: .leading) { fpsIndicator; Text
(...); Spacer() }` to `VStack(alignment: .leading) { Spacer(); statusBox }`, moving the whole thing
to the bottom-leading corner instead. The standalone `fpsIndicator` computed property and its
ad hoc pill background are removed, folded into `statusBox`.

## Rationale

Requested directly: "sekarang tampila si 120 fps, sama status streaming, itu pindahin ke pojok kiri
bawah, dan tambahin design language yang sama" (now the "120 FPS" display and the "Streaming"
status — move those to the bottom-left corner, and add the same design language). Continues the
same design-consistency pass as ADR-098 through ADR-104 — this readout was the last HUD element
still using ad hoc styling instead of the established card language.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), and an actual launch/`ps`-confirmed-running/quit with no crash. As with every ADR since
ADR-096, final in-context placement (exact corner spacing against the safe area, live fps/
connection-state values) could not be visually confirmed this pass — no Rod device was paired.
Open device-validation gap.

------------------------------------------------------------------------

# ADR-104 --- Top HUD Stack Gets Breathing Room; Bite-Window Prompt Moves to Center Screen

## Decision

Two related layout adjustments, both from the same request:

- The top-center HUD stack (`FishCounterBadgeView`, `CastMeterView`, `LineTensionView`, all
  sharing one `VStack` since ADR-096/097) gains `.padding(.top, 32)` so the whole group sits a
  little below the screen's top edge instead of flush against it — per "cast meter sama reel
  tension turunin kebawah dikit, bersamaan dengan amount of fish caught nya (biar ga terlalu
  nempel ke atas)" (move the cast meter and reel tension down a bit, together with the fish-caught
  count, so it's not too stuck to the top).
- `BiteAlertView` — the "FISH ON! FLICK TO HOOK!" bite-window prompt — is restyled (ADR-103, this
  same change) and its call site in `ContentView` moves out of the bottom-leading stat stack into
  a bare top-level position inside the fading `Group`, which centers it via `ZStack`'s default
  alignment. Per "qte untuk nge flick hp nya ketika fish bite... mau taro tengah apa dimana bebas"
  (the QTE for flicking the phone when the fish bites... place it in the middle or wherever, your
  choice) — center screen was chosen since a QTE-style prompt needs to command full attention the
  instant a bite window opens, more than a corner stat stack does.
- The `lastError` text, previously grouped with `BiteAlertView` in the bottom-leading `HStack`, is
  now its own conditionally-shown bottom-leading overlay so removing `BiteAlertView` from that
  stack didn't leave a broken/empty leftover container.

See ADR-103 for `BiteAlertView`'s visual restyle itself.

## Rationale

Requested directly, as two parts of one message: "sisa satu lagi, yaitu qte untuk nge flick hp nya
ketika fish bite. serah deh, mau taro tengah apa dimana bebas. oya, satu lagi, cast meter sama reel
tension turunin kebawah dikit, bersamaan dengan amount of fish caught nya (biar ga terlalu nempel
ke atas)."

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), and an actual launch/`ps`-confirmed-running/quit with no crash. As with every ADR since
ADR-096, the in-scene gameplay HUD itself could not be visually confirmed this pass — no Rod device
was paired. Open device-validation gap.

------------------------------------------------------------------------

# ADR-103 --- Bite-Window Prompt Restyled to the Established Card Language

## Decision

`BiteAlertView` — the "FISH ON! FLICK TO HOOK!" prompt shown while a bite window is open — moves
from bare `Label`/`.quaternary`-capsule-progress-bar styling to the same dark-brown-card +
white-border language every other HUD surface has adopted since ADR-098 (`CastMeterView`'s track,
`LastCatchStatBoxView`, `ResultView`'s cards): a `Self.panelColor`-filled, white-bordered
`RoundedRectangle(cornerRadius: 20)` card containing a `fish_sign.png` icon beside a bold "FLICK TO
HOOK!" label (shortened from "FISH ON! FLICK TO HOOK!" — the icon now carries the "fish on" half),
and a white-bordered dark track with an orange proportional fill (same clipped-progress-fill
pattern `CastMeterView` uses, ADR-098) instead of the old plain `.quaternary`/`.orange` bar.

## Rationale

Requested directly, alongside the top-HUD-padding change (ADR-104): "sisa satu lagi, yaitu qte
untuk nge flick hp nya ketika fish bite. serah deh, mau taro tengah apa dimana bebas" (one more
thing left — the QTE for flicking the phone when the fish bites. Whatever, place it wherever you
want). The design-consistency pass (ADR-098 through ADR-102) had covered every other HUD element
except this one.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), an actual launch/`ps`-confirmed-running/quit with no crash, and — like ADR-102 — an
offscreen `NSHostingView` snapshot of the exact card markup with the real `fish_sign.png` asset,
used to visually confirm the card reads correctly before committing (throwaway scratchpad script,
not part of the repo). The in-app bite window itself still couldn't be triggered live — requires a
paired Rod device and an active fish bite. Open device-validation gap.

------------------------------------------------------------------------

# ADR-102 --- Result Screen Restructured Around the Scott Mascot

## Decision

`ResultView` is restructured to match a supplied reference: a new `scott_yeah.png` mascot asset
overlaps the top-leading corner of a "You caught an **{species}**" message card (`ZStack(alignment:
.topLeading)`, mascot drawn last/on top, offset `x: -14, y: -30` so it reads as leaning out of the
card's corner rather than sitting flush inside it — the card reserves a leading `Spacer().frame
(width: 88)` so the mascot never overlaps the text itself). Below that, the previous catch stats
(weight, length, star rating, coins, "NEW RECORD") move into their own `statsCard` — same visual
treatment, kept rather than dropped, per "tambahin aja yang details tadi" (just add the previous
details back in). The former single long instruction line ("Press 'Start Casting' on Rod to fish
again") is replaced with a short green pill reading "Press Start Casting" (`Self.ctaColor`, `Color
(red: 0.2, green: 0.78, blue: 0.35)`), matching the reference's button-shaped look — still just a
label, not an interactive control, since nothing on this screen has ever been (see the file's
existing doc comment on why: Rod's own "Start Casting" press is what actually dismisses it).

Both the greeting card and the stats card keep the dark-brown (`Self.panelColor`) + white-border
language ADR-100/101 established for the rest of the HUD.

The mascot's size (`112x112`) and offset were tuned against an offscreen `NSHostingView` render of
the exact view code with the real asset (a throwaway script in the scratchpad, not part of the
repo) before being applied here, since no paired Rod was available to trigger this screen live —
first pass at `130x130`/`offset(-18,-34)` had the mascot's face overlapping "You caught an";
the final values keep the mascot fully clear of the text.

## Rationale

Requested directly, with a reference screenshot and the new `scott_yeah.png` asset already added by
the user: "gue udah nambahin karakter scott_yeah itu. bikin catch nya kaya gini di tengah screen
(tambahin aja yang details tadi, i believe in your design taste)" (I've already added the
scott_yeah character. Make the catch screen look like this, centered on screen — just add the
previous details back in, I trust your design taste).

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), an actual launch/`ps`-confirmed-running/quit with no crash, and — unlike every ADR
since ADR-096 — an actual rendered visual check: an offscreen `NSHostingView` snapshot of the exact
layout with the real `scott_yeah.png`/panel colors, used to tune the mascot's size/offset against
the reference before committing the values to `ResultView.swift`. The in-app screen itself still
couldn't be triggered live (requires a paired Rod device and a resolved catch), so the final
in-context rendering (fonts, safe areas, actual window chrome) remains unconfirmed. Open
device-validation gap.

------------------------------------------------------------------------

# ADR-101 --- Result Screen Joins the Card Design Language Too

## Decision

`ResultView` — the post-catch blocking screen shown at `hookPhase == .result` ("Catch!", species,
weight/length, stars, coins, optional "NEW RECORD", the "Press Start Casting" instruction) — was a
distinct screen from `CatchCutsceneView` (the brief transition immediately before it) and had been
missed by ADR-100's design pass, which only touched the cutscene's title card. `ResultView.card`'s
background changes from `.regularMaterial` (a generic frosted-glass system blur, no border) to the
same `Self.panelColor` dark brown + white 2pt border every other HUD surface now uses. Every `Text`
inside the card that relied on the system's automatic light/dark contrast against
`.regularMaterial` (`.primary`/`.secondary` — title, species name, stat values, the "press to fish
again" line) gets an explicit `.white`/`.white.opacity(...)` foreground instead, since those
defaults would otherwise render near-invisible against the new solid dark background. A
`fish_sign.png` icon (`bundleImage(_:)`) sits beside the "Catch!" title, echoing
`FishCounterBadgeView`'s use of the same asset elsewhere in the HUD.

## Rationale

The user pointed at a screenshot of this exact screen still showing the old frosted-glass look
after ADR-100 landed: "masih gini jir? maksud gue bikin coklat yang sama kaya last catch juga.
bahasa designnya gue serahin ke elo. tambahin fish_sign juga deh" (still like this? I meant make it
the same brown as the last-catch box too. I'll leave the design language to you. Add fish_sign
too). ADR-100's "catch cutscene" fix only touched the brief `CatchCutsceneView` transition; this
`ResultView` screen — the one actually holding still on screen with all the catch stats — is a
separate file entirely and had been missed.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), and an actual launch/`ps`-confirmed-running/quit with no crash. As with every ADR since
ADR-096, this screen itself could not be visually confirmed this pass — it only appears after a
resolved catch mid-gameplay, which requires a paired Rod device. Open device-validation gap.

------------------------------------------------------------------------

# ADR-100 --- One Card Design Language Across the HUD: Badge, Last-Catch Box, Catch Cutscene

## Decision

Three more HUD surfaces adopt the dark-rounded-rectangle-plus-white-border language established by
`CastMeterView`'s track and `LineTensionView`'s bar (ADR-098/099):

- `FishCounterBadgeView`: the circular badge's border strengthens from a faint `.white.opacity
  (0.25)`, `lineWidth: 1.5` ring to a solid `.white`, `lineWidth: 2` ring (matching every other
  element exactly); the progress pill gains the same `.overlay(Capsule().stroke(.white, lineWidth:
  2))` it previously had none of.
- A new `LastCatchStatBoxView` (new file) replaces the plain default-chrome `GroupBox` that used to
  hold the last-catch-result row (species/weight/length) inside the bottom-leading HUD stack. It's
  a small floating card — `Self.panelColor` background (`Color(red: 0.16, green: 0.12, blue:
  0.09)`, the same dark brown used by `CastMeterView`'s track and `FishCounterBadgeView`'s pill),
  `RoundedRectangle(cornerRadius: 14)` shape, white 2pt border — showing a "LAST CATCH" label plus
  the outcome/species/weight/length text (or "No catch attempts yet"). `ContentView` moves this out
  of the bottom-leading stack entirely and floats it top-trailing instead, mirroring
  `fpsIndicator`'s top-leading placement, per "taroh di kanan aja jadi kaya small statistics box
  gitu" (put it on the right, like a small stats box).
- `CatchCutsceneView`'s "CATCH!" title moves from bare text with just a drop shadow onto the same
  card treatment (`Self.panelColor` background, `RoundedRectangle(cornerRadius: 24)`, white 2pt
  border) — the letterbox bars and radial glow stay untouched as full-bleed cinematic effects,
  since those aren't part of the card design language to begin with.

## Rationale

Requested directly, across two messages: "fish counter badge juga rectangle nya pake border yang
sama. terus, yang fishfight last catch result itu bikin designnya similar kaya style rectangle
semuanya. I trust your design deh (intinya bahasa designnya mirip). taroh di kanan aja jadi kaya
small statistics box gitu" (the fish counter badge's rectangle should also use the same border;
then, make the last-catch-result box's design similar to the rectangle style used everywhere — I
trust your design, just keep the design language consistent — put it on the right as a small stats
box), followed by "sekarang catchcutscene nya, sesuaiin bahasa design nya dengan sebelum-sebelumnya"
(now the catch cutscene — match its design language to the previous ones). Continues the same
design-consistency pass started by ADR-098/099: once the cast meter and tension bar settled on
"dark card + white border," every other HUD surface built before that point read as a mismatched
one-off next to them.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED) after each of the two edit passes (badge/stat-box, then cutscene), and an actual launch/
`ps`-confirmed-running/quit with no crash after each. As with every ADR since ADR-096, the in-scene
gameplay HUD and the catch-cutscene moment itself could not be visually confirmed this pass — no
Rod device was paired, and the cutscene only plays mid-gameplay after a resolved catch. Open
device-validation gap.

------------------------------------------------------------------------

# ADR-099 --- Line Tension Bar Border Moves to the Whole Rectangle; Safe-Zone Box Dropped

## Decision

`LineTensionView`'s bar drops its partial, middle-only safe-zone `Capsule().stroke()` outline
(spanning only `safeLow`...`safeHigh`) in favor of a white border wrapping the entire gradient bar
(`.overlay(Capsule().stroke(.white, lineWidth: 2))` applied directly to the full-width gradient
`Capsule`, matching the border treatment `CastMeterView`'s track already has). The `safeLow`/
`safeHigh` constants and the safe-zone `Capsule` are removed entirely — the concept isn't
represented as a separate visual anymore, only implicitly via the gradient's own green/yellow/red
coloring and the `fish_sign.png` marker's live position. `dangerLow`/`dangerHigh` are unchanged and
still drive the "LOSING FISH"/"SNAPPING" warning label. The gradient itself stays a full,
edge-to-edge fill — unlike `CastMeterView` (ADR-098), tension isn't a "fill toward a goal" value,
it's a live position that can move either direction across the whole range, so there's no
track/fill split to apply the border to separately; the border wraps the one gradient shape as a
whole.

## Rationale

Requested directly, referencing the same screenshot pattern as the cast meter fix: "ini juga sama.
the whole rectangle harusnya pake border. untuk coloring full mentok aja kanan kiri" (this one's
the same [issue] — the whole rectangle should have a border; for the coloring, just keep it
flush/full left-right). The coloring was already edge-to-edge (unlike the cast meter, which needed
ADR-098's proportional-fill fix), so the only change needed here is moving the border from the
middle safe-zone box to the bar's outer edge.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), and an actual launch/`ps`-confirmed-running/quit with no crash. As with ADR-096/097/
098, the in-scene gameplay HUD itself could not be visually confirmed this pass — no Rod device was
paired. Open device-validation gap.

------------------------------------------------------------------------

# ADR-098 --- Cast Meter Becomes a True Proportional Fill Over a Bordered Track

## Decision

`CastMeterView`'s bar changes from a static, always-fully-visible gradient (with a marker riding on
top to indicate power) to a genuine progress-bar fill: a fixed-width dark brown/black track
(`Self.darkEnd`, unchanged from ADR-097) with a white `Capsule().stroke()` border, and a green ->
yellow -> red gradient fill that grows from the left proportional to `power`. The fill is
implemented as a track-width gradient `Capsule` clipped down to `fillWidth` (`.frame(width:
fillWidth, alignment: .leading).clipped()`) rather than a gradient stretched to fit the filled
portion — so a given power value always renders the same color regardless of how much of the bar is
currently filled, matching how a real gradient progress bar reads. `fish_sign.png` stays as a live
marker riding the fill's leading edge (`markerOffset` now derived from `fillWidth` directly instead
of a separate power-based offset calculation, though they were numerically equivalent already).

## Rationale

Requested directly, with a close-up reference of the intended at-rest look: "instead of ini ke fill
semua, harusnya kaya gambar kedua. dimana ada rectangle coklat as the back layer, dan meterannya nge
fill dari hijau-kuning-merah gradiently di dalem rectangle itu. also, kasih border white untuk
rectanglenya" (instead of this filling the whole thing, it should be like the second image — where
there's a brown rectangle as the back layer, and the meter fills green-yellow-red gradually inside
that rectangle. Also give the rectangle a white border). ADR-097's dark-brown third gradient stop
was a partial step toward this same reference but had been read as "change the gradient's end
color," not "the dark color is an unfilled track, not part of the fill gradient" — this ADR
corrects that.

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme World` build (BUILD
SUCCEEDED), and an actual launch/`ps`-confirmed-running/quit with no crash. As with ADR-096/097,
the in-scene gameplay HUD itself could not be visually confirmed this pass — no Rod device was
paired. Open device-validation gap.

------------------------------------------------------------------------

# ADR-097 --- Cast Meter and Line Tension Visuals Swapped Back to Their Correct Roles

## Decision

A second, more precise reference image showed what the cast meter is actually supposed to look
like: the same gradient-capsule-plus-reel-cap structure as before, but ending in a dark brown/black
third gradient stop instead of red. Comparing it against the current implementation revealed the
gradient/reel/marker visual built in ADR-095/096 had been assigned to the wrong view — it reads as
a tension gauge (red = danger), not a charge/power gauge, and the user confirmed exactly this: "yang
sekarang di implement di cast meter itu malah line tension meter" (what's currently implemented as
the cast meter is actually the line tension meter).

`CastMeterView`'s gradient keeps its structure (green -> yellow -> third stop, `roll.png` reel cap,
`fish_sign.png` power marker) but the third stop changes from `.red` to a new `Self.darkEnd`
constant (`Color(red: 0.16, green: 0.12, blue: 0.09)`, matching `FishCounterBadgeView`'s existing
dark pill color for palette consistency).

`LineTensionView` is rewritten from its original plain solid-color proportional-fill capsule (color
switching between green/yellow/red by danger zone, a light-green safe-zone highlight, "Slack"/
"Snap" labels) to the gradient-capsule + `roll.png` + `fish_sign.png`-marker structure the cast
meter had before this ADR — keeping `.red` as its third stop, since red-for-danger is the correct
semantic here. The safe-zone highlight becomes a stroked (unfilled) capsule outline over the
gradient rather than a filled overlay, since the gradient itself now occupies that visual space;
the "LOSING FISH"/"SNAPPING" warning labels are kept.

Per "taro line tension di posisi yang sama kaya cast meter" (put line tension in the same position
as cast meter), `ContentView` moves `LineTensionView`'s call site out of the bottom-leading HUD
stack and into the same top-center `VStack` as `CastMeterView` — same `geometry.size.width * 0.4`
frame width and `.padding(.top, 24)`. The two are mutually exclusive in time (`CastMeterView` shows
only during backswing/charging/release/followThrough; `LineTensionView` only while
`fishFight.hasFishOnHook`), so stacking both in the same slot reads as one continuous meter that
changes meaning by game phase, never two overlapping elements.

## Rationale

Requested directly, with a second reference image of the cast meter specifically: "cast meter itu
harusnya ini. yang sekarang di implement di cast meter itu malah line tension meter. also, taro
line tension di posisi yang sama kaya cast meter" (the cast meter should be this — what's currently
implemented as the cast meter is actually the line tension meter — also, put line tension in the
same position as the cast meter).

## Status

Accepted — verified via `xcrun swiftc -typecheck` against the full `World/World` Swift file list
(clean; the `bundleImage`/`Shared`-module/"unable to type-check in reasonable time" diagnostics
SourceKit flagged mid-edit were stale index noise and a genuinely too-complex single expression,
respectively — the latter fixed by breaking `LineTensionView`'s offset math into named local
`let`s rather than one inline expression), a real unsigned `xcodebuild -workspace
CtSPoC.xcworkspace -scheme World` build (BUILD SUCCEEDED), and an actual launch/`ps`-confirmed-
running/quit with no crash. As with ADR-096, the in-scene gameplay HUD itself (where both meters
actually render) could not be visually confirmed this pass — no Rod device was paired. Open
device-validation gap.

------------------------------------------------------------------------

# ADR-096 --- Gameplay Scene Goes Fullscreen; HUD Becomes a Floating Overlay

## Decision

`ContentView`'s `content` view is restructured from a `VStack` (RealityView on top at
`minHeight: 320`, HUD stat block below it filling the rest of the window) to a `GeometryReader`
wrapping a `ZStack`: the `RealityView` now has `.ignoresSafeArea()` and fills the entire window,
with every HUD element — fps/connection indicator, `FishCounterBadgeView`, `LineTensionView`,
`BiteAlertView`, the catch-result `GroupBox`, `CastMeterView`, and the error text — repositioned as
overlays on top of it instead of occupying a separate region below it. There is no longer a
distinct "bottom bar" region; the scene alone determines the window's visible area.

`CastMeterView` specifically moves to a top-center overlay: wrapped in a `VStack { ...; Spacer() }`
pinned to the top via `.frame(maxWidth: .infinity)`, constrained to `geometry.size.width * 0.4`
(~40% of its previous full-bleed width), with `.padding(.top, 24)` so it reads as floating below
the top edge rather than pinned to it. Inside `CastMeterView` itself, `reelSize` (56 -> 45) and
`barHeight` (30 -> 24) both drop to 80% of their ADR-095 values, shrinking the bar's own height to
match its new role as a small floating HUD element rather than a near-full-width bar.

The power-position marker inside `CastMeterView` — a plain white `Capsule` since ADR-095 — is
replaced with the `fish_sign.png` asset (already present in `Assets/Images`, loaded via the
existing `bundleImage(_:)` helper), sized `18x(barHeight + 16)`, offset to keep it centered over
its live power position on the gradient bar the same way the capsule was.

The remaining HUD elements (badge, tension, bite alert, catch-result box, error text) keep
roughly their prior bottom-of-screen position, now as a `VStack { Spacer(); HStack { ...; Spacer()
} }` overlay anchored bottom-leading over the fullscreen scene, constrained to the same
`geometry.size.width * 0.4` width as the cast meter for visual consistency — this part wasn't
explicitly specified in the request but had to go somewhere once the separate bottom region was
removed, so it was kept in its established relative position rather than redesigned further.

## Rationale

Requested directly: "rod meter seharusnya jadi overlay diatas screen utama, jadi sekarang screen
game bisa full memakan semua bagian layar (ga perlu ada bagian paling bawa lagi). juga, kurangin
panjang meteran jadi sekitar 40% original length, dan 80% original height, lalu taruh di top dan
kasih padding dari atas (agar di tengah-atas, tapi ga nempel top). selain itu, penanda nya (yang
sekarang kotak putih), ganti pake asset fish_sign.png" (the rod meter should become an overlay on
top of the main screen, so the game screen can now fully fill the whole display — no more bottom
section needed. Also, shrink the meter to about 40% of its original length and 80% of its original
height, then place it at the top with padding from the top edge so it sits top-center without
touching the top. Also, replace the marker — currently a white box — with the fish_sign.png asset).
Continues the same reference-image-driven UI track as ADR-081, ADR-082, and ADR-095.

## Status

Accepted — verified via `swift build` for `Shared` (macOS), `swiftc -typecheck` against the full
`World/World` file list (clean), a real unsigned `xcodebuild -workspace CtSPoC.xcworkspace -scheme
World` build (BUILD SUCCEEDED), and an actual launch (confirmed running via `ps`, screenshot taken
at the Main Menu, then quit) with no crash. The Main Menu was the only screen reachable in this
check — no Rod device was paired/connected, so the in-scene gameplay HUD (fullscreen RealityView,
top-centered cast meter, bottom-leading badge/tension/bite/catch-result stack) could not be
visually confirmed against the reference this pass; this remains an open device-validation gap,
consistent with this project's usual caveat that live gameplay behavior needs a paired Rod.

------------------------------------------------------------------------

# ADR-095 --- Cast Meter Restyled and Fish Counter Badge Added, Both Reference-Image-Driven

## Decision

`World/World/Views/CastMeterView.swift` is rewritten to match a supplied reference screenshot: the
three hard-edged `.green`/`.yellow`/`.red` blocks are replaced with a single smooth
`LinearGradient` `Capsule` (green -> yellow -> red, leading to trailing), capped on the left by a
new `roll.png` reel/spool image (loaded via the existing `bundleImage(_:)` helper, `BundleImage.
swift`) sized by a new `reelSize: CGFloat = 56` constant that the bar's leading inset derives from.
The live power-position marker is kept (the reference is a static example with none, but the bar
is meaningless without one) as a slim white `Capsule` with a shadow. The existing holding-duration
and resolved power/distance text is kept but demoted from headline rows woven into the bar to small
`.caption2`/`.secondary` text below it, since the reference shows no text in the bar itself.

A new `World/World/Views/FishCounterBadgeView.swift` reproduces the reference's round fish-icon
"caught/needed" badge: a circular badge (new `fish.png` asset, via `bundleImage(_:)`) overlapping
the leading edge of a dark pill showing `"\(caught)/\(needed)"`, falling back to a bare
`"\(caughtCount)"` once `FishFightController.progressTowardNextLevel` is `nil` (all tiers
unlocked). `World/World/ContentView.swift`'s HUD `Group` gains a `FishCounterBadgeView(progress:
caughtCount:)` call site (fed by the same `fishFight` properties the old text already used), and
the `GroupBox`'s now-redundant "Caught {count}" / "Level {level} ... {caught}/{needed} to next
tier"/"All tiers unlocked" `HStack` rows are removed — the `GroupBox` now holds only the
last-catch-result row it already had.

Scope explicitly excluded: no persistent coin total exists anywhere in the codebase (`coins` is
only ever computed per-catch inside `FishCatchResult`, never accumulated), so the reference's "100"
coin display was not built — there is nothing to source it from without a new accumulator, which
was not requested. The reference's top-left "X" close button was not implemented (not mentioned in
the request). The overall HUD layout is unchanged — `FishCounterBadgeView` and the restyled
`CastMeterView` stay in their existing position inside `ContentView`'s vertical `Group`, rather
than being repositioned into a floating overlay matching the reference screenshot's exact framing.

## Rationale

Requested directly, with two reference images (a full gameplay screenshot and a cropped close-up of
the cast meter): "aku udah nambahin asset 'fish.png' dan 'roll.png' ke dalam assets/images di
World. aku mau kamu buatin beberapa hal seperti yang aku kirim ini. ini tampilan dimana kamu
menyimpan posisi si 'cast_meter'. ini contoh cast meternya. warnanya nge blend dari hijau-merah,
dan sesuaiin aja kaya di gambar" (I've added fish.png and roll.png to World's assets/images — build
several things like what I sent; this is the cast-meter's position; this is what the cast meter
should look like, colors blending green-to-red, match the picture). This is the third
reference-image-driven UI pass this session, after the Main Menu (ADR-081) and Loading Screen
(ADR-082) — same pattern of translating a supplied screenshot into SwiftUI as closely as scope
allows without inventing unrequested backing state (coins) or elements (the close button).

## Status

Accepted — verified via `swift build` for `Shared` (macOS), `swiftc -typecheck` against the full
`World/World` file list (clean; confirmed the `Cannot find 'bundleImage' in scope` and `No such
module 'Shared'` diagnostics both were stale SourceKit index noise, not real errors, matching this
session's established pattern for freshly-edited files), a real unsigned `xcodebuild -workspace
CtSPoC.xcworkspace -scheme World` build (BUILD SUCCEEDED), and an actual launch (`open World.app`,
confirmed running via `ps`, then quit) with no crash. Live visual comparison against the reference
images on an actual run, and device/hardware validation of the rest of the gameplay loop, remain
outstanding per this project's usual device-validation caveat.

------------------------------------------------------------------------

# ADR-094 --- Fight-Flick Detection Disabled Entirely; Only the Bite-Window Flick Remains

## Decision

`RodViewModel.detectFlickGesture()`'s guard is narrowed a second time — from `hookPhase ==
.fishOnHook || hookPhase == .hookInWater` (ADR-090) to `hookPhase == .hookInWater` only. No flick
is ever detected or sent while a fish is hooked, in any state; only the pre-hook bite window
(`.hookSet`, ADR-088) remains reachable. The now-always-unreachable `.fightFlick` branch of the
event-selection ternary is removed (dead code), and Rod always sends `.hookSet` unconditionally
inside the guard. `FishFightController.handleFightFlick()`, `FishFightConfig.fightFlickRelief`/
`fightFlickGraceDuration`, and `FishingEvent.fightFlick` are all left in place, unreachable from
Rod now rather than deleted — matching this project's own precedent (the QTE prompt system, ADR-
078, was disabled the same minimal way before being replaced outright by ADR-089) so re-enabling
this is a one-line change if a more reliable trigger condition is found later, not a rebuild.

## Rationale

Requested directly: "flick movement ketika reel (hook: fish in hook) masih ke register, harusnya
disable aja" (the flick movement while reeling — hook: fish in hook — is still getting registered,
it should just be disabled). This is the third report against the same mechanic (ADR-089's "flick
while `.fishOnHook` eases tension") after two rounds of fixes: ADR-091's cooldown for one flick's
own follow-through double-firing, ADR-093's post-hook grace window for the player's hand
continuing to settle. Each fix addressed a real, distinct failure mode found by tracing an actual
report, but the mechanic kept misfiring regardless — reasonable grounds to stop iterating on gate
conditions and just turn it off, per the direct instruction, rather than attempt a fourth patch.

## Status

Accepted — verified via `swiftc -typecheck` against `Shared` (iOS simulator, rebuilt after a
directory clean) and the full `Rod/Rod` file list, plus a real `xcodebuild` build (unsigned) —
all clean. Live confirmation still pending, same as every fight-flick change before it: the actual
"does flicking ever misfire now" question can only be answered on physical hardware.

------------------------------------------------------------------------

# ADR-093 --- Fight-Flick Relief Suppressed for a Grace Window Right After Hooking

## Decision

`FishFightController` gains a private `fightFlickGraceTimer: Float` and
`FishFightConfig.fightFlickGraceDuration` (default `1.0`s). `handleHookSetFlick()` sets
`fightFlickGraceTimer = config.fightFlickGraceDuration` the instant a fish is hooked;
`updateFight(...)` counts it down every tick; `handleFightFlick()` gains a second guard condition
— `fightFlickGraceTimer <= 0` — alongside its existing `hasFishOnHook` check. Both
`resetForNewCast(castDistance:)` and `resolve(outcome:)` reset the timer to `0` alongside every
other per-fight field they already clear.

## Rationale

Reported directly, continuing the same thread as ADR-091: "masih aga nge bug dikit, ketika nge
'flick' buat grab ikannya, meter line tension kadang suka loncat loncat turun sedikit" (still a
bit buggy — when flicking to grab the fish, the tension meter sometimes hops down a little,
repeatedly). ADR-091's cooldown prevents one flick's own follow-through from double-counting as a
second, but does nothing about the player's hand naturally continuing to move — sometimes crossing
the threshold again as a *third* or later, genuinely separate edge more than `flickCooldown` (0.4s)
after the first — while settling from the gesture that just set the hook. Each such edge is a
legitimate flick from the detector's point of view, and `handleFightFlick()` had no reason to
distrust it, so each shaved another `fightFlickRelief` off a `lineTension` that had *just* been set
to `initialTension` moments earlier — visibly stepping the bar down in hops right at the start of
a fight, exactly as described.

A World-side grace window (rather than, say, a longer Rod-side cooldown) was chosen because it
addresses the actual failure mode directly: the problem isn't that flicks are reported too close
together in general (ADR-091 already covers that), it's that *any* flick immediately following a
hook-set — however many, however spaced — shouldn't count yet. Gating on time-since-hooked, not
time-since-last-flick, covers the "several loosely-spaced follow-through motions" case ADR-091's
tighter cooldown couldn't.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against `Shared` (both
platforms) and the full `World`/`Rod` file lists, plus real `xcodebuild` builds (both targets,
unsigned) and a launch test on `World` — all clean, no crash. Not yet played: whether 1.0s is long
enough to reliably absorb the settling motion without also silently eating a genuinely fast,
deliberate first flick the player intends as an immediate tension-management move right after
hooking — chosen by feel, not measured from real device data.

------------------------------------------------------------------------

# ADR-092 --- Bite-Alert Haptic Repeats Continuously While the Window Stays Open

## Decision

`FishingHaptics` gains `isBiteAlertActive: Bool` and `biteAlertPulse(now:)` — same recurring-
callback pattern as `interestPulse(now:)`/`fightPulse(now:)`, called every motion sample from
`RodViewModel.updateAction()`, throttled to a new `biteAlertPulseInterval` (0.4s, deliberately
faster than `interestPulseInterval`'s 1.1s). `.biteAlert` now sets `isBiteAlertActive = true` and
plays `haptics.biteAlert()` immediately, same as before; the difference is `biteAlertPulse(now:)`
then keeps repeating that same pattern every 0.4s for as long as the window stays open, instead of
firing once and going silent. `isBiteAlertActive` clears on `.fishBite`/`.fishGaveUp` (the window
resolving either way) and via a new `stopBiteAlert()` safety net when `HookPhase` leaves
`.hookInWater` — mirroring `stopInterest()`'s existing belt-and-suspenders pattern exactly.

## Rationale

Requested directly: "tambahin juga haptic intensity, bikin continuous aja waktu ikan udah gigit
gigit" (also add haptic intensity, make it continuous while the fish keeps biting). Intensity
itself was already maxed (`1.0`, ADR-060's project-wide floor), so "gedein"/"tambahin intensity"
here reads as "make the alert itself more insistent/present," which for a *duration*-bound cue
means recurring for as long as the window is genuinely open, not a single burst the player might
miss the instant of. Matches the existing `interestPulse`/`fightPulse` pattern exactly rather than
inventing a new one.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `Rod/Rod`
file list and a real `xcodebuild` build (unsigned), both clean.

------------------------------------------------------------------------

# ADR-091 --- Flick Cooldown: One Flick's Follow-Through Was Double-Counting as a Second

## Decision

`RodViewModel` gains `lastFlickSentAt: Date` and a `flickCooldown: TimeInterval = 0.4` constant.
`detectFlickGesture()`'s send condition gains a third term: `isFlicking, !wasFlicking,
Date().timeIntervalSince(lastFlickSentAt) >= Self.flickCooldown` — a flick can only be reported if
at least 0.4s have passed since the last one was sent, regardless of `hookPhase` or which event
(`.hookSet`/`.fightFlick`) either one was.

## Rationale

Reported directly: "once aku 'flick' untuk mulai reel, tiba tiba line tension berkurang sedikit di
awal sebelum kembali normal rate" (once I flick to start reeling, the line tension suddenly drops
a bit at the start before settling into its normal rate).

Traced to a real gap in the edge-detection alone: `wasFlicking` correctly prevents the *same*
sustained motion from reporting twice while `accelerationZ` stays continuously past threshold, but
it does nothing to stop a *second*, later edge from the same physical gesture's natural
follow-through (the hand/rod decelerating, dipping back under threshold, then wobbling back above
it as it settles) — to the edge-detector, that reads as a genuinely new flick. The hook-set flick
that opens a fight is exactly this scenario: the instant it fires, `hookPhase` moves from
`.hookInWater` to `.fishOnHook` (ADR-090 already excludes `.reeling` from this detector, but not
`.fishOnHook`), and if the same physical flick's follow-through crosses the threshold again a beat
later, it now reads as a `.fightFlick` in the new phase — immediately subtracting
`fightFlickRelief` from a freshly-set `lineTension` before the player has done anything else.
That's the "berkurang sedikit di awal" (dips a bit at the start).

A cooldown after *any* sent flick (rather than, say, a longer/different debounce specific to the
hookSet-then-fightFlick transition) was chosen because it's the more general fix: the same
follow-through double-count risk exists for any two flicks sent close together, not just this one
transition, and a flat cooldown needs no phase-transition-specific logic to reason about.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `Rod/Rod`
file list and a real `xcodebuild` build (unsigned), both clean. Not yet played: whether 0.4s is
long enough to reliably absorb a real flick's follow-through without also blocking a second,
genuinely deliberate flick performed in quick succession — chosen to match the new
`biteAlertPulseInterval` (ADR-092) by feel, not measured from real device data.

------------------------------------------------------------------------

# ADR-090 --- Fight-Flick Detection Excludes `.reeling`: Reeling Motion Was Misfiring as Relief

## Decision

`RodViewModel.detectFlickGesture()`'s guard is narrowed from `hookPhase == .fishOnHook ||
hookPhase == .reeling || hookPhase == .hookInWater` to `hookPhase == .fishOnHook ||
hookPhase == .hookInWater` — dropping `.reeling`. No other change: the same threshold, the same
detector, the same two events (`.hookSet`/`.fightFlick`) it already sent.

## Rationale

Reported directly: "ada bug di line tension. ketika udah berhasil masuk ke reel, kok line tensiun
malah turun turun turun sampai losing fish" (there's a line tension bug — once already reeling,
tension keeps dropping and dropping until losing the fish).

Traced directly from ADR-089's own change: `handleFightFlick()` subtracts `fightFlickRelief` from
`lineTension` on *every* reported flick, gated only on a fish being on — no timed window, no
attempt limit, unlike the bite window. The physical motion of actually cranking a reel can itself
cross the exact same forward-acceleration threshold used to detect a deliberate flick (both are
forward-ish hand/wrist accelerations), so active reeling was intermittently misread as repeated
flicks — each one draining tension in the *relief* direction (toward the slack/escape edge), while
`updateFight(...)`'s own reel-tension-gain formula was simultaneously trying to raise it. Enough
false flicks during a real reeling session could overwhelm the gain entirely, reading exactly as
"tension only ever goes down while reeling."

Excluding `.reeling` from the detector rather than, say, debouncing/rate-limiting flicks more
aggressively was chosen because it addresses the actual conflict directly: "flick to relieve
tension" and "reel to gain tension" are now two distinct physical actions (paused vs. actively
cranking) that structurally can't misfire into each other, rather than two overlapping actions
with a patched-over collision rate. A player can still relieve tension mid-fight — just while
paused between reel cranks (`hookPhase == .fishOnHook`), not during the crank itself.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `Rod/Rod`
file list and a real `xcodebuild` build (unsigned), both clean. Not yet played: whether excluding
`.reeling` still leaves enough opportunity to use the relief mechanic in practice, given a player
actively fighting a strong fish may rarely pause reeling long enough to deliberately flick — this
trades "flicking never has an unintended cost" for "flicking is only available in fewer moments,"
and only a live session can confirm that trade reads as fair rather than as the mechanic barely
mattering.

------------------------------------------------------------------------

# ADR-089 --- Mid-Fight QTE Prompt Removed: Every Flick While a Fish Is On Now Eases Tension

## Decision

**`FishFightController`'s entire timed QTE prompt/reaction-window mechanic (ADR-078) is removed,
not just re-enabled.** `isQTEActive`, `qteProgress`, the private `qteSpawnTimer`/`qteReactionTimer`,
`updateQTE(deltaTime:)`, and `handleQTEFlick()` are all deleted. In their place, a single method —
`handleFightFlick() -> Bool` — applies `FishFightConfig.fightFlickRelief` to `lineTension` the
instant Rod reports a flick, gated only on `hasFishOnHook` (i.e. any point during an actual fight).
There is no prompt to wait for and nothing to miss: every physical flick the player performs while
a fish is on now does something.

`FishingEvent.qtePrompt` (World -> Rod, never sent by anything else now) and `.qteFlick` are
removed; `.qteFlick` is replaced by `.fightFlick` (Rod -> World), sent from the same
`RodViewModel.detectFlickGesture()` (ADR-088's rename of `detectFightFlick()`, once it started
covering the bite window too) that already sends `.hookSet` during `.hookInWater` — the
`hookPhase` check alone decides which event fires, no new gesture, no new calibration, no
per-state duplicate detection code. `FishFightConfig.qteSpawnMinInterval`/`qteSpawnMaxInterval`/
`qteReactionWindow`/`qteFailurePenalty` are removed; `qteSuccessRelief` is renamed
`fightFlickRelief` (same default value, `0.15`, now applied unconditionally instead of only on a
successful timed reaction). `HapticManager.qtePrompt()` is removed (nothing calls it anymore).
`LineTensionView`'s "FLICK ROD NOW!" banner is removed with no replacement — there's no prompt
event left for a banner to represent.

## Rationale

Reported directly, continuing the previous bite-window work: "when fish on, gagal nge flick? pake
aja movement flick dari semua state yang sama jadi ga perlu bikin flick movement lagi" (when the
fish is on, does flicking fail? just use the same flick movement across all the same states, so we
don't need to build a new flick movement again).

Traced the actual cause of "gagal nge flick" (flick fails) before changing anything: the QTE
mechanic's one live-driving call site, `updateQTE(deltaTime:)` in `updateFight(...)`, had been
commented out earlier in this same session for debugging ("untuk debug ini, disable dong QTE nya
— cukup comment aja") and never re-enabled. With it disabled, `isQTEActive` could never become
`true`, so `handleQTEFlick()`'s own `guard isQTEActive` never passed — Rod was (correctly, per its
own code) detecting and sending every flick exactly as designed, but World silently dropped every
single one as a no-op, with no prompt ever shown to explain why nothing happened. This read
exactly as "flicking fails."

Re-enabling the disabled line (`updateQTE(deltaTime:)`) alone would have fixed the immediate
symptom, but the request's second half — "pake aja movement flick dari semua state yang sama, ga
perlu bikin flick movement lagi" — asks for something more specific: don't reintroduce a mechanic
that requires waiting for a separate timed prompt at all; just make the one flick gesture Rod
already detects reliably in every relevant state (the bite window, ADR-088) equally reliable and
unconditional here too. Removing the prompt/spawn-timer layer entirely, rather than just
un-commenting it, is what actually satisfies that — and happens to fix the root cause (a
silently-disabled call site with no visible failure mode) more robustly than re-enabling a
mechanic that could, in principle, be disabled the same way again.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against `Shared` (both
platforms), the full `Rod`/`World` file lists against each, and real `xcodebuild` builds (both
targets, unsigned) plus a launch test on `World` — all clean, no crash. Repo-wide `grep` confirmed
zero remaining references to any removed QTE symbol. Not yet played: whether removing the timed
prompt (and its visual/haptic alert) makes mid-fight tension management feel too passive/optional
now that there's no moment specifically demanding the player's attention — the previous QTE
mechanic's whole point was creating that moment; this trades it for pure player-initiated
simplicity per the direct request, without a live session to confirm the feel is still right.

------------------------------------------------------------------------

# ADR-088 --- Bite Window: Flick to Set the Hook, Three Attempts Before the Fish Gives Up

## Decision

**Fish no longer hook themselves automatically.** `FishFightController.updateSearching(deltaTime:)`
no longer rolls a species and sets `hasFishOnHook = true` the instant `biteTimer` elapses. Instead,
elapsing `biteTimer` opens a **bite window**: `isBiteWindowActive = true`,
`biteWindowProgress` ticks `1.0 -> 0.0` over `FishFightConfig.biteWindowDuration` seconds, and
World emits `FishingEvent.biteAlert` (World -> Rod) — a strong, unmistakable haptic
(`HapticManager.biteAlert()`, five sharp full-sharpness pulses) telling the player a fish is
testing the bait *right now*.

The player must flick the rod forward — the identical gesture as a cast release/the QTE flick,
per the standing "reuse the cast gesture, don't invent a new one" precedent — before the window
expires. `RodViewModel.detectFlickGesture()` (renamed from `detectFightFlick()`, since it now
covers two different moments) is extended to also fire during `HookPhase.hookInWater`, sending a
new `FishingEvent.hookSet` (Rod -> World) instead of `.qteFlick` in that phase. World's
`FishFightController.handleHookSetFlick()` — mirroring `handleQTEFlick()`'s own shape exactly —
does the actual species roll/hook-set that `updateSearching` used to do inline, but only while a
bite window is genuinely open; a stray/late flick outside one is a no-op, same as an off-window
QTE flick already was.

**Three missed attempts and the fish gives up.** If `biteWindowTimer` reaches 0 with no flick,
`biteAttemptsUsed` increments. Below `FishFightConfig.maxBiteAttempts` (default 3), a new attempt
starts after a short random delay (`biteRetryMinInterval...biteRetryMaxInterval`) — same
"randomizer" spirit as the original interest/bite timers, giving the next alert a natural,
unpredictable beat rather than firing on a fixed metronome. At the limit, the fish swims off
entirely: `FishingEvent.fishGaveUp` (World -> Rod, a soft/deflating haptic distinct from
`fishEscaped()`), `isFishInterested` clears, and normal searching resumes from scratch as if this
fish never bit — no `HookPhase` change, no new cast needed.

A new `BiteAlertView` (World HUD) mirrors `LineTensionView`'s existing QTE banner treatment — a
"FISH ON! FLICK TO HOOK!" label over a shrinking orange progress capsule — shown whenever
`isBiteWindowActive`, giving the alert a visual complement to the haptic (Rod owns no gameplay
HUD, so this is the only place it can be shown).

## Rationale

Requested directly: "sekarang fish insta-bite the hook setelah beberapa detik. gimana kalo, 1.
haptics nya gedein, jadi user tau kalo hook nya lagi digigit ikan 2. tambahin action untuk 'flick'
(samain aja kaya cast) untuk actually start the reeling game 3. kalo setelah 3x haptics gede, ga
nge 'cast', otomatis hook nya hening lagi. jadi literally kaya mancing beneran" (right now the fish
insta-bites after a few seconds — what if: 1. bigger haptics so the player knows a fish is biting,
2. add a "flick" action, same as cast, to actually start the reeling game, 3. after 3 big haptics
with no flick, the hook goes quiet again — literally like real fishing).

Reusing the QTE flick's exact gesture/detector/no-op-outside-window pattern (rather than inventing
new mechanics) was the direct, lowest-risk way to satisfy request #2 — the game already has a
fully working "flick to react to a timed prompt" system (ADR-078); this just adds a second
context that gesture is meaningful in, gated by `HookPhase` the same way the first one already is.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against `Shared` (both
`arm64-apple-ios17.0-simulator` and `arm64-apple-macosx26.0`), the full `Rod`/`World` file lists
against each, and real `xcodebuild` builds (both targets, unsigned) plus a launch test on `World`
— all clean, no crash. Not yet played: whether `biteWindowDuration` (1.5s) gives a fair reaction
time given real BLE round-trip latency between World's alert and Rod's flick detection (the same
open question ADR-078's QTE window already carried, now doubled up), whether 3 attempts feels
right rather than too generous/stingy, and whether the new `biteAlert()` haptic actually reads as
meaningfully "bigger" than `fishBite()` on physical hardware (both use `intensity: 1.0`, so the
felt difference is sharpness/pulse-count only — untested on a real device in this environment).

------------------------------------------------------------------------

# ADR-087 --- Credits and Tutorial Ported From feat/ui-slice Onto Main's Navigation Model

## Decision

Merging PR #7 (`feat/ui-slice`) into `main` found it had independently built a full competing Main
Menu/loading/navigation system (`RootView.swift`'s own screen router, pill-shaped buttons, a
Fredoka-font `Theme.swift`) that collided with this session's own ADR-081/082 Main Menu/loading
redesign and `WorldViewModel.Screen`-driven overlay model. Confirmed with the user rather than
picking a side: keep main's Main Menu/loading/navigation entirely; port `feat/ui-slice`'s
genuinely new, non-overlapping features (`CreditsView.swift`, `TutorialView.swift`) onto main's
kept navigation model instead of discarding them outright.

`CreditsView.swift` is unchanged (self-contained, only needs `Theme.swift`) — reachable via a new
"Credits" button on `MainMenuView` (`StackedMenuButtonStyle(isProminent: false)`, matching "How to
Play"), owned by local `@State private var isShowingCredits` rather than a new
`WorldViewModel.Screen` case, since Credits has no bearing on session/gameplay state.

`TutorialView.swift` is unchanged aside from one doc-comment correction. It's now shown via
`ContentView`'s own overlay `ZStack` — the same "overlay atop the live game scene" composition
`RootView` originally used, just reached through this screen's overlay stack instead of a separate
router. `WorldViewModel` gained `isShowingTutorial: Bool` (set `true` alongside `screen = .playing`
in `handleState(_:)`) and `dismissTutorial()`; reset alongside the other overlay flags in
`returnToMenu()`. Shown unconditionally on every "Start Fishing," not gated to a player's first
session — an inherited simplification, not new: persisted first-session-only gating was explicitly
flagged as future work on the original branch and remains unimplemented here too.

`Support/Theme.swift` is trimmed on port to only the tokens `CreditsView`/`TutorialView` actually
reference (`buttonFill`/`buttonLabel`/`buttonLabelShadow`/`Color(hex:)`/`Font.fredoka`/
`fredokaBold`/`ShadowedLabel`) — the `overlay`/`menuButtonFace`/`menuButtonEdge`/`menuButtonText`
tokens existed solely for the dropped pill-button `MainMenuView` and were dropped as dead weight.
`Fonts/Fredoka-{Bold,Regular}.ttf` and `Info.plist`'s `ATSApplicationFontsPath`/`UIAppFonts` keys
are ported as `Theme.swift`'s own dependencies. `Assets.xcassets/Image/{FrameIcon,HandTutor}
.imageset` are ported as `TutorialView`'s illustration assets.

`RootView.swift`, `LoadingView.swift`, and their Main-Menu/Loading-specific asset catalog entries
(`LoadingScreen`/`landingImage`/`logo` imagesets) are dropped entirely — fully superseded, no
longer referenced by anything once `MainMenuView.swift`/`WorldApp.swift` were resolved to main's
side.

Two silent-wrong auto-merges were caught and fixed while resolving this (both textual merges git
reported as clean, i.e. no conflict markers, but whose result was actually wrong): `WorldApp.swift`
had reverted to `feat/ui-slice`'s `RootView()` instead of main's `ContentView()` (each side's diff
landed in non-overlapping line ranges, so git had nothing to flag); `Assets.xcassets/AppIcon
.appiconset/Contents.json` had reverted to a single incomplete iOS-only icon entry, silently
dropping the working macOS multi-size icon set (the actual `CTS-Logo_*.png` files were all still
present in the tree — a manifest regression, not a missing-asset situation). Both restored to
main's versions explicitly, not left to the auto-merge.

## Rationale

See `CHECKPOINT.md`'s "Merge PR #7 (feat/ui-slice) into main" entry for the full investigation
(what was found, read, and decided file-by-file) and the exact request that prompted the
keep-mine/port-theirs split.

## Status

Accepted — verified via `swiftc -typecheck` (`World`/`Rod` against manually-built `Shared` modules,
both platforms) and a full unsigned `xcodebuild` build + launch, all clean, no crash. Confirmed via
`git write-tree`/`git ls-tree` diff against `origin/main` that the final merged result is *exactly*
`main` plus the deliberate additions above — nothing else differs. Not yet played live: Credits/
Tutorial are newly rewired onto a navigation model neither was originally built against, and
`TutorialView` in particular was never visually confirmed live even on its origin branch (no
Accessibility/UI-scripting permission there either, per that branch's own CHECKPOINT history).

------------------------------------------------------------------------

# ADR-086 --- World Launches Directly Into Fullscreen

## Decision

`WorldApp.swift` gains an `NSApplicationDelegateAdaptor`-attached `WorldAppDelegate`, whose
`applicationDidFinishLaunching(_:)` finds the `WindowGroup`'s window
(`NSApplication.shared.windows.first`) and calls `window.toggleFullScreen(nil)` on it if it isn't
already fullscreen — wrapped in `DispatchQueue.main.async` since SwiftUI's window can land a beat
after `applicationDidFinishLaunching` fires, and `toggleFullScreen` needs a window that already
exists on screen. Standard AppKit `toggleFullScreen`, not a locked/kiosk mode — the player keeps
the normal exit paths (green traffic-light button, Control-Command-F).

## Rationale

Requested directly: "kalo nge buka World, langsung otomatis masuk mode full screen (jadi ga bisa
windowed)" (when opening World, it should go straight into fullscreen mode automatically, so it's
not [left] windowed). Read as "launch fullscreen by default," matching how most single-purpose
game apps behave, not as a request to remove the standard OS fullscreen-exit affordances — no
window-style/behavior changes beyond the one auto-toggle call were made.

## Status

Accepted, verified live, not just by inspection — `swiftc -typecheck` against the full `World/World`
Swift file list passed (exit code 0), the actual `World.xcodeproj` target was built end to end
(unsigned `xcodebuild`, `** BUILD SUCCEEDED **`), and the built `.app` was launched and its window
state directly queried via `CGWindowListCopyWindowInfo` (this environment has no Accessibility
permission for AppleScript/System Events UI scripting, so `AXFullScreen` couldn't be read directly)
— confirmed the window's on-screen compositing layers span the full display including the menu-bar
row (`Y:0, Height:33` present, which only a fullscreen window occupies; windowed apps queried the
same way all sit at `Y:33`, below the menu bar), positively confirming fullscreen engaged
automatically on launch, not merely inferred from the code.

------------------------------------------------------------------------

# ADR-085 --- "Start Casting" Defers Instead of Interrupting the Catch Cutscene

## Decision

`WorldViewModel.continueFishing()` gains a second guard condition: `!isShowingCatchCutscene`,
alongside its existing `hookPhase == .result`. Rod's "Start Casting" button is only ever gated on
`hookPhase` (`.idle`/`.result`) — it has no notion of `isShowingCatchCutscene`, a World-only
presentation flag that never crosses the wire. `hookPhase` becomes `.result` the instant a catch
resolves, at the very *start* of the catch cutscene (needed so `tick()`'s `case .result:` branch
keeps calling `updateCatchCutscene(deltaTime:)` every frame for the cutscene's whole ~5 s
duration), not at the end. Without this guard, a player pressing "Start Casting" during the
cutscene would immediately flip `hookPhase` to `.idle`, which stops `tick()` from ever entering
`case .result:` again — freezing the cutscene's fish/`"CATCH!!"` mid-animation while gameplay had
already moved on underneath it, with `isShowingCatchCutscene` left permanently stuck `true`.

The armed press is deferred, not dropped: Rod keeps `isCastingArmed == true` until it sees
confirmation the dismissal actually happened, and `WorldViewModel.handleState(_:)` re-checks
`state.isCastingArmed` on every incoming `.state` message (high-frequency, unreliable delivery) —
so the instant the cutscene's own natural completion clears `isShowingCatchCutscene`, the very
next `.state` message satisfies both guard conditions and `continueFishing()` fires. No change to
Rod, `Shared`, or the wire protocol was needed.

## Rationale

Reported directly: "saat berhasil catch, ada slight delay karena menunggu layar ikan dan tulisan
CATCH!! menghilang, baru tombol Start Casting bisa aktif lagi" (when a catch succeeds, there's a
slight delay because it's waiting for the fish screen and "CATCH!!" text to disappear, only then
can the "Start Casting" button become active again). Read as the desired/correct behavior, not a
complaint about it — tracing the actual code found the *opposite* was true: `continueFishing()`
had no cutscene awareness at all, so pressing early would have visibly broken the cutscene (frozen
mid-animation) rather than merely feeling early. This fix makes the actual behavior match what was
described as expected, and incidentally fixes a real, previously-unreported glitch in the process.

Deferring via the existing armed-press/re-check mechanism (rather than, say, disabling the Rod
button for the cutscene's duration, which would need a new synced field) was chosen because it
reuses ADR-061's existing round-trip pattern exactly — Rod already tolerates its own press being
acted on some indeterminate short time later, so this is one more reason for that gap to exist, not
a new kind of gap.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `World/World`
Swift file list, exit code 0, and by tracing `tick()`'s `case .result:` dependency on `hookPhase`
directly to confirm the freeze scenario this fixes would otherwise occur. Not yet played: whether a
press during the cutscene visibly registers as "Casting Armed…" on Rod for the deferred duration
(a few seconds) reads as expected/reassuring, or as if the button is unresponsive.

------------------------------------------------------------------------

# ADR-084 --- Ambient Sound Redesigned: Idle Owns the Menu, Reel-Fight Owns the Catch, Nothing Plays While Loading

## Decision

**The separate lake-ambience track (`ambienceLake`/`ambience_lake.mp3`) is retired entirely** —
removed from `SoundManager.Sound`, `FishingSounds.Config` (now deleted, since it was the struct's
only field), and `FishingSounds.handleScreenChange(isPlaying:)` (also deleted, along with its three
`WorldViewModel` call sites in `start()`, `returnToMenu()`, and the `.playing` transition in
`handleState(_:)`). `SoundManager.Category.ambience` is removed too, since `ambienceLake` was its
only member. The `.mp3` file itself is left on disk, unreferenced — not deleted.

`idle.wav` is repurposed as the Main Menu/Onboarding's sole ambient sound, replacing what
`ambienceLake` used to cover there, instead of its previous role as a "waiting for a bite during
gameplay" layer. `WorldViewModel.tick()`'s active-condition changed from `screen == .playing &&
(hookPhase == .idle || hookPhase == .hookInWater)` to `screen == .mainMenu || screen ==
.onboarding` — silent during `.playing` now (not just during the fight, all of gameplay), and
silent during `.loading` (a screen that didn't exist when `idle` was first wired up). `reel_fight`
is unchanged: still active exactly while `screen == .playing && (hookPhase == .fishOnHook ||
hookPhase == .reeling)`.

Both loops remain purely frame-driven, computed fresh every `tick()` call — and `tick()` itself
only ever runs after `attachFrameLoop(to:)` subscribes to the scene's per-frame update event,
which happens *after* `makeSceneEntity()`'s async asset load completes (`ContentView`'s `RealityView`
`make` closure). This means no ambient loop of any kind can start during `.loading`, not by
explicit exclusion but because the code path that would start one doesn't run yet — the previous
design's eager `sounds.handleScreenChange(...)` call from `start()` (fired immediately on
`.onAppear`, before any asset had loaded) was the actual root cause of ambience audibly starting
during the loading screen, and removing that call site (now dead code anyway, given
`handleScreenChange`'s deletion) closes the gap structurally rather than with an added guard.
`FishingSounds.handlePhaseChange(_:)`'s belt-and-suspenders idle-stop block is removed too — idle's
lifecycle is `screen`-driven now, not `HookPhase`-driven, so a phase transition alone must never
touch it.

## Rationale

Two notes given together: "loading screen ga seharusnya nge play sfx apapun" (the loading screen
shouldn't play any SFX at all) and "ketika di main menu, matiin semua suara environment, dan hanya
play idle. ketika bermain, idle dimatikan, dan hanya reel_fight yang aktif ketika reeling" (at the
main menu, turn off all environment sound and only play idle; during gameplay, idle turns off, and
only reel_fight is active — confirmed via follow-up question to mean the existing `fishOnHook ||
reeling` window, not narrowed to literally `RodState.action == .reeling`). Investigated the first
report's root cause directly rather than patching around it: `start()` called
`sounds.handleScreenChange(isPlaying: screen == .playing)` unconditionally on `.onAppear`, at which
point `screen` is always `.loading` (ADR-082) — with `Config.ambiencePlaysInMenu` defaulting `true`,
`shouldPlay` evaluated `true` regardless of `isPlaying`, so the lake ambience started audibly the
instant the app launched, well before any asset (or the loading screen's own minimum-duration gate,
ADR-082's amendment) had finished. The two reports turned out to share one root fix: retiring the
screen-transition-triggered ambience path entirely in favor of the already-existing frame-driven
pattern `idle`/`reelFight` used, which has no such "fires immediately regardless of load state"
failure mode by construction.

## Amendment: `ambienceLake` Restored, Scoped to Gameplay

Live playtest report, same day: "ada bug sedikit, ketika in game, semua suara yang seharusnya main
sebelumnya, tiba tiba berhenti semua. I believe aku minta ke kamu buat specifically matiin idle.wav
aja ketika in game" (there's a small bug — when in-game, all the sounds that used to play suddenly
all stop. I believe I asked you to specifically turn off only idle.wav during gameplay).

Re-reading the original request's two clauses separately clarified the actual scope: "ketika di
main menu, matiin semua suara environment, dan hanya play idle" is entirely about the *menu*
(replace environment sound with idle there); "ketika bermain, idle dimatikan, dan hanya reel_fight
yang aktif ketika reeling" says idle turns off during gameplay and reel_fight is the only *fight*
loop — it does not say gameplay should lose its continuous background bed entirely. Retiring
`ambienceLake` outright (this ADR's original Decision) over-applied the menu clause's "turn off all
environment sound" to gameplay too, leaving gameplay silent outside of an active fight — read by
the player as "everything stopped," when only `idle.wav` specifically was ever meant to stop.

**Fix: `ambienceLake` is un-retired, re-added to `SoundManager.Sound`/`Category.ambience`, but
rescoped from "menu and gameplay both" (its original, pre-ADR-084 behavior) to gameplay only.** A
new `FishingSounds.updateAmbienceLoop(active:)` (same frame-driven pattern as `updateIdleLoop`/
`updateReelFightLoop`) is called from `WorldViewModel.tick()` as `screen == .playing`. The
resulting model: exactly one base ambience is active at a time — `idle` at the Main Menu/
Onboarding, `ambienceLake` during gameplay — never both, never neither (outside `.loading`, where
neither plays, unchanged from this ADR's original fix). `reelFight` layers on top of `ambienceLake`
during an actual fight, exactly as it always has.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `World/World`
Swift file list (exit code 0, for both the original change and this amendment) and by building/
launching the actual `World.xcodeproj` target end-to-end twice (unsigned `xcodebuild`, `** BUILD
SUCCEEDED **` both times, launched without crashing both times). Repo-wide `grep` confirmed zero
remaining references to `ambiencePlaysInMenu`/`handleScreenChange`/`FishingSounds.Config` (still
correctly retired) and that `ambienceLake` now appears only in its restored, gameplay-scoped form.
Not yet played: whether gameplay's restored continuous ambience, now correctly coexisting with
`idle`'s menu-only role, sounds right in practice — the original report was caught in the very next
live session, so this amendment itself is equally unconfirmed live.

------------------------------------------------------------------------

# ADR-082 --- A Loading Screen Covers the Initial Async Asset Load

## Decision

`WorldViewModel.Screen` gains a new first case, `.loading`, placed before `.onboarding`/`.mainMenu`.
`screen` now starts as `.loading` (was `Self.hasSeenOnboarding ? .mainMenu : .onboarding`, computed
immediately in `init`); that same onboarding-vs-menu decision moved into a new
`sceneDidFinishLoading()`, called exactly once from `ContentView`'s `RealityView` `make` closure
right after `WorldViewModel.makeSceneEntity()`'s assets (environment, rod rig, fish) are added to the
scene. `ContentView` overlays a new `LoadingScreenView` whenever `screen == .loading`, following the
exact same pattern `MainMenuView`/`OnboardingView` already use — an opaque overlay on top of the
always-mounted RealityKit scene, not a separate view hierarchy.

`LoadingScreenView`: full-bleed `loading_screen` background photo, a flat `#505277` color layer at
40% opacity over it (requested as a flat layer, not a gradient), the `logo_cts` mark top-left, and a
"Loading..." text bottom-left — matching a supplied reference screenshot.

**`bundleImage(_:)` (the loose-bundled-PNG loader ADR-081 introduced inside `MainMenuView`) is
factored out into a new shared `BundleImage.swift`**, since `LoadingScreenView` needs the identical
loading behavior for its own two images (`loading_screen`, `logo_cts` reused from the main menu).
`MainMenuView`'s private copy is removed in favor of the shared one; no behavior change there.

`returnToMenu()` gains an added guard (`screen != .loading`, alongside its existing `screen !=
.mainMenu`): a Rod disconnect arriving before the async asset load finishes must not skip past the
loading screen (and the first-launch onboarding decision `sceneDidFinishLoading()` still owns)
straight to the menu.

## Rationale

Requested directly, with a reference screenshot: "tambahin loading screen dong, di awal aja waktu
nge load semua asset. image background nya udah ditambahin under folder yang sama, 'loading_screen'.
tambahin semacam rectangle layer dengan fills #505277 dengan opacity 40%" (add a loading screen, only
at the start while loading all the assets — I've already added the `loading_screen` background image
under the same folder; add a rectangle layer with fill `#505277` at 40% opacity).

Before this change, `screen` defaulted to `.mainMenu`/`.onboarding` immediately in `init`, before
`RealityView`'s async `make` closure had loaded anything — the menu/onboarding overlay appeared
instantly while the environment/rod-rig/fish assets were still loading underneath, with no visible
indication loading was even happening. Moving the onboarding-vs-menu decision to fire only once
loading actually finishes (rather than removing the loading screen once *some* fixed delay elapses,
or gating on a guessed condition) ties the loading screen's lifetime exactly to real work, not an
approximation of it.

## Amendment: 10-Second Minimum Display Duration

Immediate same-day follow-up: "kasih delay 10 detik dong ke loading screen" (add a 10-second delay
to the loading screen) — directly addressing the Status section's own flagged risk below ("asset
loading is normally fast enough that a live tester may barely see it").

Added `loadingStartedAt: Date` (set once, in `init`, the instant `.loading` begins) and
`minimumLoadingScreenDuration: TimeInterval = 10`. `sceneDidFinishLoading()` became `async`: it now
measures elapsed time since `loadingStartedAt` and, if under 10 seconds, `Task.sleep`s out the
remainder before transitioning `screen` — in the same async context `ContentView`'s `RealityView`
`make` closure already runs in (`await viewModel.sceneDidFinishLoading()`), no separate `Task {}` or
timer needed. This is additive to, not a replacement for, the real-completion gating this ADR's
original Rationale argued for: the loading screen still won't disappear before assets are actually
ready (the original guarantee), and now additionally won't disappear before 10 seconds even if
assets finish sooner (the new guarantee) — the two conditions combine as a maximum, not either/or.
A second `guard screen == .loading` after the sleep protects against `screen` having moved on for an
unrelated reason during the wait (defensive; no code path currently does this while `.loading`, given
`returnToMenu()`'s own guard, but cheap to keep correct regardless).

## Status

Accepted, pending live confirmation — verified by building the actual `World.xcodeproj` target
twice: once via `xcodebuild -target World -configuration Debug` (code signing disabled), and again
via a from-scratch `clean build` after this amendment, both `** BUILD SUCCEEDED **`. Confirmed
`loading_screen.png` lands in the built bundle's `Resources/` alongside `main_menu_bg.png`/
`logo_cts.png`. Launched the built `.app` after the amendment and confirmed via `ps` that the process
was still alive and unchanged (no crash, no relaunch) past the 10-second window. `swiftc -typecheck`
against the full `World/World` Swift file list also passes, exit code 0. **Not confirmed**: an actual
visual screenshot — this environment has no screen-recording permission granted (same gap noted in
ADR-081), so the loading screen's actual on-screen appearance is unverified by eye, only that the
timing/lifecycle logic runs without crashing.

------------------------------------------------------------------------

# ADR-081 --- Main Menu Restyled to a Background Photo, Logo, and Stacked-Rectangle Buttons

## Decision

`World/World/Views/MainMenuView.swift` is restyled from a plain black background with a plain-text
title to match a supplied reference design:

- **Background**: `main_menu_bg.png`, full-bleed (`resizable().scaledToFill()`), with a top-to-bottom
  black gradient overlay (transparent at top, ~45% opaque at the bottom) so the status panel and
  buttons — sitting over the photo's busier lower half — stay legible regardless of what's beneath.
- **Logo**: `logo_cts.png` replaces the plain-text "Catch the Scott" title, `scaledToFit()` capped at
  360pt wide, with a drop shadow for separation from the photo.
- **Buttons**: a new `StackedMenuButtonStyle` (`ButtonStyle`) gives `Retry Connection` and `How to
  Play` a cream, dark-bordered rounded-rectangle card with a second, darker rectangle offset behind
  it — "two stacked cards," matching the reference's button treatment. `isProminent` scales
  size/padding for a primary-vs-secondary role: whichever of the two buttons is the only actionable
  one currently shown gets the larger, primary treatment (`Retry Connection` while disconnected;
  `How to Play` once connected, since `Retry Connection` disappears). Pressing narrows the gap
  between the two stacked rectangles, reading as the top card pressing down onto its stack.
  `Forget Device`/`Reset Progress` (destructive, infrequent) keep their existing plain small-text
  treatment rather than becoming stacked-card buttons, preserving the visual hierarchy between
  common and dangerous actions.
- **Status/calibration area**: wrapped in a translucent dark rounded-rectangle card
  (`Color.black.opacity(0.38)`) for legibility against the photo. `CalibrationGuidanceView` itself is
  unchanged — only `MainMenuView` gained a background container around it.

**Both images are loose bundled resources, not `Assets.xcassets` entries**, loaded via a new
`bundleImage(_:)` helper (`Bundle.main.url(forResource:withExtension: "png")` +
`NSImage(contentsOf:)`) rather than the plain `Image("name")` initializer. Confirmed by actually
building the `World` target (`xcodebuild -target World`, unsigned) and inspecting the resulting
`.app` bundle: `World.xcodeproj`'s `PBXFileSystemSynchronizedRootGroup` (the same mechanism already
covering `Assets/FishCaught/mekong_catfish_caught.usdz`, loadable via `Entity(named:)` with no
manual project entry) flattens every loose file under `World/World` straight into
`Contents/Resources/` at the bundle root — `main_menu_bg.png`/`logo_cts.png` land right alongside
`mekong_catfish_caught.usdz` and every `.wav`/`.usdz` asset, confirmed by directly listing the built
bundle's `Resources/` folder rather than assumed from the RealityKit precedent alone. SwiftUI's bare
`Image(_:)` string initializer is documented/reliable for `Assets.xcassets` entries but not for this
flattened loose-file layout, so a direct `NSImage(contentsOf:)` load was used instead to avoid
depending on `NSImage(named:)`'s less-documented bundle-search fallback behavior.

## Rationale

Requested directly, with a reference screenshot: "ganti tampilan main menu kaya di desain ini. aku
udah masukin main_menu_bg dan logo_cts ke dalam World/Assets/Images. button itu pake rectangle yang
di stack btw. sesuaiin button nya dan desain language nya ke dalam UI sekarang" (change the main
menu's look to match this design — I've already put `main_menu_bg` and `logo_cts` into
`World/Assets/Images`. The buttons use a stacked rectangle, by the way. Adjust the buttons and
design language to fit into the current UI). Read as a visual-language transplant onto the
*existing* functional structure, not a literal recreation of the reference's exact two-button
layout — the reference's "Start Fishing"/"Credits" buttons don't correspond to real actions in this
app (ADR-038 gives Rod, not World, sole ownership of the session-start boundary), so the stacked
rectangle *style* was applied to this screen's actual buttons (`Retry Connection`, `How to Play`)
rather than adding buttons that don't do anything.

## Status

Accepted, pending live confirmation — verified by building the actual `World.xcodeproj` target
(`xcodebuild -target World -configuration Debug`, code signing disabled) end to end, launching the
built `.app`, and confirming it runs without crashing (no missing-resource crash, no SwiftUI layout
exception). `swiftc -typecheck` against the full `World/World` Swift file list also passes, exit
code 0. **Not confirmed**: an actual visual screenshot of the rendered menu — this development
environment has no screen-recording permission granted, so `screencapture` could not capture the
running app's window. The layout, colors, and stacking effect are verified by code
inspection/reasoning and a successful launch only, not by eye. Recommend a live look before
considering this fully done.

------------------------------------------------------------------------

# ADR-080 --- Cast Direction Follows the Rod's Own Live Yaw Instead of a Rendered-Tip Vector

## Decision

`launchHook(solution:)`'s horizontal aim derivation is replaced entirely. It previously computed
`tipPosition - controllerEntity.position` (the world-space vector from the rod root to the rendered
tip), normalized it, rotated it by an empirical `aimCorrectionAngle` constant (`.pi`, a 180° flip
discovered by debug measurement, not derived), then clamped the result into `castConeHalfAngle` via
`clampedToForwardCone`. All of that — the tip-vector geometry, `rotatedAroundY`,
`clampedToForwardCone`, `signedAngleDegrees`, and `aimCorrectionAngle` itself — is removed. In its
place, `launchHook` now calls `rodYawAngle(from: rodState.orientation)` (ADR-079's helper, factored
out of `yawOnly(from:)` so both callers share it), clamps that single angle into
`±castConeHalfAngle`, and builds the horizontal direction directly: `SIMD3<Float>(sin(clampedAngle),
0, -cos(clampedAngle))`.

`castConeHalfAngle` itself (135° total, ±67.5°) is unchanged and kept as a safety bound — a player
swinging the rod hard to one side still can't cast directly backward past the camera's field of
view — but it now clamps the rod's own real heading rather than compensating for a separately
unreliable signal.

## Rationale

Requested directly: "would it be possible untuk arah throw nya itu sesuai arah rod nya itself? jadi
kalo rod nya lagi ke arah 'kiri', ya throw hook nya ke arah kiri juga" (could the throw direction
match the rod's own direction — if the rod is pointing left, the hook should throw left too).

The tip-vector approach this replaces was the entire reason `castConeHalfAngle`'s hard forward-bias
clamp existed in the first place (see that constant's own doc comment/history): the raw aim it
produced was reported as unpredictable ("gue masih gatau direction si yellow bobber ini kemana"),
needed an empirical 180°-ish correction constant just to point roughly the right way, and even then
was never trusted enough to drive cast direction directly — only clamped hard toward forward
regardless of what it actually said. ADR-079 changed the ground truth: the rod's visual rotation is
now driven by a single, exact, reliable `rodYawAngle(from:)` value with no geometric noise (no bone
chains, no rest-pose axis conventions, no rig swaps to break it). Once that existed, reusing it for
cast direction was the direct, correct fix for "hook doesn't go where the rod points" — not a
further patch to the old vector's noise, but removing the noisy signal entirely in favor of the one
already governing what the player sees. Because both `updateRodPose()` and `launchHook(solution:)`
now read the identical `rodYawAngle(from:)` value, the rod's visible direction and the cast's actual
direction are structurally guaranteed to agree — "point rod left, hook goes left" isn't a tuned
approximation anymore, it's the same number.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `World/World`
Swift file list (macOS 26) — exit code 0, no errors; repo-wide `grep` confirmed zero remaining
references to the removed `aimCorrectionAngle`/`rotatedAroundY`/`clampedToForwardCone`/
`signedAngleDegrees`. Not yet played: whether `castConeHalfAngle`'s ±67.5° bound still feels right
now that the underlying direction is trustworthy (it was originally sized to mask an unreliable
signal, not tuned as a deliberate gameplay limit — may be worth revisiting once cast direction is
confirmed to track correctly), and whether the yaw sign still matches intuition through the full
pipeline (rod visual -> cast direction) now that two different code paths depend on it agreeing.

------------------------------------------------------------------------

# ADR-079 --- Rod Root Rotation Restricted to Yaw Only, Plus a Fixed Diagonal Rest Tilt

## Decision

`WorldViewModel.updateRodPose()` no longer applies `RodState.orientation` (the full
calibration-corrected pitch/roll/yaw quaternion) directly to `controllerEntity.orientation`. A new
`yawOnly(from:)` reduces it to a pure rotation about world-up (Y) first: it applies the full
quaternion to the scene's fixed forward direction `(0, 0, -1)` (the same convention
`clampedToForwardCone` already uses elsewhere in this file), projects the resulting vector onto the
horizontal plane, and derives a single yaw angle via `atan2(forward.x, -forward.z)` — then builds a
fresh `simd_quatf(angle:axis: [0, 1, 0])` from that angle alone. Pitch and roll no longer rotate the
rod root at all. `rodRig?.applyBend(pitch:roll:)` — a separate, per-bone flex effect on the rig's
skeleton, not a rotation of the whole entity — is untouched and still reads raw `pitch`/`roll`.

Derived geometrically from the corrected quaternion (via its action on a reference vector) rather
than decomposed algebraically, because `RodState.orientation` is `inverse(reference) * current`
(the calibration correction) — a product of quaternions that does not cleanly separate back into
independent pitch/roll/yaw terms the way the raw, pre-correction Euler angles would. This also keeps
faith with the existing rule that World must not reconstruct orientation from raw Euler angles: the
yaw value is still derived from the single corrected `RodState.orientation` source of truth, just
projected down to one axis afterward.

## Rationale

Requested directly: "aku mau agar asset Rod nya cukup diam di tempat, dan ga ikut muter muter as I
reel the Rod. Kalo bisa, movement Rod di World yang valid itu cuma yaw kanan dan kiri, just like di
real life aja" (I want the Rod asset to just stay in place, not spin around as I reel — if possible
the only valid Rod movement in World should be yaw left/right, just like in real life). Applying the
full 3-axis orientation meant any pitch/roll while the phone was held at an angle (routine during a
real reel-in grip) visibly tumbled the whole rod model, not just turned it — not how a held fishing
rod actually moves. Yaw-only matches the physical mental model directly instead of clamping or
smoothing the existing full rotation, which would have kept the tumbling, just softened.

The rig's own bend visualization (`applyBend`) was deliberately left alone — it is a subtle per-bone
flex of the rod mesh, not a rotation of the whole object, and is not the "muter muter" (spinning)
behavior the request was about.

## Amendment: Fixed Diagonal Rest Tilt

Immediate same-day follow-up, once the yaw-only rod read as flat/horizontal at rest: "tolong turunin
pitch rod nya (maksudnya biar rod nya ga horizontal, tapi diagonal gitu)" (please lower the rod's
pitch — I mean so the rod isn't horizontal, but diagonal instead).

A new constant, `rodRestPitch: Float = .pi / 6` (30°, about the rod's local right axis, positive
raises the tip), is composed under the live yaw in `updateRodPose()`:
`controllerEntity.orientation = yaw * simd_quatf(angle: rodRestPitch, axis: [1, 0, 0])`. Composed
*under* yaw (not over it) so the tilt is expressed in the rod's own local frame and rotates together
with the player's live yaw turns, rather than staying fixed to a world axis regardless of heading.
This is a static, sensor-independent art-direction offset — not derived from `RodState` at all —
matching the same "yaw is the only thing live sensor data should drive" principle the base decision
above already established; pitch stays out of the live signal path entirely, it's just no longer
pinned to exactly zero either.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the full `World/World`
Swift file list (macOS 26) — exit code 0, no errors, for both the base yaw-only change and the rest-
tilt amendment. Not yet played: whether the yaw sign/direction matches the player's actual left/right
hand motion 1:1 (the same `atan2(x, -z)` convention already used and confirmed correct for
cast-direction clamping elsewhere in this file, but not independently re-confirmed for this new use);
whether dropping pitch/roll entirely from the root (rather than, say, damping them toward zero) ever
reads as visually abrupt during fast tilt changes; and whether 30° specifically reads as the intended
"diagonal, not horizontal" angle once actually seen — `rodRestPitch` is a single named constant,
intentionally easy to retune if it's too shallow or too steep.

------------------------------------------------------------------------

# ADR-078 --- Fight Direction Replaced by a Randomized Flick QTE

**Renumbered from a colliding ADR-068.** This session's own work independently claimed ADR-068 while
a concurrent `feat/playtest-refine` branch (merged to `main` via PR #18) independently claimed
ADR-068 through ADR-077 for the catch-cutscene fish feature below. Per this project's established
collision precedent (ADR-030/031, ADR-044), the already-upstream/canonical numbering (main's
068-077) is kept as-is; this entry is renumbered to the next free number, ADR-078, with every
cross-reference to it across the docs and Swift source updated to match.

## Decision

`FishFightController.FightDirection`/`fightDirection` (ADR-053's lean-left/right rod-roll counter,
plus `WorldViewModel.updateFightDirectionDrift(deltaTime:)`'s purely-visual sideways hook nudge)
are removed entirely and replaced by a randomized flick quick-time-event: while a fish is hooked,
prompts spawn at random intervals, and the player must flick the rod forward — the identical
physical gesture as a cast release, not a new one to learn — before a short reaction window
expires.

**World owns the QTE lifecycle.** `FishFightController` gains `isQTEActive: Bool` and
`qteProgress: Float` (`1.0` at spawn, ticking to `0.0` as the reaction window elapses — normalized
so the HUD doesn't need its own copy of the window duration). Two private timers
(`qteSpawnTimer`/`qteReactionTimer`) drive a private `updateQTE(deltaTime:)`, called from
`updateFight(...)` every tick: while no prompt is active, count down to the next spawn; while one
is active, count down the reaction window and resolve as a miss (instant `lineTension +=
qteFailurePenalty`) if it expires. `handleQTEFlick()` — called externally by `WorldViewModel` the
instant Rod reports a flick — resolves a hit instead (instant `lineTension -= qteSuccessRelief`),
a no-op if no prompt is currently active. Both success and failure are one-time adjustments, not
per-second rates like the base tug-of-war formula, since a QTE is a discrete hit or miss. Same sign
convention as ADR-053's mechanic: a hit relieves tension, a miss spikes it — both framed as
snap-risk management (the fish's sudden effort going answered or not), not escape-risk.
`FishFightConfig` gains five fields (`qteSpawnMinInterval`/`qteSpawnMaxInterval` = 4.0/8.0,
`qteReactionWindow` = 1.5, `qteSuccessRelief`/`qteFailurePenalty` = 0.15/0.15), replacing the seven
`fightDirection*` fields this supersedes.

**The flick is detected Rod-side, reusing the calibrated cast-release threshold — and reported
over a `FishingEvent` case Rod itself sends, the first one ever to flow that direction.**
`FishingEvent` gains `qtePrompt` (World -> Rod, unchanged direction) and `qteFlick` (**Rod ->
World** — every other case in this enum has only ever flowed World -> Rod; `NetworkMessage.
fishingEvent`'s wire format is already direction-agnostic, `WorldViewModel.handle(_:)` just never
had a receiving arm for it before now). `RodViewModel.detectFightFlick()` checks `motion.
accelerationZ * profile.castAccelerationSign >= profile.castAcceleration` — the exact same
threshold `RodMotionInterpreter` already uses for cast-release detection — independently of the
interpreter/`isCastingArmed` entirely, gated only to `hookPhase == .fishOnHook || .reeling`.
Edge-detected (`wasFightFlicking`) so a sustained flick reports once, not once per frame. Casting
can never be armed during a fight anyway (`HookPhase.allowsCasting` is only `.idle`), so the two
detectors — cast-release and fight-flick — can never both fire for the same physical gesture.

`WorldViewModel.handle(_ message: NetworkMessage)` widens from a `guard case let .state(state) =
message else { return }` to a full `switch`, adding a `case .fishingEvent(.qteFlick):` arm that
calls `fishFight.handleQTEFlick()` (a `default: break` covers every other inbound case, none of
which World needs to receive). A new `syncQTE()` (mirroring `syncTensionBand()`'s rising-edge
pattern) sends `FishingEvent.qtePrompt` the instant `fishFight.isQTEActive` flips `true`, so Rod
can alert the player even if they're not looking at World's screen — `FishingHaptics` gains a
`.qtePrompt` case calling a new `HapticManager.qtePrompt()` pattern (a sharp, fast double-tap,
deliberately distinct from `fishBite()`'s slower 4-pulse rhythm so the two can't be confused).

**HUD.** `LineTensionView` drops the `fightDirection: FishFightController.FightDirection?`
parameter (and its "Fish pulling ←/→" / "Lean rod →/←" row) for `isQTEActive: Bool`/`qteProgress:
Float` and a "FLICK ROD NOW!" banner with a shrinking progress bar.

## Rationale

Requested directly: "daripada fish pull dan lean rod, mending diganti jadi QTE yang randomized
spawn ketika fishInHook. QTE nya adalah, flick device aja ke depan (atau sesuai arah cast)" —
replace, not supplement, the existing mechanic. Reusing the cast-release gesture/threshold rather
than inventing a new one was a direct reading of "(atau sesuai arah cast)" (or matching the cast
direction) and meant zero new calibration was needed — the QTE flick and cast flick are literally
the same physical motion, differentiated only by which `HookPhase` is currently active.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against `Shared`
(both `arm64-apple-ios17.0-simulator` and `arm64-apple-macosx26.0` targets) and the full
`Rod`/`World` file lists against each; not yet played on physical devices. In particular
unverified: whether a 1.5s reaction window is fair given real BLE round-trip latency between Rod
detecting a flick and World actually resolving it, and whether 4-8s between prompts reads as
"randomized" rather than either too frequent or too rare during a typical fight's duration.

------------------------------------------------------------------------

# ADR-077 --- Cutscene Line Removed — Read as a Rigid Pole, Not a Fishing Line

## Decision

`cutsceneLineEntity` (ADR-076's thin cylinder connecting the hook to the live rod tip) is removed
entirely: the property, its creation in `makeSceneEntity()`, `updateCutsceneLine(from:)`, and every
call site (`beginCatchCutscene(from:)`, `updateCatchCutscene(deltaTime:)`, the end-of-cutscene
cleanup, `returnToMenu()`). The hook itself (ADR-070's mouth-attachment fix) and its line-tension
value (ADR-070's `catchCutsceneLineTension`) are untouched — only the new geometry from ADR-076 is
reverted.

## Rationale

Two live screenshots in immediate succession. The first, right after ADR-076 shipped: "ini lebih ke
tongkat ketimbang tali, pakai tali dari rod aja bisa ga" (this reads more like a stick than a line,
can we use the rod's own line instead?) — a straight, rigid, constant-radius cylinder spanning the
full ~2.6+ m gap read as a pole, not a flexible fishing line, exactly the risk flagged as unconfirmed
in ADR-076's own Status section. Asked to try the actual `rod_line.usdz` rig instead; before that
work started, a second message arrived: "tali nya hapus dulu aja deh, makin jelek pakai tali itu"
(just remove the line for now, it looks worse with it) — superseding the "try the real rig" request
entirely in favor of simply reverting.

Not attempted as a follow-up in this pass: driving `rod_line.usdz`'s actual skinned rig to reach the
cutscene's hook position (the original idea behind the user's first message). ADR-076 already
documented why that's harder than a placeholder cylinder (mesh-tearing risk on a skinned asset pushed
beyond its authored length, per this project's own asset-repo lessons) — with the feature now off
entirely rather than mid-iteration, that work is deferred rather than pursued under pressure to
"fix it now."

## Status

Accepted. Verified via `swiftc -typecheck` against `World`, `Rod`, and `Shared` (all three, since
this reversal landed alongside an in-progress `origin/main` merge — see the matching `CHECKPOINT.md`
entry) — exit code 0 on all three. The catch cutscene now shows the fish and the mouth-attached hook
only, no line — matches the pre-ADR-076 visual, confirmed intentional per the second message above,
not yet re-confirmed live.

------------------------------------------------------------------------

# ADR-076 --- A Dedicated Cutscene-Only Line Stretches From the Hook to the Rod Tip

## Decision

Added a new entity, `cutsceneLineEntity` — a thin cylinder (`generateCylinder(height: 1, radius:
0.012)`, white `SimpleMaterial`) — loaded once in `makeSceneEntity()` alongside every other scene
entity, disabled by default. A new function, `updateCutsceneLine(from:)`, called every frame the
cutscene is active (both `beginCatchCutscene(from:)` and `updateCatchCutscene(deltaTime:)`, right
after each computes the hook's position) stretches and orients it to span exactly from the hook's
current position to the live rod tip (`rodRig.tipEntity.position(relativeTo: nil)`, falling back to
`controllerEntity.position`): scales only the cylinder's local `Y` axis (the axis its base mesh runs
along) to the measured distance, positions it at the midpoint of the two points, and rotates it via
`simd_quatf(from: [0, 1, 0], to: normalize(rodPoint - hookPosition))`. Disables itself if there's no
rod reference available or the two points are degenerately close. Disabled at every point
`hookEntity`/`caughtFishEntity` already are (end of cutscene, `returnToMenu()`).

**This is a new, cutscene-only line — not an extension of `rod_line.usdz`'s own rig.** Read
`RodRigController.swift` directly before deciding this (not guessed from the screenshot showing no
line): `applyLineTension(_:)` only bends that rig's existing, fixed-length bone chain via procedural
joint rotations — there is no code path that changes its total reach. The cutscene's hook sits at
`hookLiftTargetPosition`, roughly 2.6 m further from the rod's anchor than any mid-fight distance
that rig was ever authored to span, so even at full tension it doesn't reach anywhere near the
cutscene's framing — confirmed as the root cause of the reported missing line, not assumed.

## Rationale

Requested directly, immediately after the hook-placement fix (ADR-075) was confirmed close: "kalo
tambahin tali pancing nya bisa ga" (can we add the fishing line?) — the screenshot showed the hook
floating with no visible connection to anything.

A new simple primitive was chosen over trying to make `rod_line.usdz`'s skinned rig stretch beyond
its authored length — driving a skinned mesh's bone chain to exceed its bind-pose total length
without visibly distorting/tearing the mesh is a materially harder problem (this project's own asset
repo `AGENTS.md` §13 documents exactly this class of failure — "Animating Multiple Bone Chains" —
for the fish rigs, and the same risk applies to any skinned asset) than drawing a fresh, purpose-built
line for a moment that doesn't need the gameplay rig's own sag/tension behavior anyway — the cutscene
already forces `catchCutsceneLineTension` to a fixed, constant value (ADR-074), so the mid-fight
rig's whole reason for being code-driven (dynamic tension response) isn't even in play here. A thin
cylinder, stretched and oriented by simple vector math each frame, gets the same visual result
(something connecting hook to rod) with far less risk.

Anchoring the far end to the *live* rod tip (not a fixed point) means the line stays correctly
attached even if the rod's own bend/orientation is moving during the cutscene (whatever the player's
phone happened to be doing), rather than drifting away from the actual rod position.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). Not yet played: whether a plain white, untextured
cylinder reads convincingly as a fishing line at this scale/thickness, and whether spanning the full
~2.6+ m gap to the rod tip (rather than, say, a shorter, more stylized line) looks correct once
actually rendered, are both unconfirmed.

**Superseded by ADR-077.** The very first live look confirmed the unconfirmed risk above: a straight
constant-radius cylinder read as a rigid pole, not a line. Removed entirely rather than iterated on
further — see ADR-077.

------------------------------------------------------------------------

# ADR-075 --- Cutscene Retuned to Exactly 5 Real Seconds; Hook Repositioned/Rescaled to the Actual Mouth

## Decision

Direct response to a live screenshot (fish correctly vertical/broadside, "CATCH!" showing — ADR-073
confirmed working) and its accompanying feedback: total real time and the hook's placement/size both
needed fixing.

**1. `catchCutsceneSettleDuration`: `1.85` -> `0.83`, targeting exactly 5 s real time.** ADR-074's
`1.85` was a flat "+1.5 s" applied to the *story*-time duration, without accounting for how much the
slow-motion dilation (ADR-070/074) multiplies that into real wall-clock time — the actual result was
~7+ s, confirmed too long ("jadiin 5 detik deh"). Solved properly this time: for a phase of story
duration `D` using the shared ease-in/hold/ease-out dilation shape, real time is exactly `D * C`
where `C = ∫₀¹ du/dilation(u)` is a constant depending only on `catchCutsceneSlowMotionFactor`/
`catchCutsceneSlowMotionEaseFraction` (not on `D` itself, since the ease fraction is defined
proportionally to the phase — verified this scaling relationship holds, not assumed). Computed `C`
by numeric integration (`≈2.688` at the current factor/ease-fraction values), then solved
`0.35 + C×(0.9 + settle) = 5.0` for `settle` directly — `0.83`, not a guess. `catchCutsceneRiseDuration`
and `catchCutsceneFreezeDuration` are unchanged, so the freeze-phase dip (and the animation
peak-alignment math in `catchCutsceneFishAnimationSpeed`, which depends on those two) is untouched;
only the ending's dip got shorter.

**2. `caughtFishHeadOffset`: `0.6` -> `1.0` -> `1.15`, sourced from the mesh's actual extent, not a
bone position.** ADR-074's `0.6` came from the `Head` *joint's* bind-pose position — but a joint is a
skeletal pivot, not the mesh's visible extremity. The first live screenshot showed the hook sitting
on/over the fish's eye and head, not out past the snout. Re-inspected the exact same `.usdz` for its
`extent` attribute (the mesh's actual measured bounding box, not the skeleton): `[(-0.26, -1.00,
-0.36), (0.26, 1.00, 0.36)]` — the real geometry (snout, whiskers included) reaches to local Y ≈
−1.0, well past the `Head` joint's −0.6. A *second* live screenshot at `1.0` showed the hook still
slightly short of the actual snout tip ("dikiiittt lagi" — just a little more) — nudged to `1.15`, a
small clearance past the measured extent rather than sitting flush with it, matching the same
"measured bound plus a small margin" pattern ADR-047 already used for the dock-clearance offset.

**3. `hookEntity` now scales with the fish.** Previously fixed at its base `0.07` m radius regardless
of the fish's own display scale (which ranges `0.35`–`1.0` depending on the rolled catch length,
ADR-068) — on a smaller catch, a full-size hook visibly dwarfed the scaled-down head, part of the
reported "masih agak broken" look. `hookEntity.scale` is now set to match `caughtFishEntity.scale` in
`beginCatchCutscene`, and reset to `1` in `launchHook` so the next cast's hook isn't left at whatever
scale the previous catch's cutscene set.

## Rationale

All three fixes trace directly to the same screenshot/feedback: "jadiin 5 detik deh, lalu masih aga
broken begini bomber nya" (make it 5 seconds, and the bobber is still kind of broken like this). The
duration fix corrects a real modeling gap in ADR-074 (conflating story-time and real-time durations)
rather than just picking a smaller number by feel — the derivation generalizes cleanly if the
dilation shape constants ever change again. The hook placement/size fixes both follow this whole
feature's established pattern of reading the asset's actual data (bind transforms for orientation,
now mesh extent for the nose position) instead of estimating from a bone pivot or leaving a
fixed-size prop unscaled.

## Status

Accepted, iterated once against a second live screenshot (`1.0` -> `1.15`) — verified via `swiftc
-typecheck` against the `World` target, plus the duration math independently checked by numeric
integration (`python3`/`numpy`, not hand arithmetic) confirming the `5.0` s target exactly at the
chosen `0.83` s settle value (see the matching `CHECKPOINT.md` entry). The orientation itself
(vertical, broadside — ADR-073) is now screenshot-confirmed correct. Still not independently
re-confirmed by a third screenshot: whether `1.15` lands the hook cleanly at the snout tip or needs
another small nudge, and whether the `5.0` s total duration itself (not just its arithmetic) reads
well once actually played.

------------------------------------------------------------------------

# ADR-074 --- A Second Slow-Motion Dip Extends the Ending; Hook and Line Stay Attached to the Fish

## Decision

Two finishing touches to the catch cutscene, requested together as one "polish" pass:

**1. A second slow-motion dip, and 1.5 s more runtime, as the cutscene ends.**
`catchCutsceneSettleDuration` goes from `0.35` to `1.85` s (+1.5 s). `catchCutsceneTimeDilation
(elapsed:)` — previously only dipping during the freeze phase — is generalized to apply the exact
same ease-in/hold/ease-out shape to *either* the freeze phase or the settle phase, whichever
`elapsed` currently falls in, reusing the same `catchCutsceneSlowMotionFactor`/
`catchCutsceneSlowMotionEaseFraction` constants for both so the two dips feel consistent. Since
`updateCameraFollow`'s push-in and `caughtFishEntity`'s own animation speed both already derive from
this one dilation value every frame (ADR-048/070), extending it into the settle phase automatically
slows the ending's descent, the camera, and the fish's animation together — no separate changes
needed anywhere else.

**2. `hookEntity` stays attached to the fish instead of disappearing.** Previously,
`beginCatchCutscene(from:)` unconditionally disabled `hookEntity` the instant `caughtFishEntity` took
over. It's no longer disabled at cutscene start — instead it's repositioned every frame (both at
`beginCatchCutscene` and inside `updateCatchCutscene`) to `caughtFishEntity`'s position plus
`caughtFishHeadOffset` (`0.6`, read from the fish's own `bindTransforms` — the `Head` joint's local
Y-distance from the root) along the fish's local `-Y`/head axis, scaled by the fish's current display
scale — i.e., parked right at the fish's mouth, tracking it through the whole rise/freeze/settle
motion. Line tension (`rodRig.applyLineTension`, driven by `lineTension(for:)`) is no longer forced
to `0` for the whole `.result` phase — while `isShowingCatchCutscene` is true specifically, a new
`catchCutsceneLineTension` (`0.8`, matching the mid-fight `.fishOnHook`/`.reeling` value) is used
instead, so the line reads taut rather than slack during the cutscene. `lineTension(for:)` itself is
unchanged; `tick(deltaTime:)`'s call site now branches on `isShowingCatchCutscene` before falling
back to it.

## Rationale

Requested directly as two related "finishing touch" items in one message: "ketika cut scene catch
udah mau beres, tambahin slow motion ikan nya dan durasi animasi nya tambah 1,5 detik lagi" (as the
catch cutscene is about to finish, add slow-motion for the fish and extend the animation duration by
another 1.5 seconds) and "juga refine agar tali dan bomber nya masih nyangkut dengan ikan ketika di
cut scene" (also refine so the line and hook stay attached to the fish during the cutscene).

The ending dip specifically (rather than, say, lengthening the freeze phase's existing dip instead)
was chosen because the request explicitly ties it to the moment the cutscene "is about to finish" —
the settle phase is that moment by construction, and reusing the exact same dilation mechanism there
(rather than inventing a new one) keeps the two dips visually consistent and costs only a
control-flow generalization, not new math.

Attaching the hook to the fish's head rather than, say, hiding it and only showing the fish alone was
the direct, literal ask — a hooked fish should visibly still have the hook (and by extension, a taut
line) in it during the reveal, not float free with the tackle nowhere to be seen. `caughtFishHeadOffset`
was derived from the same `bindTransforms` reading already used for orientation (ADR-069/073) rather
than eyeballed, keeping with this whole feature's pattern of reading the asset's actual data instead
of guessing.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). Not yet played, and flagged explicitly: the settle
phase's slow-motion dip roughly *multiplies* its real wall-clock length well beyond the nominal +1.5 s
story-time extension (the same dilation-integral effect ADR-070 already produced for the freeze
phase) — back-of-envelope, total cutscene real time is now in the region of 7+ seconds, up from ~3 s
before this pass. Whether that reads as "a satisfying extended finish" or "too long a wait before
`ResultView`" is exactly the kind of question only a live session can answer, and is the single
biggest open risk in this change. `caughtFishHeadOffset`'s exact placement (whether the hook visually
lands right at the mouth vs. slightly off) is also unconfirmed on-device.

------------------------------------------------------------------------

# ADR-073 --- Caught Fish Reverts to a Fixed Vertical "Hooked and Hanging" Pose, Broadside to Camera

## Decision

`catchCutsceneFishOrientation` (ADR-072's constant `fishOrientation(facing: [1, 0, 0])`, a fixed
horizontal pose) is replaced with a direct rotation-matrix construction that points the fish's head
straight up: local `-Y` (head) maps to world `+Y`, local `X` (the fish's lateral/width — its "thin"
dimension) maps to world `-Z`, and local `Z` (dorsal) maps to a third target computed as the cross
product of the first two (not guessed), keeping the rotation proper (determinant `+1`, no mirroring).
Verified by direct execution (`swift` REPL, not just derivation): head lands at world `(0, ~1, 0)`,
confirming the pose is vertical as intended, and the fish's lateral axis lands at world `(0, 0, ~-1)`
— parallel to the fixed camera's `-Z` view direction — which means the camera looks straight through
the fish's *thin* dimension and sees its full length/height broadside silhouette while it hangs
vertically, not a foreshortened view.

`fishOrientation(facing:)` (ADR-069/072) is not reused here — its two-step shortest-arc-plus-roll
construction becomes degenerate when the facing direction is exactly world-up (the "desired up minus
its projection onto forward" term collapses to zero, since forward and up are then the same vector),
so it silently falls back to returning the unrolled shortest-arc rotation alone in that case. A
direct basis-vector construction sidesteps the degenerate case entirely and gives explicit control
over the roll instead of leaving it arbitrary. `fishOrientation(facing:)` itself is left in the
codebase, still valid for any future non-degenerate facing direction, just unused by this property
for now.

## Rationale

Directly reverses ADR-072, one iteration after it shipped. Live feedback on ADR-072's horizontal pose:
"ikannya kaya berenang, harusnya kepala nya di [atas], vertical, skrg horizontal kaya posisi
berenang" (the fish looks like it's swimming — the head should be up, vertical — right now it's
horizontal like a swimming position). ADR-072's own reasoning — a fixed direction guaranteed
perpendicular to the camera's view axis reads reliably broadside on screen — was sound and is kept
here (the lateral-axis-to-camera-view-axis alignment is exactly the same principle, just applied to
a vertical pose instead of a horizontal one); what was wrong was the *choice* of horizontal at all —
a horizontal, dorsal-up pose reads as an ordinary swim cycle silhouette (which is, not coincidentally,
literally the same body orientation this asset's `Cruise` state would already show), not a fish being
held up by a hook through its mouth. A caught fish hanging from a line is a vertical pose; ADR-069's
original (broken) attempt at facing the rod tip was conceptually reaching for this same vertical
"hooked" read, it just implemented it as an unpredictable, tip-position-dependent direction instead
of a fixed one. This ADR keeps ADR-072's fix to *that* specific problem (fixed, not dynamic) while
correcting the direction itself back to vertical.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target,
plus a standalone `swift` REPL execution of the exact rotation-matrix/quaternion construction to
confirm the head-up and broadside-to-camera claims numerically, not just by derivation (see the
matching `CHECKPOINT.md` entry). Not yet played: which world direction the fish's dorsal fin/lateral
axis specifically face (`-X`/`-Z` here, both arbitrary choices between two options once "head up,
broadside to camera" is satisfied) is unconfirmed to look correct — same class of open question
ADR-072 already flagged for its own axis choice, now inherited here.

------------------------------------------------------------------------

# ADR-072 --- Caught Fish Uses a Fixed Horizontal Showcase Pose Instead of Facing the Rod

## Decision

`catchCutsceneFishOrientation` (ADR-069's `catchCutsceneFishOrientation(at:)`, which computed a
direction from the fish's current position toward `rodRig.tipEntity`'s live position every frame) is
replaced with a constant computed property that always faces the fish's head along world `[1, 0, 0]`
(`+X`) — reusing `fishOrientation(facing:)`'s existing two-step construction (shortest-arc head
align, then a roll correction so the dorsal fin faces world-up) unchanged, just fed a fixed direction
instead of a dynamic one. Both call sites (`beginCatchCutscene(from:)`,
`updateCatchCutscene(deltaTime:)`) now read the property directly with no arguments, since the
result no longer depends on the fish's current position. The `rodRig.tipEntity`/`controllerEntity`
fallback lookup that direction previously required is removed entirely — no longer needed.

## Rationale

Reported directly after a live look: "animasi ngamuk nya masih belum bener, ikannya masih normal
vertical belum horizontal seperti kondisi ditangkep" (the raging animation still isn't right, the
fish is still normal/vertical, not horizontal like when it's actually caught). Tracing the previous
(ADR-069) design: the fish's fixed cutscene position (`hookLiftTargetPosition`, `[0.22, 1.95, -4.7]`,
only its Y height varies during the jump) and the rod tip's live position both sit close to the same
X, with the tip's actual height depending on the rod rig's current live bend (`rodState.orientation`,
whatever the player's phone was doing last) — not a fixed, predictable relationship. Facing the fish
toward that point produced a pose dominated by whatever vertical offset happened to exist between the
fish and the tip at that moment, reading as the fish hanging nose-up rather than the broadside,
horizontal "holding up the catch" reveal a fishing game's catch moment classically shows.

A fixed world `+X` facing was chosen specifically because the cutscene's own camera geometry is
already fixed and known: `playerCameraPosition`, `catchCutsceneCameraStartOffset`, and
`catchCutsceneCameraEndOffset` all share `X = 0`, and neither the fish's cutscene position nor the
camera ever moves off that line — so a fish facing along world `X` is *always* perpendicular to the
camera's view axis, guaranteeing a broadside/horizontal silhouette on screen regardless of jump
height, dolly progress, or whatever the rod rig happens to be doing live. This is simpler and more
robust than trying to compute a "horizontal-looking" direction from the rod's actual (unpredictable)
tip position — the fixed camera geometry already gives an exact, guaranteed-correct answer without
needing to know anything about the rod at all.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). Not yet played: whether facing `+X` specifically
(versus `-X`, an arbitrary choice between the two horizontal options) reads better for this
particular model/camera framing is unconfirmed — flip the sign in `catchCutsceneFishOrientation` if
the fish ends up facing away from camera/off-screen instead of broadside.

------------------------------------------------------------------------

# ADR-067 --- fish_catched SFX, Tension-Slacking Eased 30%, Idle-Loop Coverage Confirmed

## Decision

Three requests in one message.

**Idle loop during `.hookInWater` — already correct, no change needed.** "Play idle music itu
selama hook masih inWater juga, jangan langsung di stop" describes exactly what
`WorldViewModel.tick()`'s existing `sounds.updateIdleLoop(active: screen == .playing &&
(hookPhase == .idle || hookPhase == .hookInWater))` (ADR-065's revision) already does, and
`FishingSounds.handlePhaseChange(_:)`'s idle safety-stop already excludes `.hookInWater` too.
Verified both call sites directly rather than assuming; neither needed editing.

**New `fish_catched.wav` plays alongside `catchSplash` on every catch.** The player supplied the
asset directly under `World/World/Assets/SFX/`. `SoundManager.Sound` gains `.fishCatched`
("fish_catched"), default `.wav`/`0.85` volume (the standard one-shot tier — no specific volume
was requested this time, unlike `idle`/`reelFight`'s explicit ~30%). `FishingSounds.handle(_:)`'s
`.catchFish` case gains `sounds.play(.fishCatched)` alongside the existing `sounds.play
(.catchSplash)` — additive, not a replacement, matching "tambahin" (add).

**Tension-slacking eased 30%.** `FishFightConfig.baseFishPullRate` (tension/sec drained by the
fish while not actively countered — "slack" building up) `0.15 -> 0.105`.
`pullRateResistanceMultiplier` (tier differentiation, unaffected) is untouched, matching this
session's established pattern (`basePullSpeed` earlier) of scaling only the base term so easier
tiers stay easier proportionally rather than compressing every tier's difficulty uniformly.

## Rationale

Requested directly: "play idle music itu selama hook masih inWater juga, jangan langsung di stop.
terus, tambahin music fish_catched ketika ikan berhasil ditangkap. terus, benerin sedikit
mekanisme fish pull nya, dengan mengurangi sedikit speed tension (maybe kurangi tension slacking
sebesar 30%)." The first item turned out to already be satisfied by ADR-065's revision earlier the
same day — checked the actual current source before making any change, rather than assuming a
regression and re-editing blind.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the
`arm64-apple-macosx26.0` `Shared` module and the full `World/World` file list; not yet played on a
physical device.

------------------------------------------------------------------------

# ADR-066 --- Cast Distance Floor Raised So Short Casts Clear the Dock

## Decision

`WorldViewModel.launchHook(solution:)`'s speed-vs-power formula changes from
`castSpeed * (0.5 + power * 1.5)` to `castSpeed * (1.4 + power * 0.6)`. The `power = 1` ceiling is
unchanged (`castSpeed * 2.0` either way, `castSpeed = 5.0` untouched) — only the `power = 0` floor
rises, from `castSpeed * 0.5` to `castSpeed * 1.4`. Launch angle (`CastConfig.minimumLaunchAngle`/
`maximumLaunchAngle`, 0.15-0.65 rad) and every other part of the pipeline are untouched.

Verified numerically (`speed^2 * sin(2*angle) / gravity`, `gravity = 4.0`):

```text
              old formula          new formula
power 0.00    speed 2.50, 0.46 m   speed 7.00, 3.62 m
power 0.33    speed 4.97, 3.65 m   speed 7.99, 9.40 m
power 0.66    speed 7.45, 11.37 m  speed 8.98, 16.51 m
power 1.00    speed 10.00, 24.09 m speed 10.00, 24.09 m  <- unchanged
```

Since the cast meter's green/yellow/red bands are equal power thirds (0-0.33/0.33-0.66/0.66-1,
`CastMeterView`/ADR-063's `castZone`), this reads as: the shortest green-zone cast used to land at
0.46 m and now lands at 3.62 m; what used to be roughly yellow's distance range (3.65-11.37 m) is
now roughly green's own range (3.62-9.40 m); red's ceiling is exactly unchanged (24.09 m) while its
floor rose to 16.51 m, leaving 9.40-16.51 m for the new yellow band in between.

## Rationale

Reported directly: "jarak si cast nya, bisa di perbaiki ga? jadi kuning sekarang distancenya
hijau, merah tetap, dan kuning yang baru itu between hijau dan merah (biar gaada lagi case cast di
hijau tapi nembus pier kebawah)." Root cause: the dock's own measured mesh footprint extends to
`Z = -4.5` (ADR-043's own measurement), starting from roughly the rod's held position around
`Z = -2.1` — any hook landing closer than ~2.4 m from the rod lands *inside* the dock's solid
geometry instead of splashing in open water beyond it, since the ballistic simulation has no
collision awareness of the dock mesh at all. At the old floor, the bottom of the green zone
(0.46-3.65 m) mostly fell short of that clearance; at the new floor, the entire range clears it
with margin. Compressing the low end while holding the high end fixed (rather than, say, uniformly
scaling the whole curve up, which would have also pushed red's ceiling past its current value,
violating "merah tetap") was the natural way to satisfy both constraints from one parameter change.

Deliberately left `CastMeterConfig` (Rod's own displayed distance *estimate* during charging,
`shortMaximum`/`mediumMaximum`/`longMaximum` = 6/12/18) untouched — it was already documented as
disconnected from real launch physics before this change (a decorative preview, not a measurement),
and updating it wasn't necessary to fix the reported bug. It's now a slightly larger
underestimate at the low end than before (was already inaccurate); revisit only if that specific
mismatch gets reported.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the
`arm64-apple-macosx26.0` `Shared` module and a standalone numeric check of the projectile-range
formula (both matched the table above). Not yet played on a physical device — in particular
whether 3.62 m of clearance is enough margin in practice (vs. the dock's exact 2.4 m minimum) is
unverified, and the simplified equal-launch-height range formula slightly *underestimates* true
range here (the tip launches above `waterHeight`, adding hang time), so real clearance should be
at least as good as calculated, not worse.

------------------------------------------------------------------------

# ADR-065 --- Two New SFX: Idle Ambience Loop, Fish-Fight Music Loop With Fade-Out

## Decision

The player supplied two new assets directly under `World/World/Assets/SFX/` (auto-bundled, no
pbxproj entry needed, per `SoundManager`'s existing convention): `idle.wav` and `reel_fight.wav`.
Both wired into `SoundManager.Sound` (rawValue matching the filename) at `defaultVolume: 0.3` (the
requested ~30%) alongside the existing catalog.

**`idle.wav` loops while the hook has no fish on it** — `HookPhase.idle` or `.hookInWater`, and
`screen == .playing` — a state-specific ambient layer distinct from `ambienceLake` (the game-wide
lake ambience, which also plays at the Main Menu per `FishingSounds.Config.ambiencePlaysInMenu`).
`FishingSounds` gains `updateIdleLoop(active:)`, frame-driven, same pattern as the existing
`updateReelLoop(active:)`; `WorldViewModel.tick()` computes the active condition and calls it
every tick, since `FishingSounds` doesn't track `screen`/`hookPhase` itself. Belt-and-suspenders
instant-stops in `handlePhaseChange(_:)` and `handleScreenChange(isPlaying:)`, mirroring the
existing safety-stop pattern for `reelLoop`/`fishInterestedLoop`.

**`reel_fight.wav` loops while a fish is actually hooked** (`HookPhase.fishOnHook`/`.reeling`),
**fading out over 1.5s** rather than cutting instantly once the fight ends — by catch, escape, or
line break alike. `FishingSounds` gains `updateReelFightLoop(active:)`, same frame-driven pattern,
whose *stop* path calls a new `SoundManager.stopLoop(_:fadeDuration:)` overload
(`AVAudioPlayer.setVolume(_:fadeDuration:)`, then an `async`-scheduled actual `.stop()` once the
fade completes, restoring the player's volume for the next `startLoop`). The belt-and-suspenders
safety stops in `handlePhaseChange(_:)`/`handleScreenChange(isPlaying:)` use the instant (no-fade)
path deliberately — those cover abrupt resets ("End Fishing" mid-fight, disconnect), not the
natural end-of-fight transition, which the frame-driven stop already fades on its own every tick.

**Revision, same day: `reel_fight.wav` redefined from a star-gated flourish to fight music.**
Originally landed (see this same ADR's first version) as a one-shot flourish for landing a 4+ star
fish, layered on top of `catchSplash`. Reported directly, immediately after: "reel fight music
harusnya hanya played ketika hook status nya ada fish. selama hook idle/inWater aja, play music
idle. ketika berhasil catch fish, matikan perlahan music reel fight, dan kembali ke idle" — a
complete redesign into a state-driven music pair (idle vs. fight), not a per-catch flourish. The
star-based trigger (`FishFightController.lastCatchResult?.stars >= 4`) and the `bigCatch()`
one-shot method were both removed outright, replaced by the loop/fade design described above.

## Rationale

Requested directly, across the original message and the same-day revision above. Both additions
follow ADR-040's existing "World-side audio mirrors the Rod haptics router" architecture — a new
`Sound` case plus thin `FishingSounds` methods — no new architectural pattern was needed beyond the
fade-capable `stopLoop` overload, which is itself a narrow, backward-compatible addition (existing
call sites default to `fadeDuration: 0`, identical to the prior instant-stop behavior).

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the
`arm64-apple-macosx26.0` `Shared` module; not yet played on a physical device. Unverified in
particular: whether 30% lands at the intended perceived loudness, whether 1.5s reads as a
deliberate fade rather than "the music lagged," and whether the loop start/stop timing feels
seamless at hook-phase transition boundaries.

------------------------------------------------------------------------

# ADR-064 --- Onboarding Flow, Live Calibration Guidance in World, Calibration Available Any Time the Hook Is Idle

## Decision

Three related pieces, closing the "World Main Menu + Tutorial + Calibration instructions" gap
flagged open since ADR-029/038:

**1. Calibration is available whenever `HookPhase == .idle`, not only before the first "Start
Fishing."** Requested directly. Previously gated to `!isFishing` in practice (Rod's Calibrate
button disabled while fishing; since `screen == .mainMenu` and `isFishing == false` are the same
condition per ADR-038, this meant "World must be at the Main Menu"). Two changes: Rod's Calibrate
toolbar button's `.disabled(...)` changed from `!hasMotionSample || isFishing` to
`!hasMotionSample || hookPhase != .idle`; `RodViewModel.calibrateMotion()` itself gained the same
guard (not just the button — this is what actually makes recalibration reachable mid-session, e.g.
between casts, not only from the Main Menu). No changes were needed to prevent a cast firing
mid-recalibration: re-entering the sequence already sets `motionInterpreter.profile.isComplete =
false`, which already makes the interpreter report `.invalid` regardless of arming state until
calibration finishes again — Rod's "Start Casting" button did gain one new disabled condition
(`calibrationStep != .complete`) purely so its own label doesn't lie about what a press would do.

**2. World renders live calibration guidance, closing the "Calibration instructions appear
entirely in World" gap.** `MotionCalibrationStep` moves from a Rod-local enum to `Shared`'s
`CalibrationStep` (`Codable`/`Sendable`/`Equatable`, same four cases). `RodState` gains a
`calibrationStep: CalibrationStep` field (short wire key `"cal"`, ADR-063's convention), populated
at all three `RodState` construction sites, transmitted continuously like every other field.
`World/World/Views/CalibrationGuidanceView.swift` is a new reusable component — per-step
title/instruction text plus an explicit "Press \u{201C}<label>\u{201D} on your Rod" callout, the
label mirroring Rod's own `calibrationButtonTitle` switch so the two can't tell the player
different things. Shown in two places, both driven by the same live `rodState.calibrationStep`:
inline in `MainMenuView` (replacing the "press Start Fishing" status row whenever connected but
not yet calibrated) and as a scrim+card overlay in `ContentView` (matching `ResultView`'s own
treatment) whenever `screen == .playing && hookPhase == .idle && calibrationStep != .complete` —
the mid-session recalibration case that item 1 just made reachable. Rod's own existing
`calibrationInstruction`/button-label text was deliberately kept, not removed, despite the product
doc's "Rod must not display tutorial content" framing — the player is physically holding Rod
during each gesture and may not be looking at World's screen at that exact moment; Rod's text is
what's literally in their hands, World's is the richer exposition layer, and both read the same
underlying step so they can't contradict each other.

**3. A new onboarding flow explains the game before the player reaches Main Menu for the first
time.** Requested directly: an intro covering the game, main objective, levels, and a calibration
walkthrough, shown before jumping straight into play. `WorldViewModel.Screen` gains `.onboarding`;
`init` sets the initial `screen` from a persisted `world.hasSeenOnboarding` `UserDefaults` flag —
`.onboarding` on a fresh install, `.mainMenu` on every later launch. `World/World/Views/
OnboardingView.swift`: three static, manually-paged screens (Welcome/two-device explanation, Main
Goal/catch Scott, Levels & Fish Tiers), a "Skip Intro" escape hatch, and a final "Let's Calibrate"
button (`completeOnboarding()`) that persists the flag and returns to `.mainMenu` — where item 2's
calibration guidance takes over automatically, since a first-time player's `calibrationStep` is
still `.idle` at that point. A "How to Play" button on `MainMenuView` (`showOnboarding()`, only
reachable from `.mainMenu` so it can't interrupt an active session) lets a returning player revisit
the pages without touching the persisted flag. Onboarding deliberately does not embed calibration
guidance itself — reusing item 2's already-built, already-live component instead of duplicating
per-step instructional text in two places.

The Levels page's copy comes from `ProgressionStore.swift`'s actual code (3 small -> unlock
medium, 5 medium -> unlock big, 10 big -> unlock Scott, 1 Scott catch completes it), not from that
file's own doc comment or ADR-037's original prose — both describe an older 10/10, three-level
version that no longer matches what's shipped; fixed `ProgressionStore`'s doc comment in the same
pass since writing accurate onboarding copy required reading the real thresholds anyway.

## Rationale

All three came from one request, and are genuinely one coherent change: the product doc
(`GAMEPLAY_ARCHITECTURE_V1.md`) has said since its own first version that World owns "Main Menu,
Tutorial, Calibration Instructions" — Main Menu shipped in ADR-036, but Tutorial and
Calibration-instructions-in-World were both flagged open and left unaddressed across every session
since (ADR-029's own rationale text, restated verbatim in `SOFTWARE_ARCHITECTURE_DOCUMENT.md`).
This closes both halves in one pass, plus the specific UX complaint (calibration locked to
"before you ever start fishing," even though a rod's calibration can reasonably drift or need a
redo mid-session) that prompted revisiting the area at all.

`CalibrationStep` moving to `Shared` rather than duplicating an equivalent enum in World mirrors
`HookPhase`'s own precedent — any state Rod owns that World needs to react to lives in `Shared` and
travels over `RodState`, never a parallel local re-derivation.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` (`Shared` rebuilt
for both `arm64-apple-ios17.0-simulator` and `arm64-apple-macosx26.0`, full `Rod`/`World` file
lists against each) and an empirical encode test confirming the new field keeps a
populated-`castSolution` payload comfortably under ADR-063's 512-byte one-chunk budget (436 bytes
measured, ~76 bytes of margin). Not yet played on physical devices — in particular, the onboarding
copy/pacing and whether recalibrating mid-session actually feels discoverable (there's no
in-gameplay hint pointing at Rod's Calibrate button beyond the overlay that appears once
recalibration is already underway) are unverified until tried live.
# ADR-063 --- RodState Gets Short Wire Keys — Every Cast Was Silently Dropped Over BLE

## Decision

`RodState` gains an explicit `CodingKeys: String, CodingKey` enum mapping every property to a
short wire name (`timestamp` -> `"ts"`, `distance` -> `"d"`, `directionX` -> `"dx"`, `pitch` ->
`"p"`, `orientation` -> `"o"`, `castSolution` -> `"cs"`, `castHoldDuration` -> `"chd"`,
`isCastingArmed` -> `"ca"`, etc. — full mapping in the source). Property names, types, and every
call site are unchanged; this only shrinks the JSON produced on encode and expected on decode.

## Root cause

`TransportClient.sendUnreliable(_:)` (Rod's peripheral-side `.state` notify path) deliberately
never fragments a message across multiple BLE packets — a message that doesn't fit in one chunk is
dropped outright, by design (see the function's own long-standing doc comment about avoiding
desync risk on a channel with no delivery guarantee). Measured directly via new logging added
while diagnosing a report that the cast meter charged and released correctly on Rod (confirmed via
console: `phase=release`, `hookPhase=idle`, `allowsCasting=true`) but the hook never launched on
World, with zero errors anywhere: a `RodState` with a populated `castSolution` — i.e. every single
`.state` message during and immediately after a real cast's `followThrough` window — reliably
encoded to **531-542 bytes** against this connection's measured **512-byte one-chunk budget**.
Every one of those messages was silently dropped, for the entire `followThrough` duration (dozens
of consecutive frames confirmed in the logs), meaning **a cast could never reach World at all** —
not an occasional drop, a total, permanent failure for every attempt. An idle `RodState`
(`castSolution == nil`) stays comfortably small, which is why everything else (button state,
`isFishing`, the meter's own live oscillation) worked normally and gave no hint the transport layer
was the actual problem.

This was a latent, pre-existing fragility (the encoded size was apparently already close to the
budget) that ADR-061's new `isCastingArmed` field tipped over the edge — but the *design* flaw
(verbose property-name JSON keys against a hard one-chunk ceiling, for the one message type that
routinely carries a large nested payload) predates that change and would recur with any future
`RodState` field addition without this fix.

Empirically verified: the exact same populated-`castSolution` payload that measured ~540 bytes
under default keys encodes to **419 bytes** under the new `CodingKeys` — comfortably under 512
with real margin, without touching `CastSolution`'s or `RodOrientation`'s own (already short or
modest) keys at all.

## Rationale

Two alternatives considered and rejected:
- **Increase the chunk budget.** `chunkBudget()` reflects `CBCentral.maximumUpdateValueLength`,
  the BLE-negotiated ATT MTU — not fully within the app's control, and not guaranteed to be large
  on every device/OS combination even if it happened to be 512 here.
- **Fragment `.state` across multiple chunks.** Directly contradicts the documented reasoning for
  never fragmenting this path (an unacknowledged channel risks a permanently desynced reassembly
  stream from one lost chunk) — the original design intent was sound, the payload just needed to
  actually fit it.

Shrinking the payload preserves the original single-chunk design guarantee while fixing the actual
bug, and is a fully self-contained change (one file, no protocol/behavior changes, both Rod and
World read the same `Shared` type so there's no versioning concern).

Also added while diagnosing this (kept as permanent diagnostics, matching ADR-062's precedent of
logging previously-silent failure paths): `sendUnreliable(_:)` now logs when a `.state` message is
dropped for exceeding the chunk budget, and when `updateValue` itself returns `false` (send queue
full) — so a future regression of this exact class shows up immediately instead of silently
failing again.

Status: Accepted — verified via `swiftc -typecheck` (both `Shared` targets, full `Rod`/`World` file
lists) and an empirical standalone encode test confirming the byte-count reduction (419 vs. ~540
bytes for an identical populated-`castSolution` payload). Not yet re-confirmed end-to-end on the
reporter's own two-device setup that a cast now actually reaches World and launches the hook.

------------------------------------------------------------------------

# ADR-062 --- Rod Gains a "Forget Paired Mac" Recovery Path; Silent Decode Failures Now Logged

## Decision

Two fixes found while diagnosing a report that World stayed stuck on "Press \u{201C}Start
Fishing\u{201D} on Rod to play" even after Rod's own UI confirmed `isFishing` had flipped true
(its button relabeled to "End Fishing"):

**1. Decode failures on both transports now log in DEBUG instead of failing silently.**
`TransportHost.peripheral(_:didUpdateValueFor:)` and `TransportClient.peripheralManager(_:didReceiveWrite:)`
both decoded incoming `NetworkMessage` data with `try? ... else { continue }` — any decode failure
(e.g. a schema mismatch from only one side of Rod/World being rebuilt after a `RodState` field
change) was dropped with zero signal. Both now `do`/`catch` and `print` the error under `#if DEBUG`.
This ruled out the schema-mismatch hypothesis during diagnosis (no decode errors ever printed) and
is a permanent diagnostic improvement independent of that.

**2. Rod's UI gains a "Forget Paired Mac" row, wired to the already-implemented
`RodViewModel.forgetPairedDevice()`.** Root cause, found by reading `TransportClient.swift`'s own
`didSubscribeTo` comment: Rod (the BLE peripheral) has no CoreBluetooth API to *reject* a
subscription — a central whose identifier doesn't match `PairedCentralStore`'s saved one still
subscribes successfully at the protocol level (so World correctly reads `.ready`/`.streaming`), but
Rod's app layer never sets `subscribedCentral` for it, so `sendTargets` stays empty and Rod
silently never transmits anything to that Mac — including the very first `.state` message that
would carry `isFishing`. This reproduces exactly as "looks connected, nothing ever happens, no
error anywhere." World's own `TransportHost.didDiscover` avoids the equivalent problem by filtering
*before* ever connecting to a mismatched peripheral, an option not available to a GATT peripheral
receiving a subscription — Rod's "accept but don't route" behavior is the only implementable
strategy, so a **recovery path**, not a protocol-level fix, is what was actually missing.
`RodViewModel.forgetPairedDevice()` -> `TransportClient.forgetPairedDevice()` already existed and
worked; it simply had no reachable caller, since the Developer Details `DisclosureGroup` containing
the original "Forget Paired Mac" button is commented out in `Rod/Rod/ContentView.swift` (predates
this session, left alone per this project's standing precedent of not touching what looks like
someone else's in-progress work — see `WINDOW_2.md`'s own known-issues note on this exact block).
Added a small, standalone `pairedDeviceRow` (shown only while `hasPairedDevice`) to Rod's primary
UI instead of touching that commented-out block — mirrors World's own `MainMenuView.pairedDeviceRow`
for the same recovery action.

## Rationale

World's "Forget Device" (ADR-049) only ever clears *World's* saved pairing — it has no way to reach
across and clear Rod's independently-persisted `PairedCentralStore`, and was never meant to; device
pairing is symmetric infrastructure but each side's stored identifier is its own. Reported directly
during this diagnosis: after using World's "Forget Device" as a troubleshooting attempt, Rod refused
to connect at all afterward, surviving even a full Rod app relaunch — consistent with a **stale
saved pairing on Rod's side that nothing in the app could clear**, since `PairedCentralStore`
persists to `UserDefaults` independent of process lifetime. Without today's fix this was a true
dead end recoverable only by clearing Rod's app data/reinstalling — clearly not acceptable for a
core connectivity path.

Status: Accepted, pending live confirmation that pressing the new "Forget Paired Mac" row on Rod
actually restores a working connection to World in the reporter's specific stuck state — verified
here only via `swiftc -typecheck` (iOS 17 simulator target for Rod, both targets for the logging
change) and code-reading of the `didSubscribeTo`/`sendTargets` path, not a live two-device session.

------------------------------------------------------------------------

# ADR-061 --- Five Playtest Notes: Cast Meter Delay, Hook Float, Cast-Zone Fish Size, Result-Screen Dismissal, Connection Retry

## Decision

Five related fixes, all requested together in one playtest-notes message, each touching a
different system:

**1. Cast meter now starts the instant "Start Casting" is armed.**
`RodMotionInterpreter.interpret(_:isCastingArmed:)` previously only ran the charging/oscillation
logic inside the pose-classification switch's `case .cast:` branch — so the meter stayed pinned at
0 until the phone's raw orientation also drifted closer to the calibrated `castPose`, reading as an
unexplained delay between pressing the button and the meter appearing. The armed-charging logic
(hold-duration tracking, the oscillation formula, backswing/forward-motion phase detection,
release) now runs unconditionally whenever `isCastingArmed` is `true`, ahead of the classification
switch entirely; the switch only still matters while *not* armed. Flick detection
(`accelerationZ` crossing `profile.castAcceleration`) was already independent of pose
classification, so nothing about how a flick is detected or how power is computed changed — only
the gate on *entering* the charging branch was removed.

**2. Hook lift/catch resolves instantly within 1m, no scripted climb.**
`WorldViewModel.reelHook(deltaTime:)`'s near-dock zone (`hookLiftDistance`, 1.0m) previously
climbed toward `hookLiftTargetPosition` at a fixed `dockLiftSpeed` (3.5 m/s, ADR-044) and only
resolved the catch/empty-retrieve once within a further 0.15m of the target — a guaranteed climb
that still left the hook visibly hanging/drifting in the air for a beat before landing. Reported
directly: the hook "melayang dikit" (floats a bit) near the pier, which should instead be an
instant lift-and-catch the moment hook-to-rod distance drops under 1m. `reelHook` now snaps
`hookEntity.position` straight to `hookLiftTargetPosition` and resolves in the same tick
`horizontalDistance <= hookLiftDistance` first becomes true. `dockLiftSpeed` and the 0.15m 3D
catch guard are removed outright (dead code, nothing left to gate). The catch cutscene's own jump
animation (ADR-045/047) still sells the "lift" for a caught fish; an empty line just disappears at
the same instant.

**3. Cast distance gates fish size in three discrete zones, not a continuous ceiling.**
Requested directly: "semakin jauh cast, seharusnya ikan yang ditangkap semakin besar (for ex, jika
user hanya bermain di area hijau dari cast, maka ikan bintang 1-2 saja yang bisa ditangkap ... jika
kuning, maka bintang 3-4, jika area merah, maka bintang 4-5)" — mapping `CastMeterView`'s existing
green/yellow/red power-bar thirds directly onto fish-size tiers. `FishFightController` gains
`castZone` (green/yellow/red, from `currentCastDistance / maxExpectedCastDistance` thirds — the
same ratio ADR-031's continuous ceiling already used, just bucketed) and `sizeRollWindow`, a hard
floor+ceiling roll window per zone instead of ADR-031's ceiling-only cap:

```text
green:  ratio in [0.000, 0.375)  -> stars 1-2 only
yellow: ratio in [0.375, 0.875)  -> stars 3-4 only
red:    ratio in [0.625, 1.000]  -> stars 4-5 only
```

Boundaries derived by inverting `stars(forWeight:in:)`'s own `1 + round(4 * ratio)` formula at each
star cutoff, so each window exactly covers its advertised tier (yellow/red deliberately overlap at
`[0.625, 0.875)`, both able to roll a 4-star fish, matching the user's own overlapping wording).
`biasedRoll(in:floorRatio:ceilingRatio:)` replaces the old ceiling-only `biasedRoll(in:ceilingRatio:)`.
A short cast can no longer occasionally roll a big fish by chance the way a ceiling-only cap
allowed — the zone is now a hard guarantee in both directions.

**4. Result screen dismisses via "Start Casting" on Rod, not a World-side button.**
Requested directly: remove `ResultView`'s "Continue Fishing" button, replace with text like "Press
start casting to fish again." `RodState` gains `isCastingArmed: Bool` (same always-transmitted
pattern as `isFishing`, ADR-038). `RodViewModel.startCasting()`'s guard relaxes from
`hookPhase == .idle` to `hookPhase == .idle || hookPhase == .result`, and the `.hookPhase` handler's
"clear `isCastingArmed` whenever phase leaves `.idle`" reset gains the same `.result` exception —
otherwise World's own echoed `.result` phase would immediately clear the arm the player just set
before World ever sees it. `WorldViewModel.handle(_:)` calls `continueFishing()` the instant it
sees `state.isCastingArmed` true (idempotent — `continueFishing()`'s own `hookPhase == .result`
guard makes repeat calls a no-op once already dismissed). `HookPhase.allowsCasting` itself is
untouched (still only `.idle`), so ADR-029's original race protection — a physical flick can't
fire an actual cast until World's dismissal round-trip completes — is fully preserved; only
*arming* is now allowed one phase earlier.

**5. "Retry Connection" button on World's Main Menu.**
Reported directly: the Rod<->World BLE link occasionally wedges into a state the existing
automatic reconnection (Rod re-advertising, World re-scanning after disconnect) never recovers
from, previously only fixable by force-quitting and relaunching World. `WorldViewModel.
retryConnection()` runs `transport.disconnect()` then `transport.connect()` — the same
teardown-then-restart sequence a full relaunch would trigger, without losing `screen`/`fishFight`/
progression state. Surfaced as a "Retry Connection" button on `MainMenuView`, shown only while
`!isRodReady` (retrying an already-healthy link would just interrupt it).

## Rationale

All five came from one round of hands-on playtesting notes, each identifying a place where the
implemented behavior read as unintentional (a delay, a float, an inconsistent size gate) or where
a two-step flow (view result -> tap World -> arm on Rod) was more friction than the one-step
version the player actually wanted (view result -> arm on Rod, done). None of the five change what
a *correct* cast/catch/fight looks like at the physics or fight-tuning level — they're presentation
and flow fixes on top of already-shipped systems (ADR-031, ADR-044, ADR-050, prior Main Menu work),
which is why each is a targeted change to existing code rather than a new subsystem.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against `Shared`
(macOS 26 and iOS 17 simulator targets) and the full `World`/`Rod` file lists on top of it; not yet
played on physical devices. In particular unverified: whether the cast-zone star tiers (item 3)
feel right in practice now that they're a hard window instead of a soft ceiling, and whether
`retryConnection()` (item 5) actually recovers from the specific wedged states that prompted the
request — CoreBluetooth's own internal state is not something this environment can observe or
reproduce directly.

------------------------------------------------------------------------

# ADR-060 --- Every Rod Haptic Pattern Maxed to CoreHaptics' Intensity Ceiling

## Decision

Every `hapticIntensity` value fed to `CHHapticEventParameter` across Rod's haptic layer is now
`1.0` — the largest value CoreHaptics accepts for that parameter (the API defines intensity as a
normalized `0...1` range; the OS clamps anything above `1.0`, so `1.0` is the literal ceiling "the
phone supports," not an arbitrary round number). Changed in two places:

- `Rod/Rod/Haptics/HapticManager.swift`: every pattern's intensity raised to `1.0` — `cast()`
  (was 0.75), `splash()` (0.45), `reelTick()` (0.4), `fishBite()`'s four-pulse pattern (0.85/0.75/
  0.75/0.85), `catchFish()`'s second pulse (0.6 — its first pulse was already 1.0),
  `fishEscaped()`'s three-pulse pattern (0.7/0.55/0.35), and `fishInterested()` (0.35).
  `lineBreak()` was already 1.0. `sharpness` values are all untouched.
- `Shared/Sources/Shared/Gameplay/FishFightConfig.swift`: `lowBandIntensity`/
  `mediumBandIntensity`/`highBandIntensity` defaults raised from ADR-054's 0.50/0.70/0.95 to
  1.0/1.0/1.0 — these feed `FishingHaptics.fightPulse(now:)`'s continuous fight-tension rhythm via
  `HapticManager.fightTick(intensity:sharpness:)`, the one haptic call site whose intensity isn't a
  `HapticManager`-internal constant.

`sharpness` was deliberately left alone at every call site — it controls the felt *timbre* (crisp
tap vs. dull thud), not strength, and the tension-band rhythm still differentiates low/medium/high
through tap interval and sharpness even with intensity now identical across all three bands. This
mirrors ADR-054's precedent of leaving sharpness untouched while intensity was raised.

## Rationale

Requested directly: "Increase haptics feedback yang diberikan ke Rod di semua bagian. Multiply it
to the largest number the phone supports" (increase the haptic feedback given to Rod across every
part; multiply it to the largest number the phone supports) — a follow-up on the same feel-focused
thread as ADR-054's "haptic nya kurang kerasa kenceng" (the haptics don't feel strong enough), which
had already raised values once but stopped short of the ceiling. Rather than guess at another
intermediate number, this pass goes straight to `1.0` everywhere, since that is the actual maximum
`CHHapticEventParameter.hapticIntensity` supports — no further "increase" is possible on this
parameter without a different pattern shape (e.g. `.hapticContinuous` events or layered
transients), which was not requested here.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`Shared` module and the full `Rod/Rod` file list (iOS simulator target); not yet played on a
physical device, so how a uniformly maxed intensity across every band actually feels (previously a
meaningful part of the low/medium/high differentiation) is unverified.

------------------------------------------------------------------------

# ADR-057 --- Cast Power Becomes a Timing Mini-Game, Not a Charge Ramp

## Decision

Replaced ADR-054/056's monotonic hold-duration ramp (`castPower` rises linearly with hold time,
capping at `maximumBackswingHoldDuration`) with a **continuously oscillating** power curve:

```text
phase = backswingHoldDuration * 2π / oscillationPeriod
power = (1 - cos(phase)) / 2
```

Starting at `0` the instant "Start Casting" arms and the pose first reads as a cast attempt, power
rises smoothly to `1` at half the period, falls back to `0` at the full period, and repeats
indefinitely for as long as the backswing is held — a classic timing-minigame curve ("meteran naik
turun perlahan," a golf-swing-meter/fishing-bobber-game shape), not a charge-and-cap ramp. The flick
(`forwardMotion`, unchanged) still triggers the release exactly as before; it now locks in whatever
the oscillating value happens to be at that exact instant, rather than a value that only ever grew
with hold time.

`CastConfig.minimumBackswingHoldDuration`/`maximumBackswingHoldDuration` (ADR-054/056) are removed
— replaced by a single `oscillationPeriod: TimeInterval` (2.0s: one full 0→1→0 cycle). Both
`RodMotionInterpreter`'s live meter and `CastResolver.resolve(_:)`'s authoritative calculation apply
the identical formula to the same `backswingHoldDuration` value (transmitted unchanged via
`CastSnapshot`, per ADR-056), so the live meter always agrees with what a release actually produces
— `RodMotionInterpreter` keeps its own `oscillationPeriod` constant in sync with `CastConfig`'s,
the same duplication pattern this file already used for the bounds it just replaced.

No other part of the pipeline changed: arming (`isCastingArmed`), the pose-classification gate, the
flick-detection threshold, `CastMeterView`'s display (its existing power-bar offset now simply
sweeps back and forth instead of climbing once), and the World transmission path are all untouched.

**Live-tested correction, same day: re-arming inherited the previous cast's frozen power.**
Reported directly: "power nya meningkat terlalu cepat, sampai sampai ketika aku pencet 'start
casting', tiba tiba powernya udah max aja" (the power ramps up too fast — to the point that the
instant I press "Start Casting," the power is already maxed). Root cause: `interpret(_:)`'s
`followThrough` early-return (`input.timestamp < castEndsAt`, replaying `releasedCastPower`/
`releasedHoldDuration`) is gated purely on Rod's own local post-release cooldown timer
(`profile.castDuration`, ~0.15–0.8s), completely independent of `isCastingArmed` — pressing "Start
Casting" again shortly after a release (well within that short local window, since Rod's cooldown
and the World round-trip that eventually flips `HookPhase` away from `.idle` are two unrelated
clocks) hit this guard and kept replaying the *previous* cast's frozen values, which the oscillating
meter can easily have released at or near its peak. That read exactly as "the instant I press the
button, power is already max," when it was really the last cast's leftover freeze-frame bleeding
into the new attempt. Fixed by having a fresh arm unconditionally win over any still-ticking
cooldown: whenever `isCastingArmed` is true, `castEndsAt` is reset to the current timestamp before
the `followThrough` check runs, so the check never fires while armed and a genuinely fresh
oscillation (from a `castHoldStartTimestamp` already correctly cleared during the disarmed
interval) starts immediately instead.

Also **slowed `oscillationPeriod` from 2.0s to 3.5s**, responding to the same report's "terlalu
cepat" (too fast) more generally, not just the re-arm bug — a full cycle in 2 seconds may simply
have been too quick to time deliberately even once the freeze-frame bug is fixed. Still a
hand-picked guess, not tuned against a live session with the bug actually fixed.

## Rationale

Requested directly: "ketika user pencet tombol 'Start Casting', maka meteran akan naik turun
perlahan (kaya di game yang nyari momen pas), baru ketika user nge flick, otomatis bakal ke
register sebagai cast" (when the player presses "Start Casting," the meter should slowly go up and
down — like games where you look for the right moment — then when the player flicks, it
automatically registers as the cast). This is a direct, literal description of a timing-meter
mechanic (the "hit the peak" pattern from golf-swing/fishing minigames), distinct from — and
superseding — ADR-054/056's "hold longer for more power" charge model.

Reusing the exact same `backswingHoldDuration` plumbing (arm timestamp, hold tracking, flicker
immunity from the ADR-054 correction, transmission via `CastSnapshot`) rather than introducing a
new timer was a direct fit: everything about *how* hold time is measured was already correct and
unaffected by this change — only the *function applied to it* needed to change, from a linear ramp
to a periodic oscillation.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played. `oscillationPeriod` (now 3.5s) is hand-picked, not tuned against a live session — whether a
full cycle in 3.5 seconds reads as "perlahan" (slow enough to time deliberately) or still too
fast/slow, now that the re-arm freeze-frame bug is fixed, is unverified until tried physically.

------------------------------------------------------------------------

# ADR-056 --- Cast Power Drops the Flick Bonus Entirely; Live Timer Shown in World

## Decision

**Flick speed no longer contributes to cast power at all.** ADR-054's `holdPower * (0.7 + 0.3 *
flickPower)` blend is now just `holdPower` — power comes *purely* from how long the backswing was
held. The forward flick (`forwardMotion`, an acceleration-threshold check) is unchanged as the
*trigger* that ends the hold and releases the cast; it just no longer scales the outcome.

This let a real amount of now-dead code come out cleanly, all the way back to the sensor:
- `CastSnapshot.angularVelocity: CastVector3` (Shared) — removed; nothing else read it.
- `CastConfig.minimumCastVelocity`/`maximumCastVelocity` (Shared) — removed; only existed to
  normalize the now-gone flick term.
- `RodMotionInput.rotationRateX/Y/Z` (Shared), `MotionSample.rotationRateX/Y/Z` (Rod), and the
  corresponding `MotionManager`/`RodViewModel` plumbing that carried per-axis rotation rate from
  CoreMotion all the way up — the *only* consumer of the three individual axes (vs. the still-used
  aggregate `rotationRateMagnitude`, which drives reel speed) was building `angularVelocity`.
  Confirmed via `grep` before removing: zero other references anywhere in the repo.

**Live hold-duration timer, transmitted and shown in World.** `RodMotionInterpretation`/`RodState`
gained `castHoldDuration: TimeInterval` — the same raw seconds-held value `castPower` is now
computed from, sent alongside it every state tick (not reconstructed client-side from the
normalized power). `releasedHoldDuration` (mirroring the existing `releasedCastPower`) freezes it
through `followThrough` so the meter doesn't visibly reset before the next cast begins.

**`CastMeterView` — actually shown for the first time.** Its call site in `World/ContentView.swift`
had been commented out; nothing this ADR touches was ever broken, it just was never on screen. Now
uncommented, with a new `holdDuration` parameter rendered as a live "Holding X.Xs" readout next to
the existing normalized power bar.

## Rationale

Requested directly, following up on an explanation of how cast/reel currently work: "bisa ga
instead of pake 'flick' aja, gimana kalo timer aja yang ditampilin di World, berapa lama kita nahan
hp kebelakang? jadi remove flick totally. Tampilin juga cast meter power yang nge charge di World
view nya. Gimana? Jadi ketika user nge flick, baru jarak hook akan ke register, sesuai power yang
udah di tahan tadi" (instead of relying on "flick," how about just showing a timer in World for how
long we hold the phone back? Remove flick entirely. Also show the charging cast meter power in
World's view. So when the user flicks, the hook's distance registers according to the power already
held). The "flick still triggers release, but doesn't affect the result" framing was taken literally
— `forwardMotion` (the acceleration check) is unchanged as the release trigger, only its former
role scaling power is gone.

Removing the now-fully-dead `angularVelocity`/per-axis-rotation-rate chain (rather than leaving the
fields in place unused) follows this project's own standing convention against half-finished
cleanups — confirmed via `grep` first that nothing else depended on any part of that chain before
deleting it, the same discipline used for prior dead-code passes in this repo's history.

Discovering `CastMeterView` was commented out (not merely under-tested) was incidental to
investigating where the timer should be displayed — worth recording plainly since the player's
"tampilin cast meter" ask a few turns ago should have already been satisfied by ADR-045's own
finding that the view "needed no changes," which was true of the view's *logic* but missed that its
call site wasn't even in the render tree.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played. Whether pure hold-duration power (with zero flick influence) reads as satisfying on release,
and whether the "Holding X.Xs" readout is legible at a glance during a real cast, are both
unverified until tried physically.

------------------------------------------------------------------------

# ADR-055 --- Reset Progression Button

## Decision

Added `ProgressionStore.reset()`: clears every tier's stored catch count back to zero (persisted
via the same `UserDefaults` mechanism `recordCatch(tier:)` already writes to), dropping `level`
back to 1 (only `.small` catchable). `FishFightController.resetProgression()` calls it and also
resets its own `currentLevel` (published, seeded from the store at init and otherwise only updated
on a catch) and clears any in-flight `levelUpAnnouncement`, so no stale banner survives a reset.
`WorldViewModel.resetProgression()` is a thin passthrough.

Surfaced as a new "Reset Progress" button on World's `MainMenuView`, alongside the existing
"Forget Device" button — same `role: .destructive` styling, no confirmation dialog, matching this
project's own established precedent for this class of admin/debug action in this exact view.
Visible unconditionally (not gated on `hasPairedDevice` like "Forget Device" is), since progression
state exists independent of whether a device has ever paired.

## Rationale

Requested directly: "bisa di tambahin button buat reset level ga ke level 1 lagi" (can a button be
added to reset the level back to Level 1). A debug/utility action, not part of the fishing session
loop, so it belongs on the Main Menu (unrelated to the ADR-038 session boundary, same reasoning
already used for "Forget Device") rather than anywhere in the active gameplay HUD.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World`
(macOS) target (see the matching `CHECKPOINT.md` entry), not yet played.

------------------------------------------------------------------------

# ADR-054 --- Cast Hold Timer, Stronger Haptics, Eased Tier 3/4 Difficulty

## Decision

Three unrelated requests made together in one message; handled as three independent changes.

**1. Cast power now comes from how long the backswing is held, not how far it moved (replaces
ADR-032's distance measurement).** `CastSnapshot.backswingDistance: Float` (radians) is now
`backswingHoldDuration: TimeInterval` (seconds); `CastConfig.minimumBackswingDistance`/
`maximumBackswingDistance` are now `minimumBackswingHoldDuration`/`maximumBackswingHoldDuration`
(0.15/1.5s). `RodMotionInterpreter` replaces `backswingPeakDistance` tracking with
`castHoldStartTimestamp: TimeInterval?`. `holdDuration = input.timestamp - castHoldStartTimestamp`
feeds the exact same `holdPower * (0.7 + 0.3 * flickPower)` blend ADR-032 already established —
only the *base* term's source changed, from "how far did you pull back" to "how long did you hold
it back." `CastResolver` (the authoritative, transmitted calculation) mirrors the same swap.
World's `CastMeterView` needed no changes — same finding as ADR-045: its display already reads
generic `power`/`phase` values, not distance/duration internals.

**Live-tested correction, same day: the timer reset on classification flicker.** Originally,
`castHoldStartTimestamp` was (re-)set whenever `previousClassification != .cast` — i.e. whenever
the pose classification had just *changed into* `.cast`. Reported directly as "cast mechanism nge
bug" after playing it. Root cause: `distances(from:).minimum` picks whichever of idle/cast/reel is
closest *this exact frame* — while the player holds deliberately still to charge, ordinary sensor
jitter can make the pose read fractionally closer to `idlePose` than `castPose` for a single frame,
flipping classification to `.idle` and back to `.cast` one frame later. That single flicker frame
looked identical to a genuine fresh backswing entry, silently resetting the hold timer to zero and
discarding however long the player had already been charging — reading as "the cast never charges
no matter how long I hold it." Fixed by decoupling the reset condition from frame-to-frame
classification change entirely: `castHoldStartTimestamp` now only starts when it's `nil`, and is
only cleared by the unarmed-guard (added as its own top-level check, run every frame regardless of
which classification branch executes — the previous code only cleared it from inside the
`.cast where !isCastingArmed` branch, so a played-out attempt where the pose went all the way back
to a genuinely idle classification between casts, rather than lingering near the cast/idle
boundary, could leave a stale timestamp from the *previous* attempt sitting unreset) or by
`updateProfile(_:)`/`setIdlePose(_:)`'s full resets. The release-trigger logic's own use of "did
classification just change" (renamed `isFreshCastEntry`, kept for the OR-condition that lets a
release fire on the very first frame of an attempt that's simultaneously already forward-
accelerating) is unaffected — only the timer's reset condition changed.

**2. Every Rod haptic pattern got a real intensity increase**, in
`Rod/Rod/Haptics/HapticManager.swift` and `FishFightConfig`'s tension-band fields:

```text
                  before -> after
cast              0.55   -> 0.75
splash            0.32   -> 0.45
reelTick          0.20   -> 0.40
fishBite (peaks)  0.65   -> 0.85
catchFish (peak)  0.95   -> 1.00
lineBreak         0.90   -> 1.00
fishEscaped(peak) 0.50   -> 0.70
fishInterested    0.22   -> 0.35
low/med/high band 0.30/0.45/0.70 -> 0.50/0.70/0.95  (FishFightConfig, Rod's continuous fight rhythm)
```

Sharpness was bumped alongside intensity on the tension bands (0.3/0.45/0.6 -> 0.4/0.55/0.75) for a
crisper, not just louder, feel. `catchFish`/`lineBreak` were already close to the `1.0` ceiling
(`CHHapticEventParameter.hapticIntensity`'s max) and are now pinned at it — nothing above `1.0` is
possible on this API, so those two are now maxed rather than merely raised.

**3. `fish_c` (tier 3, big) and `scott` (tier 4, boss)'s `FishSpecies.resistance` were lowered** —
first to `0.60` and `0.75` (from `0.75`/`0.95`), then tuned further to `0.10` for both (matching
`fish_b`, also retuned to `0.10`) in `World/World/Gameplay/FishCatalog.swift` — a bigger cut than
the initial pass, landing all three above-`fish_a` tiers at the same, much lower ceiling. `fish_a`
alone keeps its original `0.35`.

## Rationale

Requested directly, three asks in one message: "tampilin 'cast meter' nya di UI world. pake timer
aja gimana? jadi semakin lama user nahan di 'belakang', ketika flick buat nge cast, jaraknya bakal
semakin jauh tergantung seberapa lama timer nya berlangsung. Haptic nya juga kurang kerasa kenceng,
bisa ditambah lagi intensitasnya. Sama, mudahin dikit dong ikan level 3 dan 4 nya" (show the cast
meter in World's UI — how about just using a timer? So the longer the player holds at "the back,"
the farther the cast goes on the flick, depending on how long the timer ran. Also the haptics don't
feel strong enough, can the intensity be increased more. Also, ease up fish level 3 and 4 a bit).

**Cast timer**: re-reading `CastMeterView.swift` first confirmed the meter *already* displays
correctly and is already wired to appear via `RodState.motionPhase` (ADR-045's own finding) — the
actual gap was the *charging mechanism* underneath it, not the UI. The player's "pake timer aja"
suggestion was adopted directly rather than debated: a hold-duration timer is a more legible mental
model ("hold longer = more power," a standard charge-up convention) than the previous "how far did
you physically pull the phone back" distance measurement, which required the player to intuit an
unfamiliar-in-a-phone-game relationship between wrist displacement and cast power.

**Haptics**: a direct, literal request ("kurang kerasa kenceng, bisa ditambah lagi intensitasnya")
— every pattern got a real bump, not just the ones guessed to matter most, since the report was
general rather than pointing at one specific moment.

**Tier 3/4 easing**: `FishFightConfig`'s resistance multipliers apply globally to every species'
formula, so they weren't the right lever for a tier-3/4-only ask — retuning them would have also
changed `fish_a`/`fish_b`, which wasn't requested. `FishSpecies.resistance` (the per-species ceiling
from ADR-030) is the correct, already-existing lever for "make specifically the harder tiers
easier" without touching the easier ones. New target values were worked out by hand against the
same net-tension-rate formula ADR-039 used for its own difficulty corrections (see that ADR's
"Rationale" for the worked-math method), not picked arbitrarily.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played. All tuned numbers here (hold-duration bounds, haptic intensities, the two resistance values)
are hand-picked/hand-derived, not measured on a live device.

------------------------------------------------------------------------

# ADR-053 --- Fight Direction: a Timed Left/Right Juking Sub-Phase Requiring a Rod Counter

**Superseded by ADR-078**: replaced entirely by a randomized flick QTE ("daripada fish pull dan
lean rod, mending diganti jadi QTE") — every type/field/method this entry describes
(`FightDirection`, `fightDirection`, the seven `fightDirection*` `FishFightConfig` fields,
`updateFightDirectionDrift(deltaTime:)`) was removed from the codebase, not just deprecated. Kept
below as an accurate record of what shipped and why, at the time.

## Decision

Added `FishFightController.FightDirection` (`.left`/`.right`) and a `@Published private(set) var
fightDirection: FightDirection?` — a new sub-mechanic layered on top of the existing tension
safe-zone fight (ADR-028/039/042), not a replacement for it. The instant a fish bites
(`updateSearching`'s `.bite` branch), a juking phase begins: `fightDirection` is set to a random
side, and a random total duration (`fightDirectionMinDuration...fightDirectionMaxDuration`, default
5...10s) starts counting down in `updateFight`. While active, `fightDirection` flips to the other
side after a random interval (`fightDirectionSwitchMinInterval...fightDirectionSwitchMaxInterval`,
default 0.6...1.8s — the "rapid randomizer") — a genuinely unpredictable side-to-side juke, not a
slow metronomic swing. Once the total duration elapses, `fightDirection` returns to `nil` and only
the base tension fight continues for however much longer the fight naturally takes.

**Countering is evaluated from `RodState.roll`, not from anything RealityKit-side** —
`updateFight` gained a required `rodRoll: Double` parameter, and a new private
`updateFightDirection(deltaTime:rodRoll:)` (called from inside `updateFight`) returns a tension/sec
delta folded additively into the existing `(reelPull - effectiveFishPullRate) * deltaTime` formula:

```text
fightDirection == .left  -> counters correctly when rodRoll >=  fightDirectionRollThreshold
fightDirection == .right -> counters correctly when rodRoll <= -fightDirectionRollThreshold
correctly countering -> -fightDirectionCounterRelief  (tension relief, real "rod-side pressure")
not countering        -> +fightDirectionPenalty        (extra strain, on top of the base pull)
```

A fish pulling `.left` requires a *positive* rod roll (the player leaning the rod toward their
right) to counter, and vice versa — the opposite-direction convention real anglers use to keep
pressure on a fish trying to run sideways. All seven new numbers
(`fightDirectionMinDuration`/`MaxDuration`/`SwitchMinInterval`/`SwitchMaxInterval`/
`RollThreshold`/`CounterRelief`/`Penalty`) live in `FishFightConfig` (Shared), following this
project's existing ADR-039 convention of collecting every fight-tuning number in one hand-editable
struct rather than scattering constants.

**Visual sell, kept separate from the tension math.** `WorldViewModel.updateFightDirectionDrift
(deltaTime:)`, called every `.fishOnHook`/`.reeling` tick alongside `reelHook`/`driftHookAway`,
nudges the hook's world-X position toward the current `fightDirection` at `fightDirectionLateralSpeed`
(0.35 m/s), clamped within `fightDirectionMaxLateralOffset` (1.0 m) of the rod's own X — purely
cosmetic (it does not feed back into the counter check above, which reads `RodState.roll` directly)
so the fish visibly darts side to side without that visual needing to stay perfectly synchronized
with the tension formula's own timing.

**World HUD, not Rod** (per the project's "Rod owns no gameplay HUD" contract):
`LineTensionView` gained a `fightDirection` parameter and, whenever it's non-`nil`, a row showing
"Fish pulling ←/→" and "Lean rod →/←" (the literal opposite arrow) beneath the tension bar. Rod
itself gained no new UI or haptic for this — the direction can only be communicated visually
(Core Haptics can't convey "left" vs "right" through a single actuator), and World already owns
gameplay HUD, so this is the one place it can live.

## Rationale

Requested directly: "aku pengen ikannya ada behavior geser kanan kiri dengan rapid randomizer. jadi
motion fight juga berlaku. misalnya kalo ikan narik ke kiri, otomatis user harus pull rod ke kanan
belakang. ini state 'Fight' yang berlangsung selama kurang lebih beberapa detik aja (misal 5-10
detik) gitu randomizernya" (I want the fish to have left-right shifting behavior with a rapid
randomizer, so motion applies to the fight too — e.g. if the fish pulls left, the player
automatically has to pull the rod back-right. This "Fight" state lasts roughly a few seconds, like
5-10 seconds, randomized).

Scoping the juking phase to a bounded random window per fight (not the whole fight) matches "state
Fight yang berlangsung selama kurang lebih beberapa detik" literally — after it elapses, the fight
reverts to being governed by tension/reeling alone, same as before this ADR. Layering the
direction penalty/relief additively on top of the existing tension formula (rather than replacing
it, or adding a second, independent failure condition) keeps a single source of truth for "is the
fight going well" — one bar, one number — instead of forcing the player to track two unrelated
meters simultaneously.

Using `RodState.roll` (already transmitted, already relative to the calibrated idle pose — no new
Shared/Rod plumbing needed) as the counter signal was a direct fit with "pull rod ke kanan": roll is
this project's existing lateral-tilt axis (already driving the rod rig's own lateral bend
visualization, `RodRigController.applyBend`'s `bendRollScale`), so reusing it for "did the player
lean the rod the correct way" needed no new sensor plumbing, just a new consumer of a value already
flowing through `RodState`.

The visual hook drift and the World HUD indicator were both judged necessary, not optional
additions, even though only the core randomizer/counter mechanic was explicitly requested: without
*some* indication of which way to counter, the mechanic would be unplayable (the player has no way
to know which way is currently required), and per this project's own architecture (`GAMEPLAY_ARCHITECTURE_V1.md`,
"Rod is an input device. World is the game"), that indication has to live on World, not Rod.

All seven new config numbers are hand-picked, not measured against a live session — a first pass at
the requested feel ("rapid," "a few seconds"), expected to need retuning once actually played.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played.

------------------------------------------------------------------------

# ADR-052 --- Floating Bobber: Idle Bob and a Pre-Bite "Interest Dip"

## Decision

`WorldViewModel` never touched `hookEntity.position.y` at all during `.hookInWater` (unless the
player was reeling in an empty line) — the hook sat perfectly still at `waterHeight` from splash
until whatever happened next (bite or reel-in), and the bite itself (`FishFightController
.updateSearching`'s `.bite` case) transitioned straight to `.fishOnHook` with no visual lead-up.

Added `updateBobberFloat(deltaTime:)`, called from `tick()`'s `.hookInWater` case whenever the
player *isn't* reeling (so it never fights with `reelHook`/the fight mechanics for control of
`hookEntity.position.y`):

```text
idleBob     = sin(bobberBobPhase * idleBobFrequency * 2π) * idleBobAmplitude        (0.02 m, 0.5 Hz)
interestDip = fishFight.isFishInterested
                ? -abs(sin(bobberBobPhase * interestDipFrequency * 2π)) * interestDipAmplitude
                : 0                                                                  (0.06 m, 2.0 Hz)
hookEntity.position.y = waterHeight + idleBob + interestDip
```

`idleBob` is a small, slow, always-present sine wave — ambient buoyancy realism, not a gameplay
signal. `interestDip` layers on top only while `fishFight.isFishInterested` (the existing ADR-029
pre-bite state) is true: sharper, faster, and downward-only (`-abs(sin(...))`), reading as a fish
visibly nibbling and tugging the float toward the surface before the real bite fires, rather than
the bite happening with zero visual warning. `bobberBobPhase` resets to `0` on every fresh splash
(`simulateFlyingHook`) so the pattern doesn't carry an arbitrary phase across casts.

## Rationale

Requested directly: "bobber nya celap celup (just like in real life), karena yang sekarang langsung
nge bite gitu ikannya, jadi kurang realistis. also, bobber movement masih terlalu static,
seharusnya bobber itu dinamis naik turun kecil kaya pelampung in real life" (the bobber should dip
in and out like in real life, because right now the fish bites immediately, which feels
unrealistic; also, the bobber's movement is still too static — it should dip up and down slightly,
dynamically, like a real floater).

Reusing the existing `isFishInterested` state (rather than adding new fight-controller state) was a
direct fit: ADR-029 already models a 0.8-2.0s pre-bite "interested" window specifically so a fish's
presence can be telegraphed before the strike — it just never had a *visual* consumer on the hook
itself before this entry, only a haptic pulse (Rod) and a bubble-loop sound (World). Layering the
dip on top of, rather than replacing, the idle bob means the two complaints compose naturally: an
idle float always looks alive, and a nibbling float looks *more* alive, in the same direction real
bobber fishing actually reads (dips get more insistent as a fish investigates, then it goes under).

`idleBobAmplitude`/`idleBobFrequency`/`interestDipAmplitude`/`interestDipFrequency` are all
hand-picked, not measured against any reference footage or played — a first pass at the requested
feel, expected to need retuning once actually watched running.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World`
(macOS) target only (see the matching `CHECKPOINT.md` entry), not yet played.

------------------------------------------------------------------------

# ADR-051 --- Rod Rig Pass: Bend Smoothing, Placeholder Reel Spin, Line-Follow Fix

## Decision

Three related `RodRigController` (World) fixes, requested together as the third of three jobs in
one message ("benerin rod (rod diem or bend, reel muter, line ngikut)" — fix the rod: stays still
or bends [correctly], reel spins, line follows):

**Bend smoothing.** `applyBend(pitch:roll:)` became `mutating` and now runs the raw `pitch`/`roll`
it receives through a one-pole low-pass filter (`bendSmoothing = 0.25`) before computing the
per-joint bend angles, stored as new `smoothedBendPitch`/`smoothedBendRoll` fields. This does not
touch the primary whole-rig rotation (`WorldViewModel.updateRodPose()`'s `controllerEntity.orientation
= RodState.orientation`, still exactly per ADR-016) — only the secondary flex visualization this
function already owned. Raw per-sample sensor noise fed directly into a per-frame bend computation
can read as the rod alternating between looking rigid and snapping into an odd flex frame-to-frame;
this is the same class of visible jitter this project already diagnosed and fixed once for the
whole-rig rotation itself (`CHECKPOINT.md`'s "Rod Tingling" entry, later superseded when the
asset-integration merge moved smoothing off the primary orientation per ADR-016/019) — just not yet
applied to this specific supplementary effect.

**Placeholder reel spin.** Confirmed by extracting and directly inspecting `rod_main.usdz` (not
assumed): its skeleton has exactly six joints (`Root`, `Handle`, `Rod_01/02/03`, `Tip`) and its mesh
data is a single `Mesh` prim with two material `GeomSubset`s (`rod06`, `RodThread`) — no reel/spool
geometry or joint exists anywhere in the asset. A real modeled reel is therefore a follow-up asset
task in the sibling Blender repo (`AGENTS.md`'s "Asset source repo" convention), not fixable from
this repo alone. Added a placeholder: a flattened-sphere `ModelEntity` (matching this project's own
established precedent of primitive shapes standing in for missing assets — the hook and the
pre-asset-integration rod "arrow" did the same) pinned near the `Handle` joint via the same
skeletal-pin mechanism `load()` already uses for the tip marker and line attachment. New
`applyReelSpin(reelSpeed:isReeling:deltaTime:)` rotates it around its local Y axis proportional to
`RodState.reelSpeed` while `RodState.action == .reeling`, called every tick from
`WorldViewModel.tick(deltaTime:)` alongside the existing `applyLineTension` call.

**Line-follow fix (a previously known, unfixed issue).** `rod_line.usdz`'s root inherits the rod's
Tip joint's full *world* orientation (attached via the pin `load()` sets up), so
`applyLineTension`'s fixed local-X sag axis used to rotate along with whatever roll `applyBend` gave
the tip — under combined pitch+roll the line visibly forked away from the rod's own bend plane
instead of drooping toward true down. This is the exact issue flagged as a "Known Remaining Issue"
in `CHECKPOINT.md`'s "Asset-Integration Environment, First-Person Camera, and Rod Motion Fixes"
entry and never addressed since. Fixed by reading the tip's current world orientation
(`tipEntity.orientation(relativeTo: nil)`) and rotating the sag axis by its inverse before building
each joint's sag rotation, keeping the sag pointed at a stable world-frame direction instead of one
that rotates along with the rod's own roll. Not a full physical simulation — each line joint
counters against the *tip's* world orientation specifically, rather than fully compounding through
the line's own preceding joints' rotations, which is a reasonable approximation given each joint's
own contribution is small (bounded by the existing `maxLineSagAnglePerJoint`, ~20°).

## Rationale

The three sub-issues map onto three different kinds of problem, handled accordingly rather than
uniformly:

- "Rod diem or bend" was read as jitter/inconsistency in the secondary flex effect (alternating
  between looking rigid and snapping into a flex), since nothing in `updateRodPose()`'s primary
  rotation path showed an obvious functional bug on inspection — smoothing the bend inputs is a
  low-risk, previously-proven fix for this class of complaint in this exact codebase. This
  interpretation is flagged explicitly as an inference, not a confirmed diagnosis (no live device
  was available to observe the actual symptom) — see the `CHECKPOINT.md` entry's own caveat.
- "Reel muter" surfaced a genuine content gap (no reel geometry exists at all), not a code bug —
  confirmed by extracting and reading the actual asset before writing anything, per this project's
  own established discipline of checking the asset directly rather than guessing (the same
  discipline behind, e.g., the sky-dome/terrain winding fixes). A placeholder was added rather than
  leaving the ask entirely unaddressed, consistent with this codebase's own precedent of primitive
  stand-ins for missing assets elsewhere.
- "Line ngikut" was a rediscovery, not a new find — the project's own history had already root-caused
  and precisely described this exact bug (down to "the line visually forks away from the rod's bend
  plane under combined pitch+roll") but left it unfixed pending "the line's droop [needing] to
  counter-rotate for the parent's current world orientation." This entry implements exactly that
  previously-proposed fix.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World`
(macOS) target only (see the matching `CHECKPOINT.md` entry), not yet played. All three fixes are
first-pass and hand-tuned/approximated where noted above; none have been visually confirmed running.

------------------------------------------------------------------------

# ADR-050 --- Cast Attempts Require an Explicit "Start Casting" Arm

## Decision

`RodMotionInterpreter.interpret(_:)` previously classified a pose as `.cast` (starting backswing
tracking and the charging phase) purely by proximity to the calibrated `castPose` — no explicit
intent signal, so any phone movement that happened to read closest to that calibrated pose would
silently start charging a cast, whether the player meant to or not.

`interpret(_:)` gained a required `isCastingArmed: Bool` parameter. When a pose classifies as
`.cast` but `isCastingArmed` is `false`, the interpreter now treats it exactly like `.idle` — no
backswing tracking, no charging phase, no `castPower`, no cast meter — regardless of how close the
pose actually is to `castPose`. The existing backswing-distance/flick blend (ADR-032) and cast
resolution (ADR-017) are otherwise completely unchanged; arming only gates *whether* that machinery
runs at all, not how it computes power once running.

**`RodViewModel.isCastingArmed` (`@Published`)** is the source of truth for the flag, set by a new
`startCasting()` method (guarded to `isFishing && hookPhase == .idle && !isCastingArmed` — mirrors
`HookPhase.allowsCasting`, since arming while a cast couldn't possibly complete would just leave the
button stuck "armed" for nothing) and passed into every `interpret(_:isCastingArmed:)` call in
`updateAction()`. It clears automatically in three places, so a stale arm can never persist past one
real attempt or outlive its own preconditions:

- In `updateAction()`, the instant `interpretation.castSnapshot` comes back non-`nil` — a real cast
  just fired, so the single-use arm is spent.
- In `handle(_:)`'s `.hookPhase` case, whenever the phase leaves `.idle` for any reason.
- In `endFishing()`, since arming without an active session makes no sense.

**Rod UI**: a new "Start Casting" button (`Rod/Rod/ContentView.swift`), shown only while
`isFishing`, disabled whenever `hookPhase != .idle` or already armed (label switches to "Casting
Armed…"). Extends the V1 controller interface documented in `GAMEPLAY_ARCHITECTURE_V1.md`, updated
alongside this change.

**World's existing `CastMeterView`** needed no changes at all — its visibility is already driven
purely by `RodState.motionPhase` being one of the charging-related phases (backswing/charging/
forwardSwing/release/followThrough). Since those phases can now only ever be reached once armed,
pressing "Start Casting" causes the meter to appear as a direct consequence of the same existing
wiring, not a new, separate signal.

## Rationale

Requested directly, as the second of three jobs in one message: "add button 'start casting' di rod,
terus munculin 'cast meter'. nah, core motion nya, harus narik hp ke belakang (jadi semakin - nilai
pitch maybe), maka ketika nge flick, akan makin jauh. so maybe detect dari original device, ukur
seberapa jauh device bergerak, baru 'cast' nya itu ketika nge flick device. langsung disable tombol
'start casting' kalo kondisi hook nya != idle" (add a "Start Casting" button on Rod, which brings up
the cast meter. The core motion: pull the phone back — pitch getting more negative, maybe — then
when flicked, it goes further. So maybe detect from the original device position, measure how far
the device moved, and the "cast" itself fires on the flick. Disable the "Start Casting" button
whenever the hook state isn't idle).

The "measure how far it moved from the original pose, then fire on the flick" mechanic itself
already existed end-to-end (ADR-032's `backswingPeakDistance`/distance-power blend) — re-reading
`RodMotionInterpreter` confirmed this directly rather than assuming it needed rebuilding from
scratch, so this ADR adds the missing piece (an explicit arm gate) instead of re-implementing
already-working motion math. What was genuinely missing was intent: casting was always "live," so
the player's own framing (an explicit button before the motion counts) reads as a real, previously
unaddressed usability gap — the calibrated `castPose` proximity check alone can't distinguish
"about to cast" from "just moved the phone that way incidentally."

Disarming automatically in three places (rather than requiring the player to somehow "cancel") was
chosen so the flag can never get stuck in a confusing state: a fired cast obviously shouldn't stay
"armed" for a hook that's now flying, a hook leaving `.idle` for *any* reason (bite/catch/escape
cycle, or the player ending the session) means casting isn't possible again until back at `.idle`
regardless of arm state, and ending the session outright shouldn't leave an arm dangling for the
next one.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played. In particular, whether the arm/disarm lifecycle feels natural (vs. e.g. wanting a manual
cancel, or the button needing to stay visible/disabled differently) is unverified until tried
physically.

------------------------------------------------------------------------

# ADR-049 --- Device Pairing Allowlist Over CoreBluetooth

## Decision

`TransportHost` (World, BLE central) previously connected to whichever Rod peripheral it
discovered first advertising the shared service UUID (ADR-035) — with multiple Rods/Worlds in
Bluetooth range of each other in the same room, any phone could end up paired with any Mac.
Symmetrically, `TransportClient` (Rod, BLE peripheral) treated whichever central subscribed to its
`state` characteristic as "the" connection, with no check on which Mac that was.

Added a **first-connection-pairs, then locked** allowlist on both sides, each persisted locally
via `UserDefaults` (no new `Shared` model — `CBPeripheral`/`CBCentral` are CoreBluetooth types,
and `Shared` must stay platform-independent per `AGENTS.md`):

- **World**: new `World/World/Transport/PairedDeviceStore.swift` persists the paired Rod's
  `CBPeripheral.identifier` (and `.name`, for display). `TransportHost.startScanningIfPossible()`
  tries `centralManager.retrievePeripherals(withIdentifiers:)` for the saved identifier first
  (CoreBluetooth can hand back a known peripheral without a fresh scan); `didDiscover` ignores any
  peripheral whose identifier doesn't match once a pairing exists. The first full successful
  connection (`.ready`, all characteristics subscribed) saves the pairing if none exists yet.
  `TransportHost.forgetPairedDevice()` clears it and re-enters first-run behavior.
- **Rod**: new `Rod/Rod/Transport/PairedCentralStore.swift` persists the paired central's
  `CBCentral.identifier` (no display name — `CBCentral` exposes none). `didSubscribeTo` ignores
  any central that isn't the saved one once a pairing exists, and the first subscriber is saved as
  the pairing if none exists yet. Critically, every `updateValue(_:for:onSubscribedCentrals:)` call
  (`sendUnreliable`, `drainReliableQueue`) now targets `[subscribedCentral]` specifically instead of
  `nil` — passing `nil` sends to *every* subscribed central regardless of app-level pairing state,
  so an unpaired Mac that happened to subscribe would otherwise still receive `RodState`/events over
  the air even though the app never treats it as connected. `TransportClient.forgetPairedDevice()`
  mirrors World's.

**UI**: World's `MainMenuView` gained a "Paired with `<name>`" line and a "Forget Device" button
(unrelated to the fishing session boundary that ADR-038 gives to Rod, so it isn't gated by
`isRodReady`). Rod's Developer Details gained a "Paired Mac" row (short ID only) and a "Forget
Paired Mac" button, following this project's existing precedent of putting admin/dev-facing
controls behind Developer Details rather than the minimal V1 primary surface.

Neither side's GATT layout, message framing, or reconnection behavior (ADR-035) changed — this is
purely an additional identity check layered on top of the existing scan/advertise/connect flow.

## Rationale

Requested directly: "list saved device, biar 1 hp ga konek ke mac lain (setup device pair di awal.
pake bluetooth connected aja kali ya)" (a list of saved devices, so one phone doesn't connect to a
different Mac — set up device pairing at the start, maybe just use Bluetooth's own "connected"
info). "First-connection-pairs" (rather than a dedicated pairing UI/flow with device pickers) was
chosen as the simplest mechanism satisfying "set up pairing at the start": the very first
successful connection *is* the setup step, with no extra screen needed, and "Forget Device" is the
escape hatch if a different phone/Mac needs to pair later.

The fix had to be symmetric, not just on World's side: World is the side that actively *chooses*
who to connect to (central), but Rod (peripheral) cannot refuse an incoming BLE connection at the
protocol level, and CoreBluetooth has no "reject a subscription" API — so without Rod's own check,
a second Mac's `TransportHost` could still discover and subscribe to Rod even after World-side
filtering was added, and (per the `onSubscribedCentrals: nil` finding above) would have kept
*receiving real data* from Rod even while Rod's own app state never called it "connected." Fixing
only the app-level `subscribedCentral` bookkeeping without also restricting the actual
`updateValue` target list would have been a state-only fix that didn't change what was actually
transmitted over the air.

A single paired-device slot per app (not a genuine multi-device list with a picker) is a
deliberate, minimal reading of "list saved device" — matching "setup di awal" (set up once, at the
start) rather than ongoing multi-device management. If real multi-device support (e.g. a Rod
choosing between several known Worlds) is wanted later, that's a bigger UX than what was asked for
here and should be a separate task.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets (see the matching `CHECKPOINT.md` entry), not yet
played with two physical devices.

# ADR-071 --- New "Caught" Clip Integrated; Animation Speed Derived to Center Its Peak in the Slow-Motion Dip

## Decision

The Blender-side handoff (ADR-070's own follow-up, `new-blender-project/FishAssets/
APP_TEAM_HANDOFF_CAUGHT_STRUGGLE.md`) delivered a re-authored `Caught` clip for
`Fish06_MekongGiantCatfish` — same model/rig (confirmed byte-identical `bindTransforms` to the
previous file: same 11-joint hierarchy, same local axes, same `upAxis = "Z"`), only the animation
itself replaced with a genuinely more violent thrash/arch/ease structure, per that handoff's spec.
Copied into `World/World/Assets/FishCaught/mekong_catfish_caught.usdz` (overwriting the ADR-068
file), `shasum -a 256`-verified identical to the source repo's copy.

**`catchCutsceneFishAnimationSpeed` changed from a hardcoded `1.4` constant to a computed property**,
derived so the new clip's single most dramatic beat (a full-body arch at frame 44 of a 90-frame/24fps
clip, ≈1.83 s in — `caughtFishAnimationPeakTime`) lands exactly at the freeze phase's story-time
midpoint (`catchCutsceneRiseDuration + catchCutsceneFreezeDuration / 2`) — the deepest, most
sustained point of ADR-070's slow-motion dip, by construction, regardless of the dip's specific
`catchCutsceneSlowMotionFactor`/`catchCutsceneSlowMotionEaseFraction` shape (a symmetric envelope's
center is always its deepest point). At the current rise/freeze durations (0.35 s / 0.9 s), this
computes to `1.83 / (0.35 + 0.45) = 2.2875`.

No other cutscene constant changed — `catchCutsceneRiseDuration`, `catchCutsceneFreezeDuration`,
`catchCutsceneSettleDuration`, `catchCutsceneSlowMotionFactor`, and
`catchCutsceneSlowMotionEaseFraction` are all untouched. `fishOrientation(facing:)`'s hardcoded
`headAxis`/`dorsalAxis` constants are also untouched — independently re-confirmed (not trusted from
the Blender session's own report) that this export's `bindTransforms` are byte-identical to the
previous file's for every joint, so the rig genuinely didn't change.

## Rationale

The Blender session's own handback (`FishAssets/CHECKPOINT.md` CP44/CP45 in the asset repo) explicitly
flagged that the app side would need to retune timing constants to match the new clip's real
proportions (90 frames/3.75 s, up from 72 frames/3.0 s) and reported exactly where the peak beat
landed (frame 44, ≈1.83 s, ≈49% through — deliberately centered in the clip's middle third per the
handoff's own spec). Rather than picking a new speed by feel, the relationship between playback speed
and where the peak lands in *story* time was derived directly:

Both `cutscene.elapsed`'s advancement (`deltaTime * dilation`, ADR-070) and the animation
controller's own `.speed` (`catchCutsceneFishAnimationSpeed * dilation`) are scaled by the *identical*
per-frame dilation value each tick. Clip-time consumed per unit of *real* time is
`catchCutsceneFishAnimationSpeed * dilation`; story-time consumed per unit of real time is `dilation`.
Dividing one by the other to get clip-time-per-story-time cancels `dilation` out entirely, leaving a
plain constant: clip-time consumed is simply `catchCutsceneFishAnimationSpeed * story_elapsed`,
**independent of the slow-motion dip's shape**. This is what makes deriving the speed from a target
story-time straightforward and exact, rather than requiring an integral over a variable dilation
curve — and why the resulting formula doesn't need to reference `catchCutsceneSlowMotionFactor`/
`catchCutsceneSlowMotionEaseFraction` at all, only the rise/freeze durations and the target peak time.

Making this a computed property rather than re-solving the arithmetic by hand and hardcoding the
result was deliberate: a future retune of `catchCutsceneRiseDuration`/`catchCutsceneFreezeDuration`
(or another new clip with a different peak time) automatically keeps the peak centered without
anyone needing to remember to redo this specific calculation — the previous approach (ADR-069's
hardcoded `1.4`, picked for a different reason entirely — compensating for the *old* clip's
deliberately gentle authored tempo) had no such self-correcting property and was already stale the
moment the underlying clip changed.

An alternative considered and rejected: keeping `catchCutsceneFishAnimationSpeed` near `1.0` (letting
the new clip play at its own authored tempo) and instead extending `catchCutsceneFreezeDuration` to
give the peak time to arrive naturally. Rejected because the real wall-clock cost of extending freeze
duration is amplified by the slow-motion dilation itself — a back-of-envelope estimate put total
cutscene length at roughly 8+ seconds for a freeze duration that would land the peak at 1.0x speed,
which is not viable for a moment that repeats on every single catch. Raising playback speed instead
keeps total cutscene length at roughly the same ~3 s ADR-070 already established.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target,
independent `unzip`/`usdcat` re-verification of the new file's stage metadata (`endTimeCode = 89`,
`timeCodesPerSecond = 24`) and `bindTransforms` (byte-identical to the previous file), and `shasum`
confirming the byte-identical copy (see the matching `CHECKPOINT.md` entry). Not yet played: whether
a ~2.29x base playback speed (which the thrash phase plays at, before dilation kicks in) looks
appropriately violent or too fast/blurry during the rise phase is an open question a live session
would need to answer — the derivation guarantees correct *timing* alignment, not that the resulting
speed necessarily looks good.

------------------------------------------------------------------------

# ADR-070 --- Catch Cutscene Gains an In-Code Slow-Motion Envelope During the Freeze Phase

## Decision

`updateCatchCutscene(deltaTime:)`'s `cutscene.elapsed` — the single "story clock" that
`catchCutsceneHeight(elapsed:)` (position) and `updateCameraFollow`'s cutscene branch (camera dolly)
both already read — now advances at `deltaTime * catchCutsceneTimeDilation(elapsed:)` instead of raw
`deltaTime`. `catchCutsceneTimeDilation(elapsed:)` returns `1` (normal speed) everywhere outside the
freeze phase, and inside it, eases from `1` down to `catchCutsceneSlowMotionFactor` (`0.3`) over the
first `catchCutsceneSlowMotionEaseFraction` (`0.2`, i.e. 20%) of the freeze window, holds at `0.3`
through the middle 60%, then eases back to `1` over the last 20% — a smooth dip, not an abrupt
on/off at the freeze's own phase boundaries.

Because both position and camera already derive everything from `cutscene.elapsed`, slowing that one
value down automatically slows the fish's rise-hold-settle motion *and* the ADR-048 camera push-in
together, with no separate changes needed to either. `caughtFishEntity`'s own animation is kept in
sync explicitly: `beginCatchCutscene` now keeps the `AnimationPlaybackController` returned by
`playAnimation(_:)` (`caughtFishAnimationController`), and `updateCatchCutscene` retargets its
`.speed` every frame to `catchCutsceneFishAnimationSpeed * dilation` — so the fish's own thrashing
visibly slows and speeds back up in lockstep with everything else, not just the world-space motion.

The freeze phase's nominal "story" duration (`catchCutsceneFreezeDuration`, `0.9` s) is unchanged, but
real wall-clock time to get through it is now considerably longer while dilated (roughly 2.3–2.4 s at
the current constants, versus 0.9 s un-dilated) — the total cutscene now runs roughly 3 s in real
time instead of the previous ~1.6 s.

## Rationale

Requested directly: "butuh animasi baru dengan rigging baru, yang menggambarkan ikan ngamuk dan ada
slowmotion ketika di cut scene ketangkep, jadi beneran kaya game mancing" (need new animation and
rigging depicting a raging fish, plus slow-motion in the catch cutscene, so it really feels like a
fishing game). The "new animation + rigging" half of that request needs real Blender authoring this
session cannot do (confirmed via `ToolSearch` — no Blender/MCP tool reachable from a `CtSPoC`-rooted
session) and was instead handed off as a written spec
(`new-blender-project/FishAssets/APP_TEAM_HANDOFF_CAUGHT_STRUGGLE.md`, see the matching `CHECKPOINT.md`
entry). Offered the user a choice between building slow-motion now with the existing asset, writing
the handoff only, or both; the user picked handoff-only first, then asked to "try again" and, when
asked what specifically to retry, chose to implement slow-motion in code now — this ADR is that.

Slow-motion was placed inside the existing freeze phase rather than as a new fourth phase, since the
freeze already *is* the cutscene's dramatic hang-time (ADR-047 — added specifically because a
continuous arc read as "too quick a blip"); dilating time during the beat that's already meant to be
the hold is more coherent than introducing another distinct segment.

An eased envelope (ramp down/hold/ramp up) was used instead of an instant dilation change at the
freeze phase's boundaries specifically to avoid a visible "jump cut" into and out of bullet-time —
a hard speed discontinuity right at a phase boundary would read as a stutter, not a deliberate
slow-motion effect.

Retargeting `caughtFishAnimationController.speed` every frame (rather than only at
`beginCatchCutscene`, as ADR-069 originally did) was necessary specifically because the whole point
of this ADR is that the fish's own struggle visibly slows down too — leaving the animation at a fixed
`1.4`x throughout while the world-space motion and camera slowed around it would have made the two
visibly disagree (a slow-drifting fish still flapping at normal-ish speed), undermining the "genuine
bullet-time" goal.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). Not yet played: `catchCutsceneSlowMotionFactor`
(`0.3`), the ease fraction (`0.2`), and the resulting ~3 s total real-time cutscene length are all
hand-picked, not tuned against how the dip actually feels live — in particular, whether ~3 s is too
long a wait before `ResultView` appears is an open question a live session would need to answer.

------------------------------------------------------------------------

# ADR-069 --- Caught Fish Orients to Face the Rod, and Plays Its Struggle Clip Faster

## Decision

Two fixes to `caughtFishEntity` (ADR-068), both reported directly after the first live look at the
cutscene: "ikannya masih make animasi preview, kurang cocok, harusnya animasi ikan ngamuk ketika
ditangkep, ngepak ngepak dan orientasi nya ngikuti arah pancing" (the fish still reads like it's
using the preview animation — it should look like it's thrashing/struggling on the line, flapping,
and its orientation should follow the rod/line direction).

**1. Orientation now follows the rod, recomputed every frame.** Added
`catchCutsceneFishOrientation(at:)` and `fishOrientation(facing:)`. Both `beginCatchCutscene(from:)`
and `updateCatchCutscene(deltaTime:)` now set `caughtFishEntity.orientation` alongside its position —
previously never touched at all, so the entity sat at RealityKit's default identity rotation for the
whole cutscene regardless of where it was or which way the rod pointed.

`fishOrientation(facing:)`'s local-axis assumptions were **not** taken from the source repo's
Blender-side documentation — they were confirmed by directly inspecting the copied `.usdz`'s own
data (`unzip` + `usdcat` on `mekong_catfish_caught.usdz`, reading `Skeleton.bindTransforms` per named
joint): body length runs along local **Y** (`Head` joint at Y≈−0.6, `Tail`/`Caudal_Fin` at
Y≈+0.5/+0.75), dorsal-ventral runs along local **Z** (`Dorsal_Fin` at Z≈+0.1, `Anal_Fin` at Z≈−0.1).
This matched the Blender-side note ("head −Y / tail +Y / dorsal +Z") but wasn't assumed to — the file
also declares `upAxis = "Z"`, meaning this specific USDZ export preserves Blender's native Z-up
convention directly rather than going through the Y-up axis-swap the sibling glTF exporter performs
(AGENTS.md §5.3) — so trusting the pre-export note without checking the actual exported file would
have been a real risk, not a formality.

Construction is two-step to avoid a handedness mistake: `simd_quatf(from: headAxis, to:
forwardDirection)` first aligns local `-Y` (head) to the target direction via the shortest-arc
rotation, which leaves an arbitrary roll around that axis; a second step then rotates around
`forwardDirection` so local `+Z` (dorsal) ends up as close to world-up as geometrically possible,
instead of whatever roll the shortest-arc step happened to produce (which could otherwise leave the
fish looking correctly "aimed" but rolled sideways or upside down).

`forward` is `rodRig.tipEntity`'s live world position minus the fish's current position — the rod
tip, not `dockAnchorPosition`/`controllerEntity` (the rig's root/handle), matching how
`launchHook(solution:)` already derives cast aim from the tip rather than the root — falling back to
`controllerEntity.position` only if the rig somehow isn't loaded.

**2. The struggle clip now plays at 1.4x speed.** `beginCatchCutscene`'s
`caughtFishEntity.playAnimation(clip)` call now sets `.speed = catchCutsceneFishAnimationSpeed`
(`1.4`) on the returned `AnimationPlaybackController`. This is a tempo change only — playback rate is
the one lever available from the app side without re-authoring the clip in Blender.
`Fish06_MekongGiantCatfish/Documentation/Source_Log.md` (asset repo) states this species was
deliberately animated with "a fuller-body amplitude profile... + slower cadence" than other fish
(catfish are flexible-bodied swimmers, not stiff thunniform like tuna/billfish) — meaning the authored
motion is *inherently* gentler than, say, a tuna's strike, by design, not by defect. Speeding up
playback makes it read more frantic without changing that authored amplitude, which a playback-rate
change cannot add.

## Rationale

The clip itself was independently re-confirmed (not re-trusted) to actually contain real, varying
per-frame motion across all 11 joints from frame 0 (direct inspection of
`rotations.timeSamples`, not just the presence of a `SkelAnimation` prim) before concluding the
reported "looks like the preview animation" complaint was about orientation/tempo rather than the
wrong clip being loaded or no clip playing at all — there's exactly one `SkelAnimation` embedded in
this file (`Catfish_Caught`), explicitly bound via the `Skeleton`'s `skel:animationSource` relationship,
so `availableAnimations.first` cannot be resolving to some other, wrong clip.

This leaves the most likely explanation for "looks like Preview" as: a technically-animating fish
sitting in an unrotated (identity) orientation, whose silhouette from the fixed ADR-048 cutscene
camera didn't read as "hooked and struggling" regardless of the bones moving underneath — exactly
what fixing orientation targets. The animation-speed change is a secondary, additive fix for the
literal "ngamuk... ngepak ngepak" (more frantic/thrashing) request, addressing tempo since amplitude
isn't available to change from this side.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry), plus direct `usdz` bindTransform/rotation inspection
for the axis and motion claims above. **Not yet re-verified live** — this is a direct response to a
live playtest observation, but the fix itself has not yet been re-tested on-device; the axis
identification is evidence-based (read from the file), not a guess, but the two-step orientation
construction, the specific rod-tip reference point, and the `1.4` speed multiplier are all still
first-pass choices pending a second live look.

------------------------------------------------------------------------

# ADR-068 --- Catch Cutscene Plays a Real Animated Fish, One Species Only, Scaled to the Rolled Catch Length

## Decision

`hookEntity` (the placeholder yellow sphere referenced throughout ADR-042 through ADR-048) is no
longer what the catch cutscene shows. A new entity, `caughtFishEntity`, is loaded once up front in
`makeSceneEntity()` via `Entity(named: "mekong_catfish_caught")` — the same `Entity(named:)` pattern
`EnvironmentSceneBuilder` already uses for every other bundled asset — disabled by default, added as
a sibling of `hookEntity` under the scene root.

`beginCatchCutscene(from:)` now: disables `hookEntity`; if `caughtFishEntity` loaded successfully,
enables it, positions it at the landing point, scales it (`max(rolledLengthMeters /
caughtFishAuthoredLength, 0.35)` — `caughtFishAuthoredLength` is `2.0`, this asset's authored body
length per its own `Source_Log.md`) so the displayed size tracks the actual rolled catch length
(`fishFight.lastCatchResult.length`, already available by this point — `resolveCatch()` runs before
`beginCatchCutscene`) rather than always showing the asset at its fixed authored size, and plays its
first baked animation (`caughtFishEntity.availableAnimations.first`) — the asset has exactly one, its
"Caught" struggle→calm→showcase clip.

The rise/freeze/settle height math from ADR-047 was factored out into a new
`catchCutsceneHeight(elapsed:)`, shared by `updateCatchCutscene` (now moves whichever entity is
active — `caughtFishEntity` if loaded, `hookEntity` as a fallback) and `updateCameraFollow`'s
ADR-048 push-in branch (now computes its focus point from `cutscene.origin` +
`catchCutsceneHeight(elapsed:)` directly, instead of reading `hookEntity.position`, since
`hookEntity` is hidden and stale for the whole cutscene now). `hookEntity` and `caughtFishEntity` are
both explicitly re-disabled wherever the cutscene can end — the normal settle-complete path in
`updateCatchCutscene`, and the mid-cutscene session-end path in `returnToMenu()`.

**Only one species, `mekong_catfish_caught.usdz`, regardless of which `FishSpecies` tier
(`fish_a`/`fish_b`/`fish_c`/`scott`) was actually rolled.** `FishCatalog`'s four tiers remain
placeholder data with no asset reference field at all (see its own doc comment — "parameter fish nya
nanti di ubah lagi") — mapping specific tiers to specific real species is a content/game-design
decision, not a technical one, and out of scope for this pass.

## Rationale

Requested directly: "skrg kita butuh animasi ikan ketangkep buat scene barusan... siapkan asset dan
manfaatkan di repo ini" (we now need the caught-fish animation for the cutscene we just built —
prepare the asset and put it to use in this repo), pointing at a separate sibling asset repo
(`~/repos/new-blender-project`) built specifically to supply this game's fish/environment assets —
confirmed by reading that repo's own `CLAUDE.md`, which states outright: "The app repo is
`~/repos/c4/CtSPoC`... this file is your entry point... before integrating any asset."

**Why Mekong Giant Catfish specifically, out of the asset repo's ten species:** that repo's own
`CLAUDE.md` (§3, "Current status") lists 8 of 10 species as fully complete (4 baked states,
GLB+USDZ), but a separate handoff note
(`FishAssets/APP_TEAM_HANDOFF.md`, written by an earlier session working this same app's since-shelved
AR fish-preview feature) documents that 5 of those 8 have **known, unresolved
orientation/normals/UV export defects** confirmed via on-device testing (Skipjack Tuna, Grouper,
Giant Trevally still broken as of that note's last update; Bluefin/Yellowfin Tuna fixed but
unconfirmed on-device). Two species are explicitly called out as reliable: **Sailfish** ("confirmed
correct on-device... do not touch") and **Mekong Giant Catfish**, named the actual **reference**
other species' fixes should be modeled on ("the best-exported and best-oriented fish currently in the
app... use its current Blender object transform, material setup, and export process as the template
for everything else"). Sailfish was excluded from this pick only because that same note explains its
rig/orientation convention is a known outlier (came through a different Sketchfab/FBX import chain
than every Blender-native fish) — not a reason to avoid it forever, just not the safer first pick
when only one species needs choosing. Mekong Giant Catfish's `Caught` USDZ was independently confirmed
here (not just trusted from the note) to actually contain a real baked `SkelAnimation` (`unzip` +
`usdcat` inspection: a `Skeleton "CatfishArm"` with a `SkelAnimation "Catfish_Caught"` carrying
`rotations.timeSamples`), so this isn't resting on the source repo's documentation alone.

The asset was copied byte-for-byte (`shasum -a 256` confirmed identical both sides) from
`new-blender-project/FishAssets/Fish06_MekongGiantCatfish/Caught/MekongCatfish_Caught.usdz` to
`World/World/Assets/FishCaught/mekong_catfish_caught.usdz`, renamed to this project's own snake_case
asset convention (already established for every `World/World/Assets/Environment/*.usdz` file) rather
than kept as the source repo's PascalCase. This is a **new** asset category
(`World/World/Assets/FishCaught/`), not an addition to `Assets/Environment/` — fish are not
environment set-dressing, and the source repo's own explicit "byte-identical, keep both copies in
sync" sync rule is scoped specifically to `FishAssets/Environment/*.usdz`, not fish.

Scaling the displayed fish to the rolled catch length (rather than always showing it at its fixed
2.0 m authored size) was a small addition beyond the minimum needed to "show a real fish instead of a
sphere" — the data (`fishFight.lastCatchResult.length`) was already computed and about to be shown
moments later on `ResultView`, so tying the cutscene's visual size to the same number costs little and
avoids an obviously-wrong outcome (a `fish_a`-tier catch, weight range 0.8–3.5 kg, displaying at a
fixed 2 m regardless).

Mapping the four `FishCatalog` tiers to four distinct real species (so a `scott`-tier catch shows a
different, bigger-feeling fish than a `fish_a`-tier catch) was deliberately **not** attempted here —
it requires either fixing/vetting more of the remaining broken species first, or accepting a
currently-broken one, and deciding *which* real species represents which abstract tier (especially
`scott`, a named "boss" fish) is a content decision for the game's designers, not something to invent
silently while wiring a rendering pipeline.

**License note (unresolved, flagged for follow-up):** `Fish06_MekongGiantCatfish/Documentation/
Source_Log.md` states this asset is **CC-BY 4.0**, requiring attribution ("Ikan Patin," Sketchfab, UID
`d9e7f483…`). This branch (`feat/playtest-refine`) has no credits/attribution screen yet — the
Main Menu/Credits/Tutorial UI work lives on a separate, not-yet-merged branch
(`feat/ui-slice`) — so this attribution requirement is **not yet satisfied** anywhere in the shipped
app. Recorded here explicitly rather than silently shipped unattributed; must be wired into whatever
credits screen eventually lands, per the asset repo's own §5 licensing note.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry), plus direct `usdz` content inspection (`unzip`/
`usdcat`) confirming the baked animation exists, and `shasum` confirming the byte-identical copy. Not
run: any live session — the fish's final display scale, whether `Entity(named:)` successfully
resolves `availableAnimations.first` as the intended "Caught" clip (vs. some other embedded
animation, if any), and the model's world-space orientation once actually rendered (this pass applies
no corrective rotation at all, trusting the source repo's own claim that this specific species needs
none) are all unverified on-device. The CC-BY attribution gap above is a known, unresolved item, not
an oversight.

------------------------------------------------------------------------
# ADR-048 --- Catch Cutscene Gains Letterboxing, a Camera Push-In, and a Title Flourish

## Decision

Three presentation-only additions, all scoped to the existing catch cutscene (ADR-045/046/047), none
touching `Shared` or `Rod`:

1. **Camera push-in.** `updateCameraFollow()`'s cutscene branch (ADR-046) no longer holds a single
   static offset from `hookEntity`. It now eases from a new `catchCutsceneCameraStartOffset`
   (`[0, 1.2, 2.4]`) to the existing tight `catchCutsceneCameraEndOffset` (`[0, 0.9, 1.6]`, formerly
   just `catchCutsceneCameraOffset`) over the cutscene's full run — a `smoothstep`
   (`t*t*(3-2*t)`) of `catchCutscene.elapsed / catchCutsceneTotalDuration`, a new computed property
   summing the three ADR-047 phase durations so the camera and hook motion can't disagree on when the
   cutscene ends.
2. **Letterbox bars and a radial glow.** `CatchCutsceneView` gained top/bottom black bars that slide
   in on appear (0 to 64pt over 0.25s) and a soft yellow radial glow behind the title, plus a
   background vignette (`RadialGradient`, clear center to `black.opacity(0.5)` at the edges) — all
   purely `SwiftUI`, no RealityKit changes.
3. **Title flourish.** The "CATCH!" title's entrance changed from a simple `spring(response: 0.4,
   dampingFraction: 0.55)` (critically-damped-ish, no overshoot) to `spring(response: 0.45,
   dampingFraction: 0.45)` — low enough damping to visibly overshoot past full scale before settling,
   read as a punchier "pop." Font size grew 64 -> 72.
4. **HUD hides during the cutscene.** `ContentView`'s stat block (`LineTensionView`, the
   caught-count/level `GroupBox`, `CastMeterView`'s commented slot, the error `Text`) is now wrapped
   in a `Group` with `.opacity(viewModel.isShowingCatchCutscene ? 0 : 1)` and a matching
   `.animation(...)`. The `RealityView` and its fps/connection-state overlay are unaffected.

## Rationale

Requested directly, immediately after ADR-047's freeze landed: "dan bikin lebih 'dramatis'" (and make
it more "dramatic"). None of ADR-045 through ADR-047 individually were wrong, but stacked together
they still amounted to a static camera holding on a placeholder sphere with a single title label
fading in over an unchanged gameplay HUD — correct timing and framing, but visually flat, which reads
as the opposite of "dramatic" regardless of how good the underlying rise/freeze/settle timing is.

Each addition targets a specific flatness the others don't fix: a locked-off camera shot (even a
well-framed one, ADR-046) doesn't read as "cinematic" the way a moving shot does, hence the push-in;
a floating title over an otherwise-unchanged HUD doesn't isolate the moment, hence the HUD fade and
the letterboxing (an immediately-recognizable "cutscene mode" signal borrowed from film/games
generally); and a title that just fades in at fixed scale reads as flat compared to one with a bit of
punch, hence the overshoot spring and added glow. All four are presentation-only and layer on top of
the existing trigger/phase/camera-branch structure from ADR-045/046/047 without changing any of it —
`beginCatchCutscene(from:)`, `updateCatchCutscene(deltaTime:)`'s phase math, and the `reelHook` trigger
are all untouched.

An actual "catch" sound cue was considered but turned out to already exist: `reelHook`'s
`emit(.catchFish)` (present since before ADR-045, unchanged by any of this cutscene work) already
plays `catch_splash.wav` via `FishingSounds.handle(.catchFish)` at the exact moment the cutscene
begins, so no audio changes were needed here.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). The push-in offsets, letterbox bar height, spring
parameters, and vignette/glow opacities are all hand-picked, not tuned against how they actually read
on-device — first-pass placeholders same as the rest of this cutscene work, expected to change again
once real fish/camera assets are integrated.

------------------------------------------------------------------------

# ADR-047 --- Catch Cutscene Holds the Fish at the Jump's Peak Instead of a Single Continuous Arc

## Decision

`updateCatchCutscene(deltaTime:)`'s single `sin`-eased up-and-down arc (ADR-045, one continuous
motion across `catchCutsceneDuration`) is replaced with three explicit phases:

1. **Rise** (`catchCutsceneRiseDuration`, 0.35 s) — ease from the origin up to
   `catchCutsceneJumpHeight` (`sin(t * .pi / 2)`, `t` = elapsed/rise duration).
2. **Freeze** (`catchCutsceneFreezeDuration`, 0.9 s) — `hookEntity` holds exactly at
   `catchCutsceneJumpHeight`, motionless.
3. **Settle** (`catchCutsceneSettleDuration`, 0.35 s) — ease back down to the origin
   (`cos(t * .pi / 2)`, `t` = elapsed-since-freeze-end/settle duration).

Both eases are continuous at the phase boundaries (rise ends at exactly `catchCutsceneJumpHeight`,
matching the freeze's held value; settle starts at exactly `catchCutsceneJumpHeight`, matching where
freeze left off), so there is no positional snap between phases. The old single `catchCutsceneDuration`
constant is removed; total cutscene play time is now the sum of the three phase durations (1.6 s, up
from the old 1.3 s). `beginCatchCutscene(from:)`, the catch trigger in `reelHook`, `ContentView`'s
overlay wiring, and ADR-046's camera-cut branch are all unchanged — only `updateCatchCutscene`'s
internal motion curve and its three new constants changed.

## Rationale

Requested directly, immediately after ADR-046's camera cut landed: "ikan dan bomber nya harus
'freeze' di cut scene agar kesan cut scene nya tidak terlalu singkat" (the fish and bobber need to
freeze during the cutscene so it doesn't feel too brief). A single continuous `sin(t * .pi)` arc
spends almost all of its time in motion and only touches its peak height for a single instant — even
at the full 1.3 s duration, the hook is only ever "at the top" for one frame, so the moment reads as
a quick blip passing through rather than a deliberate pause on the catch. An explicit held phase,
with the hook motionless at the peak for nearly a second, is what actually reads as "the cutscene
lingers on the catch," which continuous easing alone could not produce no matter how long
`catchCutsceneDuration` was set to.

Split into three phases rather than, e.g., biasing a single easing curve to spend more time near its
peak (a harder-to-read, less explicit approach) — three named, independently tunable durations make
the "how long does it hang in the air" question a single obvious constant
(`catchCutsceneFreezeDuration`) to adjust once this is played live, consistent with this pass's own
placeholder-pending-live-confirmation status.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). All three phase durations and the total 1.6 s runtime
are hand-picked, not tuned against how the hold actually reads in a played session.

------------------------------------------------------------------------

# ADR-046 --- Catch Cutscene Cuts the Camera to the Hook, Reusing the Existing Follow-Cam Path

## Decision

`updateCameraFollow()` gained a new first branch: whenever `isShowingCatchCutscene` (ADR-045) is
true, the camera looks at `hookEntity` from `hookEntity.position + catchCutsceneCameraOffset`
(`[0, 0.9, 1.6]`) and returns immediately, before the existing `hookPhase`-based `followsHook` check
runs. `catchCutsceneCameraOffset` is deliberately closer and lower than the mid-fight trailing
`followOffset` (`[0, 1.5, 3.0]`, ADR-039) — a tighter, more deliberate shot rather than reusing the
same trailing framing the fight itself already uses. Once the cutscene ends (`isShowingCatchCutscene`
flips back to `false`, still inside `.result` while `ResultView` waits for "Continue Fishing"), the
function falls through to its existing behavior — `.result` was never in `followsHook`'s phase list,
so the camera resets to the player pose exactly as it did before this change.

## Rationale

Requested directly, immediately after the ADR-045 cutscene landed: "butuh cameranya langsung ke
bomber dan ikan yang ketangkep, biar beneran kaya cut scene" (the camera needs to cut directly to the
bobber and the caught fish, so it actually feels like a cutscene). Before this change,
`updateCameraFollow()`'s `followsHook` list was `.flying`/`.fishOnHook`/`.reeling` only — `.result`
was explicitly excluded (see its own prior doc comment, "Snaps back to the player pose for every
other phase — including `.result`"), so the ADR-045 cutscene played entirely off-camera from the
player's fixed POV, at `hookLiftTargetPosition` which is a further, more head-on angle than a
deliberate "hero shot." The jump was technically running but not actually visible as a cut.

Reused `updateCameraFollow()`'s existing look-at/offset mechanism rather than building a second
camera system — the function already exists precisely to point the camera at `hookEntity` from a
fixed relative offset, which is exactly what a "cut to the catch" needs; the only meaningful design
question was the offset itself, since a cutscene shot should read as distinct from the ongoing-fight
trailing shot, not identical to it. Gated on `isShowingCatchCutscene` rather than `hookPhase ==
.result`, since `.result` also covers the post-cutscene stat-card wait, where the camera should
already be back home per the pre-existing behavior — only the cutscene's own duration should pull the
camera in.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). `catchCutsceneCameraOffset` is a hand-picked value
(closer than the existing mid-fight offset), not confirmed against how the shot actually frames
`hookEntity`'s jump arc (ADR-045) in a live session.

------------------------------------------------------------------------

# ADR-045 --- Catch Resolution Plays a Cutscene Before the Result Screen, as a World Presentation State (Not a New HookPhase)

## Decision

`reelHook(deltaTime:)`'s catch guard (ADR-044's `distance3D > 0.15` check) no longer disables
`hookEntity` and shows `ResultView` in the same tick a catch resolves. On a real catch it now calls
`fishFight.resolveCatch()` and `beginCatchCutscene(from:)` instead, then still sets `HookPhase` to
`.result` immediately (unchanged) — casting/reeling stay locked for the whole cutscene exactly as
before, since `.result` already had `allowsCasting == false` and `allowsReeling == false`. Empty
retrieves (no fish on hook) are untouched: `hookEntity.isEnabled = false` and `HookPhase.idle` fire
immediately, no cutscene.

The cutscene itself is a new `@Published private(set) var isShowingCatchCutscene: Bool` on
`WorldViewModel`, driven from a private `CatchCutscene { origin, elapsed }` struct ticked inside
`tick(deltaTime:)`'s existing `.result` case (previously `break`). `updateCatchCutscene(deltaTime:)`
arcs `hookEntity` upward from where it landed (`sin` easing, peak `catchCutsceneJumpHeight`, 0.6 m)
over `catchCutsceneDuration` (1.3 s), then disables it and flips `isShowingCatchCutscene` back to
`false`. `ContentView` gates a new `CatchCutsceneView` (a non-dismissable "CATCH!" title overlay) on
`isShowingCatchCutscene`, and `ResultView`'s existing condition gained `!isShowingCatchCutscene` so
the two never show at once.

`HookPhase` itself (`Shared/Sources/Shared/Models/Gameplay/HookPhase.swift`) was **not** changed —
no new case was added. `returnToMenu()` gained `catchCutscene = nil` /
`isShowingCatchCutscene = false` alongside its existing hook/fight resets, so ending a session
mid-cutscene (Rod's "End Fishing" at any point, per ADR-038) can't leave the flag stuck `true` for a
future session.

## Rationale

Requested directly, drawing an explicit comparison to casting's own already-distinct moment (Hook
Flying/Splash): "kita harus bikin 'cut scene' seperti game-game pun ... ketika bomber nya sudah
mendekati dock, dan user melakukan final reel input, akan dimunculkan 'scene' ikan dan bomber dimana
mereka melompat ke atas dan akan muncul title 'CATCH'" (build a cutscene, like other games have —
when the bobber/fish nears the dock and the player's final reel input lands it, show a scene where
the fish and bobber jump up and a "CATCH" title appears) — "nantinya, 'scene' ini akan disambungkan
dengan blender animasi asset" (this scene will later be connected to a Blender animation asset).

A new `HookPhase` case was considered and rejected: `HookPhase` is a `Shared` contract consumed by
both `Rod` (haptics, `allowsCasting`/`allowsReeling`) and `World` (rendering/HUD), per this project's
own Rod/Shared/World dependency rule (`Rod -> Shared <- World`, never Rod <-> World directly) and its
explicit statement that "Rod owns no gameplay presentation." The cutscene is pure presentation with
no distinct input-locking or haptic behavior beyond what `.result` already provides — reusing
`.result` and adding a World-only `Bool` avoids touching `Shared` or `Rod` at all for a change that is,
by its own nature, entirely a `World` rendering/HUD concern.

`hookEntity`'s jump is explicitly a placeholder — still the same `ModelEntity` sphere referenced
throughout ADR-042 through ADR-044 (there is no separate fish mesh anywhere in this codebase; see
those ADRs and `FishFightController`'s own doc comment that it "has no knowledge of transport, hook
entities, or RealityKit"). The goal of this pass is the cutscene's *timing, trigger, and state
machine* — a scripted `sin`-eased vertical arc is enough to prove and review that shape now,
independent of the later Blender asset work the request itself flags as still pending. When a real
fish mesh/animation lands, `updateCatchCutscene(deltaTime:)` is the single, well-defined place to
replace the placeholder arc with a driven animation, and `beginCatchCutscene(from:)`/the
`distance3D > 0.15` guard in `reelHook` remain the single, well-defined trigger moment — deliberately
not spread across multiple call sites.

`catchCutsceneDuration` (1.3 s) and `catchCutsceneJumpHeight` (0.6 m) are hand-picked, matching this
project's own established pattern of flagging unverified constants explicitly (see ADR-043/044)
rather than presenting them as tuned.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
(macOS) only, since this change touches no `Shared` or `Rod` files (see the matching `CHECKPOINT.md`
entry). Not yet played; the jump arc, cutscene duration, and title styling are all first-pass
placeholders expected to change once real fish assets/animation are integrated.

------------------------------------------------------------------------

# ADR-044 --- Dock-Approach Lift Uses a Guaranteed Fixed Speed, Not Tug-of-War

## Decision

Inside `hookLiftDistance` (1.0 m) of `hookLiftTargetPosition`, `reelHook(deltaTime:)` no longer
moves at `rodState.reelSpeed * reelSpeed` net `fishFight.fishPullSpeed` (ADR-039's tug-of-war). It
now always advances toward `hookLiftTargetPosition` at a new fixed constant,
`dockLiftSpeed = 3.5` m/s — faster than the player's own max reel speed (`reelSpeed`, `3.0`) — with
no subtraction for the fish's pull. Outside that zone (the open-water reel-in), the tug-of-war stays
exactly as ADR-039 left it.

`reelHook`'s catch/empty-retrieve resolution also changed from a horizontal-only distance check
(`> 0.12` m) to a full 3D distance check against `hookLiftTargetPosition` (`> 0.15` m), so resolution
now waits for the guaranteed climb above to actually finish rather than firing horizontally while the
hook may still be partway through its vertical rise.

`driftHookAway(deltaTime:)` (ADR-042), used when a hooked fish pulls line out while the player isn't
actively reeling, is unchanged — it still uses `fishFight.fishPullSpeed` in both zones, since a fish
escaping toward open water should still be able to pull the hook back down out of the lift zone.

## Rationale

Reported directly during playtesting: "ketika bomber nya sudah mulai mengenai dock nya, bomber
kuning nya masih 'melayang' ... harusnya ketika sudah menyentuh dock, harusnya ikan mulai makin
bergerak cepat pun atau langsung naik ke dock ketimbang melayang" (once the hook/fish starts reaching
the dock, it still visibly "floats" instead of speeding up or climbing straight onto the dock).

Tracing `reelHook`'s math: the tug-of-war net speed (`playerSpeed - fishFight.fishPullSpeed`) can be
small or negative even while the player is actively reeling — a documented, intentional design
(ADR-039) for the open-water fight, where a strong fish should be able to contest the player. Left
unchanged inside the lift zone, though, the same math let the hook stall in place or even sink back
toward the water right at the dock's edge, which is exactly the reported "floating" feel — a fish
this close to being landed visually has no business still winning a tug-of-war.

The catch/empty-retrieve resolution threshold was originally horizontal-only specifically so
resolution wouldn't have to wait for the hook to climb the full ~2 m up to the rod's hand height
(ADR-043's own rationale). That tradeoff no longer applies now that the climb is fast and guaranteed
rather than tug-of-war-gated — switching the check to full 3D distance means the hook visibly
finishes arriving before it disappears, instead of vanishing mid-climb, which is the second half of
the reported issue (the hook/fish should be seen reaching the dock, not just getting close to it
horizontally and cutting away).

**Forward-looking note for fish-asset integration:** `hookEntity` is still a placeholder sphere and
literally *is* the fish's rendered position (`FishFightController` holds no RealityKit/entity state
at all — see `GAMEPLAY_ARCHITECTURE_V1.md` and the "Fish Species and Fight Simulation" section of
`SOFTWARE_ARCHITECTURE_DOCUMENT.md`). When a real fish mesh/animation replaces it, this guaranteed
dock-approach climb is the natural hook point for a "landed on the dock" animation trigger — `reelHook`
already has a single, well-defined moment (the `distance3D > 0.15` guard failing) where the fish is
considered to have arrived, rather than that being inferred indirectly from tension or distance
elsewhere.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
(macOS) and via a `Shared`-only build against the `Rod` (iOS simulator) target's module (see the
matching `CHECKPOINT.md` entry), not yet played. `dockLiftSpeed = 3.5` is a hand-picked value (faster
than the player's own max reel speed, `3.0`) rather than one tuned against a live session.


------------------------------------------------------------------------

# ADR-043 --- Hook Lift Motion Targets a Dedicated Point, Not the Rod's Render Anchor

## Decision

`reelHook(deltaTime:)` and `driftHookAway(deltaTime:)` (ADR-042) moved the hook's near-zone
(within `hookLiftDistance`) lift phase, and `reelHook`'s catch/empty-retrieve resolution distance,
toward `controllerEntity.position` — i.e. `dockAnchorPosition`, `[0.22, 1.95, -2.1]`, the rod's
fixed camera-relative render anchor (ADR-019). Loading `dock_main.usdz` directly via
`Entity(contentsOf:).visualBounds(relativeTo: nil)` (not eyeballed) measured its real footprint as
X in `[-2.04, 2.04]`, Z in `[-4.5, 4.5]` — `dockAnchorPosition`'s XZ, `(0.22, -2.1)`, sits well
inside that footprint, not at an edge. Since the lift phase rises the hook from `waterHeight` (`0`)
up to `1.95` while its XZ converges on that interior point, the rise happened directly underneath
the dock's solid deck geometry, reading as the bobber clipping through the pier on lift.

Added `hookLiftTargetPosition: SIMD3<Float> = [0.22, 1.95, -4.7]` — same X/Y as
`dockAnchorPosition` (so the pull still reads as heading toward the held rod, and still finishes at
hand height), but Z pushed to `-4.7`, just past the dock mesh's own measured `-4.5` water-facing
extreme. `reelHook`/`driftHookAway` now compute horizontal distance, the lift-phase 3D direction,
and (in `reelHook`) the catch/empty-retrieve resolution threshold all against
`hookLiftTargetPosition` instead of `controllerEntity.position`. `dockAnchorPosition` and
`controllerEntity` are otherwise untouched — `updateRodPose()`'s rendering and `ensureFightDistance()`
(ADR-031's same-tick-instant-catch guard, left alone per ADR-042's own precedent) still use the rod's
real render position.

## Rationale

Reported directly after playtesting ADR-042's fix: "waktu ngangkat, kayanya masih overlap sama pier
(maybe kurang ke depan dikit?)" (when it lifts, it seems to still overlap with the pier — maybe it
needs to be a little more forward?). Recorded as a TODO in the matching `CHECKPOINT.md` entry rather
than fixed blind at the time, pending a look at the dock's actual geometry per this project's own
established pattern of checking the asset directly instead of guessing (see e.g. the tree-orientation
and shoreline-density fixes in `EnvironmentSceneBuilder.swift`).

Reusing `dockAnchorPosition` conflated two different concerns that ADR-019 already treats as
separate elsewhere (rod-root render position vs. hook gameplay motion): a point chosen for where the
rod visually sits in the player's hand is not the same as the point gameplay motion should converge
on, and here they need to differ specifically because the render anchor happens to sit inside the
dock's own solid geometry. `hookLiftTargetPosition` keeps that separation explicit — a second,
motion-only anchor, matching the player's own diagnosis (needs to be further forward, i.e. further
out over open water) and the measured mesh bounds (which independently confirm `dockAnchorPosition`'s
Z is well short of the dock's actual water-facing edge).

Both `hookLiftDistance` (1.0 m, unchanged) and the new `-4.7` Z value are still hand-picked relative
to the *measured* mesh extreme (`-4.5` plus a 0.2 m clearance margin), not validated against a live
session — the mesh only yielded one undifferentiated bounding box (`dock_main.usdz` has no separate
deck/railing submeshes to bound individually), so `-4.7` is the most defensible value obtainable
without an interactive Blender pass, not a claim that it's exactly where the pier's walkable edge
ends.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets only (see the matching `CHECKPOINT.md` entry), not
yet played.

------------------------------------------------------------------------

# ADR-042 --- Reel-In Motion Stays at Water Height Until Near the Dock

## Decision

`WorldViewModel.reelHook(deltaTime:)` and `driftHookAway(deltaTime:)` previously moved the hook
in a straight 3D line toward/away from `controllerEntity.position` (`dockAnchorPosition`,
`[0.22, 1.95, -2.1]`) every tick. Since the hook sits at `waterHeight` (`0`) after a splash and the
rod is held at `y = 1.95`, that 3D vector always had a large vertical component from the very first
reeling tick — the bobber visibly rose and climbed diagonally toward the rod immediately, instead of
staying at the water's surface until close to shore.

Added `hookLiftDistance: Float = 1.0` (meters, horizontal). Both functions now branch on the
*horizontal* (X/Z) distance from the hook to the rod:

```text
horizontalDistance > hookLiftDistance  -> move/drift horizontally only; pin hookEntity.position.y
                                            to waterHeight every tick
horizontalDistance <= hookLiftDistance -> move/drift in full 3D (the original behavior), so the
                                            hook rises the rest of the way up to the rod
```

**Catch/empty-retrieve resolution also switched basis.** `reelHook`'s terminal `guard` — previously
`distance > 0.12` on the full 3D distance — now checks the same `horizontalDistance > 0.12`. The
full-3D version required the hook to also close the ~2 m vertical gap up to `dockAnchorPosition`'s
height before resolving, i.e. effectively requiring it to reach the rod's exact held position: doing
this diagonally, then only just barely still counting once it got close (a hook still ~1.9 m below the
rod but 12cm out).  Using horizontal distance means the catch/retrieve resolves once the hook is close
to the dock's edge horizontally, matching how the motion itself now reads — arriving at the water's
edge in front of the pier, not climbing all the way up to hand height.

`ensureFightDistance()` (the ADR-031 same-tick-instant-catch guard) was left untouched — it already
only ever fires in a rare edge case (a bite landing while the hook is already extremely close to the
rod in full 3D, effectively requiring the hook to already be in the near/lift zone), and its behavior
is unaffected either way by this change.

## Rationale

Reported directly: "kalo reel, arah si bobber nya masih diagonal langsung ke arah rod. seharusnya,
bobber ngikut di dasar air aja sampai akhir deket rod, baru keangkat (jadi ikan sukses ditangkep
bukan pas bobber hit base coordinate alias tempat rod, tapi begitu di depan pier dikit)" (when
reeling, the bobber's direction still goes diagonally straight toward the rod. It should instead
follow along the water's surface until it's near the rod at the end, then finally get lifted — so
the fish counts as caught not when the bobber hits the base coordinate, i.e. the rod's position, but
as soon as it's a bit in front of the pier).

Root cause confirmed by reading `reelHook`/`driftHookAway` directly: both used the raw
`controllerEntity.position - hookEntity.position` vector for every step, with no distinction between
the horizontal (across-the-water) component and the vertical (out-of-the-water) component. Splitting
movement into a horizontal-only phase (most of the reel-in) and a full-3D phase (only the last
`hookLiftDistance` meters) matches how a real fishing retrieve reads — the line and bobber travel
across the water's surface, and only come up out of the water right at the end, near the angler.
`driftHookAway` got the same fix for consistency: without it, a resisting fish would have dragged the
hook down and away in 3D too, which — since "away from the elevated rod" has a downward component —
would have pulled the hook visibly *below* the water plane while the player wasn't reeling, an
unrelated but symmetric instance of the same underlying bug.

`hookLiftDistance` (1.0 m) and the reused `0.12` m catch-threshold constant are both hand-picked, not
measured against the dock/water asset geometry — this is a first pass at the reported motion issue,
not a claim that 1.0 m is the exact right distance for the lift to look natural once played.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` only (see the
matching `CHECKPOINT.md` entry), not yet played.

------------------------------------------------------------------------

# ADR-041 --- Nearby Interaction Is Present but Not Load-Bearing for V1 Gameplay

## Decision

Confirmed by direct code audit, not inference from docs: Rod still owns and runs a Nearby
Interaction session exactly as ADR-014 describes (`NearbyInteractionManager.swift` populates
`SpatialState.directionX/Y/Z`/`distance`, which flow into `RodState` and transmit every ~30 Hz
sample), but **no gameplay, rendering, or connection-gating code path anywhere in Rod or World
reads those fields.** Grepped every plausible consumer:

- `WorldViewModel.updateRodPose()` sets `controllerEntity.position` from the fixed
  `dockAnchorPosition` constant and `controllerEntity.orientation` from `RodState.orientation`
  only (ADR-019) — zero reference to `rodState.distance`/`direction`.
- `CastResolver`/`RodMotionInterpreter` derive cast direction/power from corrected orientation and
  (ADR-033) live rig geometry — zero reference to NI's spatial fields.
- `hookDistanceFromRod()`, which drives the ADR-039 fight/escape-distance mechanic, is
  `simd_length(controllerEntity.position - hookEntity.position)` — a RealityKit scene-space
  calculation between two entities, unrelated to NI's real-world ranging.
- `connectionState` (which gates whether the player can start fishing) is set purely from the
  CoreBluetooth transport's own `onStateChange` callback; `spatialStatus` (NI's own status) is a
  separate published property read in exactly one place on each device — a debug status/value row
  in `ContentView.swift` (Rod: `spatialStatus` label plus the direction/distance debug rows;
  World: the same distance/direction debug rows). Nothing gates on it.

**Decision: leave the Nearby Interaction code in place** (Rod keeps owning the session per
ADR-014; `SpatialState`/`RodState.directionX/Y/Z`/`distance` are unchanged) rather than removing
it — a removal is a separate, larger-scope decision not made here. This ADR only corrects
`AGENTS.md`'s prior "Casting State and Transform Contract" wording, which claimed *"Nearby
Interaction spatial distance/direction remain the rod's spatial transform source."* That statement
was accurate before ADR-019, when `updateRodPose()` did position the rod root from live NI
distance/direction — ADR-019 deliberately decoupled that (to fix the rod visibly moving during a
cast) and nothing since has restored NI to that role. The doc line was never updated to reflect
its own project's later decision.

## Rationale

Raised directly by the player after reviewing a separate chat's analysis questioning whether NI
could ever be "load-bearing" given CoreBluetooth's RSSI-based ranging can't match NI's UWB
precision/direction — a fair technical point, but the actual question that mattered was whether
today's V1 gameplay uses NI's precision at all, not whether it theoretically could. Player's own
framing once the audit above confirmed it doesn't: **"NI awalnya akan dipakai, tapi ternyata
transport protocol pakai CoreBluetooth aja cukup untuk ngirim data sehingga spatial controller
belum akan dipakai di fase development ini"** (NI was originally going to be used, but it turned
out CoreBluetooth transport alone is enough to send data, so the spatial-controller aspect isn't
going to be used in this phase of development). This project's own name and `ADR-015`'s long-term
vision ("reusable spatial controller framework" for a tennis racket, golf club, sword, etc.) are
explicitly built on NI's distance/direction sensing being load-bearing eventually — this ADR does
not retire that vision, it records that the *current* V1 fishing gameplay never ended up needing
it, and that the Nearby Interaction plumbing is fully intact and available the moment a future
feature (e.g. a physical-proximity-driven effect) actually calls for it.

Explicitly not decided here: whether to ever remove NI, whether `AGENTS.md`/`CLAUDE.md`'s framing
of this project as a "spatial controller" PoC should change, or whether NI's debug rows should be
trimmed. Documentation-only correction of one stale claim, not a scope change.

Status: Accepted

------------------------------------------------------------------------

# ADR-040 --- World-Side Audio Mirrors the Rod Haptics Router

## Decision

Added the game's first sound effects, wired entirely on the World side. A `SoundManager` +
`FishingSounds` pair (`World/World/Audio/`) structurally mirrors Rod's `HapticManager` +
`FishingHaptics` (`Rod/Rod/Haptics/`): one preloaded `AVAudioPlayer` per sound primitive
underneath, one `handle(_ event: FishingEvent)` switch on top. Audio is presentation, so it stays
out of `Shared` and never touches the transport — Rod keeps haptics only, no phone-side audio.

`WorldViewModel` funnels every World-emitted `FishingEvent` through a single `emit(_:)` method
that calls both `sounds.handle(event)` and the existing `send(.fishingEvent(event))`, so sound
and Rod's haptic trigger can never drift out of sync with each other. `.cast` has no
World-emitted `FishingEvent` (Rod generates it locally from motion, per the existing
Rod-local/World-emitted split in `FishingEvent`), so the cast sound is triggered directly from
`launchHook(solution:)` via `sounds.castLaunched()` instead of going through the funnel.

The reel loop is **frame-driven, not event-driven**: `WorldViewModel.tick(deltaTime:)` calls
`sounds.updateReelLoop(active:)` every tick based on `rodState.action`/`hookPhase`, so an
empty-line retrieve during `.hookInWater` (no fish hooked yet) still gets the reel sound, not
just an active fight — matching what a player actually hears when reeling, independent of
whether a fish happens to be on.

`AVAudioPlayer` was chosen over RealityKit's spatial `AudioResource`/`AudioPlaybackController`:
none of the current sounds (UI clicks, ambience, splash/bite/catch one-shots) need 3D
positioning. Spatializing the hook-splash/reel sounds to the hook entity's world position is a
plausible future upgrade, not needed for this pass.

`AVAudioSession` is iOS-only, so `SoundManager`'s session setup is wrapped in `#if os(iOS)`
(`.ambient` category with `.mixWithOthers`) — macOS needs no session configuration to play audio
under its sandbox. `.ambient` was picked over `.playback` so game audio respects the iOS silent
switch by default; revisit if that turns out to be the wrong default for this game.

Two gaps left deliberately open, both user-confirmed for this pass: `fishEscaped`/`lineBreak`
have no dedicated recorded asset yet, so they reuse the hook-splash one-shot (reads as the fish
darting off) rather than staying silent; and the level-up banner has no sound at all — if one is
added later, the trigger point is `FishFightController.levelUpAnnouncement` becoming non-nil,
observed the same place `ContentView` already shows the banner.

## Rationale

Mirroring Rod's haptics router structure (rather than inventing a new shape) means anyone who
already understands `FishingHaptics.handle(_:)`'s switch, `stopInterest()`/`stopFight()`
belt-and-suspenders cleanup, or the `FishFightConfig`-driven band parameters can read
`FishingSounds` with no new mental model. Keeping the `emit(_:)` funnel as the single place both
systems get told about an event was a direct decision to prevent the two feedback channels
(haptic on Rod, audio on World) from silently diverging over time as new events get added,
rather than trusting every call site to remember to fire both a `send` and a sound.

Assets moved from a repo-root `SFX/` folder (untracked, spaces/parentheses in filenames, one
stray Ableton `.asd` analysis file) into `World/World/Assets/SFX/` with clean snake_case names
matching the `Sound` enum's raw values — both Xcode projects already use Xcode 16 synchronized
root groups (`PBXFileSystemSynchronizedRootGroup`, `objectVersion 77`), so no `.pbxproj` resource
entries were needed; anything under `World/World/` bundles automatically, the same way the
existing `Assets/Environment/*.usdz` files do.

## Verification

-   `cd Shared && swift build` — clean; Shared is untouched by this change.
-   `git diff --check` — no whitespace errors.
-   `xcodebuild -workspace CtSPoC.xcworkspace -scheme World -destination 'platform=macOS' build`
    (with `CODE_SIGNING_ALLOWED=NO`, since this machine has no matching "Mac Development"
    certificate) — builds clean after one real fix: `FishingSounds.init`'s default parameter
    value `SoundManager()` was rejected by the compiler ("call to main actor-isolated
    initializer... in a synchronous nonisolated context") because World's target sets
    `-default-isolation=MainActor` project-wide, and default-argument expressions aren't
    automatically isolated to the enclosing type's actor. Fixed by dropping the default and
    constructing `FishingSounds(sounds: SoundManager())` explicitly in `WorldViewModel`'s stored
    property initializer, which — unlike a parameter default — runs correctly isolated as part of
    the actor's own init.
-   Confirmed all eight `.wav`/`.mp3` files landed in the built `World.app/Contents/Resources/`.
-   Launched the built `World.app` directly (`open .../World.app`) and confirmed it stays running
    with no crash and no audio-related errors in the system log for the main-menu screen, where
    the ambience loop starts immediately.
-   Not run: a full manual gameplay pass with Rod actually connected (cast/splash/bite/reel/catch/
    escape/line-break audible in sequence, loop start/stop timing feel, rapid-retrigger behavior).
    iOS-device audio behavior — the silent switch, `AVAudioSession` interruptions from phone calls
    or backgrounding — is entirely unverified and needs on-device testing.

------------------------------------------------------------------------

# ADR-039 --- Fight Difficulty Pass: Tug-of-War, Distance Escape, Tension Haptics, Fight Camera

## Decision

Five related changes making the fight harder and more dramatic, all requested together after
live play ("rasanya masih terlalu gampang dapetin ikan baik fish A, B, C, bahkan Scott"):

**Longer casts.** `WorldViewModel.castSpeed` 3.6 → 5.0 (max-power ballistic range ~13 m → ~24 m);
`FishFightController.maxExpectedCastDistance` 10 → 20 so the size-ceiling normalization keeps
spanning the real achievable range.

**Camera follows the fight.** `updateCameraFollow()` — previously flight-only — now also tracks
the hook through `.fishOnHook`/`.reeling`, so the whole tug-of-war is watched up close. Every
other phase (including `.result`) still snaps back to the player pose.

**Reel tension climbs faster — revised.** `baseReelTensionRate` 0.5 → 0.85 first, then → **0.55**
after live testing showed 0.85 made even `fish_a` (the weakest tier) nearly impossible to land
without immediately overshooting to line-break: at `reelSpeed` 1.0, `reelPull` (0.85) so far
exceeded `fish_a`'s `effectiveFishPullRate` (~0.15–0.20 depending on the roll) that tension went
from `initialTension` (0.5) to 1.0 in well under a second, regardless of species. 0.55 keeps a
real risk at full reel speed (~1.25–1.44 s to snap against `fish_a`, worked out by hand — see the
Rationale) while making moderate reeling (`reelSpeed` ~0.6) give a comfortable ~3 s window and
light reeling (~0.3) roughly neutral, so modulating reel speed is a real, learnable skill instead
of "any reeling overshoots."

**Real tug-of-war + distance escape.** `basePullSpeed` 0.4 → 1.0, and `reelHook()` now subtracts
`fishFight.fishPullSpeed` from the player's reel speed — net-negative means the fish gains line
*while the player is actively reeling*. `updateFight` gained a `hookDistance:` parameter: the
first fight tick's distance becomes a baseline, and if the fish takes more than
`escapeDistanceAllowance` (6 m) of line beyond it, the fight resolves `.escaped` (the "spooled"
failure). Weak reeling is now a losing strategy against a strong fish rather than a slow
guaranteed win.

**Escape now resets to `.idle`, not `.hookInWater`.** Both `FightFailure` cases in
`resolveFightFailure` now disable the hook and go to `.idle` (a fresh cast is required) — matches
`.lineBreak`'s existing treatment, which `.escaped` previously did not get. Requested directly:
"kalo tension kerendahan (slack), reset langsung bobber ke posisi awal (alias ga hookInWater
lagi)." A slack-tension escape and a distance-spooled escape both report as the same
`FightFailure.escaped` case, so both get this treatment — there was no clean way to give one but
not the other without threading a failure subtype through, and there's no indication only one of
the two should behave differently.

**All fight-tuning numbers extracted into `FishFightConfig` (Shared, new).** `initialTension`,
`baseFishPullRate`, `baseReelTensionRate`, `basePullSpeed`, `escapeDistanceAllowance`, the two
`tensionBand` thresholds, and all nine Rod haptic-band parameters (interval/intensity/sharpness
× low/medium/high) moved out of private constants scattered across `FishFightController` (World)
and `FishingHaptics`' `FightBand` enum (Rod) into one `Codable`/`Equatable` struct in Shared, with
every field documented inline. `FishFightController.init` and `FishingHaptics.init` both take a
`config: FishFightConfig = FishFightConfig()` parameter — existing call sites (`FishFightController()`,
`FishingHaptics()`) are unaffected, and both classes now read the *same* config instance's values
so gameplay difficulty and haptic feel can't silently drift apart from each other.
`maxExpectedCastDistance` deliberately stayed a private `FishFightController` constant, not part
of the config — it's cast physics (tied to `WorldViewModel.castSpeed`), not fight tuning.

**Tier differentiation was too weak — resistance now has its own multipliers.** Both
`effectiveFishPullRate = baseFishPullRate * (1 + resistance)` and `fishPullSpeed = basePullSpeed *
(1 + resistance * 0.5)` used an implicit multiplier of `1.0`/`0.5` on `resistance`, so
`resistance`'s contribution was smaller than (pull rate) or comparable to (pull speed) the base
term itself — every species/tier produced a similar net tension rate regardless of how tough it
was supposed to be. `FishFightConfig` gained three new fields:
`pullRateResistanceMultiplier` (3.0), `pullSpeedResistanceMultiplier` (1.8), and
`escapeAllowanceResistancePenalty` (3.5, with a `minEscapeDistanceAllowance` floor of 2.0 m so it
can never over-tighten). Formulas become:

```text
effectiveFishPullRate = baseFishPullRate * (1 + resistance * pullRateResistanceMultiplier)
fishPullSpeed         = basePullSpeed * (1 + resistance * pullSpeedResistanceMultiplier)
effectiveEscapeAllowance = max(minEscapeDistanceAllowance,
                                escapeDistanceAllowance - resistance * escapeAllowanceResistancePenalty)
```

At `resistance == 0` (any tier's smallest possible roll) all three formulas are unchanged and
identical across every species — a small individual is weak regardless of species, which is
correct and not the thing being fixed. At a max-size roll, the new multipliers produce a real
spread (worked out by hand, net tension rate at full reel speed): `fish_a` ~+0.24/s (comfortable,
~2 s to snap), `fish_b` ~+0.15/s (~3.3 s, noticeably tighter), `fish_c` ~+0.06/s (~8 s, razor-thin
margin), `scott` ~**-0.03/s** — full-speed reeling alone can no longer even hold Scott's line,
forcing genuine tension modulation rather than "hold the reel button." The escape allowance
similarly tightens from ~4.8 m (`fish_a`) down to ~2.7 m (`scott`), so a powerful fish also
punishes a slack moment harder, not just a sustained-tension mistake.

**Continuous tension haptics on Rod.** `FishingEvent` gained `reelTensionLow/Medium/High`.
`FishFightController.tensionBand` derives the band from `lineTension` (< 0.55 low, 0.55–0.8
medium, ≥ 0.8 high); `WorldViewModel.syncTensionBand()` (every tick) sends an event only on band
*transitions* — no raw-tension streaming over the reliable World→Rod path. Rod's
`FishingHaptics` stores the band and pulses continuously at band-specific rhythm/intensity
(spaced 0.5 s taps → regular 0.28 s → rapid 0.11 s), reusing the same recurring-callback pattern
as `interestPulse`. Cleared by every fight-ending event and, belt-and-suspenders, by
`stopFight()` when `hookPhase` leaves the fight phases — mirroring exactly how the interest
pulse is kept from going stale. This implements `GAMEPLAY_ARCHITECTURE_V1.md`'s
"resistance through rhythm as well as intensity" haptic spec, driven by live tension rather
than static fish size — a stronger fish reaches the higher bands faster and holds them longer,
so the rhythm still communicates the fish, but through the fight's actual state.

**Live-tested retune, much later: fish pull speed halved, player reel-pull speed raised 50%.**
Reported directly as two separate feel notes: "fish pull speed rasanya terlalu kencang. kurangi
50% di semua difficulty" (fish pull speed feels too fast, reduce 50% across all difficulty) and
"ketika reel, jarak ikan ke tariknya terlalu pelan. tingkatkan 50% juga di semua difficulty" (when
reeling, the distance the fish gets pulled in is too slow, increase 50% too across all difficulty)
— two sides of the same tug-of-war math, tuned independently since they're genuinely different
terms. `FishFightConfig.basePullSpeed` 0.7 -> **0.35**: since `fishPullSpeed = basePullSpeed * (1
+ resistance * pullSpeedResistanceMultiplier)`, halving only the base term scales the fish's pull
speed down 50% uniformly at every resistance/tier, without touching
`pullSpeedResistanceMultiplier` (which still differentiates tiers the same way, just against a
lower floor). `WorldViewModel.reelSpeed` (the player-input-to-m/s multiplier in `reelHook
(deltaTime:)`'s tug-of-war) 3.0 -> **4.5**, and its paired minimum-guaranteed floor 0.35 -> **0.525**
— both raised by the same 50% so light reeling gets the full boost too, not only full-speed
reeling. Both changes are difficulty-independent by construction (`basePullSpeed`'s scaling is
multiplicative across every resistance value; `reelSpeed`/its floor never read `resistance` at
all), so "di semua difficulty" fell out automatically from where each number lives rather than
needing separate per-tier adjustments.

**Same-day follow-up: both cut a further 25%.** Requested directly: "kurangin keduanya by 25%" —
"both" referring back to the two values just retuned above, not a reversion of either one's
direction. `basePullSpeed` `0.35` -> **`0.2625`**; `reelSpeed` `4.5` -> **`3.375`** and its paired
floor `0.525` -> **`0.39375`**. Same reasoning as the pass above applies unchanged (both scale
uniformly regardless of `resistance`), just compounded on top of the already-retuned values rather
than the original ADR-039 defaults.

**Same-day follow-up: fight-direction penalty eased, reel-in speed made tension-scaled
risk/reward.** Two related requests: "kurangin pull dari state ketika 'Fish Pulling' terjadi" and
"balance pull nya dengan cara: ketika hijau, 1 rotasi reel misalnya narik 0.5m/s, dan ketika ke
merah reel distance nya naik jadi 1m/s gitu, jadi ada reward untuk player yang berani stay di red
zone."

*Fight-direction penalty halved.* "Fish pulling" is `LineTensionView`'s own label for the
left/right juking sub-phase (ADR-053) — shown whenever `fightDirection != nil`. `FishFightConfig.
fightDirectionPenalty` (the tension/sec penalty applied while not correctly countering the fish's
current juke direction) `0.20` -> **`0.10`**. `fightDirectionCounterRelief` (the reward for
countering correctly) is unchanged — only the punishment side was eased. No explicit percentage
was given for this one; halved to match this session's own established retune magnitude, flagged
as a first guess pending live feedback.

*Reel-in speed now scales with tension, rewarding holding the danger zone.* Previously a flat
`WorldViewModel.reelSpeed` constant multiplied every reel input regardless of `lineTension`. Now
`FishFightController` gains a `reelPullSpeed` computed property: `config.reelPullSpeedSafe` (0.5
m/s per full reel input) while `lineTension` is at/below `config.reelSpeedSafeTension` (0.7 —
matches `LineTensionView`'s own `safeHigh`, the green zone's upper edge, though the two constants
aren't code-shared, just numerically aligned), linearly interpolating up to
`config.reelPullSpeedDanger` (1.0 m/s) once `lineTension` reaches `config.reelSpeedDangerTension`
(0.85 — matches `LineTensionView`'s `dangerHigh`, the near-snap red edge). `WorldViewModel.
reelHook(deltaTime:)` reads this in place of the flat constant **only while a fish is actually
hooked** — `pullSpeedPerUnit = fishFight.hasFishOnHook ? fishFight.reelPullSpeed : reelSpeed`, so
empty-line retrieves (no tension to manage) keep the old flat `reelSpeed` (3.375) unaffected. The
minimum-guaranteed floor also dropped to a flat `0.1` (from `0.39375`), since the new 0.5-1.0 m/s
range is itself much smaller than the old flat constant's 3.375 m/s ceiling — the old floor would
have dominated almost the entire new range otherwise.

**Same-day follow-up #2: 0.5/1.0 m/s was unplayably slow — retuned to 2.0/4.0 m/s.** Reported
directly, immediately after trying it: "fish reel speed nya kekecilan, the gameplay is not even
playable now. coba base nya 2 m/s instead of 0.5 - 1. dan dari 2 m/s di area green, naik jadi 4
m/s di area merah." `reelPullSpeedSafe` `0.5 -> 2.0`, `reelPullSpeedDanger` `1.0 -> 4.0` — same 2x
safe-to-danger ratio, both explicit numbers from the request. The interpolation thresholds
(`reelSpeedSafeTension`/`reelSpeedDangerTension`, 0.7/0.85) are untouched; only the two speed
endpoints moved.

## Rationale

Requested directly: "rod casting nya kurang jauh"; "ketika hook kena fish, camera langsung geser
lagi ke hook dong biar proses reel nya jadi lebih dramatis"; "kasih getaran haptics continuous
juga di hp untuk reel meter (ini yang low medium high haptics)"; "masih terlalu gampang dapetin
ikan... Bikin lebih susah lagi dengan reel meter lebih cepet naik ke high tension"; "perlu ada
juga mechanism dimana ikannya bisa escape dari reel karena kejauhan."

The tug-of-war change is what makes the distance escape meaningful: with the old code the hook
only ever moved toward the rod while reeling, so no amount of fish strength could create
distance danger during active play — the escape threshold would only ever fire while the player
stood idle, which the slack-tension timer already punishes. Subtracting pull speed from reel
speed turns distance into a live resource both sides fight over, which is also exactly what the
newly-following camera is pointed at.

The 0.85 → 0.55 correction was reported directly after playing: "kayanya reel nya terlalu susah
deh, it's even impossible untuk grab fish A tanpa tensionnya ketinggian." Worked out by hand
(`baseFishPullRate(0.15) * (1 + 0.35 * sizeRatio)` for `fish_a`'s resistance/size range,
`reelSpeed * baseReelTensionRate` for reel pull, time-to-snap = `0.5 / net` since a bite starts
at `initialTension`):

```text
                        reelSpeed=0.3   reelSpeed=0.6   reelSpeed=1.0
0.85 (first pass)       overshoots      ~0.9s to snap   ~0.7s to snap
0.55 (corrected)        ~neutral/safe   ~2.8-3.9s       ~1.25-1.44s
```

0.55 was chosen so full-speed reeling stays a real, if generous, risk rather than either
"impossible to avoid" (0.85) or "no risk at all" (something closer to the original 0.5, which is
what made the fight feel trivial before this ADR started).

The config extraction followed directly from the same conversation: "bisa ga dibikin di dalam
config file beserta docs nya, agar aku bisa tuning manual?" (can this go in a config file with
docs, so I can tune it manually?) — rather than hand this specific 0.85→0.55 correction back as
another one-off edit, every number in the same tuning space moved somewhere the player can adjust
directly without needing another round-trip through code changes. `FishFightConfig`'s own doc
comments are the primary reference while tuning; this ADR is the record of *why* the current
defaults are what they are.

Every number here — reel/pull rates, the 6 m escape allowance, band thresholds, haptic
intervals — is a first-pass, hand-reasoned default, not a play-tested one. That's the explicit
point of making them config: the player is expected to keep adjusting them directly.

The resistance-multiplier fix was reported directly, in the same message that confirmed 0.55
solved the "impossible" problem: "sepertinya udah cukup susah, namun, tingkat loncatan dari fish
A - B - C - Scott masih kerasa gaada bedanya" (seems hard enough now, but the difficulty jump
from Fish A to B to C to Scott still doesn't feel like there's a difference). Diagnosed by working
the same net-tension-rate formula used for the 0.55 correction across all four species side by
side (see the Decision section's table) — confirmed the spread was only ~35% between the weakest
and strongest tier at full reel speed, with every tier sharing an identical floor, which is
exactly a "no real difference" symptom. The fix is a config change like everything else in this
ADR, not a code restructure: three new multiplier fields, same formulas otherwise.

Status: Accepted, pending live confirmation (see the matching `CHECKPOINT.md` entry).

------------------------------------------------------------------------

# ADR-038 --- Rod Owns the Session Start/End Boundary, Not World

## Decision

**`RodState` (Shared) gains `isFishing: Bool`**, streamed continuously alongside everything else
in the existing ~30 Hz `.state` message — no new message type. Set from `RodViewModel.isFishing`
(already existed locally, gating cast/reel gesture reporting; now also transmitted) in all three
`RodState` construction sites (`publishState()`, `updateAction()`, and the `.idle`-hookPhase
reset in `handle(_:)`).

**`WorldViewModel.screen` (`.mainMenu`/`.playing`, ADR-036) is now driven by `RodState.isFishing`,
not a World-side button.** `handle(_:)` compares `state.isFishing` against the previous
`rodState.isFishing` on every incoming `.state` message: rising edge → `screen = .playing`;
falling edge → `returnToMenu()` (now `private`, and no longer gated to `hookPhase == .result` —
the player can press "End Fishing" on Rod at any point, not just after a catch, so it resets
whatever fight/hook state was in progress: hook velocity zeroed, hook entity disabled,
`fishFight.resetForNewCast()`, `hookPhase` back to `.idle`, *then* `screen = .mainMenu`).
`startGame()` (the old button handler) is deleted — nothing calls it anymore.

**Fail-safe on disconnect.** Since `screen` now depends entirely on `.state` messages continuing
to arrive, a genuine Rod disconnect mid-session would otherwise leave `screen` stuck on
`.playing` forever (no more messages ever arrive to flip it, and there's no controller left to
press "End Fishing" on). `transport.onStateChange` now also calls `returnToMenu()` on
`.disconnected`/`.failed`, not just handling `.ready`'s existing `hookPhase` resync.

**`World/World/Views/MainMenuView.swift`** loses its "Start Fishing" button entirely — it's now
purely a status display (title + a status row: spinner/text per `ConnectionState`, or once ready,
"Press \"Start Fishing\" on Rod to play"). **`World/World/Views/ResultView.swift`** loses its
"Return to Menu" button (added one task ago, in ADR-036) for the same reason: with `screen` now
reactively following `isFishing`, a World-side button forcing `screen = .mainMenu` would just get
overridden back to `.playing` by the very next `.state` message, since Rod would still think
`isFishing == true`. Only "Continue Fishing" remains.

**Rod's `ContentView.swift`**: the three-button stack (`Start Fishing` / `Calibrate` /
`End Fishing`, the latter two previously always visible, Start/End both present but
disabled/enabled oppositely) becomes one `@ViewBuilder` button that swaps its entire
label/action/style based on `isFishing` — `Start Fishing` (`.borderedProminent`, disabled until
calibration is complete) when not fishing, `End Fishing` (`.bordered`) once it is. Calibrate
moves out of that stack into a `ToolbarItem(placement: .topBarTrailing)` — the phone screen's
top-right corner — using the same `calibrationButtonTitle` computed property as before (no
duplicated logic), still disabled under the same conditions
(`!hasMotionSample || isFishing`).

## Rationale

Requested directly, with the reasoning stated up front: "instead of controller di world yang
harus press button untuk mulai mancing, ganti ke phone aja. status di world mungkin 'press
\"start\" on rod to play'. dan di rod pun bukan start fishing atau end fishing [sekaligus], tapi
start fishing, terus ketika mancing ada button end fishing buat balik ke main menu. recalibrate
jangan di tengah lagi, tapi geser ke pojok kanan atas dari rod screen" (instead of the controller
in World having to press a button to start fishing, change it to the phone. World's status
should read "press start on rod to play." And on Rod, not Start and End Fishing at once — just
Start Fishing, then once fishing, an End Fishing button to go back to the main menu. Recalibrate
shouldn't be in the middle anymore, move it to Rod's top-right corner).

This is a direct extension of `GAMEPLAY_ARCHITECTURE_V1.md`'s own core principle — "Rod is an
input device. World is the game" — to the session boundary itself, not just to gameplay input:
previously, starting/ending a fishing session was the one control still routed through World
(via `MainMenuView`'s button and, briefly, `ResultView`'s "Return to Menu"), which sat oddly
against a design where the player's attention and hands are meant to stay on the physical Rod
the entire time. Making Rod authoritative and World purely reactive removes that inconsistency —
and removing World's competing buttons wasn't optional once `screen` became reactive to
`isFishing`: keeping them would have created a button that visibly worked for one frame and then
silently reverted, which is worse than not having it.

Status: Accepted, pending live confirmation. See the matching `CHECKPOINT.md` entry.

------------------------------------------------------------------------

# ADR-037 --- Fish Tiers and a Three-Level Catch-Count Progression System

## Decision

**`FishSpecies` (Shared) gains a `tier: FishTier` field.** `FishTier` is a new enum (`.small`,
`.medium`, `.big`, `.boss`) recording which progression tier gates a species' availability —
matching `GAMEPLAY_ARCHITECTURE_V1.md`'s own "Each fish species owns static data: Species ->
Weight Range -> Length Range -> Resistance Range -> Value -> Difficulty," which already called
for a difficulty/tier-like field this model didn't have yet.

**`FishCatalog` (World) grows from one species to four**, one per tier: `fish_a` (`.small`,
unchanged), `fish_b` (`.medium`), `fish_c` (`.big`), `scott` (`.boss`). `randomSpecies()` becomes
`randomSpecies(unlockedTiers: Set<FishTier>)`, filtering the pool to only tiers the player has
unlocked (falling back to `all[0]`/`fish_a` — always unlocked — if the filtered pool is somehow
empty, so a bite can never fail to resolve a species).

**New `World/World/Gameplay/ProgressionStore.swift`**, persisted to `UserDefaults` the same way
`FishRecordStore` is. Tracks cumulative catches per tier and derives the current level:

```text
Level 1 (start):        .small catchable
-> 10 small caught  ->  Level 2: .medium also catchable
-> 10 medium caught ->  Level 3: .big AND .boss (Scott) also catchable
```

`.big`/`.boss` catches are counted too but don't unlock anything further — there's no Level 4
defined yet. `unlockedTiers` (consumed by `FishCatalog.randomSpecies(unlockedTiers:)`) and
`progressTowardNextLevel: (caught: Int, needed: Int)?` (`nil` once level 3 — nothing left to
progress toward) are both derived, not separately stored.

**`FishFightController`** takes a `ProgressionStore` the same way it already takes a
`FishRecordStore` (injectable, defaulted). Publishes `currentLevel: Int` and
`levelUpAnnouncement: String?` (player-facing text, set the instant a catch crosses a threshold,
cleared by the new `dismissLevelUpAnnouncement()`) and passes through
`progressTowardNextLevel` for the HUD. `resolve(outcome:)`'s existing `.caught` branch — already
where `recordStore.recordCatch` and star/coin calculation happen — now also calls
`progressionStore.recordCatch(tier: species.tier)` and compares the returned level against
`currentLevel` to detect the transition.

**World HUD**: the existing "Caught" `GroupBox` gains a "Level N · x/10 to next tier" row. New
`World/World/Views/LevelUpBannerView.swift` — a dismissible toast pinned to the top of the
screen (not a blocking modal, and not auto-fading, so a "Scott has appeared" moment can't be
missed by looking away at the wrong second) — shown whenever `levelUpAnnouncement` is set. It can
appear stacked above `ResultView`, since the catch that crosses a tier threshold is still a
normal catch too; the two don't gate each other.

## Rationale

Requested directly, with the exact thresholds and unlock structure specified: "Level 1: after
catch 10 small fish, u can catch more medium fish. Level 2: after catch 10 medium-sized fish, u
can catch more big fish. Level 3: muncul scott dan kayak ngasih perintah untuk nangkap dia"
(Scott appears and it's like giving an order to catch him). Species stat scaling was left
explicitly loose: "parameter fish nya nanti di ubah lagi seiring berjalannya game, yang jelas
semakin tinggi level ikan, semakin susah dari sisi berat, length, dan resistance saat
reelingnya" (fish parameters will be adjusted again as the game goes on — what's firm is that
higher tier means harder in weight, length, and reeling resistance). `fish_b`/`fish_c`/`scott`'s
weight/length/resistance/value in `FishCatalog` are accordingly rough scale-ups from `fish_a`,
not balanced numbers — placeholders satisfying "harder at every tier," explicitly expected to be
retuned later, not a claim of final balance.

`.boss` was kept as its own tier rather than folding Scott into `.big` at a higher weight,
because the player's framing of Scott ("appears and gives an order to catch him") reads as a
distinct, singular, narratively-flagged encounter — not just another random roll from the same
pool as every other big fish. Unlocking `.big` and `.boss` together at Level 3 (rather than
requiring a fourth tier/threshold) matches the player's own three-level spec exactly: three
levels were specified, not four, so Scott had to enter the pool at the same unlock as `.big`
rather than gating him further out.

Because `resolve(outcome:)` already owned the one place a successful catch is processed
(star/coin/record-keeping), wiring progression in alongside it — rather than as a separate
tracked step — keeps the "a catch has consequences" logic in one place instead of splitting it
across two call sites that would need to stay in sync.

Status: Accepted, pending live confirmation. See the matching `CHECKPOINT.md` entry for what's
verified (typecheck only) versus not yet played.

------------------------------------------------------------------------

# ADR-036 --- World Main Menu, Persisting the Scene Across Menu/Play Transitions

## Decision

`WorldViewModel` gains a `Screen` enum (`.mainMenu`, `.playing`) and a `@Published private(set)
var screen`, defaulting to `.mainMenu`. Two new methods gate the transition in both directions:

```text
startGame()    — Main Menu's "Start Fishing" button. No-ops unless connectionState is
                 .ready or .streaming: "the player cannot continue until the controller
                 is available" (GAMEPLAY_ARCHITECTURE_V1.md's Connect step).
returnToMenu() — Result screen's new "Return to Menu" button (alongside the existing
                 "Continue Fishing"). Guarded to hookPhase == .result, same as
                 continueFishing(); also resolves hookPhase back to .idle.
```

**`ContentView`'s RealityKit scene (`content`) is never conditionally mounted/unmounted on
`screen`.** It stays alive for the whole app session; `MainMenuView` and `ResultView` are
overlays drawn on top of it in the same `ZStack`, shown or hidden based on `viewModel.screen`/
`hookPhase`. `content`'s existing `.onAppear { viewModel.start() }` is unchanged and still fires
immediately when `ContentView` first appears — the transport connection begins in the background
while the Main Menu is on screen, so by the time the player presses "Start Fishing" the
connection is often already `.ready`, and the (expensive, USDZ-asset-heavy) environment/rod rig
never needs to reload just because the player returned to the menu and started again.

New `World/World/Views/MainMenuView.swift`: title, subtitle, a "Start Fishing" button disabled
until `connectionState` is `.ready`/`.streaming`, and a status row (spinner + text, or a
checkmark once connected) reflecting every other `ConnectionState` case. Solid black background,
not a translucent overlay — the player shouldn't see gameplay rendering through a title screen.

`ResultView` gains a second closure, `onReturnToMenu: () -> Void`, and a second button beneath
"Continue Fishing." `Return to Menu` does **not** disconnect Rod — the transport connection is
left running, consistent with `content` never being torn down.

## Rationale

Requested directly, immediately after wrapping up the CoreBluetooth transport migration: "gausah
commit sih, maybe sekarang saat yang tepat buat implement main menu dulu sesuai v1" (no need to
commit — maybe now's the right time to implement the Main Menu, per V1). This closes a gap
flagged repeatedly since ADR-029/the Result Screen sprint: `ResultView`'s doc comment and two
prior `SOFTWARE_ARCHITECTURE_DOCUMENT.md`/`CHECKPOINT.md` entries all noted "Return to Menu" was
skipped specifically because "there is no Main Menu yet to return to" — this ADR is what makes
that button meaningful rather than adding it in isolation.

Keeping `content` permanently mounted (menu/result as overlays, not a screen replacement) was a
deliberate choice over the more literal reading of "Main Menu screen" as its own fully separate
view hierarchy: `EnvironmentSceneBuilder.build()` loads and places on the order of 200 scattered
USDZ instances (per its own scatter-instance table) plus the dock/water/terrain/rod-rig assets —
re-running that on every menu round-trip during a single play session would be a real, avoidable
cost and a jarring reload for something conceptually as simple as "look at the menu again."

Status: Accepted, pending live confirmation. Not yet run on device/simulator — verified via
`swiftc -typecheck` only (see the matching `CHECKPOINT.md` entry). In particular, whether
`content`'s `RealityView` genuinely avoids re-creating the scene across a menu round-trip (rather
than SwiftUI treating the `ZStack` reordering as a reason to rebuild anyway) has not been
observed live, only reasoned about from `RealityView`'s documented `make`-once-per-identity
behavior.

------------------------------------------------------------------------

# ADR-035 --- Transport Replaced: MultipeerConnectivity to CoreBluetooth

## Decision

`Rod/Rod/Transport/TransportClient.swift` and `World/World/Transport/TransportHost.swift` are
fully rewritten on CoreBluetooth. No `import MultipeerConnectivity` remains anywhere in either
target. `TransportProtocol` (Shared) and `NetworkMessage` (Shared) are unchanged in shape —
this is an internal swap of what implements the protocol, not a redesign of who calls it.

**Roles**, matching the previous client/host split (Rod is the side that actively broadcasts
itself; World reacts to whichever peer shows up):

- **Rod = BLE peripheral** (`CBPeripheralManager`). Advertises one custom GATT service and three
  characteristics, all defined as plain UUID strings in `SessionConfiguration` (Shared) so both
  sides share the same identifiers without Shared importing CoreBluetooth:
  - `bleStateCharacteristicUUID` — Rod → World, **notify**, unreliable. Carries the ~30 Hz
    `RodState` stream.
  - `bleReliableOutCharacteristicUUID` — Rod → World, **indicate**, reliable. Carries
    `.discoveryToken`.
  - `bleCommandCharacteristicUUID` — World → Rod, **write-with-response**, reliable. Carries
    `.fishingEvent`/`.hookPhase`. (World writing into a characteristic Rod exposes is the only
    way a BLE central can push data to a peripheral — there is no "central notifies" primitive.)
- **World = BLE central** (`CBCentralManager`). Scans for the service, connects, subscribes to
  the two Rod → World characteristics, writes to the command characteristic.

**Message-flow inventory** (confirmed by grepping actual `.send(`/`case` call sites in
`RodViewModel.swift`/`WorldViewModel.swift` before writing any replacement code, per this
migration's own instructions — not assumed from memory): Rod sends `.state` and
`.discoveryToken`; World sends `.hookPhase` and `.fishingEvent`; World's `handle(_:)` only acts
on `.state`, ignoring everything else it receives (unchanged).

**Payload framing (`Shared/Sources/Shared/Protocols/BLEFraming.swift`, new).** A JSON-encoded
`NetworkMessage` may exceed one BLE packet once the ATT MTU is accounted for. `BLEFraming`
prefixes a payload with a 4-byte big-endian length header and splits it into MTU-sized chunks;
`BLEMessageReassembler` accumulates chunks fed from repeated delivery callbacks and yields
complete messages once enough bytes have arrived. Pure `Data` manipulation, no CoreBluetooth
import, so it's usable from both Rod's and World's transport layers without Shared taking on a
platform dependency. Verified correct via a standalone roundtrip test (single-chunk, multi-chunk,
sequential messages through one reassembler, empty payload, and coalesced multi-message delivery
— all pass) before being wired into either transport file.

**The unreliable (`.state`) path never fragments.** If an encoded state sample doesn't fit in one
packet, it's dropped outright rather than risking a desynced multi-chunk stream on a channel with
no delivery guarantee — a fresher sample is always ~33 ms away, matching the semantics
`NetworkMessage.requiresReliableDelivery`'s doc comment already documents for this path. The two
reliable paths (indicate/write-with-response) may fragment safely, since both have CoreBluetooth's
own per-packet acknowledgment: indicate via `updateValue` returning `false` until
`peripheralManagerIsReady(toUpdateSubscribers:)` fires, write-with-response via
`didWriteValueFor`/`error` per chunk. Both reliable sends are queued (FIFO, one logical message's
chunks fully drained before the next starts) so overlapping calls — e.g. two `.fishingEvent`s
sent close together — can't interleave and corrupt each other's chunk sequence.

**`@MainActor` on both transport classes and on `TransportProtocol` itself.** Both CoreBluetooth
managers are constructed with `queue: nil` (main queue), so every delegate callback already lands
on the main queue in practice; isolating the classes (and the protocol they conform to) to
`@MainActor` — matching `RodViewModel`/`WorldViewModel`, the only two callers — makes that
explicit and lets the mutable send-queue state be touched from both delegate callbacks and direct
`send()` calls without a separate lock, instead of leaving a real (if currently benign) data race
implicit. CoreBluetooth's delegate protocols are Objective-C and carry no such isolation of their
own; the conformances use `@preconcurrency` (the standard bridge for implementing an unisolated
ObjC delegate protocol from an actor-isolated Swift type), avoiding warnings that are hard errors
under Swift 6.

**Reconnection**: both sides keep trying continuously rather than requiring the caller to retry.
Rod leaves advertising running after a central unsubscribes (never stops it outside
`disconnect()`); World restarts scanning after any disconnect/failed-connect while still "wanting"
a connection. This matches the previous MPC behavior of leaving the browser/advertiser active
continuously once `connect()` was called.

**Platform entitlements.** `Info.plist` (`Rod`/`World`): removed `NSBonjourServices`. Both
targets' `project.pbxproj`: `INFOPLIST_KEY_NSLocalNetworkUsageDescription` replaced with
`INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`. World specifically: `ENABLE_RESOURCE_ACCESS_
BLUETOOTH` flipped `NO` → `YES` — World runs sandboxed on macOS (`ENABLE_APP_SANDBOX = YES`), and
this build setting is the sandbox entitlement gate for CoreBluetooth; leaving it `NO` would have
silently blocked the central role at the OS level regardless of any code-level correctness. Also
tightened `ENABLE_INCOMING_NETWORK_CONNECTIONS`/`ENABLE_OUTGOING_NETWORK_CONNECTIONS` to `NO` —
grepped confirmed World has no other networking (`URLSession`/`Network.framework`), so these
existed only for MPC's local-network transport and are no longer needed.

## Rationale

Per the supplied migration brief (`MIGRATION_transport_to_corebluetooth.md`, not committed to the
repo, provided as a task document): a known MultipeerConnectivity bug on iOS 26 makes connection
pairing flaky specifically when Bluetooth is involved in establishing the connection — exactly
the Bluetooth-heavy, no-Wi-Fi-infrastructure scenario this project targets (fishing outdoors).
Apple's own migration guidance recommends moving off MPC's `NSStream`-dependent transport, and
CoreBluetooth's GATT notify/write model is a closer fit for this payload shape (small, frequent
messages at ~30 Hz) than MPC's general-purpose session/stream abstraction was.

Explicitly a **full replacement**, not a hybrid — the brief was clear that no MultipeerConnectivity
import should remain when this is done, confirmed by grep.

Status: Accepted, pending live-hardware verification (see the "Explicitly not yet verified"
section of the matching `CHECKPOINT.md` entry — this ADR records the design and code-level
verification that's actually complete; the migration brief's own test plan requires a Step 0/Step
1 baseline-vs-CoreBluetooth latency comparison on real devices with Wi-Fi off, which has not been
run).

------------------------------------------------------------------------

# ADR-034 --- Cast Direction Clamped to a Forward Cone, Bobber Doubled in Size

## Decision

`WorldViewModel.launchHook(solution:)` now clamps its computed horizontal
launch heading into a fixed cone around the camera's forward direction,
regardless of what upstream aim derivation (ADR-033's live rig-geometry
vector, or any future replacement) produces:

```text
corrected = rotatedAroundY(rawHorizontal, by: aimCorrectionAngle)
angle = atan2(corrected.x, -corrected.z)          // signed angle from -Z (straight ahead)
clamped = clamp(angle, -castConeHalfAngle, castConeHalfAngle)
horizontal = (sin(clamped), 0, -cos(clamped))
```

`castConeHalfAngle = 67.5°` (135° total cone width). The camera's forward
is a compile-time constant here, not a live basis vector — `makePlayerCamera()`
builds a static camera that never rotates dynamically (see its own
doc comment), so `(0, 0, -1)` is always correct without needing to read
camera state at cast time.

**`aimCorrectionAngle` (180°, revised from an initial 90° guess after
live-measuring the true raw angle).** ADR-033's rig-geometry-derived
aim, once actually cast on device, consistently put the bobber to the
*left* of the player's POV — a fixed rotational bias, not per-cast
noise — and cast distance dropped sharply from what it had been before
the cone clamp landed. A first 90° correction (below) turned out to be
a guess from the symptom alone, not a measurement, and the resulting
clamped landing coordinate gave no way to tell how far off the true
angle actually was — landing at the cone's boundary looks identical
whether the real angle is barely past it or wildly off. A debug-only
pair of unclamped angle readouts (`debugRawAimDegrees`/
`debugCorrectedAimDegrees`, `WorldViewModel`) exposed the real number:
raw aim measured at **-174°** — not a quarter-turn off, but almost
exactly **opposite** of forward. The tip-minus-root vector in
`launchHook(solution:)` points nearly straight backward when the player
casts forward; correcting for a near-180° inversion is a materially
different fix than nudging a 90° axis mismatch. `rotatedAroundY(_:by:)`
(a simple Y-axis rotation: `(x cosθ - z sinθ, y, x sinθ + z cosθ)`)
rotates the raw aim by `aimCorrectionAngle` — positive angles rotate
right, matching `clampedToForwardCone`'s own sign convention — *before*
the cone clamp, so the corrected heading lands inside the cone as
intended instead of constantly pinned at its edge. The measured -174°
leaves a small ~6° residual against an exact 180° correction, left
unaddressed pending the next live reading.

The hook (`World/World/ViewModels/WorldViewModel.swift`'s `makeSceneEntity()`)
also doubled in size: `.generateSphere(radius: 0.035)` → `radius: 0.07`.

## Rationale

Requested directly, immediately after ADR-033's fix: "gue masih gatau
direction si yellow bobber ini kemana, tapi yang jelas ga sesuai sama
apa yang gue mau. Bisa ga dibikin semacam limitation area jadi mau
kemanapun cast, cuma bisa ke arah depan, sekitar 135 derajat di depan
pov kamera?" (I still don't know where this yellow bobber's direction is
going, but it's clearly not what I want. Can you make a limitation area
so no matter where the cast goes, it can only go forward, about 135
degrees in front of the camera POV?) — plus, separately, "gedein juga
ukuran bobbernya by 2x" (also double the bobber's size).

This is a deliberate belt-and-suspenders addition on top of ADR-033
rather than a further attempt to prove the raw aim direction "correct":
the player's own framing ("I still don't know where it's going") calls
for a guaranteed bound on the outcome, independent of whether the
underlying rig-geometry derivation has some remaining, not-yet-
understood issue. A hard clamp to a forward-biased cone guarantees the
acceptance-criteria-relevant behavior (cast never lands behind or far to
the side of the player) even if the precise heading within that cone is
still being tuned. Doubling the bobber's visible size was requested
purely to make it easier to actually see and judge where it lands during
testing — not a gameplay-balance change.

`aimCorrectionAngle` followed from live testing with the camera-follow
debug aid: "ok kayanya ketemu masalahnya. bobbernya selalu loncat ke
kiri dari pov orang, dan cast distance nya jadi kecil banget dibanding
sebelumnya yang bisa jauh. Apa mungkin kalo kalo di define 'depan' itu
sekitar 90 derajat ke kanan dari titik cast sekarang bisa?" (I think I
found the problem. The bobber always jumps to the left of the player's
POV, and the cast distance became very small compared to before, when it
could go far. Could "forward" be redefined as about 90 degrees to the
right of the current cast point?) — a specific, testable correction
proposed directly from the reported symptom, implemented as stated. 90°
was a starting point derived from what was observed, not measured.

Live-testing that 90° value showed the landing coordinate pinned almost
exactly at the cone's -67.5° boundary — "Player facing: (0.00, -12.47),
Cast landed: (-11.52, -4.77). kan jauh" (that's really far apart) —
which could mean anything from "barely past the cone edge" to "wildly
off," since a clamp collapses both to the same result. Rather than keep
guessing against a masked number, added the unclamped
`debugRawAimDegrees`/`debugCorrectedAimDegrees` debug readout so the
next cast would report the true angle directly. It read "Raw Aim Angle:
-174.0°, Corrected Aim Angle: -84.0°" (consistent with the 90°
correction: -174 + 90 = -84, confirming the math itself was working
correctly against the wrong constant) — revealing the true raw bias is
close to a full 180° inversion, not 90°. `aimCorrectionAngle` updated to
`.pi` (180°) accordingly; the next live test's debug readout will show
whether the ~6° residual (from -174° rather than exactly -180°) needs
its own follow-up tuning.

Status: Accepted

------------------------------------------------------------------------

# ADR-033 --- Cast Direction Derived From Live Rig Geometry, Not a Mesh-Tuned Constant

## Decision

`WorldViewModel.launchHook(solution:)` no longer reinterprets
`CastSolution.direction`'s `x`/`z` as a World-space horizontal launch
heading. Instead it derives the heading live, at the exact moment of
launch, from the actual rendered rig:

```text
aim = tipEntity.position(relativeTo: nil) - controllerEntity.position
horizontal = normalize(aim.x, 0, aim.z)   // falls back to (0, 0, -1) if near-zero
```

`solution.power`, `solution.launchAngle`, and `solution.distance` are
unaffected and still come from `CastSolution` as before — only the
horizontal heading component changed. `CastResolver`/`CastSnapshot`/
`CastVector3.forward` in Shared are untouched.

## Rationale

Reported directly, with a screenshot: casting with the rod visually
aimed straight out over the pier consistently landed the hook off to the
side, near the shoreline — "casting nya masih ke kanan kiri dari pier."
Root cause: `CastResolver.resolve(_:)` computes `direction` by rotating
a hardcoded `CastVector3.forward = (0, 0, -1)` by the corrected
orientation — a constant that was only ever correct for the *old*
placeholder arrow mesh (`World/World/ContentView.swift`'s pre-asset-
integration `makeArrow()`), whose tip sat along local -Z
(`tip.position = [0, 0, -0.76]`). The asset-integration merge swapped in
`rod_main.usdz` via `RodRigController`, whose entire bone chain
(`Root/Handle/Rod_01/Rod_02/Rod_03/Tip`) rests along local **+Y**
instead (every `BoneWeight.restTranslation` in `RodRigController.
rodBones` is `[0, Y, 0]`) — a rod modeled held upright, tip up, not
tip-forward. Nobody updated the hardcoded `-Z` convention when the mesh
changed, so `solution.direction` pointed wherever local -Z ended up
after rotation — a fixed, consistent offset from wherever the rig's
actual +Y-rooted tip visually swung to. This matches the reported
pattern exactly: a *consistent* rotational drift, not per-cast noise.

Per ADR-018/019 and this bug's own architecture note, `Shared` must stay
mesh-agnostic — it has no knowledge of World's rendered rig at all, so
`CastVector3.forward` cannot be "fixed" by pointing it at whatever axis
happens to match the current mesh (that just moves the same fragility to
a different constant, and breaks again on the next rig swap). The fix
belongs in World, which is the only module that knows the rig's actual
geometry: deriving the heading from `tipEntity.position(relativeTo: nil)
- controllerEntity.position` at cast time is correct by construction — it
always matches wherever the rendered tip is actually pointing, regardless
of any particular rig's internal rest-pose axis convention, and needs no
maintenance if the rig is swapped again. `controllerEntity` (the fixed-
offset `RodRoot`, per ADR-019) itself is never moved by this — only the
hook's launch trajectory is computed from it.

Status: Accepted

------------------------------------------------------------------------

# ADR-032 --- Cast Power Weighted by Backswing Distance, Not Flick Speed Alone

## Decision

Cast power — both `RodMotionInterpreter`'s live `castPower` (the charging
meter) and, more importantly, `CastResolver.resolve(_:)`'s `CastSolution.
power` (the value that actually drives `WorldViewModel.launchHook`'s hook
velocity) — previously came from instantaneous rotation-rate magnitude
alone: a single sample of angular velocity, taken once at the exact frame
release was detected. How far back the player pulled the phone during
the backswing was never measured or used.

**`RodMotionInterpreter`** now tracks `backswingPeakDistance: Double`,
the peak of `distance(current, profile.idlePose)` (the same wrapped
pitch/roll/yaw distance metric already used for idle/cast/reel pose
classification) reached since the current cast gesture began. It resets
to `0` whenever classification freshly enters `.cast`
(`previousClassification != .cast`) and otherwise only grows
(`max(backswingPeakDistance, distances.idle)`) every frame the gesture
stays in `.cast`, so it captures the deepest point of the backswing
regardless of when it happened relative to the release.

**`CastSnapshot`** (Shared, `CastResolver.swift`) gained a
`backswingDistance: Float` field, populated from `backswingPeakDistance`
at the moment `RodMotionInterpreter` builds the release snapshot. It is
Rod-internal only — never transmitted over `NetworkMessage`, consumed
solely by `RodViewModel`'s local `castResolver.resolve(snapshot)` call.

**`CastConfig`** gained `minimumBackswingDistance`/
`maximumBackswingDistance` (radians, default `0.12`/`1.0`), the
normalization bounds for `backswingDistance`, mirroring the existing
`minimumCastVelocity`/`maximumCastVelocity` bounds for flick speed.

**Both `RodMotionInterpreter`'s live `castPower` and `CastResolver.
resolve(_:)`'s final `power`** now use the same blend:

```text
distancePower = clamp01((backswingDistance - minBackswing) / (maxBackswing - minBackswing))
flickPower    = clamp01((angularSpeed - minVelocity) / (maxVelocity - minVelocity))
power = distancePower * (0.7 + 0.3 * flickPower)
```

Backswing distance sets the base — zero backswing means zero power no
matter how fast the flick — and release-moment flick speed adds up to a
30% bonus on top. `RodMotionInterpreter`'s live meter uses a local,
uncalibrated approximation of the same shape (`rotationRateMagnitude / 5`
for the flick term, matching its pre-existing simplification) so the
on-screen charging meter tracks what the eventual release will actually
produce; `CastResolver` is the authoritative, `CastConfig`-driven
calculation that becomes the transmitted `CastSolution.power`.

## Rationale

Requested directly: "doesn't matter kalo aku narik ke belakang sejauh
apapun, dia cuma nge register ketika iphone nya aku 'flick' dengan cepat,
sementara target aku kan biar iphone nya ngitung seberapa kuat cast itu
dari jarak yang dia tempuh sampai flick" (it doesn't matter how far back
I pull, it only registers when I flick the phone fast — my goal is for
the phone to compute cast strength from the distance it traveled up to
the flick). The player also asked directly whether this was a hardware
limitation from mixing flick and reel detection on one device; it isn't
— casting and reeling are already disambiguated by proximity to separate
calibrated poses (`profile.castPose`/`profile.reelPose`) before rotation
rate is ever read, and CoreMotion already provides continuous orientation
suitable for measuring displacement across a gesture, not just an
instantaneous sample at release. The actual gap was a design/logic one:
`castPower`'s only input was `rotationRateMagnitude`, sampled once at the
release frame, and `CastResolver.resolve(_:)` — the function that
produces the `CastSolution.power` actually consumed by `WorldViewModel.
launchHook`, entirely separate from `RodMotionInterpreter`'s own
`castPower` field — made the identical mistake with `snapshot.
angularVelocity.length`. Fixing only the live meter (`RodMotionInterpreter`)
would have made the on-screen number feel right while leaving actual hook
physics governed by flick speed alone; both had to change together.
A multiplicative blend (distance as the gate, flick as a bonus) was
chosen over a flat average so a good, deliberate pull-back reliably
produces a real cast regardless of how the release itself was flicked,
mirroring how a real rod loads on the backswing and releases on the
forward snap — closer to the player's own framing of the goal than a
pure distance-only formula would have been, while still rewarding a
crisp release.

This is a first pass explicitly requested to "see how it feels" — the
`0.12`/`1.0` backswing-distance bounds and the `0.7`/`0.3` blend weights
are hand-picked, not calibrated per-player or measured on-device, and are
expected to need retuning once played.

Status: Accepted

------------------------------------------------------------------------

# ADR-031 --- Cast Distance, Fight Distance, and Search-Phase Reel State Fixes

## Decision

Four related fixes to the cast/bite pipeline:

**Real measured cast distance.** `WorldViewModel` now tracks
`castLaunchPosition` (the hook's tip position at `launchHook(solution:)`)
and, when the hook splashes in `simulateFlyingHook(deltaTime:)`, computes
the horizontal distance actually traveled
(`simd_distance` between launch and splash `xz` position) and passes it to
`FishFightController.resetForNewCast(castDistance:)` — replacing the
previous no-argument call. This is the *actual* physics-simulated
distance, not `CastSolution.distance` (Rod's meter-config estimate shown
during charging, still unwired to launch physics and left as-is for that
preview use). `FishFightController` publishes it back as
`lastCastDistance: Float`, shown in `ContentView`'s Controller State grid
as "Last Cast Distance."

**Cast distance caps rollable fish size.** `FishFightController` gained
`sizeCeilingRatio: Float` (`0.3 + 0.7 * clamp01(currentCastDistance /
maxExpectedCastDistance)`, `maxExpectedCastDistance = 10.0`, an estimate
from the launch physics at full charge/level release) and
`biasedRoll(in:ceilingRatio:)`, a static helper that rolls a
`FishSpeciesRange` value capped at `range.min + span * ceilingRatio`
instead of the full range. `updateSearching(deltaTime:)`'s bite branch now
rolls `currentWeight`/`currentLength` through this instead of
`FishSpeciesRange.randomValue()`'s uniform roll. A short cast can still
land a small-to-modest fish (the 0.3 floor); only a cast near
`maxExpectedCastDistance` can roll near the species' max. Because
`sizeRatio`/`resistance` (ADR-030) already derive from
`currentWeight`/`currentLength`, a far cast landing a big fish is
automatically also a tougher fight — no separate wiring needed.

**Guaranteed minimum fight distance on bite.** `FishFightController`
gained `minimumFightDistance: Float = 0.4` (hook-to-rod meters).
`WorldViewModel.ensureFightDistance()`, called right after
`setHookPhase(.fishOnHook)` in the `.bite` branch of `tick()`'s
`.hookInWater` case, pushes the hook entity outward along the existing
rod-to-hook axis to at least this distance if it's already closer.

**Search-phase reeling no longer fakes a hooked fish.** `reelHook
(deltaTime:)`'s unconditional trailing `setHookPhase(.reeling)` is now
`if fishFight.hasFishOnHook { setHookPhase(.reeling) }`. Reeling in
during `.hookInWater` before any bite now moves the hook and, if it
reaches the rod, resolves the existing empty-retrieve path
(`hookEntity.isEnabled = false`, `setHookPhase(.idle)`) — but no longer
sets `hookPhase` to `.reeling` along the way, so `hookPhase` stays
`.hookInWater` for the entire retrieve unless a fish actually bites.

## Rationale

**Distance gating fish size** was requested directly: "semakin jauh
casting, harusnya semakin gede ikan yang bisa ditangkap. juga, distance
belum ke reflect" (the farther you cast, the bigger the fish that should
be catchable; also, distance isn't reflected anywhere yet). Two problems
existed together: `CastSolution.distance` (the value Rod's cast meter
computes and displays) was never actually consumed by
`launchHook(solution:)` — hook speed came from `power` alone — so no
"distance" concept was wired to anything, gameplay or otherwise; and fish
weight/length rolled uniformly across each species' full range regardless
of how the cast that hooked it went. Measuring the real simulated flight
distance (rather than trying to retrofit the disconnected meter estimate)
and using it to cap the roll ceiling fixes both: a value now exists,
is shown, and has a gameplay consequence.

**The minimum fight distance** fixes a reported bug: "ketika hook inwater
tapi udah aku reel duluan, ketika fishonhook, meteran line tension ga
muncul" (when the hook is in water but I already started reeling first,
the tension meter doesn't appear once it becomes fishOnHook). Root cause:
`tick()`'s `.hookInWater` case still calls `reelHook(deltaTime:)` in the
same tick a bite just occurred (the `switch hookPhase` at the top of
`tick()` captured `.hookInWater` before `setHookPhase(.fishOnHook)` ran,
so the case body keeps executing). If the player had already been
reeling in during the search phase, the hook could already be within
`reelHook`'s catch-distance threshold (`0.12`) the instant the bite
landed — `reelHook` would then resolve the catch in that same tick,
flipping `fishFight.hasFishOnHook` `true` then `false` before SwiftUI
ever rendered a frame with it `true`. `LineTensionView` is gated on
`hasFishOnHook`, so it never appeared. Pushing the hook back out to a
guaranteed minimum distance the instant a bite lands (mirroring
`initialTension`'s existing "buffer" idea from ADR-028) guarantees a real,
visible fight instead of an instant, invisible catch.

**Search-phase reeling** fixes a second, related bug reported right after
the fight-distance fix above: "ketika hook InWater terus langsung aku
reel, status nya berubah ke fishInHook, seharusnya engga kan. Kalo
reflect mancing dunia nyata, kita bisa reel sampai batas tertentu sebelum
hook nya diangkat dari air" (when the hook is InWater and I immediately
reel, the status changes to fishOnHook — it shouldn't. To reflect real
fishing, we should be able to reel up to a point before the hook is
lifted from the water). Root cause: `reelHook(deltaTime:)` set
`hookPhase` to `.reeling` on every step that moved the hook, with no
check for whether a fish was actually attached — so reeling during
`.hookInWater` (an intentional, pre-existing "empty retrieve" action)
left `hookPhase == .reeling` the moment the player stopped reeling.
`tick()`'s `case .fishOnHook, .reeling:` branch assumes reaching it means
a fish is hooked, and its not-reeling `else` branch unconditionally calls
`setHookPhase(.fishOnHook)` — so the very next tick after releasing the
reel gesture (with no bite ever having happened) flipped `hookPhase` to
`.fishOnHook`. Gating the `.reeling` transition on `hasFishOnHook`
restores that invariant: `.reeling`/`.fishOnHook` are now only ever
reached with a real fish attached, and reeling in an empty line behaves
exactly like the real-world retrieve the player described — the hook
approaches the rod and, once close enough, comes out of the water
(`.idle`), with no phase change in between. As a side effect this also
fixes a related haptic glitch: `RodViewModel.handle(_:)` stops the fish-
interested haptic pulse whenever `hookPhase != .hookInWater`, so the
same bug was prematurely killing that pulse the instant a player reeled
during search, even if no bite had happened yet.

Status: Accepted

------------------------------------------------------------------------

# ADR-030 --- Resistance Scales With Rolled Size, Not Just Species

## Decision

`FishSpecies.resistance` is now a per-species *ceiling*, not the value
used directly in the fight. `FishFightController` computes a private
`sizeRatio: Float` (0...1) from where this catch's rolled
`currentWeight * currentLength` falls between the species' min and max
weight*length product:

```text
minProduct = species.weightRange.min * species.lengthRange.min
maxProduct = species.weightRange.max * species.lengthRange.max
sizeRatio = clamp01((currentWeight * currentLength - minProduct)
                     / (maxProduct - minProduct))

resistance = species.resistance * sizeRatio
```

`resistance` still feeds `effectiveFishPullRate` and `fishPullSpeed`
exactly as ADR-026/028 defined; only how `resistance` itself is derived
changed. `FishSpecies.resistance` and `FishCatalog` are unaffected — no
data model or catalog change was needed, since this is purely a
fight-controller computation over the already-existing weight/length
ranges.

## Rationale

Requested directly: two different rolls of the same species (a puny
`Fish A` and a near-max `Fish A`) fought identically, because
`resistance` read `currentSpecies?.resistance` straight off the species
regardless of which weight/length this particular catch happened to roll
— "tension belom corespond dengan fish weight ... seharusnya, semakin
fish weight * length mendekati angka max, maka nilai resistance juga
mengikuti" (tension doesn't yet correspond to fish weight — as the fish's
weight*length approaches the max, resistance should follow). Scaling by
`sizeRatio` makes big individual catches within a species meaningfully
harder to land than small ones of the same species, matching the
weight/length roll players already see reflected in the result screen's
star rating (`FishFightController.stars(forWeight:in:)`), which used the
same weight-proximity idea for scoring but never fed it back into the
fight itself.

Status: Accepted

------------------------------------------------------------------------

# ADR-029 --- Result Screen, Rod's Minimal V1 Interface, Fish Interest

## Decision

This sprint closes three of the gaps identified against
`GAMEPLAY_ARCHITECTURE_V1.md`: no result screen, Rod still showing its full
debug UI as the primary experience, and no "Fish Interested" phase before
a bite. All three are additive to the existing `HookPhase`/
`FishFightController`/`FishingEvent` contracts from ADR-023/026/028; none
of those contracts changed shape, only grew one case each.

### Result Screen

`HookPhase` gains `.result`: entered only when `reelHook()` closes the
distance to the rod with a fish attached (`resolveCatch()`), instead of
going straight to `.idle`. `.result` is deliberately excluded from both
`allowsCasting` and `allowsReeling`, so a physical cast gesture cannot race
the result screen off the rod display before the player has seen it — this
is why the state has to live in `HookPhase` (shared, network-synced)
rather than as World-local UI state. `WorldViewModel.continueFishing()` is
the only way out, called by World's new `ResultView` "Continue Fishing"
button; it guards `hookPhase == .result` and returns to `.idle`.

Escape and line-break do **not** enter `.result` — they keep their prior
direct transitions (`.hookInWater` / `.idle`) from ADR-028. This is a
deliberate, narrower reading of `GAMEPLAY_ARCHITECTURE_V1.md`'s "Catch or
Escape -> Result" loop diagram: the doc's detailed result content (name,
weight, length, stars, coins, new-record) is explicitly scoped to "After a
successful catch" in prose, and gating every escape/line-break behind a
modal the player must dismiss would make repeated near-misses tedious in a
loop that currently has no cooldown between bites. The existing inline
"Catch Results" HUD row already surfaces escape/line-break outcomes
without blocking play.

`FishCatchResult` gains `stars: Int`, `coins: Int`, `isNewRecord: Bool`
(all `0`/`false` for non-`.caught` outcomes), computed in
`FishFightController.resolve(outcome:)` only when `outcome == .caught`:

```text
stars = 1 + round(4 * (weight - species.weightRange.min) / species.weightRange.span)   // 1...5
coins = round(species.value * (0.6 + 0.1 * stars))
```

New `World/World/Gameplay/FishRecordStore.swift` persists the heaviest
catch per species ID to `UserDefaults` (`[String: Double]`, JSON-encoded —
same pattern as `RodViewModel`'s `MotionProfile` persistence).
`recordCatch(speciesID:weight:)` returns whether this catch beat the
stored best, which becomes `isNewRecord`. New `World/World/Views/
ResultView.swift` renders the card (species, weight, length, star row,
coins, optional "NEW RECORD" badge, "Continue Fishing" button) as a
full-screen overlay in `ContentView` when `hookPhase == .result`.
"Return to Menu" from the doc's copy is intentionally not implemented —
there is no Main Menu yet to return to, and a non-functional button would
be worse than an absent one.

### Rod's Minimal V1 Interface

`Rod/Rod/ContentView.swift` is rewritten so the primary view matches
`GAMEPLAY_ARCHITECTURE_V1.md`'s Rod interface exactly: title, connection
status, and three buttons (`Start Fishing`, the existing per-step
calibration button relabeled inline, `End Fishing`). All prior debug rows
(connection/spatial/motion status, calibration step/sample count, raw
pitch/roll/yaw/action/reelSpeed/etc.) move into a `DisclosureGroup`
labeled "Developer Details", collapsed by default, instead of being
deleted — matching this repo's existing precedent of keeping development
tooling available but demoted (e.g. the commented-out `MotionDebugView`
section) rather than removing it.

`RodViewModel` gains `isFishing: Bool` (`@Published private(set)`) and
`startFishing()`/`endFishing()`. `startFishing()` only takes effect once
`calibrationStep == .complete`. `updateAction()`'s existing
`hookPhase.allowsCasting`/`allowsReeling` gate gains a third condition
ahead of both: `!isFishing` forces `action = .idle` regardless of motion.
Before this, cast/reel gestures were always live the moment calibration
finished; now the player must explicitly start (and can explicitly end) a
session, giving the doc's three buttons real functional meaning rather
than only "Calibrate" doing anything.

**Known gap, not addressed this sprint:** `GAMEPLAY_ARCHITECTURE_V1.md`
also states "Calibration instructions appear entirely in World. Rod only
captures..." Rod's `calibrationInstruction` text (unchanged from before
this sprint) still lives on Rod, not World. This is pre-existing, not
introduced here, and is tracked as part of the still-open "World Main
Menu + Tutorial + Calibration instructions" gap.

**Closed by ADR-064**, several windows later: `RodState.calibrationStep` now transmits live so
World can render its own calibration guidance (`CalibrationGuidanceView`) directly, alongside a
new onboarding flow covering the rest of the still-open "Tutorial" half of this gap. Rod's own
`calibrationInstruction` text was left in place rather than removed (see ADR-064's own rationale)
— this paragraph is kept as an accurate record of the gap as it stood at the time.

### Fish Interested

`GAMEPLAY_ARCHITECTURE_V1.md`: "A nearby fish becomes interested but has
not bitten. World shows subtle movement and Rod provides slow periodic
vibration." This does not need its own `HookPhase` — reeling is already
allowed throughout `.hookInWater` regardless of interest, so it is
presentation-only state inside the existing search phase.

`FishFightController.updateSearching(deltaTime:)` now returns
`SearchEvent? { .interested, .bite }` instead of `Bool`, driven by two
sequential timers instead of one: `interestTimer` (`0.8...2.0s`) then,
once interested, `biteTimer` (`0.8...2.0s`) — replacing the single
`1.5...4.0s` `biteTimer` from ADR-023, so total time-to-bite stays in
roughly the same range. `isFishInterested: Bool` (`@Published`) is exposed
for a future World visual cue (not added this sprint — fish still have no
visual representation). `FishingEvent` gains `.fishInterested`, sent once
by `WorldViewModel` when `updateSearching` returns `.interested`.

Rod's periodic vibration is a new pattern:
`FishingHaptics.interestPulse(now:)` (throttled to `1.1s`, mirroring
`reelTick(reelSpeed:now:)`'s existing throttle idiom) is a no-op unless an
internal `isFishInterested` flag is set, which `handle(.fishInterested)`
sets and every other `FishingEvent` case (plus
`RodViewModel.handle(.hookPhase:)` whenever the phase leaves
`.hookInWater`, via the new `stopInterest()`) clears — so a stale interest
signal can't keep pulsing after the fish bites, escapes, or a new cast
begins. `RodViewModel.updateAction()` calls `interestPulse()`
unconditionally every motion sample, the same recurring callback that
already drives `reelTick`. `HapticManager.fishInterested()` is a single
soft transient (`0.22`/`0.15`), deliberately duller than `fishBite()`'s
four-pulse pattern.

## Rationale

Each of these three gaps was explicitly named as missing against the
product doc in the prior gap analysis; developing them together was
requested directly ("develop points 1-3 this sprint"). They compose
without touching each other's mechanics: the result screen only changes
what happens after a catch resolves, the Rod UI change only changes
whether a resolved motion action is allowed to leave the device, and fish
interest only changes what happens before a bite — none required changing
the tension/fight simulation from ADR-028.

Status: Accepted

------------------------------------------------------------------------

# ADR-028 --- Unified Tension Safe Zone Replaces the Duration Timer

## Decision

ADR-027's duration-only tension formula is replaced, one task later, by the
single tension-with-safe-zone mechanic `GAMEPLAY_ARCHITECTURE_V1.md`
already specified: "the player keeps tension in a safe zone... sustained
tension too high or too low causes the fish to escape." Two problems
prompted this: `lineTension` froze while the player wasn't reeling instead
of reflecting anything happening in the fight, and the *separate*
`biteExpireTimer`/`updateWaiting` mechanic (ADR-024) that actually caused
escapes was a flat countdown fully disconnected from hook/rod distance —
contradicting the player's (correct) expectation that a hooked fish should
visibly fight by pulling the hook away.

`FishFightController` now has one continuous update path,
`updateFight(deltaTime:isReeling:reelSpeed:)`, called every tick while
`hasFishOnHook` (both `.fishOnHook` and `.reeling` `HookPhase`s):

```text
reelPull = isReeling ? reelSpeed * baseReelTensionRate(0.5) : 0
lineTension += (reelPull - effectiveFishPullRate) * deltaTime
effectiveFishPullRate = baseFishPullRate(0.15) * (1 + resistance)

lineTension <= 0  -> FightFailure.escaped   (line went slack)
lineTension >= 1  -> FightFailure.lineBreak (reeled too hard)
```

A bite starts `lineTension` at `initialTension` (0.5), not 0, giving the
player room to react in either direction. `updateWaiting`, `pauseFight`,
`biteExpireTimer`, `baseBiteExpireDuration`, and ADR-027's
`updateFighting(deltaTime:)`/`baseMaxFightDuration` are all removed —
tension alone now governs both failure modes.

**The fish now physically pulls the hook.** `FishFightController` exposes
`fishPullSpeed: Float` (m/s, species-scaled, zero when no fish is hooked)
so `WorldViewModel` can move the hook entity itself — `FishFightController`
still has no RealityKit/entity knowledge, it only publishes a speed.
`WorldViewModel.driftHookAway(deltaTime:)` moves the hook away from the rod
along the existing rod-to-hook axis (the same vector `reelHook(deltaTime:)`
already used, just reversed) whenever a fish is hooked and the player isn't
reeling. Reeling still moves the hook toward the rod via the existing
`reelHook(deltaTime:)`/distance-to-catch logic, unchanged. The result is an
actual tug-of-war: not reeling lets the fish visibly drag the hook away
(and drains tension); reeling pulls it back (and, if sustained too hard,
raises tension toward a snap).

`WorldViewModel.tick(deltaTime:)` merges the `.fishOnHook` and `.reeling`
`HookPhase` switch cases into one block, since both now run the same
reel-or-drift-plus-tension-update logic and differ only in which the
player is currently doing. `resolveFightFailure(_:)` reacts to
`FishFightController.FightFailure` (`.escaped` -> `HookPhase.hookInWater`,
keep fishing; `.lineBreak` -> hook disabled, `HookPhase.idle`, recast
required), mirroring the event-sending shape `reelHook`'s catch path
already had.

`LineTensionView` now shades a visible safe zone (`0.3...0.7`) on the bar
and shows a `"LOSING FISH"` warning below `0.15` alongside the existing
`"SNAPPING"` above `0.85`, instead of a single-direction green-to-red ramp
that only made sense for a one-way failure mode.

## Rationale

Requested directly after the player noticed the tension bar never reset
while idle and the fish escaped on a flat ~2.5s timer with no connection to
the hook visibly getting away — "setau aku ikan nya bisa ngelawan dengan
ngejauhin lagi distance si hook nya relatif ke rod" (as far as I know the
fish should be able to fight back by pulling the hook's distance from the
rod farther away). Re-reading `GAMEPLAY_ARCHITECTURE_V1.md`'s own line
tension description confirmed the safe-zone design was the intended V1
mechanic all along; ADR-023/024/026/027 had incrementally built two
separate, simpler mechanisms (a flat escape timer, then a one-directional
duration-based snap timer) instead. Collapsing them into the one
mechanism the product doc already specifies removes both problems at once
and gives the fish a real, visible presence in the fight rather than an
invisible clock.

Status: Accepted

------------------------------------------------------------------------

# ADR-027 --- Line Tension Tracks Fight Duration, Not Reel Speed

## Decision

`FishFightController.updateFighting(deltaTime:)` no longer takes a
`reelSpeed` parameter or compares it to a per-species safe threshold.
`lineTension` now accumulates purely from elapsed time spent actively
reeling a hooked fish:

```text
lineTension += deltaTime / effectiveMaxFightDuration
effectiveMaxFightDuration = max(2.0, baseMaxFightDuration(6.0) * (1 - resistance * 0.5))
```

Tension only advances while `WorldViewModel` is calling `updateFighting`,
i.e. while `HookPhase == .reeling` and the player is actively reeling; it
is untouched (frozen, not decayed) whenever reeling pauses, since the call
site simply stops calling it (`pauseFight()` still resets the separate
`biteExpireTimer` for the escape clock). There is no decay branch anymore.
The three former constants (`baseSafeReelSpeed`, `baseTensionRiseRate`,
`tensionDecayRate`) and their `effective*` computed properties were
removed; `effectiveMaxFightDuration` is the only new one, still scaled by
species `resistance` (stronger fish give less total fight time before the
line snaps).

This amends ADR-026's tension formula only. ADR-026's `FishSpecies`/
`FishCatalog` data model, the `FishFightController` extraction, and the
HUD (`LineTensionView`, catch results) are all unaffected — `lineTension`
is still a `@Published 0...1 Float` and `WorldViewModel`'s call site
still reacts to `updateFighting`'s bool return the same way.

## Rationale

Requested directly: the meter should reflect how long the player has been
reeling, not how fast — "kalo user kelamaan nge reel, otomatis reel
meternya bisa max dan line putus" (if the player reels for too long, the
meter maxes out on its own and the line breaks). A duration budget per
fight is simpler to read from the bar (it always climbs while you're
reeling, so the bar's rate of climb answers "how much time do I have
left") and simpler to reason about than a speed-conditioned accumulate/
decay rule, while still giving stronger fish a shorter, harder fight via
the same `resistance` modifier introduced in ADR-026.

Status: Superseded by ADR-028, one task later — the duration-only formula
this ADR introduced didn't address the player's actual request (a real
safe-zone mechanic where the fish fights back via hook distance), so it
was replaced rather than further amended. Left below for history.

------------------------------------------------------------------------

# ADR-026 --- FishSpecies Data Model and Continuous Line Tension

## Decision

Two related changes replace ADR-024's binary line-break timer with a real
tension meter and separate fish data from fight logic:

**`FishSpecies` (Shared).** Added
`Shared/Sources/Shared/Models/FishSpecies.swift`: a `Codable` data-only
struct (`id`, `name`, `weightRange`, `lengthRange`, `resistance` 0...1,
`value`) plus `FishSpeciesRange` (a `Codable` replacement for `ClosedRange`,
which does not synthesize `Codable`). It carries no mesh, asset name, or
RealityKit reference — Shared still never imports rendering frameworks. The
World-owned content list (`World/World/Gameplay/FishCatalog.swift`, one
entry today: `"fish_a"`) is where species are defined and tuned; asset
wiring is deferred until 3D fish assets exist.

**Continuous line tension.** `FishFightController` (new,
`World/World/Gameplay/FishFightController.swift`, an `ObservableObject`)
replaces the boolean `lineStrainTimer`/threshold/sustain-duration mechanic
with a `lineTension: Float` (0...1) that rises while reeling above a
per-species "safe" reel speed and decays otherwise, breaking the line at
1.0. `biteTimer`/`hasFishOnHook`/`biteExpireTimer`/catch bookkeeping also
moved out of `WorldViewModel` into this controller, which
`WorldViewModel.tick(deltaTime:)` now drives through a small explicit
interface (`updateSearching`, `updateWaiting`, `pauseFight`,
`updateFighting`, `resolveCatch`, `resetForNewCast`); `WorldViewModel`
still owns `HookPhase` transitions and sending `FishingEvent` over
transport, since fight state itself has no transport or hook-entity
knowledge. `WorldViewModel` also gained `caughtCount` and
`lastCatchResult: FishCatchResult?` (`World/World/Gameplay/
FishCatchResult.swift`) for HUD display.

Species `resistance` now scales three constants: bite grace period
(`effectiveBiteExpireDuration`), the safe reel speed before tension rises
(`effectiveSafeReelSpeed`), and the tension rise rate
(`effectiveTensionRiseRate`) — a stronger fish gives less reaction time and
snaps the line faster under strain.

**World HUD additions.** `World/World/Views/LineTensionView.swift` renders
`fishFight.lineTension` as a green/yellow/red 0...1 bar, visible whenever
`fishFight.hasFishOnHook`. `ContentView` adds a "Catch Results" section
showing `fishFight.caughtCount` and the last resolved outcome (species
name, weight, length, caught/escaped/line-broke). `ContentView` now
observes `WorldViewModel.fishFight` directly as a second `@ObservedObject`
(constructed in `init()` from the same instance `WorldViewModel` owns), so
its `@Published` fight state drives the HUD independently of
`WorldViewModel`'s own `@Published` properties.

## Rationale

A binary "sustained fast reel for N seconds" rule cannot be shown to the
player as a meaningful 0...1 bar — it is just off or (after N seconds) on.
A continuously accumulating/decaying value is both a more honest fishing-
game mechanic and the only thing a tension bar can actually visualize.
Moving fish/fight state into `FishFightController` was necessary before
adding it: `WorldViewModel` was already at the file-size guideline in
`AGENTS.md` after ADR-023/024, and fish bite/escape/tension/catch
bookkeeping is a cohesive unit of behavior that does not need
`WorldViewModel`'s transport, hook-entity, or `HookPhase` internals to
operate — it only needs `deltaTime` and `reelSpeed` in, and yes/no
transition signals out. Splitting `FishSpecies` (data) from `FishCatalog`
(World-owned content) from `FishFightController` (simulation) from
`FishCatchResult` (HUD projection) keeps each piece swappable
independently — the stated reason for the split is that fish will soon get
real assets and more species, and the data model must not assume a
particular mesh or rendering approach.

Status: Accepted

------------------------------------------------------------------------

# ADR-024 --- Escape Timer and Reel-Speed Line Break

## Decision

Building on ADR-023's `fishOnHook` state, World now implements minimal line
tension without a full tension bar, using two independent timers owned by
`WorldViewModel`:

-   `biteExpireTimer` counts down while `.fishOnHook` and the player is not
    reeling. On expiry the fish escapes: `hasFishOnHook` clears,
    `HookPhase` returns to `.hookInWater` (a fresh `biteTimer` starts, so the
    hook keeps fishing rather than forcing a recast), and
    `FishingEvent.fishEscaped` sends. Pausing mid-fight resets this timer
    to `biteExpireDuration` (2.5s) rather than continuing to drain it, so a
    deliberate pause and an unaddressed bite are treated the same way.
-   `lineStrainTimer` accumulates only while actively reeling with
    `hasFishOnHook == true` and `RodState.reelSpeed` at or above
    `lineBreakReelThreshold` (0.9). Sustaining that for
    `lineBreakSustainDuration` (1.2s) snaps the line: the hook disables,
    `hasFishOnHook` clears, `HookPhase` returns to `.idle` (the line is
    gone; a new cast is required), and `FishingEvent.lineBreak` sends.
    Dropping below the threshold at any point resets the timer to zero.

`FishingEvent.fishEscaped` and `.lineBreak` were previously defined and
already handled by `Rod/Rod/Haptics/FishingHaptics.swift`, but World never
sent either one before this change. `HapticManager` gained a distinct
`fishEscaped()` pattern (a fading three-pulse taper) instead of aliasing to
the sharp single-transient `lineBreak()` pattern, so the two failure modes
feel different to the player.

## Rationale

A real tension bar (per `GAMEPLAY_ARCHITECTURE_V1.md`) needs UI, a
resistance-per-species model, and a sustained safe-zone mechanic that is out
of scope for this task. Two independent timers give the same core pressure
—react to a bite in time, then don't reel too aggressively—without any of
that. Making pausing reset the escape timer (rather than a monotonic clock
since the bite) keeps the rule simple: the fish is only lost through
inaction, never through unlucky timing across a reel/pause boundary.

Status: Superseded by ADR-028. Both timers this ADR introduced
(`biteExpireTimer` and `lineStrainTimer`) were replaced by the unified
tension safe zone — the "sustained safe-zone mechanic" explicitly called
out above as out of scope for this task turned out to be exactly what the
product doc already specified and what the player expected. Left below for
history.

------------------------------------------------------------------------

# ADR-025 --- Reel Speed Scales Continuously With Rotation Rate

## Decision

`RodMotionInterpreter`'s `.reel` classification previously computed
`reelSpeed` as
`min(1, input.rotationRateMagnitude / max(profile.reelRotationRate, 1))`.
Because `profile.reelRotationRate` (the calibrated minimum reel-detection
threshold, `max(0.2, averageRate * 0.45)`) is almost always well under 1.0,
the `max(_, 1)` floor made the denominator effectively constant at `1`, and
real device rotation rates during an actual reeling motion routinely exceed
1 rad/s. `reelSpeed` therefore saturated to `1.0` almost immediately after
crossing the detection threshold, reading as binary 0/1 rather than a
dynamic value.

`MotionProfile` gains `reelFullRotationRate`, captured during reel
calibration in `RodViewModel.calibrateMotion()` as
`max(reelRotationRate + 0.3, peakRate)`, where `peakRate` is the maximum
rotation rate magnitude observed across the player's demonstrated reel
samples (previously only the average was used). `reelSpeed` is now a linear
ramp between the two calibrated references:

```text
speed = clamp((rotationRateMagnitude - reelRotationRate)
              / (reelFullRotationRate - reelRotationRate), 0...1)
```

`reelRotationRate` remains 0 speed (the minimum motion still recognized as
reeling); `reelFullRotationRate` (the player's own demonstrated peak) is
1.0. Spinning faster than that still clamps at 1.0; spinning at the
threshold reads near 0. `MotionProfile` is Codable and persisted to
`UserDefaults`; `RodViewModel.loadMotionProfile()` already discards
undecodable stored profiles with `try?`, so profiles saved before this
change safely fall back to requiring recalibration rather than crashing.

## Rationale

The player-reported symptom was reel speed reading constant at 1.000 or
0.000 instead of tracking how fast they physically spin the controller.
The fix keeps the existing per-player calibration model (Rod owns sensing
and motion interpretation per `AGENTS.md`) but uses the player's own
demonstrated range as both ends of the scale, instead of an arbitrary
floor that happened to make the scale collapse for most real rotation
rates.

Status: Accepted

------------------------------------------------------------------------

# ADR-001 --- World/Rod Separation

## Decision

Split the application into two independent apps.

-   World (macOS)
-   Rod (iPhone)

## Rationale

The renderer and the controller have different responsibilities.

Benefits:

-   Easier testing
-   Independent deployment
-   Cleaner architecture
-   Reusable controller

Status: Accepted

------------------------------------------------------------------------

# ADR-022 --- Fish Spawn Ownership (Fish A)

## Decision

Fish spawning is a World-only concern with no Shared or Rod involvement.
`World/World/Gameplay/FishManager.swift` owns a single fish entity's spawn,
despawn, and idle swim motion. It is instantiated and driven by
`WorldViewModel`, keeping `WorldViewModel` itself under the ViewModel file
size guideline.

Fish A spawns when `HookPhase` transitions from `.flying` to `.hookInWater`
and despawns when the phase returns to `.idle`. It has no interest, bite, or
fight behavior yet; it only exists and swims in a slow idle loop near a
randomized point in the water. Fish selection, species data, resistance, and
the searching/interested/bite state machine described in
`GAMEPLAY_ARCHITECTURE_V1.md` remain unimplemented and are deferred to a
future task.

The fish body uses a non-uniformly scaled sphere primitive, matching the
existing primitive-mesh approach used for the rod arrow and hook (no capsule
mesh primitive is available on this RealityKit SDK, and no fish asset exists
yet).

## Rationale

Keeping fish spawn logic in a dedicated manager preserves `WorldViewModel`'s
role as a coordinator rather than a growing gameplay implementation, and
keeps the fish system isolated so future searching/interest/bite/fight work
can extend `FishManager` without touching hook or controller logic.

Status: Superseded by ADR-023. Direction changed the same day: no visual
fish entity for now, in favor of getting the `HookPhase` state machine
itself to reflect a real fish grab first. `FishManager.swift` was removed.

------------------------------------------------------------------------

# ADR-023 --- Hook Phase Reflects a Real Fish Grab, No Visual Fish Yet

## Decision

Before any fish is rendered in World, `HookPhase` (Shared) must accurately
represent whether a fish is actually attached to the hook, so that gameplay
state and Rod haptics are truthful rather than cosmetic. This reverses
ADR-022's visual-first approach.

`HookPhase` gains a `fishOnHook` case between `hookInWater` and `reeling`:

```text
idle -> flying -> hookInWater -> fishOnHook -> reeling -> idle
                (searching)      (bite)       (fight)   (catch)
```

`WorldViewModel` tracks the attachment as private simulation state, not as
part of `HookPhase` itself:

-   `biteTimer` counts down while `hookInWater` (searching). On expiry,
    `hasFishOnHook` becomes `true`, the phase moves to `.fishOnHook`, and
    `FishingEvent.fishBite` is sent — the first real use of that existing
    but previously unsent event.
-   Reeling is allowed from `hookInWater` (retrieve an empty hook, no event)
    or from `fishOnHook`/`reeling` (retrieve a hooked fish).
-   When the hook reaches the rod, `FishingEvent.catchFish` is sent only if
    `hasFishOnHook` was true — also a first real use of an existing,
    previously unsent event.
-   `biteTimer` and `hasFishOnHook` reset on every new splash
    (`simulateFlyingHook`), so each cast gets an independent chance to hook
    a fish.

No fish entity, mesh, or RealityKit visual exists yet. No searching/interest
distinction, line tension, or escape logic exists yet — a bite always
succeeds if reeled in. Those remain future work per
`GAMEPLAY_ARCHITECTURE_V1.md`.

## Rationale

The gameplay loop and Rod haptics (`FishingHaptics.handle(_:)` already
switches on every `FishingEvent` case, including `fishBite` and
`catchFish`) were built against events that World never actually sent.
Rendering a fish in the scene before the underlying state machine reflects
a real bite/catch would make the visual a lie layered on top of a
non-functional loop. Fixing `HookPhase`/`FishingEvent` truthfulness first
means any future visual or haptic work has a correct state machine to
attach to.

Status: Accepted

------------------------------------------------------------------------

# ADR-020 --- Rod as Controller, World as Game

## Decision

Catch the Scott is a two-device experience with a strict product boundary:
Rod is a physical input device and World is the complete game. World owns
menus, tutorials, calibration instructions, HUD, hook/fish simulation,
results, and progression. Rod owns motion, calibration capture, cast/reel
intent, buttons, connection status, and haptic output.

No gameplay information may be rendered on Rod in V1. World is the sole owner
of gameplay state and player-facing feedback. Rod receives only the input
commands and typed feedback events required to operate the physical
controller.

## Rationale

Keeping the iPhone visually quiet preserves the intended illusion that the
player is holding a fishing rod rather than using a second game screen. It
also prevents gameplay rules, fish state, and presentation logic from being
duplicated across devices.

Status: Accepted

------------------------------------------------------------------------

# ADR-017 --- Cast Resolver Boundary

## Decision

Cast motion is captured once as an immutable `CastSnapshot` containing the
corrected orientation, angular velocity vector, and timestamp. `CastResolver`
converts that snapshot into a `CastSolution` containing normalized power,
horizontal direction, and launch angle.

The motion interpreter detects the release but does not perform gameplay
balancing. World/gameplay consumes the solution and never reads CoreMotion.

## Rationale

Separating motion interpretation from gameplay translation allows cast power,
distance, arc, VFX, audio, and haptics to be balanced without changing the
controller sensor pipeline.

Status: Accepted

------------------------------------------------------------------------

# ADR-002 --- Shared Swift Package

## Decision

All shared models and protocols live inside the Shared Swift Package.

## Rationale

Avoid code duplication.

World and Rod communicate using identical models.

Status: Accepted

------------------------------------------------------------------------

# ADR-003 --- RodState is the Single Source of Truth

## Decision

All controller information is represented by one model.

``` swift
RodState
```

Gameplay and rendering consume RodState only.

No duplicate motion state may exist.

Status: Accepted

------------------------------------------------------------------------

# ADR-004 --- Separation of Motion and Spatial Data

## Decision

CoreMotion and Nearby Interaction remain independent.

Motion:

-   Pitch
-   Roll
-   Yaw

Spatial:

-   Distance
-   Direction

RodState combines both domains.

Status: Accepted

------------------------------------------------------------------------

# ADR-005 --- RealityKit Exists Only in World

## Decision

RealityKit rendering belongs exclusively to World.

Rod never renders the simulation.

## Rationale

Rod is a physical controller.

Status: Accepted

------------------------------------------------------------------------

# ADR-006 --- Rod Never Depends on Reality

Rod must never import:

-   RealityKit
-   ARKit

Its responsibility is sensing and input.

Status: Accepted

------------------------------------------------------------------------

# ADR-007 --- Shared Must Be Platform Independent

Shared may import:

-   Foundation

Shared must not import:

-   SwiftUI
-   RealityKit
-   CoreMotion
-   NearbyInteraction
-   CoreHaptics
-   UIKit
-   AppKit

Status: Accepted

------------------------------------------------------------------------

# ADR-008 --- MVVM

Use MVVM throughout the project.

Views remain passive.

Business logic belongs in ViewModels and Managers.

Status: Accepted

------------------------------------------------------------------------

# ADR-009 --- Composition Over Inheritance

Prefer composition and protocols.

Avoid deep inheritance hierarchies.

Status: Accepted

------------------------------------------------------------------------

# ADR-010 --- Incremental Delivery

Implementation proceeds sprint-by-sprint.

Each sprint must:

-   Build
-   Run
-   Be testable

No sprint may depend on unfinished work.

Status: Accepted

------------------------------------------------------------------------

# ADR-011 --- Gameplay Deferred

Fishing mechanics are intentionally postponed.

Priority:

1.  Spatial session
2.  Motion
3.  Synchronization
4.  Reality visualization
5.  Gesture recognition
6.  Gameplay

Status: Accepted

------------------------------------------------------------------------

# ADR-012 --- Apple-First APIs

Use the latest stable Apple SDKs.

Prefer:

-   Nearby Interaction
-   RealityKit
-   CoreMotion
-   CoreHaptics
-   Swift Concurrency

Avoid deprecated APIs in new implementations.

Status: Accepted

------------------------------------------------------------------------

# ADR-013 --- Loose Coupling

World and Rod communicate only through shared contracts.

------------------------------------------------------------------------

# ADR-014 --- Nearby Interaction Ownership

## Decision

Rod owns the Nearby Interaction session. World receives the resulting spatial
state through `RodState` over the shared transport contract.

## Rationale

The current macOS SDK marks `NISession` and its peer configuration APIs as
unavailable on macOS. Keeping the NI implementation on Rod preserves the
physical-controller model while allowing World to run as a native macOS app.

No project may import the other project.

Status: Accepted. Ownership as described here is still correct — Rod still runs the session
exactly this way. See ADR-041: the resulting spatial state is not currently read by any gameplay
or rendering code, only by debug display; this ADR's ownership rule is unaffected either way.

------------------------------------------------------------------------

# ADR-021 --- Debug First

Every subsystem should expose observable debug information before
gameplay is implemented.

Examples:

-   Session state
-   Distance
-   Direction
-   Pitch
-   Roll
-   Yaw
-   Update frequency

Status: Accepted

------------------------------------------------------------------------

# ADR-015 --- Reusable Spatial Controller

The long-term objective is not a fishing game.

The objective is a reusable spatial controller framework capable of
supporting multiple interaction paradigms such as:

-   Fishing rod
-   Tennis racket
-   Baseball bat
-   Golf club
-   Sword
-   Other spatial interaction experiences

Fishing is the first consumer of the framework.

Status: Accepted

------------------------------------------------------------------------

# Change Policy

Any modification to these decisions should:

1.  Explain why the existing decision is insufficient.
2.  Describe the proposed alternative.
3.  Document trade-offs.
4.  Be approved before implementation.

Architectural consistency takes priority over short-term implementation
convenience.

------------------------------------------------------------------------

# ADR-019 --- Controller Root and Hook Simulation Separation

## Decision

World keeps `RodRoot` at a fixed camera-relative offset and applies only
`RodState.orientation` to its orientation. Cast direction, power, and distance
are consumed exclusively by hook launch and simulation. Reeling updates the
hook position and never repositions the rod root.

## Rationale

The controller is the player's hand representation, while the hook is the
gameplay projectile. Coupling the rod root to cast distance caused the rod to
move forward during casting and snap back after reeling. Separate entity
ownership keeps the controller attached to the player and makes future fishing
line rendering independent of controller movement.

Status: Accepted

------------------------------------------------------------------------

# ADR-018 --- Gesture Charging and Transform Separation

## Decision

The Rod/Shared motion layer owns gesture phases (`Idle`, `Backswing`,
`Charging`, `Forward Swing`, `Release`, and `Follow Through`) and publishes
live normalized `castPower` in `RodState`. A release is resolved once into a
persistent `CastSolution`; World consumes that solution for hook physics and
HUD presentation.

Rod spatial state and cast gameplay state are separate contracts. Nearby
Interaction distance/direction control the rod root. Cast direction, power,
and distance control only the hook trajectory and cast HUD. World must not
reconstruct cast values from raw motion or use cast distance to move the rod.

## Rationale

Mixing cast output into the rod transform made the controller visibly translate
when a cast was released. Keeping the rod root spatial and the hook dynamic
preserves stable controller rendering while allowing the cast to travel.

Status: Accepted

------------------------------------------------------------------------

# ADR-016 --- Calibration-Owned Orientation

## Decision

Calibration belongs to the Rod/Shared motion pipeline. The calibration layer
captures and persists an Idle reference quaternion, applies its inverse to each
current device orientation, and publishes the corrected orientation in
`RodState.orientation`.

World consumes that orientation as-is. World does not know whether a
calibration reference exists and does not apply offsets or reconstruct the
calibrated orientation from Euler angles.

Gameplay-relative pose may be derived separately from corrected motion, but it
must not become the renderer's orientation source.

## Rationale

Using relative Euler values for both gameplay and rendering caused the rod to
appear to snap when calibration ended. A normalized quaternion contract keeps
the visual pipeline stable and makes the ownership boundary explicit.

Status: Accepted

------------------------------------------------------------------------

# ADR-058 --- World Explicitly Authors the First-Person Camera

## Decision

`RealityView` in non-AR ("virtual") mode has no ARKit device camera to fall
back on and provides no default first-person viewpoint of its own. World
must always create and add an explicit `PerspectiveCamera` entity to the
scene, and set `content.camera = .virtual` in the `RealityView` closure.

## Rationale

Without an explicit camera entity, RealityKit auto-frames the scene's
bounding box from an arbitrary vantage point instead of the intended
first-person view. This previously shipped as a bug: the player appeared to
stand underwater looking up at the dock's underside.

The camera's position/orientation must be derived from the asset repo's own
authored viewpoint (the Blender `player_pov` camera), converted through the
verified Blender-Z-up-to-RealityKit-Y-up axis mapping
(`(x, y, z) -> (x, z, -y)`), not guessed. See `CHECKPOINT.md` ("Asset-
Integration Environment, First-Person Camera, and Rod Motion Fixes") for the
empirical derivation.

Status: Accepted

------------------------------------------------------------------------

# ADR-059 --- Transport Delivery Mode Matches Message Freshness, Not a Blanket Default

## Decision

`NetworkMessage` declares `requiresReliableDelivery` per case. Continuous,
high-frequency telemetry (`state`, the streamed `RodState`) sends unreliable:
a stale sample is worthless once superseded, so retransmitting a dropped one
only adds latency for every real sample queued behind it. Discrete, one-shot
signals (`discoveryToken`, `fishingEvent`, `hookPhase`) stay reliable, since
losing one of those silently breaks game state rather than just aging out.
Both `TransportHost` and `TransportClient` read this flag to pick
`MCSessionSendDataMode` instead of hardcoding `.reliable` for every send.

## Rationale

MultipeerConnectivity's `.reliable` mode is TCP-like: ordered and
retransmitted. Sending the entire live motion stream this way meant any
single dropped packet under real Wi-Fi/Bluetooth conditions caused
head-of-line blocking — every subsequent, already-stale sample queued behind
the retransmit — which read directly as controller/rod lag independent of
frame rate or rendering. See `CHECKPOINT.md` ("Controller lag fix, FPS debug
indicator, and a stuck-error/casting investigation") for the full
investigation and the two other contributing causes found alongside this one.

Status: Accepted
