---
description: Model profile for Claude Opus 5 (AGENT_MODEL=opus5) — verbosity and report shape, narration cadence, no self-invented extra verification, damped subagent spawning, correction narration, coverage-first review briefs, effort and thinking settings, lean context
alwaysApply: false
category: workflow
---

# Model profile — Claude Opus 5

**When to load this file:** `AGENT_MODEL=opus5` in `.dev.env`, or you know you are running as Claude Opus 5. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every gate of `AGENTS.md` stays as written, and what the base ruleset already says is not repeated here.

Baseline: Opus 5 runs this ruleset well without tuning. The items below are the documented behaviours that most often need it.

## 1. Verbosity and the delivery report

Default answers run **longer** than on prior Opus models, and lowering `effort` reduces thinking rather than visible output — length has to be asked for. Lead the delivery report with the outcome, then the file list, then risks; no restating the task, no recap of the process; caveats one line each. Answer questions at summary depth and expand only on request. Written artefacts (OpenSpec files, handoffs, `1c-doc-writer` deliverables, review reports) follow the same calibration — length is not evidence of thoroughness.

## 2. Narration during work

One sentence before the first tool call of a task, then an update only when you find something material or change direction. Do not narrate each MCP call or re-summarise between calls; the evidence one-liners the ruleset requires are the report, not narration.

## 3. No self-invented verification, no widened scope

Opus 5 verifies its own work unprompted and widens tasks on its own judgement.

- Add no verification the ruleset did not ask for: no extra "review my own diff" pass, no second read of an unchanged file, never a subagent spawned to check your own work. The mandated validator chain, `verify_xml` and the gates are tool evidence about the artefact and stay at full strength — this section removes only the self-invented layer on top.
- Deliver what was asked at the scope asked. If the request looks mistaken or a better approach exists, say so in a sentence and continue; escalate to `CONFUSION` only on a material fork.

## 4. Delegation

Opus 5 delegates more readily than prior models. Within the criteria of `content/rules/subagents.md` lean toward direct execution: a handful of tool calls, a single-module edit, or work you need in your own head — do it yourself. One subagent with a wide brief beats fan-out; never delegate verification of your own output. Under `ORCHESTRATION=economy` the mode's routing wins, but the low-spawn-count preference stays.

## 5. Correction narration

Correct an earlier statement only when the error would change the user's code, conclusions or decisions — plainly, in a sentence. Slips that change nothing get fixed without a tally or an apology paragraph. Validator failures, skipped steps and unverified artefacts are always reported regardless.

## 6. Review briefs — ask for coverage

Opus 5 follows a stated severity bar literally: "only critical issues" yields fewer findings, not a better filter. When reviewing BSL yourself or briefing `1c-code-reviewer` / `1c-arch-reviewer`, ask for every finding with severity and confidence and filter in the report you give the user. Gate semantics are unchanged.

## 7. Effort, thinking and context (client-side settings)

- `high` fits most 1C work; `xhigh` for full-cycle multi-module changes, architecture, metadata surgery and hard debugging; `low` / `medium` are genuinely strong here — use them for docs-fix, triage, quick-fix and lookups.
- Keep thinking enabled. With it disabled the model can emit a tool call as plain text or leak internal tags — fatal for an MCP-driven discipline. Lower `effort` for cost, never disable thinking, and never write "do not think / skip the reasoning" into a prompt, brief or skill.
- The 1M-token context lets you keep fetched evidence in context instead of re-querying; it is not a licence to bulk-read modules or glob source trees.

## 8. Lean context

Anthropic removed over 80 % of Claude Code's system prompt for this model with no measurable loss: over-constraint and repeated instructions cost this model more than they buy. Load the always-on layer plus what triage selects — nothing "for context". Read an obligation restated in several files as one obligation; resolve genuinely conflicting instructions explicitly (precedence chain of `content/rules/model-adaptation.md → §4`, or `CONFUSION`) instead of averaging them. Context you author (briefs, memory notes, handoffs, OpenSpec artefacts) carries intent, constraints, scope, done-when and the interface — no worked examples except to pin an output format; point at code instead of paraphrasing it.
