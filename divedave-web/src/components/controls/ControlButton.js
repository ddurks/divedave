// Mirrors divedave-ios/divedave Shared/Components/Controls/ControlButton.swift.
// Touch-responsive button that exposes `isDown` and (optionally) calls
// onPressed/onReleased. `isEnabled` controls the greyed-out visual
// (alpha 0.4 when disabled) but does NOT gate touch handling — `isDown`
// stays accurate across enable/disable flips so the caller can preserve
// the hold-jump-to-bounce pattern: finger stays down through Launching/
// Airborne (button greyed), and when state returns to Grounded
// (un-greyed) the still-true isDown fires the next jump on the next
// frame. Functional gating lives in DavePlayer state checks.

const ENABLED_ALPHA = 1.0;
const DISABLED_ALPHA = 0.4;

export class ControlButton extends Phaser.GameObjects.Image {
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
