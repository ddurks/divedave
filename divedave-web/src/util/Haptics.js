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
