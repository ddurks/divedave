import { HEIGHT, WIDTH } from "../util/Constants.js";
import { GameState } from "../util/GameState.js";
import { fadeOutScene } from "../util/Utilities.js";
import { MenuDave } from "../components/menu/MenuDave.js";

const APP_STORE_URL = "https://apps.apple.com/us/app/dive-dave/id6781949245";

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
    this.load.svg("appstore-badge", "assets/appstore-badge.svg", { scale: 8 });
    this.load.bitmapFont(
      "drawvid-handwriting-black",
      "assets/fonts/drawvid-handwriting-black.png",
      "assets/fonts/drawvid-handwriting-black.xml"
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
    this.starting = false;
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
        .bitmapText(125, 60, "drawvid-handwriting-black", "YOUR CHALLENGE", 20)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
      this.add
        .bitmapText(125, 90, "drawvid-handwriting-black", "HIGH SCORE", 30)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
      this.add
        .bitmapText(125, 150, "drawvid-handwriting-black", GameState.highScore, 50)
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(24)
        .setActive(false);
    }

    const appStoreBadge = this.add
      .image(WIDTH / 2, HEIGHT - 130, "appstore-badge")
      .setScale(0.5);
    appStoreBadge.setInteractive({ useHandCursor: true }).on("pointerup", () => {
      // pointerup, not pointerdown: iOS Safari only grants the user activation
      // window.open needs on touchend. And no "noopener" feature string — it
      // would make window.open return null even on success, breaking the
      // blocked-popup fallback below.
      const appStoreTab = window.open(APP_STORE_URL, "_blank");
      if (!appStoreTab) window.location.href = APP_STORE_URL;
    });

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
    if (e.code === "Enter") {
      GameState.challengeMode = true;
      this.clickStart(this);
    }
  }

  pressButton(button, action) {
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
    if (this.starting) return;
    this.starting = true;
    // First dive of either mode is a fixed 3 m opener (matches iOS). Arcade then
    // randomises height on each subsequent dive (resetScene); challenge ramps.
    fadeOutScene("DiveScene", scene, 1500);
  }
}
