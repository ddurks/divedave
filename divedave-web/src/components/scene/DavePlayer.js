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
import { Haptics } from "../../util/Haptics.js";
import { BoostTiming, classifyBoostTiming } from "./DiveScorer.js";

const EARLY_TAP_WINDOW_MS = BOOST_OK_MS;

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
      .sprite(WIDTH / 8, DAVE_SPAWN_Y, "dave")
      .setDepth(12);
    sprite.setOrigin(0.5, 0.5);
    sprite.body.setSize(64, 256);
    sprite.body.setAllowGravity(true);
    sprite.speed = DAVE_SPEED;
    sprite.setDrag(DRAG, 1);
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
      Haptics.impactLight();
      return;
    }
    if (next === DaveState.Splashed) {
      Haptics.notificationSuccess();
      return;
    }
    if (next === DaveState.Grounded) {
      this.tucked = false;
      this.tuckCount = 0;
      this.currentVelocity = MIN_SPIN_VELOCITY;
      if (typeof this.scene.resetDiveAttempt === "function") {
        this.scene.resetDiveAttempt();
      }
      Haptics.impactLight();
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

  calculateBoost() {
    const quickness = diff(this.landedAt, this.jumpReleasedAt);
    const timing = classifyBoostTiming(quickness);
    switch (timing) {
      case BoostTiming.Perfect: this.boost = MAX_BOOST; break;
      case BoostTiming.Good:    this.boost = MAX_BOOST - 50; break;
      case BoostTiming.Ok:      this.boost = MAX_BOOST - 100; break;
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
    if (this.tucked) this.sprite.setFrame(7);
    return this.sprite.frame.name === 7 || this.tucked;
  }

  updateFrame() {
    const dave = this.sprite;
    switch (this.state) {
      case DaveState.Launching:
      case DaveState.Splashed:
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
