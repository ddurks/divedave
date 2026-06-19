// Mirrors divedave-ios/divedave Shared/Components/Menu/InfoPanel.swift.
// Post-dive result overlay: SUCCESS/FAILED text, dave-emotion frame,
// three judge scores, and a tap-to-restart prompt.
//
// Phase 0 is a verbatim move out of divedave.js. Phase 4 will add the
// staggered judge reveal + haptic beats from iOS commit 28a9b52.

import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { IS_MOBILE } from "../../util/Utilities.js";

export class InfoPanel extends Phaser.GameObjects.Group {
  constructor(scene, depth) {
    super(scene);
    this.baseDepth = depth;
    this.panel = scene.add
      .image(WIDTH / 2, HEIGHT / 2, "panel")
      .setVisible(false)
      .setScrollFactor(0)
      .setDepth(this.baseDepth);
    this.daveimage = scene.add
      .sprite(WIDTH / 2, HEIGHT / 2 - 175, "davemotions")
      .setVisible(false)
      .setScrollFactor(0)
      .setScale(2)
      .setFrame(2)
      .setDepth(this.baseDepth + 1);
    this.score1 = scene.add
      .image(WIDTH / 2 - 275, HEIGHT / 2 + 325, "sign")
      .setVisible(false)
      .setScrollFactor(0)
      .setDepth(this.baseDepth + 2);
    this.score2 = scene.add
      .image(WIDTH / 2, HEIGHT / 2 + 325, "sign")
      .setVisible(false)
      .setScrollFactor(0)
      .setDepth(this.baseDepth + 2);
    this.score3 = scene.add
      .image(WIDTH / 2 + 275, HEIGHT / 2 + 325, "sign")
      .setVisible(false)
      .setScrollFactor(0)
      .setDepth(this.baseDepth + 2);
    this.tryAgain = scene.add
      .bitmapText(
        125,
        75,
        "red-arial",
        (IS_MOBILE ? "tap" : "click") + " to dive again",
        65
      )
      .setOrigin(0.5)
      .setDepth(this.baseDepth + 2)
      .setScrollFactor(0)
      .setVisible(false);
  }

  display(scene, result, strings, frame, scores, sceneHeight) {
    let height = HEIGHT / 2 + 5;
    scene.add
      .bitmapText(
        WIDTH / 2,
        height - 375,
        result === "FAILED DIVE" || result === "GAME OVER"
          ? "red-arial"
          : "green-arial",
        result,
        80
      )
      .setOrigin(0.5)
      .setDepth(this.baseDepth + 1)
      .setScrollFactor(0);
    strings.forEach((string) => {
      scene.add
        .bitmapText(
          WIDTH / 2,
          height,
          string.includes("rotations") &&
            (result === "FAILED DIVE" || result === "GAME OVER")
            ? "red-arial"
            : "black-arial",
          string,
          80
        )
        .setOrigin(0.5)
        .setDepth(this.baseDepth + 1)
        .setScrollFactor(0);
      height += 75;
    });
    let width = WIDTH / 2 - 275;
    if (scores) {
      scores.forEach((score) => {
        scene.add
          .bitmapText(width, HEIGHT / 2 + 325, "red-arial", score, 100)
          .setOrigin(0.5)
          .setDepth(this.baseDepth + 3)
          .setScrollFactor(0);
        width += 275;
      });
    }
    this.tryAgain.setPosition(WIDTH / 2, sceneHeight - 100);
    this.tryAgain.setVisible(!!scores);
    this.panel.setVisible(true);
    this.daveimage.setFrame(frame);
    this.daveimage.setVisible(true);
    this.score1.setVisible(!!scores);
    this.score2.setVisible(!!scores);
    this.score3.setVisible(!!scores);
  }

  close() {
    this.tryAgain.setVisible(false);
    this.panel.setVisible(false);
    this.daveimage.setVisible(false);
    this.score1.setVisible(false);
    this.score2.setVisible(true);
    this.score3.setVisible(true);
  }
}
