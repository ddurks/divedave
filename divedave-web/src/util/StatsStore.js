// Mirrors divedave-ios/divedave Shared/Util/StatsStore.swift.
//
// iOS uses UserDefaults; the web has long used a cookie, which we keep
// behind a tiny adapter so Phase 0 stays a pure refactor. A localStorage
// migration is straightforward and can land later.

import { HIGH_SCORE_KEY } from "./Constants.js";

function createCookie(name, value, days) {
  let expires = "";
  if (days) {
    const date = new Date();
    date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
    expires = "; expires=" + date.toGMTString();
  }
  document.cookie = name + "=" + value + expires + "; path=/";
}

function readCookie(name) {
  const nameEQ = name + "=";
  const ca = document.cookie.split(";");
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) === " ") c = c.substring(1, c.length);
    if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
}

export const StatsStore = {
  loadHighScore() {
    const raw = readCookie(HIGH_SCORE_KEY);
    return raw ? Number(raw) : 0;
  },

  saveHighScore(value) {
    createCookie(HIGH_SCORE_KEY, value, 400);
  },
};
