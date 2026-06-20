# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Project: divedave

Two implementations of the same small game, kept at feature parity:

- `divedave-web/` — Phaser 4 (JavaScript). Served directly from the directory; no bundler. `index.html` loads `src/main.js` as a module.
- `divedave-ios/` — SpriteKit (Swift). Source paths contain spaces (`divedave iOS/`, `divedave Shared/`) — quote them.

When you change behavior in one, check whether the other needs the same change. Do not assume; read the matching file. The numeric tuning values differ between platforms (Phaser pixels vs SpriteKit units), but the *behavior* should match.

**Parity is enforced on:** scoring (`DiveScorer`), tuning constants (gravity, drag, boost windows, spin velocities), scene geometry (board position, spawn point, platform sections), and HUD behavior.

**The game is silent on purpose.** No SFX, no music, ever. Do not propose adding audio. Haptics on iOS are fine.

**High scores** persist via `StatsStore` (localStorage on web, UserDefaults on iOS). Key: `highScore`.

**Cross-platform tooling.** Values that must be byte-identical between the two builds live at the top of each `Constants` file under a `=== Shared with ... ===` block — change one side, mirror it on the other. `tools/run-parity.sh` exercises `DiveScorer` on both sides against `tools/parity-fixtures.json` (covers scoring and boost-window classification); run it after touching scoring or boost-window logic.

