// Mirrors divedave-ios/divedave Shared/Components/Controls/HUD.swift.
//
// Both jump and flip are always rendered (flip stacked above jump) and
// driven by enabled state via updateButtons(jumpEnabled, flipEnabled),
// matching iOS. The old jumpControls()/flipControls() toggle pattern is
// gone — input gating happens in DavePlayer's tryJump/applyTuck state
// checks, not button visibility.

import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { ControlButton } from "./ControlButton.js";

// Layout. The control sprites are scaled to 0.5 in ControlButton; the
// raw texture is 512×512, so each on-screen button is ~256 tall. Stack
// flip above jump with a small gap so the two read as separate hit
// targets.
const BUTTON_SCREEN_HEIGHT = 256;
const STACK_GAP = 20;
const JUMP_Y = HEIGHT - 150;
const FLIP_Y = JUMP_Y - BUTTON_SCREEN_HEIGHT - STACK_GAP;

export class HUD {
  constructor(scene) {
    this.leftButton = scene.add.existing(
      new ControlButton(scene, 175, HEIGHT - 150, "controls-left")
    );
    this.rightButton = scene.add.existing(
      new ControlButton(scene, 450, HEIGHT - 150, "controls-right")
    );
    this.jumpButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, JUMP_Y, "controls-jump")
    );
    this.flipButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, FLIP_Y, "controls-flip")
    );
  }

  setVisible(visible) {
    this.leftButton.setVisible(visible);
    this.rightButton.setVisible(visible);
    this.jumpButton.setVisible(visible);
    this.flipButton.setVisible(visible);
  }

  /**
   * Drive the visual enabled/disabled state of the jump and flip
   * buttons from the caller's input-eligibility logic. Both buttons
   * remain visible at all times; the disabled one greys out.
   */
  updateButtons(jumpEnabled, flipEnabled) {
    this.jumpButton.setEnabled(jumpEnabled);
    this.flipButton.setEnabled(flipEnabled);
  }
}
