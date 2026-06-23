import {
  BOOST_GOOD_MS,
  BOOST_OK_MS,
  BOOST_PERFECT_MS,
  MAX_SPIN_VELOCITY,
} from "../../util/Constants.js";
import { getRandomIntInclusive } from "../../util/Utilities.js";

export const DiveResult = Object.freeze({
  Success: "success",
  Failure: "failure",
});

export const BoostTiming = Object.freeze({
  Perfect: "perfect",
  Good: "good",
  Ok: "ok",
  Miss: "miss",
});

export function classifyBoostTiming(quicknessMs) {
  if (quicknessMs < BOOST_PERFECT_MS) return BoostTiming.Perfect;
  if (quicknessMs < BOOST_GOOD_MS) return BoostTiming.Good;
  if (quicknessMs < BOOST_OK_MS) return BoostTiming.Ok;
  return BoostTiming.Miss;
}

export function scoreDive({ goalRotations, rotations, angle, tuckCount }) {
  if (Math.abs(rotations - goalRotations) >= 0.25) {
    return { result: DiveResult.Failure, scores: [0, 0, 0], emotionFrame: 0 };
  }

  const baseFrame = chooseEmotionFrame(angle);
  const scores = [0, 1, 2].map(() => scoreForFrame(baseFrame, tuckCount));

  const emotionFrame = tuckCount > 1 ? baseFrame - 1 : baseFrame;
  return { result: DiveResult.Success, scores, emotionFrame };
}

function scoreForFrame(frame, tuckCount) {
  switch (frame) {
    case 4:
      return Math.trunc(10 - getRandomIntInclusive(0, 1) / 2.0 - (tuckCount - 1));
    case 3:
      return Math.trunc(10 - getRandomIntInclusive(3, 6) / 2.0 - (tuckCount - 1));
    case 2:
      return Math.trunc(10 - getRandomIntInclusive(7, 10) / 2.0 - (tuckCount - 1));
    case 1:
      return Math.trunc(10 - getRandomIntInclusive(10, 15) / 2.0 - (tuckCount - 1));
    case 0:
      return Math.trunc(10 - getRandomIntInclusive(14, 18) / 2.0 - (tuckCount - 1));
    default:
      return 0;
  }
}

export function chooseEmotionFrame(angle) {
  const a = Math.abs(angle);
  if (a < 10 || a > 170) return 4;
  if ((a >= 10 && a < 25) || (a <= 170 && a > 155)) return 3;
  if ((a >= 25 && a < 45) || (a <= 155 && a > 135)) return 2;
  if ((a >= 45 && a < 70) || (a <= 135 && a > 110)) return 1;
  if (a >= 70 && a < 110) return 0;
  return 2;
}

export function heightInMeters(springboardY, waterY) {
  const heightDifference = waterY - springboardY;
  const inMeters = heightDifference / 200.0;
  return Math.round(inMeters * 10) / 10;
}

// Dive height (metres) → number of half-flips the goal may ask for. A tuning
// heuristic, not real physics; computed in iOS's reference-screen space (852/3000)
// so the curve is identical to native. Mirrors DiveScorer.swift goalHalfFlips
// (parity-tested); the 852/3000 must track iOS Game.referenceScreenHeight.
export function goalHalfFlips(heightMeters) {
  const referenceScale = 852 / 3000;
  const diveHeight = heightMeters * 200 * referenceScale;
  const waterLevel = (256 * referenceScale) / 2 + 1;
  const distance = Math.max(0, diveHeight - waterLevel);
  const time = Math.sqrt(distance) / 10;
  const totalRotation = (time * MAX_SPIN_VELOCITY * 0.7 * Math.PI) / 180;
  return Math.floor((totalRotation / (2 * Math.PI)) * 2);
}
