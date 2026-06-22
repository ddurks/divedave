import {
  ANGULAR_DRAG,
  BOOST_OK_MS,
  DAVE_SPAWN_Y,
  DAVE_SPEED,
  DRAG,
  JUMP_VELOCITY,
  MAX_BOOST,
  MAX_SPIN_VELOCITY,
  MIN_SPIN_VELOCITY,
  WIDTH,
} from "../../util/Constants.js";
import { diff } from "../../util/Utilities.js";
import { BoostTiming, classifyBoostTiming } from "./DiveScorer.js";

const EARLY_TAP_WINDOW_MS = BOOST_OK_MS;
// Per-frame duration of the grounded direction-change pivot (5 frames).
const TURN_FRAME_MS = 50;
// How long the falling frame is held when tucking straight from the dive pose.
const TUCK_FALL_MS = 80;

export const DaveState = Object.freeze({
  Grounded: "grounded",
  Launching: "launching",
  Airborne: "airborne",
  Diving: "diving",
  Splashed: "splashed",
});

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
  [DaveState.Diving]: new Set([DaveState.Splashed]),
  [DaveState.Splashed]: new Set(),
};

export class DavePlayer {
  constructor(scene, springboard) {
    this.scene = scene;
    this.springboard = springboard;

    const sprite = scene.physics.add
      .sprite(springboard.x - springboard.width / 4, DAVE_SPAWN_Y, "dave")
      .setDepth(12);
    sprite.setOrigin(0.5, 0.5);
    sprite.body.setSize(64, 256);
    sprite.body.setAllowGravity(true);
    sprite.speed = DAVE_SPEED;
    sprite.body.setAngularDrag(ANGULAR_DRAG);
    sprite.body.setAllowDrag(true);
    this.sprite = sprite;

    this.state = DaveState.Airborne;
    this.landedAt = null;
    this.jumpReleasedAt = null;
    this.boost = 0;
    this.currentVelocity = MIN_SPIN_VELOCITY;
    this.tucked = false;
    this.tuckCount = 0;
    // Facing + turn-on-reversal (grounded only). facing: 1 = right, -1 = left.
    this.facing = 1;
    this.prevDesired = 0;
    this.turning = false;
    this.turnFrom = 1;
    this.turnTo = 1;
    this.turnViaBack = false;
    this.turnStart = 0;
    // Tuck transition: slip the falling frame in when tucking from the dive pose.
    this.wasTucked = false;
    this.tuckTransitioning = false;
    this.tuckTransitionStart = 0;
    this.lastFrame = 11;

    sprite.on(Phaser.Animations.Events.ANIMATION_COMPLETE, (anim) => {
      if (!anim || anim.key !== "jump") return;
      const timing = this.calculateBoost();
      this.landedAt = null;
      sprite.setVelocityY(-JUMP_VELOCITY - this.boost);
      this.transition(DaveState.Airborne);
      if (typeof this.scene.onJumpBoostApplied === "function") {
        this.scene.onJumpBoostApplied(timing);
      }
    });
  }

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
      this.sprite.body.checkCollision.none = true;
      return;
    }
    if (next === DaveState.Splashed) {
      return;
    }
    if (next === DaveState.Grounded) {
      this.turning = false;
      this.prevDesired = 0;
      this.tucked = false;
      this.tuckCount = 0;
      this.currentVelocity = MIN_SPIN_VELOCITY;
      if (typeof this.scene.resetDiveAttempt === "function") {
        this.scene.resetDiveAttempt();
      }
      // jumpReleasedAt is intentionally NOT cleared — calculateBoost()
      // reads it to score the next jump's quickness.
      if (
        this.jumpReleasedAt &&
        Date.now() - this.jumpReleasedAt < EARLY_TAP_WINDOW_MS
      ) {
        this.tryJump();
      }
    }
  }

  tryJump() {
    if (this.state !== DaveState.Grounded) return false;
    if (this.sprite.anims.getName() === "jump") return false;
    if (!this.transition(DaveState.Launching)) return false;
    this.sprite.setFlipX(false);
    this.springboard.anims.play("flex", true);
    this.sprite.anims.play("jump", true);
    return true;
  }

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

  releaseTuck() {
    this.tucked = false;
    this.currentVelocity = MIN_SPIN_VELOCITY;
  }

  noteJumpReleased() {
    this.jumpReleasedAt = Date.now();
  }

  noteBoardLanded() {
    if (!this.landedAt) this.landedAt = Date.now();
  }

  applyDamping() {
    this.sprite.body.velocity.x *= DRAG;
  }

  calculateBoost() {
    const quickness = diff(this.landedAt, this.jumpReleasedAt);
    const timing = classifyBoostTiming(quickness);
    switch (timing) {
      case BoostTiming.Perfect: this.boost = MAX_BOOST; break;
      case BoostTiming.Good:    this.boost = MAX_BOOST / 2; break;
      default:                  this.boost = 0;
    }

    const daveBoardDist =
      this.sprite.x - (this.springboard.x - this.springboard.width / 2);
    if (daveBoardDist > 0) {
      let newRatio = daveBoardDist / this.springboard.width;
      if (newRatio > 1) newRatio = 1;
      this.boost = this.boost * newRatio;
    }

    return timing;
  }

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

  isCleanLanding() {
    const body = this.sprite.body;
    if (!body) return false;
    const notLaunching = body.velocity.y > -50;
    const lowSpin = Math.abs(body.angularVelocity) < 30;
    return notLaunching && lowSpin;
  }

  isTucked() {
    if (this.tucked) this.sprite.setFrame(13);
    return this.sprite.frame.name === 13 || this.tucked;
  }

  updateFrame() {
    const dave = this.sprite;
    switch (this.state) {
      case DaveState.Launching:
      case DaveState.Splashed:
        return;

      case DaveState.Grounded: {
        if (dave.angle !== 0) dave.setAngle(0);
        if (this.turning) {
          this.advanceTurn();
          return;
        }
        const thr = DAVE_SPEED / 10;
        const vx = dave.body.velocity.x;
        const desired = vx > thr ? 1 : vx < -thr ? -1 : 0;
        if (desired === 0) {
          dave.setFlipX(this.facing < 0);
          if (dave.anims.getName() !== "idle") dave.anims.play("idle", true);
          this.prevDesired = 0;
        } else if (desired === this.facing) {
          dave.setFlipX(this.facing < 0);
          dave.anims.play("walk", true);
          this.prevDesired = desired;
        } else if (this.prevDesired === 0) {
          // From idle/landing: snap to the new direction, no turn.
          this.facing = desired;
          dave.setFlipX(this.facing < 0);
          dave.anims.play("walk", true);
          this.prevDesired = desired;
        } else {
          // Reversed mid-walk: pivot through the turn frames, then resume walk.
          this.startTurn(this.facing, desired);
          this.prevDesired = desired;
        }
        return;
      }

      case DaveState.Airborne:
        // Frames face right; mirror for leftward motion. Ascending = jump-up
        // (11), descending = falling-down (12).
        dave.setFlipX(dave.body.velocity.x < 0);
        this.lastFrame = dave.body.velocity.y < 0 ? 11 : 12;
        dave.setFrame(this.lastFrame);
        return;

      case DaveState.Diving: {
        // Dive pose never mirrors — always the original (right-facing) frame.
        dave.setFlipX(false);
        if (this.tucked) {
          // Tucking straight from the dive (inverted) frame slips the falling
          // frame in first; from the falling/upright frame it's skipped.
          if (!this.wasTucked && this.lastFrame === 14) {
            this.tuckTransitioning = true;
            this.tuckTransitionStart = this.scene.time.now;
          }
          if (
            this.tuckTransitioning &&
            this.scene.time.now - this.tuckTransitionStart < TUCK_FALL_MS
          ) {
            this.lastFrame = 12;
          } else {
            this.tuckTransitioning = false;
            this.lastFrame = 13;
          }
        } else {
          this.tuckTransitioning = false;
          // Falling pose while upright; dive pose once rotated upside down.
          const upright = dave.angle >= -90 && dave.angle <= 90;
          this.lastFrame = upright ? 12 : 14;
        }
        dave.setFrame(this.lastFrame);
        this.wasTucked = this.tucked;
        return;
      }
    }
  }

  startTurn(from, to) {
    this.turning = true;
    this.turnFrom = from;
    this.turnTo = to;
    this.turnViaBack = Math.random() < 0.5;
    this.turnStart = this.scene.time.now;
    this.sprite.anims.stop();
    this.advanceTurn();
  }

  advanceTurn() {
    const mid = this.turnViaBack ? 3 : 1;
    const pivot = this.turnViaBack ? 4 : 0;
    const frames = [2, mid, pivot, mid, 2];
    const dirs = [
      this.turnFrom,
      this.turnFrom,
      this.turnFrom,
      this.turnTo,
      this.turnTo,
    ];
    const step = Math.floor((this.scene.time.now - this.turnStart) / TURN_FRAME_MS);
    if (step >= frames.length) {
      this.turning = false;
      this.facing = this.turnTo;
      this.sprite.setFlipX(this.facing < 0);
      this.sprite.setFrame(2);
      return;
    }
    this.sprite.setFlipX(dirs[step] < 0);
    this.sprite.setFrame(frames[step]);
  }
}
