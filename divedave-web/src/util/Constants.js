// === Shared with divedave-ios Constants.swift — keep in sync. ===
// `tools/run-parity.sh` catches drift in DiveScorer + boost-window
// classification. The remaining values are stable; check the matching
// Swift declaration when changing any of them.
export const WIDTH = 1250;

export const MIN_SPIN_VELOCITY = 100;
export const MAX_SPIN_VELOCITY = 550;

export const BOOST_PERFECT_MS = 90;
export const BOOST_GOOD_MS = 175;
export const BOOST_OK_MS = 265;

export const MIN_CLOUDS = 5;
export const MAX_CLOUDS = 12;
export const MIN_BIRDS = 0;
export const MAX_BIRDS = 3;

// Atmosphere parallax depth: 0 = pinned to camera (deepest), 1 = full world-space.
export const STAR_PARALLAX = 0.3;
export const CLOUD_PARALLAX = 0.6;
export const BIRD_PARALLAX = 0.8;
export const PLANE_PARALLAX = 0.8;
export const UFO_PARALLAX = 1.0;

export const HIGH_SCORE_KEY = "highScore";
// === End shared block. ===

export const GRAVITY = 1200;

export const REF_HEIGHT = 1500;

function computeViewportHeight() {
  if (typeof window === "undefined") return REF_HEIGHT;
  const aspect = window.innerHeight / window.innerWidth;
  return Math.max(REF_HEIGHT, Math.round(WIDTH * aspect));
}
export const HEIGHT = computeViewportHeight();

export const BOARD_Y = REF_HEIGHT / 2 + 40;
export const PLATFORM_TOP_Y = 797;
export const PLATFORM_SECTION_START_Y = 897;
export const DAVE_SPAWN_Y = REF_HEIGHT / 3;

export const DAVE_SPEED = 300;
export const JUMP_VELOCITY = 800;
// Per-frame horizontal velocity multiplier, mirrors iOS Game.drag.
export const DRAG = 0.94;
export const ANGULAR_DRAG = 150;
export const MAX_BOOST = 400;
export const IDLE_DELAY = 1000;

export const TIMING_TINT_PERFECT = 0x57e857;
export const TIMING_TINT_GOOD = 0xffe14d;
export const TIMING_TINT_OK = 0xff7a33;

export const CLOUDMINSPEED = 35;
export const CLOUDMAXSPEED = 85;
export const BIRDMINSPEED = 50;
export const BIRDMAXSPEED = 200;

export const START_COLOR = 0xbed5ff;
export const MIDDLE_COLOR = 0x7da8e8;
export const END_COLOR = 0x201f4b;
