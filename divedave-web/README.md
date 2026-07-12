# divedave-web

The Phaser 4 web build of divedave.

## Stack

- Phaser 4.2.0 (vendored at `lib/phaser.min.js`)
- Vanilla JavaScript, ES modules, loaded directly by the browser
- No bundler, no transpile step, no build output
- Served as static files

## Run locally

Serve this directory with any static file server, then open the URL it prints:

```
cd divedave-web
python3 -m http.server 8000
# open http://localhost:8000
```

Any equivalent (`npx http-server`, `caddy file-server`, etc.) works. There is nothing to build — edit a file, refresh the browser.

The hosted demo lives at `drawvid.com/code/divedave/`.

## Source layout

```
divedave-web/
  index.html              entry; loads phaser.min.js + src/main.js
  lib/phaser.min.js       vendored Phaser 4.2.0
  assets/                 sprites, backgrounds, bitmap fonts
  src/
    main.js               Phaser config, scene registration
    scenes/               top-level Phaser scenes
    components/
      controls/           on-screen buttons and HUD
      menu/               menu-screen UI pieces
      scene/              in-scene actors (player, camera, scorer)
    util/                 constants, persistence, helpers
```

One-liners:

- `src/scenes/` — `MainMenuScene` (title + mode select) and `DiveScene` (the dive itself).
- `src/components/controls/` — touch buttons (`ControlButton`) and the score/streak HUD.
- `src/components/menu/` — info/instruction panels shown over the menu.
- `src/components/scene/` — gameplay objects pulled out of `DiveScene` to keep it manageable.
- `src/util/` — shared constants and small modules used by every scene.

## Key files

- `src/main.js` — Phaser config: arcade physics, `Scale.FIT`, scene list `[MainMenuScene, DiveScene]`.
- `src/scenes/DiveScene.js` — the dive: spawn, jump, spin, scoring, water entry, climb-out.
- `src/scenes/MainMenuScene.js` — title screen, mode toggle, instructions.
- `src/components/scene/DavePlayer.js` — Dave's sprite, physics body, animation state.
- `src/components/scene/DiveScorer.js` — boost-timing windows and streak scoring.
- `src/components/scene/CameraController.js` — camera follow, shake, fade.
- `src/components/controls/HUD.js` — score, streak, and high-score display.
- `src/util/Constants.js` — gravity, viewport size, jump/spin tuning, boost-window timings, color constants. Single source of truth for gameplay numbers.
- `src/util/GameState.js` — small mutable singleton holding the current run's state (streak, score, references to live actors).
- `src/util/StatsStore.js` — cookie wrapper for the high score.

## Assets

Everything is under `assets/`:

- `assets/*.png` — backgrounds, props, and grid-frame spritesheets. Spritesheets are loaded via `this.load.spritesheet(..., { frameWidth, frameHeight })`; there are no JSON texture atlases.
- `assets/fonts/*.png` + `assets/fonts/*.xml` — BMFont bitmap fonts (`drawvid-handwriting-black`, `-green`, `-red`, `-white`, `-yellow`).
- `assets/daveicon.ico` — favicon.

## See also

- [`../README.md`](../README.md) — what the game is.
- [`../PARITY.md`](../PARITY.md) — what stays in sync between the web and iOS builds.
- [`../CLAUDE.md`](../CLAUDE.md) — rules for AI agents working in this repo.
