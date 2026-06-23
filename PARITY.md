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
| Reference world | `Constants.{js,swift}` | 1250 units wide; reference height 1500 |
| Launch / walk / boost velocities | `Constants.{js,swift}` | jump `704`, speed `352`, max boost `352` — both engines set velocity directly |
| High score storage key | `Constants.{js,swift}` | `"highScore"` (localStorage on web, UserDefaults on iOS) |
| Dive scoring algorithm | `DiveScorer.{js,swift}` | Same emotion-frame buckets, same score tiers, same tuck penalty |
| Emotion frame bands | `DiveScorer.chooseEmotionFrame` | Same angle thresholds: 10°, 25°, 45°, 70° (and their reflections) |
| Failure threshold | `DiveScorer` | `abs(rotations - goal) >= 0.25` |
| Linear damping | `Constants.{js,swift}` (`DRAG`/`drag`) | `0.94` per-frame velocity multiplier |
| Angular drag | `RotationTracker` | 150°/s² (web `ANGULAR_DRAG = 150`; iOS `linearAngularDrag = 2.618` rad/s²) |
| Goal-flip estimate | `DiveScorer.goalHalfFlips` | dive height (m) → half-flips, same heuristic curve |

When you change any of these, change both. The shared values live at the top of each `Constants` file under a labelled block (`=== Shared with ... ===`). The DiveScorer parity tests (see [Tooling](#tooling)) catch drift in scoring, boost-window classification, and the goal-flip estimate automatically; the other values are stable enough that the inline comment is the enforcement.

## What intentionally differs

Both builds now run physics in the **same fixed 1250-wide reference space** (see [Device independence](#device-independence)), so the launch/walk/boost velocities are byte-identical (listed above). The one exception is **gravity**: each engine applies it through its own integrator with different internal units — Phaser's Arcade gravity is px/s² at a fixed 60 Hz step; SpriteKit applies its gravity vector through its own (≈150 pt/m) integrator. The two numbers aren't interconvertible and were matched by feel.

| Concern | Web (Phaser) | iOS (SpriteKit) |
|---|---|---|
| Gravity | `GRAVITY = 1083` (px/s²) | `Game.gravity = 7.04` (SpriteKit integrator units) |
| Cloud speed | `35–85` px/s | `8–20` SpriteKit units/s |
| Bird speed | `50–200` px/s | `25–100` SpriteKit units/s |

Cloud/bird speeds are cosmetic and were tuned by eye. If you re-tune gravity on one side, playtest the other and match by feel.

### Device independence

Both builds reach it the **same way**: physics and layout live in a fixed reference world, and a scale mode fits that world to any screen — zero per-device scaling in game logic.

- **Web** — fixed `1250` wide; canvas height computed once from the device aspect ratio (`max(1500, round(1250 · aspect))`); Phaser `Scale.FIT`.
- **iOS** — `SceneMetrics` is the same fixed `1250` wide × aspect-derived height, presented with SpriteKit `.aspectFit`. The former per-device `scaleFactorHeight` / `physicsScale` multipliers are gone; every position, sprite scale, and velocity is a plain fixed number in the 1250-wide world.

Because both worlds are the identical 1250-wide space, the kinematic constants are the same numbers on both sides — only gravity (engine integrator) differs.

## What only exists on one side

- **Haptics** — iOS only (`Haptics.swift`). The web `Haptics.js` is a no-op shim where the Vibration API is unavailable; on supported mobile browsers it falls back to `navigator.vibrate`.
- **Viewport adaptation** — both compute a fixed reference world and fit it to the screen: Web computes `HEIGHT` from the device aspect ratio at module load (Phaser FIT); iOS computes the same aspect-derived height in `SceneMetrics` and presents with `.aspectFit`. No per-device physics or geometry scaling on either side (see [Device independence](#device-independence)).
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
- `goalHalfFlips` — dive height (m) → half-flips, the goal-difficulty curve shared by the main game and the iMessage duel.

If you change scoring or the boost windows on one side, update the fixtures and confirm both sides still pass before committing.
