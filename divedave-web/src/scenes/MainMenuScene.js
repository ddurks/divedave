import { HEIGHT, WIDTH } from "../util/Constants.js";
import { GameState } from "../util/GameState.js";
import { Haptics } from "../util/Haptics.js";
import { fadeOutScene, getRandomInt } from "../util/Utilities.js";
import { MenuDave } from "../components/menu/MenuDave.js";

export class MainMenuScene extends Phaser.Scene {
  constructor() {
    super("MainMenu");
  }

  preload() {
    this.load.spritesheet("dave", "assets/divedave-spritesheet-extruded.png", {
      frameWidth: 256,
      frameHeight: 256,
      margin: 1,
      spacing: 2,
    });
    this.load.image("cover", "assets/cover.png");
    this.load.image("panel", "assets/panel.png");
    this.load.image("controls-help", "assets/controls-help.png");
    this.load.image("controls", "assets/controls.png");
    this.load.image("arcade", "assets/arcade.png");
    this.load.image("challenge", "assets/challenge.png");
    this.load.image("sign", "assets/sign.png");
    this.load.bitmapFont(
      "black-arial",
      "assets/fonts/black-arial.png",
      "assets/fonts/black-arial.xml"
    );
  }

  displayInstructions() {
    if (this.instructionsGroup) return;
    // Same illustrated splash as mobile: the controls image has transparent
    // margins, so the panel border frames it (matches the iOS layout).
    const panel = this.add
      .image(WIDTH / 2, HEIGHT / 2 - 45, "panel")
      .setScrollFactor(0)
      .setDepth(20);
    const controls = this.add
      .image(WIDTH / 2, HEIGHT / 2 - 45, "controls")
      .setScrollFactor(0)
      .setDepth(21);
    // Full-screen catcher above the splash: any tap dismisses it (and blocks
    // taps from reaching the menu buttons underneath), matching mobile.
    const dismiss = this.add
      .zone(0, 0, WIDTH, HEIGHT)
      .setOrigin(0)
      .setScrollFactor(0)
      .setDepth(22)
      .setInteractive();
    dismiss.on("pointerdown", () => this.hideInstructions());
    this.instructionsGroup = [dismiss, controls, panel];
  }

  hideInstructions() {
    if (!this.instructionsGroup) return;
    this.instructionsGroup.forEach((o) => o.destroy());
    this.instructionsGroup = null;
  }

  create() {
    this.input.keyboard.on("keydown", this.handleKey, this);
    const cover = this.add.image(WIDTH / 2, HEIGHT / 2 - 250, "cover");
    cover.setScale(1.5);
    const instructions = this.add
      .image(WIDTH - 100, 100, "controls-help")
      .setOrigin(0.5)
      .setScale(0.5);
    instructions
      .setInteractive({ useHandCursor: true })
      .on("pointerdown", () => {
        this.pressButton(instructions, () => this.displayInstructions());
      });
    const startText = this.add
      .image(WIDTH / 2 + 200, HEIGHT / 2 + 250, "arcade")
      .setOrigin(0.5)
      .setScale(0.5);
    startText.setInteractive({ useHandCursor: true }).on("pointerdown", () => {
      GameState.challengeMode = false;
      this.pressButton(startText, () => this.clickStart(this));
    });
    const startChallengeText = this.add
      .image(WIDTH / 2 - 200, HEIGHT / 2 + 250, "challenge")
      .setOrigin(0.5)
      .setScale(0.5);
    startChallengeText
      .setInteractive({ useHandCursor: true })
      .on("pointerdown", () => {
        GameState.challengeMode = true;
        this.pressButton(startChallengeText, () => this.clickStart(this));
      });
    if (GameState.highScore > 0) {
      this.add
        .image(125, 110, "sign")
        .setRotation(Math.PI)
        .setDepth(23)
        .setScrollFactor(0);
      this.add
        .bitmapText(125, 60, "black-arial", "YOUR CHALLENGE", 20)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
      this.add
        .bitmapText(125, 90, "black-arial", "HIGH SCORE", 30)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
      this.add
        .bitmapText(125, 150, "black-arial", GameState.highScore, 50)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
    }

    this.menuDave = new MenuDave(this, {
      // Feet sit at the frame's bottom edge; a half-frame (128 at scale 1) up
      // puts his bottom edge flush with the bottom of the screen.
      y: HEIGHT - 128,
      leftBound: 150,
      rightBound: WIDTH - 150,
      scale: 1,
    });
  }

  update(time, delta) {
    if (this.menuDave) this.menuDave.update(delta);
  }

  handleKey(e) {
    if (e.code === "Enter") this.clickStart(this);
  }

  pressButton(button, action) {
    Haptics.impactLight();
    const base = button.scaleX;
    this.tweens.chain({
      targets: button,
      tweens: [
        { scaleX: base * 1.25, scaleY: base * 1.25, duration: 500 },
        { scaleX: base, scaleY: base, duration: 500 },
      ],
      onComplete: action,
    });
  }

  clickStart(scene) {
    if (GameState.challengeMode) {
      fadeOutScene("DiveScene", scene, 1500);
    } else {
      fadeOutScene("DiveScene", scene, getRandomInt(1500, 10000));
    }
  }
}
