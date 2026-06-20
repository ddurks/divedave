import { HEIGHT, WIDTH } from "../../util/Constants.js";
import { Haptics } from "../../util/Haptics.js";
import { IS_MOBILE } from "../../util/Utilities.js";

const REVEAL_BEAT_MS = 400;
const REVEAL_TWEEN_MS = 200;

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

    this.panel.setVisible(true);
    this.daveimage.setFrame(frame);
    this.daveimage.setVisible(true);
    this.tryAgain.setPosition(WIDTH / 2, sceneHeight - 100);

    if (!scores) {
      this.score1.setVisible(false);
      this.score2.setVisible(false);
      this.score3.setVisible(false);
      this.tryAgain.setVisible(false);
      return;
    }

    const signs = [this.score1, this.score2, this.score3];
    const numberLabels = scores.map((score, i) =>
      scene.add
        .bitmapText(
          WIDTH / 2 - 275 + i * 275,
          HEIGHT / 2 + 325,
          "red-arial",
          score,
          100
        )
        .setOrigin(0.5)
        .setDepth(this.baseDepth + 3)
        .setScrollFactor(0)
        .setAlpha(0)
        .setScale(0.3)
    );

    signs.forEach((sign) => {
      sign.setVisible(true).setAlpha(0).setScale(0.3);
    });
    this.tryAgain.setVisible(true).setAlpha(0);

    const isStillValid = (obj) => obj && obj.active;

    scores.forEach((_score, idx) => {
      scene.time.delayedCall(REVEAL_BEAT_MS * (idx + 1), () => {
        if (!isStillValid(signs[idx]) || !isStillValid(numberLabels[idx])) {
          return;
        }
        Haptics.impactMedium();
        scene.tweens.add({
          targets: [signs[idx], numberLabels[idx]],
          alpha: 1,
          scaleX: { from: 0.3, to: 1.0 },
          scaleY: { from: 0.3, to: 1.0 },
          ease: "Back.easeOut",
          duration: REVEAL_TWEEN_MS,
        });
      });
    });

    scene.time.delayedCall(REVEAL_BEAT_MS * (scores.length + 1), () => {
      if (!isStillValid(this.tryAgain)) return;
      scene.tweens.add({
        targets: this.tryAgain,
        alpha: 1,
        duration: REVEAL_TWEEN_MS,
      });
    });
  }

  close() {
    this.tryAgain.setVisible(false);
    this.panel.setVisible(false);
    this.daveimage.setVisible(false);
    this.score1.setVisible(false);
    this.score2.setVisible(false);
    this.score3.setVisible(false);
  }
}
