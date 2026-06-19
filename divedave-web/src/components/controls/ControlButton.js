// Mirrors divedave-ios/divedave Shared/Components/Controls/ControlButton.swift.
// Touch-responsive button that exposes isDown and (optionally) calls
// onPressed/onReleased. Phase 0 keeps the original Phaser.Image-based
// implementation; later phases will add the enabled/disabled visual
// state to match the iOS stacked HUD.

export class ControlButton extends Phaser.GameObjects.Image {
  constructor(scene, x, y, texture, frame = null) {
    super(scene, x, y, texture, frame);

    this.setInteractive();
    this.setScrollFactor(0);
    this.setScale(0.5);
    this.setDepth(14);
    this.isDown = false;

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
}
