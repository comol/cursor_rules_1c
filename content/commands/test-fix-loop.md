---
description: Closed deploy → test → fix → redeploy loop against the test infobase, until the scenarios pass or the iteration budget is exhausted
argumentHint: "[<scenario / task description>] [--iterations N]"
---

# /test-fix-loop — deploy → test → fix → redeploy until green

Run the requested test scenarios against the test infobase and, when they fail, close the loop: diagnose → fix the code → redeploy → re-test — until every scenario passes or the iteration budget runs out. This is the *outer* loop over test failures; the *inner* retry loop for deploy errors stays where it lives (`/update1cbase → Update retry loop`) and does not consume test iterations.

**Strictly opt-in.** This loop runs only when invoked as a command or explicitly requested in words. It is never an automatic stage of the subagent pipeline or the verification phase (`subagent-pipeline.md → When to deviate` — "UI testing is never an automatic stage of this pipeline"). Invoking it **is** the explicit UI-test request that `UI_TESTING=manual` requires; `UI_TESTING=off` still blocks — report that web testing is disabled in `.dev.env` and ask the user to switch before proceeding. UI iterations are token-expensive — state the expected cost once at the start.

## Step 0. Prerequisites

Canon — `dev-standards-env.md`. Blocking for this command: `PLATFORM_PATH`, `INFOBASE_PATH`, **and `INFOBASE_PUBLISH_URL`** (the loop tests through the web client; without the URL there is nothing to loop over — stop and ask). The dev/test-target confirmation of `/deploy-and-test` applies unchanged.

Scenario set: taken from the argument / user request. Do not invent scenarios beyond what was asked; one scenario per user-visible behavior, in the template of `content/agents/tester.md → Test Scenarios`.

**EDT projects** (`.dev.env` `USE_EDT=true`): the deploy step keeps a single owner per `content/rules/edt-workflow.md`.

Iteration budget: `--iterations N` or a number stated in the request; default **3** (mirrors the update-retry budget). Browser-tool preflight and driving rules — via `/deploy-and-test` Step 4a (`ui-testing-tools.md`, `web-client-driving.md`), including the two-attempts anti-loop limit inside the browser.

## The loop (per iteration)

1. **Deploy.** Run `/deploy-and-test` Steps 0–3 (its command lines, tool selection, and retry loop are the single source of truth). Full-snapshot mode when `EXTENSION_NAMES` is configured, single-target otherwise. If the deploy retry loop exhausts its own budget, the whole command stops with its failure report — a broken deploy is not a test failure.
2. **Test.** Run the scenario set per `/deploy-and-test` Step 4 / the `1c-tester` workflow.
   - Iteration 1: the full requested set.
   - Later iterations: only the previously failed scenarios, **plus** any previously passed scenario whose covered area was touched by the fix (use the impact-analysis evidence from Gate 4 of `verification-gates.md` to decide; when in doubt, re-run the scenario).
3. **All green → exit** to the final report.
4. **On failure — fix before the next iteration.** Diagnose per `systematic-debugging.md` (the `DEBUG_FAST_PATH` fast path applies). Fix through the normal development procedure — triage quick-fix vs full-cycle per `AGENTS.md`, delegating to `1c-error-fixer` when delegation is warranted (`subagents.md`). Run the applicable Gates 1–3 on every touched module **before** redeploying. Re-deploying unchanged sources is forbidden — the same no-change-repeat rule as everywhere else; an iteration without a fix is a wasted iteration and a defect.
5. Next iteration (back to 1) while the budget allows.

## Hard rules

- **Every iteration must change something** — a code/metadata fix, a corrected scenario precondition, or a corrected test step proven wrong by evidence. "Try again, maybe it passes" is forbidden.
- **A scenario is not massaged into passing.** If the expected result was wrong, say so explicitly and get the user's confirmation before changing the expectation; silently weakening an assertion is a defect.
- **Budget exhausted → honest stop.** Report the remaining failures with reproduction steps, screenshots/log fragments, the fix applied in each iteration, and a recommendation. Never present a red loop as done.

## Final report

An iteration table — per iteration: deployed git state, scenarios run, pass/fail per scenario, one-line fix summary — followed by the standard test report (`tester.md → Test Report Format`) for the final state, and the `IB tooling:` line required by `AGENTS.md → Skills and Subagents`.
