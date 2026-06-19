// Mirrors divedave-ios/divedave Shared/Util/GameState.swift.
// ES modules give us a single instance per import, which matches the
// @MainActor singleton on the iOS side.
//
// Per-dive transients that belong to the player (jumping, landedAt,
// jumpReleasedAt, boost, currentVelocity, tucked, tuckCount) moved onto
// DavePlayer in Phase 1. What remains is genuinely scene/session scope.

export const GameState = {
  // Mode
  challengeMode: true,

  // Session totals (survive scene restarts within a session)
  streak: 0,
  totalScore: 0,
  highScore: 0,
  highScoreSession: false,

  // Shared sprite handles. iOS scopes these to the relevant components;
  // we'll migrate them off GameState as those components land (Springboard,
  // Water, etc. in later phases). `dave` is set during DiveScene.create
  // only for legacy hand-offs and will be removed entirely once nothing
  // outside DavePlayer touches it.
  springboard: null,
  dave: null,
  controls: null,
  waterLevel: null,
};
