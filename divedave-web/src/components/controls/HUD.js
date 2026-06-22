import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { IS_MOBILE, makeShadowedBitmapText } from "../../util/Utilities.js";
import { ControlButton } from "./ControlButton.js";

const BUTTON_SCREEN_HEIGHT = 256;
const STACK_GAP = 20;
const JUMP_Y = HEIGHT - 150;
const FLIP_Y = JUMP_Y - BUTTON_SCREEN_HEIGHT - STACK_GAP;
const MOVE_HINT_X = 40;
const MOVE_HINT_Y = HEIGHT - 40;

export class HUD {
  constructor(scene) {
    this.leftButton = scene.add.existing(
      new ControlButton(scene, 175, HEIGHT - 150, "controls-left"),
    );
    this.rightButton = scene.add.existing(
      new ControlButton(scene, 450, HEIGHT - 150, "controls-right"),
    );
    this.moveHint = makeShadowedBitmapText(
      scene,
      MOVE_HINT_X,
      MOVE_HINT_Y,
      "red-arial",
      "[A] [D]  or  [<] [>]  to walk",
      40,
      3,
    )
      .setScrollFactor(0)
      .setDepth(14);
    // Anchor to the bottom-left instead of the helper's default centered
    // origin (shadow stays offset down-right for the drop-shadow effect).
    this.moveHint.list.forEach((t) => t.setOrigin(0, 1));
    // Plaque behind the hint: platform-grey fill (#9badb7, the diving-board
    // platform's main grey) with a chunky black border. Added as the first
    // container child so it renders behind the text and inherits the hint's
    // position and visibility.
    const hintText = this.moveHint.list[this.moveHint.list.length - 1];
    const HINT_PAD = 16;
    const plaque = scene.add
      .graphics()
      .fillStyle(0x9badb7, 1)
      .lineStyle(5, 0x000000, 1);
    const px = -HINT_PAD;
    const py = -hintText.height - HINT_PAD;
    const pw = hintText.width + HINT_PAD * 2;
    const ph = hintText.height + HINT_PAD * 2;
    plaque.fillRoundedRect(px, py, pw, ph, 18);
    plaque.strokeRoundedRect(px, py, pw, ph, 18);
    this.moveHint.addAt(plaque, 0);

    this.jumpButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, JUMP_Y, "controls-jump"),
    );
    this.flipButton = scene.add.existing(
      new ControlButton(scene, WIDTH - 175, FLIP_Y, "controls-flip"),
    );

    // Menu button matches the sign's width (both 256-px native frames,
    // both rendered at scale 1.0). y is tuned for the web art so the MENU
    // board hangs from the sign by its visible chains (≈ sign.y + 0.80 *
    // signHeight); iOS uses the sign-xl asset and needs its own offset.
    this.menuButton = scene.add.existing(
      new ControlButton(scene, 125, 315, "menu-button", 1),
    );
    this.menuButton.setScale(1.0);
    this.menuButton.growsOnPress = false;
    this.onMenuPressed = null;
    // Guard against repeated presses during the click animation queuing
    // multiple ANIMATION_COMPLETE handlers and firing the transition
    // more than once.
    this._menuHandled = false;
    this.menuButton.onPressed = () => {
      if (this._menuHandled) return;
      this._menuHandled = true;
      this.menuButton.play("menuClicked");
      this.menuButton.once(
        Phaser.Animations.Events.ANIMATION_COMPLETE,
        () => this.onMenuPressed && this.onMenuPressed(),
      );
    };

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
