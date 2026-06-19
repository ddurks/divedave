// Mirrors divedave-ios/divedave Shared/Components/Scene/DavePlayer.swift.
//
// Owns Dave's sprite, the explicit DaveState machine, per-frame animation
// orchestration, the jump→boost flow, and the tuck/spin accumulator.
// Climbdave / gettingoutdave / splash stay on DiveScene since they're
// post-dive presentation, not player physics.
//
// Behavior parity notes (vs. iOS):
//   - Boost thresholds here are still 125 / 250 / 350 ms (web's
//     pre-7e85b69 values). Phase 2 tightens to iOS's 50 / 100 / 175.

import {
  ANGULAR_DRAG,
  DAVE_SPEED,
  DRAG,
  HEIGHT,
  JUMP_VELOCITY,
  MAX_BOOST,
  MAX_SPIN_VELOCITY,
  MIN_SPIN_VELOCITY,
  WIDTH,
} from "../../util/Constants.js";
import { diff } from "../../util/Utilities.js";

// How long after a jump-button release we still treat it as "buffered"
// for the next landing. Matches the iOS early-tap window (175 ms).
const EARLY_TAP_WINDOW_MS = 175;

export const DaveState = Object.freeze({
  Grounded: "grounded",
  Launching: "launching",
  Airborne: "airborne",
  Diving: "diving",
  Splashed: "splashed",
});

// Allowed transitions. Anything else logs and is rejected. Self-
// transitions are silent no-ops in transition().
const ALLOWED_TRANSITIONS = {
  [DaveState.Grounded]: new Set([
    DaveState.Launching,
    DaveState.Airborne,
    DaveState.Splashed,
  ]),
  [DaveState.Launching]: new Set([DaveState.Airborne]),
  [DaveState.Airborne]: new Set([
    DaveState.Diving,
    DaveState.Grounded,
    DaveState.Splashed,
  ]),
  // Diving is a commit point. Match iOS: once tucked, the only way out
  // is Splashed. didEnter(Diving) also zeros the collision mask so
  // Dave passes through the board on the way down.
  [DaveState.Diving]: new Set([DaveState.Splashed]),
  [DaveState.Splashed]: new Set(),
};

export class DavePlayer {
  constructor(scene, springboard) {
    this.scene = scene;
    this.springboard = springboard;

    const sprite = scene.physics.add
      .sprite(WIDTH / 8, HEIGHT / 3, "dave")
      .setDepth(12);
    sprite.setOrigin(0.5, 0.5);
    sprite.body.setSize(64, 256);
    sprite.body.setAllowGravity(true);
    sprite.speed = DAVE_SPEED;
    sprite.setDrag(DRAG, 1);
    sprite.body.setAngularDrag(ANGULAR_DRAG);
    sprite.body.setAllowDrag(true);
    this.sprite = sprite;

    // Match iOS: start Airborne. Dave spawns above the board and falls
    // onto it; the per-frame landing check in the scene transitions to
    // Grounded on first clean contact.
    this.state = DaveState.Airborne;
    this.landedAt = null;
    this.jumpReleasedAt = null;
    this.boost = 0;
    this.currentVelocity = MIN_SPIN_VELOCITY;
    this.tucked = false;
    this.tuckCount = 0;

    // Jump animation completion finalizes the launch: compute the
    // timing-based boost, clear the landed-at stamp, push Dave upward,
    // and advance the state machine. Filter on key so future one-shot
    // animations on this sprite don't accidentally re-fire this.
    sprite.on(Phaser.Animations.Events.ANIMATION_COMPLETE, (anim) => {
      if (!anim || anim.key !== "jump") return;
      this.calculateBoost();
      this.landedAt = null;
      sprite.setVelocityY(-JUMP_VELOCITY - this.boost);
      this.transition(DaveState.Airborne);
    });
  }

  // ---------- State machine ----------

  transition(next) {
    if (next === this.state) return true;
    const allowed = ALLOWED_TRANSITIONS[this.state];
    if (!allowed || !allowed.has(next)) {
      console.warn(
        `[DavePlayer] rejected transition ${this.state} → ${next}`
      );
      return false;
    }
    const prev = this.state;
    this.state = next;
    this.didEnter(next, prev);
    return true;
  }

  didEnter(next /*, prev */) {
    if (next === DaveState.Diving) {
      // Commit to the dive: pass through the board, no more bonks /
      // landings. Pairs with the HUD greying-out the jump button in
      // Diving — together they're the two halves of "you are diving,
      // full stop." Scene restart spawns a fresh DavePlayer with a
      // default-collision body, so we don't need to undo this here.
      this.sprite.body.checkCollision.none = true;
      return;
    }
    if (next === DaveState.Grounded) {
      // Per-attempt reset on (re)landing. The rotation accumulators
      // live on the scene, so the scene exposes resetDiveAttempt() and
      // we call it from here. See the comment that previously lived in
      // DiveScene.daveIsAboveBoard.
      this.tucked = false;
      this.tuckCount = 0;
      this.currentVelocity = MIN_SPIN_VELOCITY;
      if (typeof this.scene.resetDiveAttempt === "function") {
        this.scene.resetDiveAttempt();
      }
      // Early-tap jump buffer: if the player tapped + released the
      // jump button within the last EARLY_TAP_WINDOW_MS *before*
      // landing, fire that queued jump now. Pair with: the jump
      // button stays visually enabled in all states so the tap reads
      // as a real button press. jumpReleasedAt is intentionally NOT
      // cleared here — calculateBoost() reads it to score this jump's
      // quickness based on the original release timestamp, and any
      // future release will overwrite it.
      if (
        this.jumpReleasedAt &&
        Date.now() - this.jumpReleasedAt < EARLY_TAP_WINDOW_MS
      ) {
        this.tryJump();
      }
    }
  }

  // ---------- Inputs ----------

  /** Attempt to start a jump. Returns true if the jump began. */
  tryJump() {
    if (this.state !== DaveState.Grounded) return false;
    if (this.sprite.anims.getName() === "jump") return false;
    if (!this.transition(DaveState.Launching)) return false;
    this.springboard.anims.play("flex", true);
    this.sprite.anims.play("jump", true);
    return true;
  }

  /**
   * Player is holding the tuck/flip input this frame. First tuck while
   * Airborne commits to Diving. Subsequent calls ramp angular velocity.
   * No-op outside Airborne / Diving.
   */
  applyTuck() {
    if (this.state !== DaveState.Airborne && this.state !== DaveState.Diving) {
      return;
    }
    if (!this.tucked) {
      this.tucked = true;
      this.tuckCount++;
      if (this.state === DaveState.Airborne) {
        this.transition(DaveState.Diving);
      }
    }
    if (this.currentVelocity < MAX_SPIN_VELOCITY - 200) {
      this.currentVelocity += 5;
    } else if (this.currentVelocity < MAX_SPIN_VELOCITY) {
      this.currentVelocity += 1;
    }
    this.sprite.body.setAngularVelocity(this.currentVelocity);
  }

  /** Player released the tuck/flip input this frame. */
  releaseTuck() {
    this.tucked = false;
    this.currentVelocity = MIN_SPIN_VELOCITY;
  }

  /** Mark that the jump button was released (for boost-timing math). */
  noteJumpReleased() {
    this.jumpReleasedAt = Date.now();
  }

  /** Mark that Dave touched the board (called from the scene's collider). */
  noteBoardLanded() {
    if (!this.landedAt) this.landedAt = Date.now();
  }

  // ---------- Boost math ----------

  calculateBoost() {
    const quickness = diff(this.landedAt, this.jumpReleasedAt);
    if (quickness < 125) this.boost = MAX_BOOST;
    else if (quickness < 250) this.boost = MAX_BOOST - 50;
    else if (quickness < 350) this.boost = MAX_BOOST - 100;
    else this.boost = 0;

    const daveBoardDist =
      this.sprite.x - (this.springboard.x - this.springboard.width / 2);
    if (daveBoardDist > 0) {
      let newRatio = daveBoardDist / this.springboard.width;
      if (newRatio > 1) newRatio = 1;
      this.boost = this.boost * newRatio;
    }
  }

  // ---------- Geometry predicates ----------

  isAboveBoard() {
    const d = this.sprite;
    const b = this.springboard;
    return (
      d.x + d.width / 4 > 0 &&
      d.x - d.width / 4 < b.x + b.width / 2 - 10 &&
      d.y + d.height / 2 < b.y - b.height / 2 + 1
    );
  }

  isTouchingBoard() {
    return (
      this.sprite.y + this.sprite.height / 2 >=
      this.springboard.y - this.springboard.height / 2
    );
  }

  /**
   * Port of iOS DavePlayer.isCleanLanding(). Distinguishes a real
   * landing from a same-frame board contact while Dave is still flying
   * upward right after the jump impulse, or while he's spinning fast
   * mid-dive (so a board bonk doesn't get treated as a landing).
   *
   * Phaser uses Y-down, so "not launching" means vy >= small-negative
   * (i.e., not moving upward faster than 50 px/s). Angular velocity in
   * Phaser is degrees/sec; ~30 deg/s ≈ iOS's 0.5 rad/s.
   */
  isCleanLanding() {
    const body = this.sprite.body;
    if (!body) return false;
    const notLaunching = body.velocity.y > -50;
    const lowSpin = Math.abs(body.angularVelocity) < 30;
    return notLaunching && lowSpin;
  }

  isTucked() {
    // Preserve the slightly odd legacy behavior: writing frame 7 here
    // ensures isTucked() is a no-op idempotent read that also re-asserts
    // the tucked pose if it got swapped out. Subsequent updateFrame()
    // for Diving will re-write to frame 7 too.
    if (this.tucked) this.sprite.setFrame(7);
    return this.sprite.frame.name === 7 || this.tucked;
  }

  // ---------- Per-frame ----------

  /**
   * Per-frame animation orchestration, driven entirely by `state` — no
   * geometric predicates. Matches iOS DavePlayer.updateFrame(tucked:).
   * Position-gated logic (the old `if (isAboveBoard())` branch) caused
   * mid-dive rotations to snap upright + lose the tuck pose whenever
   * Dave's arc carried him back over the board's x range.
   */
  updateFrame() {
    const dave = this.sprite;
    switch (this.state) {
      case DaveState.Launching:
      case DaveState.Splashed:
        // Jump anim / splash sequence own the texture during these states.
        return;

      case DaveState.Grounded:
        if (dave.angle !== 0) dave.setAngle(0);
        if (dave.body.velocity.x > 0) {
          dave.anims.play("walkright", true);
        } else if (dave.body.velocity.x < 0) {
          dave.anims.play("walkleft", true);
        } else if (dave.anims.getName() !== "idle") {
          dave.anims.play("idle", true);
        }
        return;

      case DaveState.Airborne:
        if (dave.body.velocity.y < 0) {
          dave.setFrame(dave.body.velocity.x < 0 ? 15 : 6);
        } else {
          dave.setFrame(dave.body.velocity.x < 0 ? 11 : 2);
        }
        return;

      case DaveState.Diving:
        if (this.tucked) {
          dave.setFrame(7);
        } else {
          dave.setFrame(dave.angle >= -90 && dave.angle <= 90 ? 6 : 8);
        }
        return;
    }
  }
}
