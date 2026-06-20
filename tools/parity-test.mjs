#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const fixtures = JSON.parse(readFileSync(resolve(HERE, "parity-fixtures.json"), "utf8"));

Object.defineProperty(globalThis, "navigator", {
  value: { userAgent: "node" },
  configurable: true,
  writable: true,
});
const scorerPath = resolve(HERE, "../divedave-web/src/components/scene/DiveScorer.js");
const { chooseEmotionFrame, classifyBoostTiming, scoreDive } = await import(scorerPath);

let failed = 0;
let passed = 0;
const failures = [];

function check(label, expected, actual) {
  if (expected === actual) {
    passed++;
    return;
  }
  failed++;
  failures.push(`  ${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

for (const c of fixtures.chooseEmotionFrame) {
  check(`chooseEmotionFrame(${c.angle})`, c.expected, chooseEmotionFrame(c.angle));
}

for (const c of fixtures.classifyBoostTiming) {
  check(`classifyBoostTiming(${c.quicknessMs})`, c.expected, classifyBoostTiming(c.quicknessMs));
}

for (const c of fixtures.scoreDive) {
  const out = scoreDive(c.input);
  const input = JSON.stringify(c.input);
  check(`scoreDive(${input}).result`, c.expectedResult, out.result);
  check(`scoreDive(${input}).emotionFrame`, c.expectedEmotionFrame, out.emotionFrame);
}

console.log(`[js]  ${passed} passed, ${failed} failed`);
if (failed) {
  for (const f of failures) console.log(f);
  process.exit(1);
}
