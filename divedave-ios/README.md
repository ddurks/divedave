# divedave-ios

The SpriteKit iOS build of divedave.

## Stack

- SpriteKit + GameplayKit
- Swift 5.9
- iOS 15.0 deployment target, iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- Xcode project at `divedave.xcodeproj` (no SPM/CocoaPods/Carthage)
- No audio, no haptics.

## Build & run

Open `divedave.xcodeproj` in Xcode, select the `divedave iOS` scheme, and run on a simulator or device.

There is no CI or Fastlane setup in-repo.

## Project layout

```
divedave-ios/
  divedave.xcodeproj/     Xcode project
  divedave iOS/           main app glue (AppDelegate, GameViewController, launch storyboard)
  divedave Shared/        the game itself (scenes, components, util, assets)
  build/                  xcodebuild derived output, not source
```

`build/` is xcodebuild output and should not be committed.

## Key files

### App glue (`divedave iOS/`)
- `AppDelegate.swift` — stock `UIApplicationDelegate`, no custom lifecycle logic.
- `GameViewController.swift` — seeds `GameState.metrics` from the view bounds, preloads textures, and presents `MainMenuScene`.

### Scenes (`divedave Shared/Scenes/`)
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
- `GameState.swift` — singleton holding metrics, mode, streak, total score, current `DiveStats`, and `highScore` (persisted to `UserDefaults`).
- `SceneMetrics.swift` — view-bounds-derived sizing (`width`, `height`, scale factors).
- `StatsStore.swift` — persistent stats.
- `Utilities.swift` — misc helpers.

## Cross-device physics (parity-critical)

The scene runs in a **fixed 1250-wide reference world** — `SceneMetrics` is `width = 1250`, `height = max(1500, round(1250 · deviceAspect))`, presented with SpriteKit `.aspectFit`, mirroring the web build. Every position, sprite scale, and velocity is a plain fixed number in that world; there is no per-device scaling (the old `scaleFactorHeight` / `physicsScale` multipliers are gone). Launch/walk/boost velocities are therefore byte-identical to web (the `Constants` shared block); `Game.gravity` is the lone SpriteKit-specific physics value — its integrator differs from Phaser's, so it is *not* web's `1083`. Goal-rotation math (`DiveScorer.goalHalfFlips`) is computed from dive height in metres and shared with web.

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
