# divedave-ios

The SpriteKit iOS build of divedave, with a bundled iMessage extension for sending challenge bubbles to friends.

## Stack

- SpriteKit + GameplayKit
- Swift 5.9
- iOS 15.0 deployment target, iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- Xcode project at `divedave.xcodeproj` (no SPM/CocoaPods/Carthage)
- No audio. Haptics via `Util/Haptics.swift`.

## Build & run

Open `divedave.xcodeproj` in Xcode, pick a scheme, and run on a simulator or device:

- `divedave iOS` — the main app.
- `divedave Messages` — the bundled iMessage extension. Builds the main app too and embeds the extension. Run it on a simulator and the Messages app opens with the extension available in the app drawer.

There is no CI or Fastlane setup in-repo.

## Project layout

```
divedave-ios/
  divedave.xcodeproj/     Xcode project (two targets)
  divedave iOS/           main app glue (AppDelegate, GameViewController, launch storyboard)
  divedave Shared/        the game itself (scenes, components, util, assets); compiled into both targets
  divedave Messages/      iMessage extension target (MessagesViewController, Info.plist, Messages App Icon)
  tools/                  one-shot Xcode-project helpers (e.g. wire-messages-target.rb)
  build/                  xcodebuild derived output, not source
```

Both `divedave iOS` and `divedave Messages` compile every file under `divedave Shared/` (multi-target membership), so the extension runs the real `DiveScene` rather than a copy.

`build/` is xcodebuild output and should not be committed.

## Key files

### App glue (`divedave iOS/`)
- `AppDelegate.swift` — stock `UIApplicationDelegate`, no custom lifecycle logic.
- `GameViewController.swift` — preps `Haptics`, seeds `GameState.metrics` from the view bounds, preloads textures, and presents `MainMenuScene`.

### Scenes (`divedave Shared/Scenes/`)
- `LoadingScene.swift` — initial splash.
- `MainMenuScene.swift` — title screen, mode select, info panels.
- `DiveScene.swift` — gameplay scene: physics world, scoring, HUD, atmosphere, camera, water/splash.

### Scene components (`divedave Shared/Components/Scene/`)
- `DavePlayer.swift` — player state machine (`grounded`/`launching`/`airborne`/`diving`/`splashed`), boost-window timing, sprite animation.
- `DiveScorer.swift` — pure scoring from goal rotations, actual rotations, angle, and tuck count; also `goalHalfFlips` (dive height → number of flips the goal may ask for). Shared, parity-tested with the web build.
- `RotationTracker.swift` — accumulates rotations and tracks tuck count from angular state each frame.
- `CameraController.swift` — vertical follow camera clamped to scene bounds, with screen shake.
- `Atmosphere.swift` — declarative layer system for clouds, birds, planes, UFOs (static, drift, or animated).
- `BoardContact.swift` — springboard contact handling.
- `AnimatedSprite.swift` — sprite-sheet helper used across the game.

### Controls / menu (`divedave Shared/Components/`)
- `Controls/HUD.swift` — on-screen buttons (left/right/jump/flip/menu) and the score/streak/high-score labels.
- `Controls/ControlButton.swift` — touchable button node.
- `Menu/MenuButton.swift`, `Menu/InfoPanel.swift` — main-menu widgets.

### Util (`divedave Shared/Util/`)
- `Constants.swift` — `Game` enum with gravity, speeds, spin limits, drag, cloud/bird counts, etc. Single source of tuning numbers. Top block is shared with the web `Constants.js`; the parity harness watches it.
- `GameState.swift` — singleton holding metrics, mode, streak, total score, current `DiveStats`, `highScore` (persisted to `UserDefaults`), and `duelSeed` (non-nil when the dive is being driven by an iMessage challenge).
- `SceneMetrics.swift` — view-bounds-derived sizing (`width`, `height`, scale factors).
- `Haptics.swift` — `UIImpactFeedbackGenerator` wrapper.
- `StatsStore.swift` — persistent stats.
- `Utilities.swift` — misc helpers.
- `SeededRandom.swift` — deterministic RNG (FNV-1a-of-seed → SplitMix64). Used by duel mode so two devices roll the same dive from the same seed.
- `ChallengeState.swift` — `Codable` payload that travels through `MSMessage.url` (seed, board height, goal rotations, challenger + responder). `ChallengeStateCodec` handles base64url encode/decode and seed minting.

## iMessage extension (`divedave Messages/`)

A bundled extension that lets two friends play the same seeded dive and compare scores in-bubble. Single App Store listing — installing the main app installs the extension too.

- `MessagesViewController.swift` — `MSMessagesAppViewController` subclass. Reads the incoming `MSMessage`, hosts the `DiveScene` in expanded mode, builds the outgoing message. Scene creation is deferred to `viewDidLayoutSubviews` so it runs against the *expanded* view bounds rather than the stale compact ones.
- `Assets.xcassets/iMessage App Icon.stickersiconset/` — generated from the main app icon by letterboxing the square onto a sky-blue 4:3 background.
- `Info.plist` — extension principal class wiring.
- `Base.lproj/MainInterface.storyboard` — Xcode-template storyboard (unused; the controller programmatically owns its view).

How a round works:

1. Compact bubble offers "Tap to challenge a friend".
2. Tap → extension expands, `GameState.shared.duelSeed` is set, the dive runs once with `DiveScene.duelParams(seed:)` driving the board height and goal rotations from the seed (so both players get the same dive).
3. `DiveScene.onDuelComplete` fires with the final score; the controller encodes a fresh `ChallengeState` into `MSMessage.url` and inserts it into the conversation draft.
4. The recipient taps the bubble → same flow, but with `incomingState` populated — `responder` is filled and the bubble updates to show both scores plus a "Get divedave" App Store link.

The challenge-round URL payload is ~140 chars (base64url JSON) for a finished round, well under Apple's recommended `MSMessage.url` budget. Goal-rotation math uses a phone-reference scale factor so the goal is achievable on the smallest target devices regardless of who's playing.

## Cross-device physics (parity-critical)

The scene runs in a **fixed 1250-wide reference world** — `SceneMetrics` is `width = 1250`, `height = max(1500, round(1250 · deviceAspect))`, presented with SpriteKit `.aspectFit`, mirroring the web build. Every position, sprite scale, and velocity is a plain fixed number in that world; there is no per-device scaling (the old `scaleFactorHeight` / `physicsScale` multipliers are gone). Launch/walk/boost velocities are therefore byte-identical to web (the `Constants` shared block); `Game.gravity` is the lone SpriteKit-specific physics value — its integrator differs from Phaser's, so it is *not* web's `1083`. Goal-rotation math (`DiveScorer.goalHalfFlips`) is computed from dive height in metres and shared with web; the iMessage duel uses the same function so duels and the main game agree.

> **Footgun:** author new geometry and velocities as fixed numbers in the 1250-wide world — don't reintroduce device-dependent scaling. Angular values (spin, angular drag) are scale-invariant. `Game.defaultHeight` (3000) and `Game.referenceScreenHeight` (852) now survive **only** as the ratio inside `goalHalfFlips`; the parity harness compiles `DiveScorer` + `Constants` standalone, so keep them free of scene/SpriteKit types.

## Assets

Everything is in `divedave Shared/Assets.xcassets/`:
- Character sprite sheets (`divedave-spritesheet-extruded`, `divedave-emotions`, `divedave-crouched`, `divedave-full`, `getting-out-spritesheet`, `climbdave`, `menu-spritesheet`, `divedave_loading_spritesheet`, `star-spritesheet`).
- Environment (`clouds`, `bird`, `plane`, `ufo`, `landscape`, `water`, `board`, `platformtop/section/base`, `splash`, `sign`).
- UI (`controls`, `controls-*`, `panel`, `cover`, `arcade`, `challenge`).
- A `fonts/` group containing rasterized number/letter atlases (`Arial20`, `black-arial`, `green-arial`, `red-arial`, `yellow-arial`) used for HUD labels.

`GameViewController.preloadAllAssets` warms the heavy textures before the main menu presents.

## See also

- `../README.md` — game overview and shared context.
- `../PARITY.md` — what is kept in sync between the web and iOS builds.
- `../CLAUDE.md` — AI-collaboration rules for this repo.
