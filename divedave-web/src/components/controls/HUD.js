import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { Haptics } from "../../util/Haptics.js";
import { IS_MOBILE } from "../../util/Utilities.js";
import { ControlButton } from "./ControlButton.js";

const BUTTON_SCREEN_HEIGHT = 256;
const STACK_GAP = 20;
const JUMP_Y = HEIGHT - 150;
const FLIP_Y = JUMP_Y - BUTTON_SCREEN_HEIGHT - STACK_GAP;
const MOVE_HINT_X = 312;
const MOVE_HINT_Y = HEIGHT - 150;

export class HUD {
  constructor(scene) {
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

    this.jumpButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, JUMP_Y, "controls-jump")
    );
    this.flipButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, FLIP_Y, "controls-flip")
    );

    // Menu button matches the sign's width (both 256-px native frames,
    // both rendered at scale 1.0). y ≈ sign.y + 0.675 * signHeight,
    // mirroring the iOS HUD layout where the menu button sits below
    // the sign with overlap on the transparent padding but a clean gap
    // between the visible artwork.
    this.menuButton = scene.add.existing(
      new ControlButton(scene, 125, 283, "menu-button", 1)
    );
    this.menuButton.setScale(1.0);
    this.onMenuPressed = null;
    // Guard against repeated presses during the click animation queuing
    // multiple ANIMATION_COMPLETE handlers and firing the transition
    // more than once.
    this._menuHandled = false;
    this.menuButton.onPressed = () => {
      if (this._menuHandled) return;
      this._menuHandled = true;
      Haptics.impactLight();
      this.menuButton.play("menuClicked");
      this.menuButton.once(
        Phaser.Animations.Events.ANIMATION_COMPLETE,
        () => this.onMenuPressed && this.onMenuPressed()
      );
    };

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

  setVisible(visible) {
    this.jumpButton.setVisible(visible);
    this.flipButton.setVisible(visible);
    this.menuButton.setVisible(visible);
    if (IS_MOBILE) {
      this.leftButton.setVisible(visible);
      this.rightButton.setVisible(visible);
    } else {
      this.moveHint.setVisible(visible);
    }
  }

  updateButtons(jumpEnabled, flipEnabled) {
    this.jumpButton.setEnabled(jumpEnabled);
    this.flipButton.setEnabled(flipEnabled);
  }
}
