const ENABLED_ALPHA = 1.0;
const DISABLED_ALPHA = 0.4;

export class ControlButton extends Phaser.GameObjects.Sprite {
  constructor(scene, x, y, texture, frame = null) {
    super(scene, x, y, texture, frame);

    this.setInteractive();
    this.setScrollFactor(0);
    this.setScale(0.5);
    this.setDepth(14);
    this.isDown = false;
    this.isEnabled = true;

    this.onPressed = null;
    this.onReleased = null;

    this.on("pointerdown", () => {
      this.isDown = true;
      if (this.onPressed) this.onPressed();
    });
    this.on("pointerup", () => this.pointerUp());
    this.on("pointerout", () => this.pointerUp());
  }

  pointerUp() {
    this.isDown = false;
    if (this.onReleased) this.onReleased();
  }

  setEnabled(enabled) {
    if (this.isEnabled === enabled) return;
    this.isEnabled = enabled;
    this.setAlpha(enabled ? ENABLED_ALPHA : DISABLED_ALPHA);
  }
}
