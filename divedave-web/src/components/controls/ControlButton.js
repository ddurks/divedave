const ENABLED_ALPHA = 1.0;
const DISABLED_ALPHA = 0.4;
const PRESS_SCALE = 1.25;

export class ControlButton extends Phaser.GameObjects.Sprite {
  constructor(scene, x, y, texture, frame = null) {
    super(scene, x, y, texture, frame);

    this.baseScale = 0.5;
    this.growsOnPress = true;

    this.setInteractive();
    this.setScrollFactor(0);
    this.setScale(this.baseScale);
    this.setDepth(14);
    this.isDown = false;
    this.isEnabled = true;

    this.onPressed = null;
    this.onReleased = null;

    this.on("pointerdown", () => {
      this.isDown = true;
      if (this.growsOnPress) this.setScale(this.baseScale * PRESS_SCALE);
      if (this.onPressed) this.onPressed();
    });
    this.on("pointerup", () => this.pointerUp());
    this.on("pointerout", () => this.pointerUp());
  }

  pointerUp() {
    this.isDown = false;
    if (this.growsOnPress) this.setScale(this.baseScale);
    if (this.onReleased) this.onReleased();
  }

  setEnabled(enabled) {
    if (this.isEnabled === enabled) return;
    this.isEnabled = enabled;
    this.setAlpha(enabled ? ENABLED_ALPHA : DISABLED_ALPHA);
  }
}
