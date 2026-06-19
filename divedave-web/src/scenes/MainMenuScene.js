// Mirrors divedave-ios/divedave Shared/Scenes/MainMenuScene.swift.
// Phase 0 verbatim move from divedave.js (renamed from MainMenu →
// MainMenuScene to match the iOS file name).

import { HEIGHT, WIDTH } from "../util/Constants.js";
import { GameState } from "../util/GameState.js";
import { Haptics } from "../util/Haptics.js";
import { fadeOutScene, getRandomInt, IS_MOBILE } from "../util/Utilities.js";

export class MainMenuScene extends Phaser.Scene {
  constructor() {
    super("MainMenu");
  }

  preload() {
    this.load.image("cover", "assets/cover.png");
    this.load.image("panel", "assets/panel.png");
    this.load.image("controls-help", "assets/controls-help.png");
    this.load.image("arcade", "assets/arcade.png");
    this.load.image("challenge", "assets/challenge.png");
    this.load.image("sign", "assets/sign.png");
    this.load.bitmapFont(
      "black-arial",
      "assets/fonts/black-arial.png",
      "assets/fonts/black-arial.xml"
    );
  }

  displayInstructions(strings) {
    this.add
      .image(WIDTH / 2, HEIGHT / 2 - 45, "panel")
      .setVisible(true)
      .setScrollFactor(0)
      .setDepth(20);
    let height = HEIGHT / 2 - 450;
    strings.forEach((string) => {
      this.add
        .text(WIDTH / 2, height, string, {
          align: "center",
          color: "white",
          fontFamily: "Arial",
          fontSize: "55px",
          fontStyle: "bold",
        })
        .setOrigin(0.5)
        .setScrollFactor(0)
        .setDepth(21);
      height += 75;
    });
  }

  create() {
    const instructionStrings = IS_MOBILE
      ? [
          "touch left and right buttons",
          "to move dave",
          "",
          "touch the jump button to jump",
          "while above the board",
          "",
          "jump quickly multiple times",
          "near the end of the board",
          "to jump higher",
          "",
          "touch the flip button to flip",
          "once dave has left the board",
        ]
      : [
          "[A] and [D] or [<] [>] arrow keys",
          "to move dave",
          "",
          "[W] or [^] arrow key to jump",
          "while above the board",
          "",
          "jump quickly multiple times",
          "near the end of the board",
          "to jump higher",
          "",
          "[R] [^] or [space] to flip",
          "once dave has left the board",
        ];
    this.input.keyboard.on("keydown", this.handleKey, this);
    const cover = this.add.image(WIDTH / 2, HEIGHT / 2 - 75, "cover");
    cover.setScale(2);
    const instructions = this.add
      .image(WIDTH - 100, 100, "controls-help")
      .setOrigin(0.5)
      .setScale(0.5);
    instructions
      .setInteractive({ useHandCursor: true })
      .on("pointerdown", () => {
        this.displayInstructions(instructionStrings);
      });
    const startText = this.add
      .image(WIDTH / 2 + 200, HEIGHT / 2 + 570, "arcade")
      .setOrigin(0.5)
      .setScale(0.5);
    startText.setInteractive({ useHandCursor: true }).on("pointerdown", () => {
      Haptics.impactLight();
      GameState.challengeMode = false;
      this.clickStart(this);
    });
    const startChallengeText = this.add
      .image(WIDTH / 2 - 200, HEIGHT / 2 + 570, "challenge")
      .setOrigin(0.5)
      .setScale(0.5);
    startChallengeText
      .setInteractive({ useHandCursor: true })
      .on("pointerdown", () => {
        Haptics.impactLight();
        this.clickStart(this);
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
  }

  handleKey(e) {
    if (e.code === "Enter") this.clickStart(this);
  }

  clickStart(scene) {
    if (GameState.challengeMode) {
      fadeOutScene("DiveScene", scene, 1500);
    } else {
      fadeOutScene("DiveScene", scene, getRandomInt(1500, 10000));
    }
  }
}
