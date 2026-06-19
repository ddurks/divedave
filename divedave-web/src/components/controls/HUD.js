// Mirrors divedave-ios/divedave Shared/Components/Controls/HUD.swift.
//
// Both jump and flip are always rendered (flip stacked above jump) and
// driven by enabled state via updateButtons(jumpEnabled, flipEnabled),
// matching iOS. The old jumpControls()/flipControls() toggle pattern is
// gone — input gating happens in DavePlayer's tryJump/applyTuck state
// checks, not button visibility.

import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { Haptics } from "../../util/Haptics.js";
import { IS_MOBILE } from "../../util/Utilities.js";
import { ControlButton } from "./ControlButton.js";

// Layout. The control sprites are scaled to 0.5 in ControlButton; the
// raw texture is 512×512, so each on-screen button is ~256 tall. Stack
// flip above jump with a small gap so the two read as separate hit
// targets.
const BUTTON_SCREEN_HEIGHT = 256;
const STACK_GAP = 20;
const JUMP_Y = HEIGHT - 150;
const FLIP_Y = JUMP_Y - BUTTON_SCREEN_HEIGHT - STACK_GAP;
// Hint text replaces the left/right buttons on desktop, where keyboard
// drives movement. Same Y as those buttons so layouts read consistently.
const MOVE_HINT_X = 312;
const MOVE_HINT_Y = HEIGHT - 150;

export class HUD {
  constructor(scene) {
    // Movement input. Mobile: tap buttons. Desktop: keyboard with a
    // hint label in the same slot so the bottom-left area isn't an
    // empty void. Both branches still construct symmetric handles so
    // upstream code can read isDown on the (potentially hidden)
    // buttons without null-checking.
    this.leftButton = scene.add.existing(
      new ControlButton(scene, 175, HEIGHT - 150, "controls-left")
    );
    this.rightButton = scene.add.existing(
      new ControlButton(scene, 450, HEIGHT - 150, "controls-right")
    );
    this.moveHint = scene.add
      .bitmapText(
        MOVE_HINT_X,
        MOVE_HINT_Y,
        "black-arial",
        "[A] [D]  or  [<] [>]  to move",
        40
      )
      .setOrigin(0.5)
      .setScrollFactor(0)
      .setDepth(14);

    // Action buttons live on both platforms — desktop players click
    // them the same way mobile players tap them.
    this.jumpButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, JUMP_Y, "controls-jump")
    );
    this.flipButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, FLIP_Y, "controls-flip")
    );

    // Press haptics on every control button — matches the iOS feel.
    // setEnabled() only affects the visual; touches still register, so
    // pressing a greyed-out button still gives the user feedback.
    for (const b of [
      this.leftButton,
      this.rightButton,
      this.jumpButton,
      this.flipButton,
    ]) {
      b.onPressed = () => Haptics.impactLight();
    }
    this.jumpButton.onReleased = () => Haptics.impactMedium();

    if (IS_MOBILE) {
      this.moveHint.setVisible(false);
    } else {
      this.leftButton.setVisible(false);
      this.rightButton.setVisible(false);
    }
  }

  /** Hide all HUD elements (used during the post-dive result panel). */
  setVisible(visible) {
    this.jumpButton.setVisible(visible);
    this.flipButton.setVisible(visible);
    if (IS_MOBILE) {
      this.leftButton.setVisible(visible);
      this.rightButton.setVisible(visible);
    } else {
      this.moveHint.setVisible(visible);
    }
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
