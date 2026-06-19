// Mirrors divedave-ios/divedave Shared/Util/Haptics.swift. The web has
// no UIImpactFeedbackGenerator; we use navigator.vibrate where it
// exists (Chrome/Android) and silently no-op elsewhere (iOS Safari).
//
// Patterns are picked to roughly match the *intent* of each iOS
// generator, not its exact tactile profile.

function buzz(pattern) {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate(pattern);
  }
}

export const Haptics = {
  impactLight: () => buzz(10),
  impactMedium: () => buzz(20),
  impactHeavy: () => buzz(30),
  notificationSuccess: () => buzz([10, 50, 30]),
  notificationError: () => buzz([30, 50, 30, 50, 30]),
};
