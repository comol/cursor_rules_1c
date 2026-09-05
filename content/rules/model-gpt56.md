---
description: Model profile for GPT-5.6 (AGENT_MODEL=gpt56) — lean context and each instruction once, reasoning-effort and verbosity calibration, autonomy boundaries for local vs. external actions, intent-level briefs, no contradictory instructions
alwaysApply: false
category: workflow
---

# Model profile — GPT-5.6

**When to load this file:** `AGENT_MODEL=gpt56` in `.dev.env`, or you know you are running as GPT-5.6. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every gate of `AGENTS.md` stays as written, and what the base ruleset already says is not repeated here.

Baseline: GPT-5.6 is more concise, more proactive and better at inferring intent than GPT-5.5, and it responds measurably better to **lean** context than to repeated emphasis.

## 1. Lean context — each instruction once

Removing repeated instructions and examples improves both task performance and token efficiency on this model (vendor testing: ~10–15 % higher scores at 41–66 % fewer tokens). Load the minimum rule set triage selects — docs-fix nothing beyond the always-on layer, quick-fix the one relevant rule, full-cycle the routers it needs — and never re-read overlapping files inside one task (an index points at its owner; read the owner). Where the ruleset restates an obligation for readers who see a file in isolation, read it as **one** obligation: a gate mentioned three times is still one gate. Call the MCP tools the task needs and no more; when parameters are not obvious, read the one server doc that covers them. Leanness never trims a mandated call.

## 2. Reasoning effort and verbosity (client-side settings)

- `reasoning_effort`: `low` / `none` for docs-fix and lookups; `medium` for quick-fix BSL and routine metadata work; `high` for full-cycle changes; `xhigh` / `max` for architecture, cross-subsystem refactors and hard debugging. Porting from GPT-5.5 / 5.4 — try one level lower than before, this model usually holds quality there.
- `text.verbosity` controls answer length; GPT-5.6 is already concise, so blanket brevity instructions carried over from older prompts are redundant — drop them.
- Delivery report: conclusion first, then the evidence, then any material caveat, then the next action; file list with paths in backticks stays. Where these parameters are not exposed, state the intended depth once at the start of the plan.

## 3. Autonomy boundaries

This model is proactive and persistent; it needs the boundary drawn, not the initiative suppressed.

- **Proceed without asking** for safe, local, reversible work: MCP reads and searches, project-file edits, validators, `1c-metadata-manage` tools, OpenSpec artefacts, memory notes.
- **Ask first** for anything that changes state outside your own edits or is hard to reverse: infobase mutations (`/update1cbase`, `/loadfrom1cbase`, `/UpdateDBCfg`, publication), deletions, `git push` / history rewrite, anything reaching an external system, and any material expansion of scope. A confirmation request for a destructive action is a one-line question; `CONFUSION` is for genuine forks.
- Never use a destructive shortcut to get past an obstacle — no bypassing checks, no discarding files you did not create, no rewriting a failing validation away.

## 4. Intent-level briefs, not micro-steps

GPT-5.6 infers the goal and the intended level of work from context, so prescriptive step lists buy little. Brief a subagent with goal, constraints, scope and definition of done; keep the mechanical step list only where order genuinely matters (say "validators per `verification-policy.md → Validator budget`", not the three call names spelled out). Underspecified low-risk requests: infer the most useful reading, state the assumption in one line, proceed. One-line preamble before a batch of tool calls; no narration per call.

## 5. No contradictory instructions

Conflicting instructions are expensive on reasoning models. Resolve a conflict between a user instruction and a rule, or between two rules, explicitly — the precedence chain of `content/rules/model-adaptation.md → §4`, or `CONFUSION` on a material fork — never an averaged compromise. A conflict inside the ruleset is a friction signal (`remember` with the `rule-friction:` prefix, then recommend `/evolve`), not something to patch inline. Structure long briefs with named sections (`<task>`, `<constraints>`, `<scope>`, `<done_when>`) so nothing has to be restated.

## 6. Levers worth knowing (client-side)

Pro mode applies extra model work to hard, quality-critical tasks — architecture reviews and risky refactors, not routine edits. Programmatic tool calling suits bounded workflows where code processes several tool results at once (validating a batch of modules, aggregating findings). Both are the user's configuration choices: recommend in one line when a task would clearly benefit, then proceed with what is available.
