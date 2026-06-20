export const GRAVITY = 1000;

export const WIDTH = 1250;

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
export const MIN_SPIN_VELOCITY = 100;
export const MAX_SPIN_VELOCITY = 550;
export const DRAG = 500;
export const ANGULAR_DRAG = 150;
export const MAX_BOOST = 200;
export const IDLE_DELAY = 1000;

export const BOOST_PERFECT_MS = 90;
export const BOOST_GOOD_MS = 175;
export const BOOST_OK_MS = 265;

export const TIMING_TINT_PERFECT = 0x57e857;
export const TIMING_TINT_GOOD = 0xffe14d;
export const TIMING_TINT_OK = 0xff7a33;

export const MIN_CLOUDS = 5;
export const MAX_CLOUDS = 12;
export const CLOUDMINSPEED = 35;
export const CLOUDMAXSPEED = 85;

export const MIN_BIRDS = 0;
export const MAX_BIRDS = 3;
export const BIRDMINSPEED = 50;
export const BIRDMAXSPEED = 200;

export const START_COLOR = 0xbed5ff;
export const MIDDLE_COLOR = 0x7da8e8;
export const END_COLOR = 0x201f4b;

export const HIGH_SCORE_KEY = "highScore";
