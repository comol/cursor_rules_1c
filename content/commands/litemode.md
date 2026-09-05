---
description: Toggle lightweight QA mode — set VERIFICATION_DEPTH (full|standard|lite) in .dev.env and, at level lite, disable UI testing (UI_TESTING=off)
argumentHint: "[on|off|full|standard|lite|status]"
---

# /litemode — lightweight QA mode

Toggle how much static verification and UI testing the agent runs for the **project** by writing `VERIFICATION_DEPTH` (and, coupled, `UI_TESTING`) in `.dev.env`. Canonical behaviour of the depth levels — `content/rules/verification-policy.md → "Verification depth levels"` (installed copy; match by file name per the path convention in `AGENTS.md`). Load `verification-policy.md` before acting.

Parameters, classes and defaults — `content/rules/dev-standards-env.md §1`; Defaulted keys are never asked for.

Parse the argument: empty or `on` / `lite` — enable lite; `standard` — set the standard level; `off` — same as `standard` (plus the `UI_TESTING` restore below); `full` — set the strictest level explicitly; `status` — report the current state without editing.

The command edits **only** the `VERIFICATION_DEPTH` and (as described below) `UI_TESTING` lines in `.dev.env` — never other keys, never other files. Rewrite the `KEY=` line in place, or append `KEY=value` at the end; if `.dev.env` is missing, run the installer (`install.ps1 init`) instead of creating a partial file — until then apply the level for the current session only.

## on / lite (default)

1. Read `.dev.env`: `VERIFICATION_DEPTH` and `UI_TESTING`.
2. Set `VERIFICATION_DEPTH=lite`.
3. **UI-testing coupling.** Lite means "minimal QA, no browser UI tests". Set `UI_TESTING=off`. If `UI_TESTING` was `auto`, note in the confirmation that automatic UI testing is now disabled (so the user is aware it will not run after a deploy).
4. **No re-render needed.** `VERIFICATION_DEPTH` and `UI_TESTING` are read directly from `.dev.env` by the rules at task time — editing the file is enough, no `install.ps1 update` and no client restart.
5. Load the `verification-policy.md` rule and apply the lite semantics immediately — from this message on, in this session.
6. Confirm to the user in 3–4 lines, in Russian:
   - режим облегчённых проверок включён и записан в `.dev.env` (`VERIFICATION_DEPTH=lite`) — действует для проекта, включая новые чаты;
   - что именно облегчается и что остаётся обязательным — одной строкой по канону `verification-policy.md`;
   - UI-тесты отключены (`UI_TESTING=off`);
   - выключение — `/litemode off`.

## standard (also: `off`)

1. Set `VERIFICATION_DEPTH=standard`. If `.dev.env` or the key is absent, there is nothing to persist.
2. **UI-testing restore (only for `off`).** If the argument was `off` and `UI_TESTING` is currently `off`, set it back to `manual` so UI tests are again available on explicit request; if it holds any other value, leave it untouched. State the resulting `UI_TESTING` value in the confirmation (if the user previously ran `auto`, they must re-set it manually — the command cannot know the pre-lite value). For an explicit `standard` argument do **not** touch `UI_TESTING` — report its current effective value.
3. Apply immediately and confirm in one line what the level means (canon `verification-policy.md`).

## full

1. Set `VERIFICATION_DEPTH=full`. Do **not** touch `UI_TESTING` — report its current effective value.
2. Stop applying the lite/standard semantics immediately in this session and confirm in one line: максимальная глубина проверок включена (`VERIFICATION_DEPTH=full`).

## status

Read `.dev.env` and report, without editing anything:

- the `VERIFICATION_DEPTH` value (or the default when the file / key is absent or the value is invalid) and what it means;
- the `UI_TESTING` value and whether UI tests run automatically, on request, or are disabled.

## Constraints (always)

The mode never overrides the safety floor of `verification-policy.md → "Verification depth levels"`: `syntaxcheck` (Gate 1) always runs on every touched BSL module, promotion-trigger paths (`verification-policy.md → Triage details`) always get the full chain, and Gates 4 / 5 are unaffected by `VERIFICATION_DEPTH`. `UI_TESTING=off` set by lite behaves exactly like a manually set `off` (`dev-standards-env.md → "UI_TESTING"`).
