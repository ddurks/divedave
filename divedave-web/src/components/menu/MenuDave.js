// A decorative Dave that paces back and forth between two x bounds, reusing the
// gameplay walk cycle and the direction-change turn pivot. Purely cosmetic;
// driven by the scene's update(delta). Mirrors the iOS MenuDave in
// MainMenuScene.swift — keep the two in sync.
const WALK_FRAMES = [5, 6, 7, 8];
const WALK_FRAME_MS = 125;
const TURN_FRAME_MS = 50;

export class MenuDave {
  constructor(scene, { y, leftBound, rightBound, speed = 0.15, scale = 1, depth = 1 }) {
    this.leftBound = leftBound;
    this.rightBound = rightBound;
    this.speed = speed; // px per ms
    this.dir = 1;
    this.walkTimer = 0;
    this.walkIndex = 0;
    this.turning = false;
    this.turnElapsed = 0;
    this.turnViaBack = false;
    this.turnFrom = 1;
    this.turnTo = 1;

    this.sprite = scene.add
      .sprite(leftBound, y, "dave")
      .setScale(scale)
      .setDepth(depth)
      .setFrame(WALK_FRAMES[0]);
  }

  update(delta) {
    if (this.turning) {
      this.advanceTurn(delta);
      return;
    }
    this.sprite.x += this.dir * this.speed * delta;
    this.sprite.setFlipX(this.dir < 0);
    this.walkTimer += delta;
    if (this.walkTimer >= WALK_FRAME_MS) {
      this.walkTimer -= WALK_FRAME_MS;
      this.walkIndex = (this.walkIndex + 1) % WALK_FRAMES.length;
      this.sprite.setFrame(WALK_FRAMES[this.walkIndex]);
    }
    if (
      (this.dir > 0 && this.sprite.x >= this.rightBound) ||
      (this.dir < 0 && this.sprite.x <= this.leftBound)
    ) {
      this.startTurn();
    }
  }

  startTurn() {
    this.turning = true;
    this.turnElapsed = 0;
    this.turnViaBack = Math.random() < 0.5;
    this.turnFrom = this.dir;
    this.turnTo = -this.dir;
    this.advanceTurn(0);
  }

  advanceTurn(delta) {
    this.turnElapsed += delta;
    const mid = this.turnViaBack ? 3 : 1;
    const pivot = this.turnViaBack ? 4 : 0;
    const frames = [2, mid, pivot, mid, 2];
    const dirs = [this.turnFrom, this.turnFrom, this.turnFrom, this.turnTo, this.turnTo];
    const step = Math.floor(this.turnElapsed / TURN_FRAME_MS);
    if (step >= frames.length) {
      this.turning = false;
      this.dir = this.turnTo;
      this.walkTimer = 0;
      this.walkIndex = 0;
      this.sprite.setFlipX(this.dir < 0);
      this.sprite.setFrame(WALK_FRAMES[0]);
      return;
    }
    this.sprite.setFlipX(dirs[step] < 0);
    this.sprite.setFrame(frames[step]);
  }
}
