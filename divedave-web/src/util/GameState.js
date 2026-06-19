// Mirrors divedave-ios/divedave Shared/Util/GameState.swift.
// ES modules give us a single instance per import, which matches the
// @MainActor singleton on the iOS side.
//
// This holds the mutable globals that used to sit at module-level in
// divedave.js. Phase 0 keeps the same field names; later phases will
// migrate to the iOS field names (e.g. jumpReleasedAt → jumpReleasedAt
// already matches, but stats → DiveStats wrapper, etc.).

import { MIN_SPIN_VELOCITY } from "./Constants.js";

export const GameState = {
  challengeMode: true,

  // Dive-in-progress transients
  jumping: false,
  landedAt: null,
  jumpReleasedAt: null,
  boost: 0,
  currentVelocity: MIN_SPIN_VELOCITY,
  tucked: false,
  tuckCount: 0,

  // Session totals
  streak: 0,
  totalScore: 0,
  highScore: 0,
  highScoreSession: false,

  // Shared sprite handles (set during DiveScene.create). Keeping these
  // here matches the iOS pattern where DavePlayer/Springboard expose
  // their nodes via the scene. They will move onto DavePlayer.js etc.
  // in Phase 1.
  springboard: null,
  dave: null,
  controls: null,
  waterLevel: null,
};
