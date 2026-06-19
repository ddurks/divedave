// Mirrors divedave-ios/divedave Shared/Util/Constants.swift.
// Numeric values reflect the Phaser pixel space (not SpriteKit units);
// see PARITY notes when porting from Swift.

export const GRAVITY = 1000;

export const WIDTH = 1250;

// Reference height used for *world geometry* — springboard y, dave's
// spawn position, platform sections, atmosphere altitude bands. These
// stay fixed across devices so the game world looks the same shape on
// every screen, the way iOS treats its reference design.
export const REF_HEIGHT = 1500;

// Viewport HEIGHT matches the device's aspect ratio so the canvas
// fills the screen (no letterbox) like iOS. We clamp at REF_HEIGHT
// minimum so wider-than-tall desktop windows don't squish the layout.
// Computed once at module load — rotating the device requires a
// reload, same as iOS launches into the active orientation.
function computeViewportHeight() {
  if (typeof window === "undefined") return REF_HEIGHT;
  const aspect = window.innerHeight / window.innerWidth;
  return Math.max(REF_HEIGHT, Math.round(WIDTH * aspect));
}
export const HEIGHT = computeViewportHeight();

// Fixed world-position constants derived from the reference height.
// Use these (not HEIGHT/2 + 40 etc.) for anything that's positioned
// in the game world.
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

// Jump-release timing windows (ms). Halfway between the original web
// (125/250/350) and the post-7e85b69 iOS tightening (50/100/175) —
// the latter felt punishing in playtest. iOS should be relaxed to
// match. Compared against |landedAt - jumpReleasedAt|, so an early
// release is scored symmetrically to a late one.
export const BOOST_PERFECT_MS = 90;
export const BOOST_GOOD_MS = 175;
export const BOOST_OK_MS = 265;

// Tint colors for the springboard pulse on landing.
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
