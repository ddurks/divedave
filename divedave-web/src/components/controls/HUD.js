// Mirrors divedave-ios/divedave Shared/Components/Controls/HUD.swift.
// Phase 0 only renames the class (MobileControls → HUD) so the file
// layout matches iOS. Behavior is unchanged: jumpControls()/
// flipControls() toggle visibility one at a time. Phase 3 will switch
// to the iOS stacked-button layout (both buttons always rendered,
// gated by enabled state driven from DaveState).

import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { ControlButton } from "./ControlButton.js";

export class HUD {
  constructor(scene) {
    this.leftButton = scene.add.existing(
      new ControlButton(scene, 175, HEIGHT - 150, "controls-left")
    );
    this.rightButton = scene.add.existing(
      new ControlButton(scene, 450, HEIGHT - 150, "controls-right")
    );
    this.jumpButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, HEIGHT - 150, "controls-jump")
    );
    this.flipButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, HEIGHT - 150, "controls-flip")
    );
    this.flipButton.setVisible(false);
  }

  setVisible(visible) {
    this.leftButton.setVisible(visible);
    this.rightButton.setVisible(visible);
    this.jumpButton.setVisible(visible);
    this.flipButton.setVisible(visible);
  }

  jumpControls() {
    this.jumpButton.setVisible(true);
    this.flipButton.setVisible(false);
  }

  flipControls() {
    this.flipButton.setVisible(true);
    this.jumpButton.setVisible(false);
  }
}
