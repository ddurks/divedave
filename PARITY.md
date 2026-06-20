# Parity between web and iOS

`divedave-web/` and `divedave-ios/` are two independent implementations of the same game. They are deliberately kept feature-equivalent. This document describes what stays in sync, what intentionally diverges, and why.

## The rule

When you change *behavior* on one side, change the matching file on the other. When you tune a *value*, both sides need to reach the same feel — but the numeric value will usually differ because Phaser and SpriteKit use different unit conventions.

If you can't tell which side is canonical for a given change, web is canonical for new features (it's the faster iteration loop), iOS is canonical for input feel (the touch-first design originated there).

## What stays identical

These are byte-for-byte identical (no unit conversion):

| Concern | Where | Value |
|---|---|---|
| Boost timing windows | `Constants.{js,swift}` | 90 / 175 / 265 ms (perfect / good / ok) |
| Spin velocity range | `Constants.{js,swift}` | 100°/s to 550°/s (Swift stores radians; web stores degrees) |
| Cloud/bird counts | `Constants.{js,swift}` | 5–12 clouds, 0–3 birds |
| Reference width | `Constants.{js,swift}` | 1250 units |
| High score storage key | `Constants.{js,swift}` | `"highScore"` (localStorage on web, UserDefaults on iOS) |
| Dive scoring algorithm | `DiveScorer.{js,swift}` | Same emotion-frame buckets, same score tiers, same tuck penalty |
| Emotion frame bands | `DiveScorer.chooseEmotionFrame` | Same angle thresholds: 10°, 25°, 45°, 70° (and their reflections) |
| Failure threshold | `DiveScorer` | `abs(rotations - goal) >= 0.25` |

When you change any of these, change both. The shared values live at the top of each `Constants` file under a labelled block (`=== Shared with ... ===`). The DiveScorer parity tests (see [Tooling](#tooling)) catch drift in scoring and boost-window classification automatically; the other values are stable enough that the inline comment is the enforcement.

## What intentionally differs

Physical units are platform-specific. Phaser's Arcade Physics uses pixels-per-second; SpriteKit's physics world uses its own scaled units with `linearDamping` in `[0, 1]` rather than a drag coefficient. The values below are not directly convertible — they were tuned independently to feel the same.

| Concern | Web (Phaser) | iOS (SpriteKit) |
|---|---|---|
| Gravity | `GRAVITY = 1000` | `Game.gravity = 2` (applied to `physicsWorld.gravity`) |
| Dave speed | `DAVE_SPEED = 300` | `daveSpeed = 100` |
| Jump velocity | `JUMP_VELOCITY = 800` | `jumpVelocity = 200` |
| Linear drag | `DRAG = 500` | `drag = 0.94` (linearDamping) |
| Angular drag | `ANGULAR_DRAG = 150` | `angularDrag = 0.9` |
| Max boost | `MAX_BOOST = 200` | `maxBoost = 100` |
| Cloud speed | `35–85` px/s | `8–20` SpriteKit units/s |
| Bird speed | `50–200` px/s | `25–100` SpriteKit units/s |

The ratios are not constant across rows; do not try to derive a single conversion factor. If you re-tune one side, playtest the other and adjust by feel.

## What only exists on one side

- **Haptics** — iOS only (`Haptics.swift`). The web `Haptics.js` is a no-op shim where the Vibration API is unavailable; on supported mobile browsers it falls back to `navigator.vibrate`.
- **Viewport adaptation** — Web computes `HEIGHT` from the device aspect ratio at module load. iOS uses `SceneMetrics` to scale the reference 1250×3000 design to the actual device size.
- **Audio** — neither side has any. Don't add it.

## When in doubt

Read the matching file. The folder structures mirror each other:

```
divedave-web/src/scenes/        ↔  divedave-ios/divedave Shared/Scenes/
divedave-web/src/util/          ↔  divedave-ios/divedave Shared/Util/
divedave-web/src/components/    ↔  divedave-ios/divedave Shared/Components/
```

Same file names, same responsibilities, parallel APIs. If a function exists on one side and not the other, that's a parity bug — flag it.

## Tooling

`tools/parity-fixtures.json` holds input/output cases for `DiveScorer`. Both `tools/parity-test.mjs` (Node) and `tools/parity-test.swift` (compiled with `swiftc`) load the same fixtures and exercise the matching function on each platform. The Swift binary is built on demand into `tools/.build/`.

```
tools/run-parity.sh
```

Output is one line per side (`[js] N passed, M failed` / `[swift] ...`). Non-zero exit if either side regresses. Coverage:

- `chooseEmotionFrame` — angle-to-frame staircase, boundary-heavy.
- `classifyBoostTiming` — quickness-ms-to-tier, which transitively asserts the three boost-window constants match between platforms.
- `scoreDive` — the deterministic outputs (`result` and `emotionFrame`). The three judge scores include a per-tier random component and are not asserted across runs.

If you change scoring or the boost windows on one side, update the fixtures and confirm both sides still pass before committing.
