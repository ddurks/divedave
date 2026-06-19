// Mirrors divedave-ios/divedave Shared/Components/Scene/DiveScorer.swift.
//
// Pure dive-scoring math. No scene/HUD/persistence side effects —
// DiveScene handles those at the call site. Keeping this pure makes
// it easy to reason about and lets tests exercise it without spinning
// up a Phaser scene.

import { getRandomInt } from "../../util/Utilities.js";

export const DiveResult = Object.freeze({
  Success: "success",
  Failure: "failure",
});

/**
 * Compute the dive's outcome from raw flight data.
 * @param {object} args
 * @param {number} args.goalRotations
 * @param {number} args.rotations
 * @param {number} args.angle - degrees, signed
 * @param {number} args.tuckCount
 * @returns {{result: 'success'|'failure', scores: [number, number, number], emotionFrame: number}}
 */
export function scoreDive({ goalRotations, rotations, angle, tuckCount }) {
  if (Math.abs(rotations - goalRotations) >= 0.25) {
    return { result: DiveResult.Failure, scores: [0, 0, 0], emotionFrame: 0 };
  }

  const baseFrame = chooseEmotionFrame(angle);
  const scores = [0, 1, 2].map(() => scoreForFrame(baseFrame, tuckCount));

  // More than one tuck visually drops Dave's emotion one notch — same
  // penalty the iOS DiveScorer applies after the score math.
  const emotionFrame = tuckCount > 1 ? baseFrame - 1 : baseFrame;
  return { result: DiveResult.Success, scores, emotionFrame };
}

function scoreForFrame(frame, tuckCount) {
  // Tier ranges match iOS: better entry → smaller random deduction.
  // (tuckCount - 1) is the extra-tuck penalty applied uniformly.
  switch (frame) {
    case 4:
      return 10 - getRandomInt(0, 1) / 2.0 - (tuckCount - 1);
    case 3:
      return 10 - getRandomInt(3, 6) / 2.0 - (tuckCount - 1);
    case 2:
      return 10 - getRandomInt(7, 10) / 2.0 - (tuckCount - 1);
    case 1:
      return 10 - getRandomInt(10, 15) / 2.0 - (tuckCount - 1);
    case 0:
      return 10 - getRandomInt(14, 18) / 2.0 - (tuckCount - 1);
    default:
      return 0;
  }
}

/**
 * Map final body angle (degrees) to one of 5 "emotion" frames.
 * 4 = best (vertical, head-down), 0 = worst (horizontal flop).
 */
export function chooseEmotionFrame(angle) {
  const a = Math.abs(angle);
  if (a < 10 || a > 170) return 4;
  if ((a >= 10 && a < 25) || (a <= 170 && a > 155)) return 3;
  if ((a >= 25 && a < 45) || (a <= 155 && a > 135)) return 2;
  if ((a >= 45 && a < 70) || (a <= 135 && a > 110)) return 1;
  if (a >= 70 && a < 110) return 0;
  return 2;
}

/**
 * Display height of the springboard above water, in the HUD's "meters"
 * units. The 200 divisor matches the web's heightFromWater/2/100
 * arithmetic that lived inline in DiveScene before extraction.
 */
export function heightInMeters(springboardY, waterY) {
  const heightDifference = waterY - springboardY;
  const inMeters = heightDifference / 200.0;
  return Math.round(inMeters * 10) / 10;
}
