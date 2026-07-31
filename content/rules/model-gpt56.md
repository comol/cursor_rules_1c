---
description: Model profile for GPT-5.6 (AGENT_MODEL=gpt56) — lean context and each instruction once, reasoning-effort and verbosity calibration, autonomy boundaries for local vs. external actions, intent-level briefs, no contradictory instructions
alwaysApply: false
category: workflow
---

# Model profile — GPT-5.6

**When to load this file:** `AGENT_MODEL=gpt56` in `.dev.env`, or you know you are running as GPT-5.6. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every hard gate of `AGENTS.md` stays exactly as written.

Baseline: GPT-5.6 is more concise, more proactive and better at inferring intent than GPT-5.5, and it responds measurably better to **lean** context than to repeated emphasis.

## 1. Lean context — each instruction once

Removing repeated instructions and examples and simplifying tool descriptions improves both task performance and token efficiency on this model (vendor testing: ~10–15% higher scores at 41–66% fewer tokens). This ruleset is deliberately layered so that leanness is achievable — use the layering.

- **Load the minimum rule set the task needs**, chosen by triage: docs-fix loads nothing beyond the always-on layer; quick-fix loads the one relevant rule; full-cycle loads the routers it actually needs. Do not preload the whole `content/rules/` set "for context".
- **Do not re-read overlapping files** inside one task. `coding-standards.md` is an index — read the detail file it points at, not both plus `dev-standards-core.md`. Same for the verification trio (`verification-policy` → `verification-gates` → `verification-delivery`): load the stage you are in.
- **Treat a rule as stated once.** This ruleset repeats emphasis ("hard gate", "defect", the same obligation restated in a rule file and in `AGENTS.md`) so that a rule survives being read in isolation. Repetition marks importance, not additional work: one obligation = one action. A gate mentioned three times is still one gate.
- **Keep the exposed tool surface tight.** Call the MCP tools the task needs and no more (`AGENTS.md → MCP Tool Calling → C.1`); when the parameters are not obvious, read the one `content/skills/mcp-1c-tools/docs/<server>.md` that covers them rather than several.
- Leanness never means skipping a mandated call. The `A` section obligations (`templatesearch`, `recall`, platform-capability check, MCP-first search) and the validator chain are the floor, not emphasis to be trimmed.

## 2. Reasoning effort and verbosity (client-side settings)

- **`reasoning_effort`** supports `none`, `low`, `medium`, `high`, `xhigh`, `max`. Practical mapping for this ruleset: `low` / `none` for docs-fix and lookups; `medium` for quick-fix BSL and routine metadata work; `high` for full-cycle changes; `xhigh` / `max` for architecture, cross-subsystem refactors and hard debugging. When porting a setting from GPT-5.5 / 5.4, keep the old level as the baseline and try **one level lower** — this model usually holds quality there.
- **`text.verbosity`** (`low` / `medium` / `high`) controls answer length. GPT-5.6 is already more concise by default than 5.5, so blanket brevity instructions carried over from older prompts are redundant — drop them instead of stacking them.
- Report shape for the mandatory delivery report (`AGENTS.md → Development Procedure → 5`): **lead with the conclusion**, then the evidence that supports it, then any material caveat, then the next action. File list with paths in backticks stays.
- Where these parameters are not exposed to you, apply the equivalent in-prompt: state the intended depth once at the start of the plan and keep the report to the four elements above.

## 3. Autonomy boundaries

This model is proactive and persistent across multi-step tasks; it needs the boundary drawn, not the initiative suppressed.

- **Proceed without asking** for safe, local, reversible work inside the project: reading and searching through MCP, editing project files, running validators (`syntaxcheck`, `check_1c_code`, `review_1c_code`, `verify_xml`), driving the `1c-metadata-manage` tools, writing OpenSpec artefacts, saving memory notes. Pausing on these only slows the task down.
- **Ask first** for anything that changes state outside your own edits or is hard to reverse: infobase operations that mutate the base or its configuration (`/update1cbase`, `/loadfrom1cbase`, config load, `/UpdateDBCfg`, web publication), deleting files or objects, `git push` / force-push / history rewrite, anything reaching an external system, and any **material expansion of scope** beyond what was requested.
- The escalation format for a genuine fork is `CONFUSION` (`AGENTS.md → Development Procedure → 1`); a confirmation request for a destructive action is a plain one-line question, not a CONFUSION block.
- Do not use a destructive shortcut to get past an obstacle (no bypassing checks, no discarding files you did not create, no rewriting a failing validation away).

## 4. Intent-level briefs, not micro-steps

GPT-5.6 infers the user's underlying goal and the intended level of work from context better than earlier models, so prescriptive step-by-step guidance buys little and costs tokens.

- When briefing a subagent (`content/rules/subagents.md → Bounded sidecar task templates`): state the goal, the constraints, the scope, and the definition of done. Skip the mechanical step list unless the order genuinely matters (it does for the gates — say "validators per `B.1`", not the three call names spelled out with parameters).
- When the user's request is underspecified in a low-risk way, infer the most useful reading, state the assumption in one line, and proceed — the same rule as `AGENTS.md → Development Procedure → 1`, and this model is good at it.
- Keep a one-line preamble before a batch of tool calls ("проверяю метаданные объекта и шаблоны, потом правлю") — it costs nothing and keeps the trace readable. No narration per call.

## 5. No contradictory instructions

Conflicting instructions are expensive on reasoning models: the model spends effort reconciling them instead of solving the task.

- When a user instruction conflicts with a rule, or two rules appear to conflict, **resolve it explicitly** — apply the precedence chain (`content/rules/model-adaptation.md → §4`), or raise `CONFUSION` when the fork is material. Never average the two readings into a compromise implementation.
- When you notice the conflict is in the ruleset itself, capture it as a friction signal (`remember` with the `rule-friction:` prefix) and recommend `/evolve` per `AGENTS.md → Rules self-improvement`. Do not patch the rule inline.
- Structure long briefs with named sections / tags (`<task>`, `<constraints>`, `<scope>`, `<done_when>`) so the instruction set is unambiguous instead of restated.

## 6. Levers worth knowing (client-side)

- **Pro mode** applies extra model work to hard, quality-critical tasks — a reasonable choice for architecture reviews and risky refactors, not for routine edits.
- **Programmatic tool calling** suits bounded workflows where code can process several tool results at once (for example validating a batch of modules and aggregating findings) — useful when a task turns into many mechanical validator calls with predictable post-processing.
- Both are configuration choices for the user; state the recommendation in one line when a task would clearly benefit, then proceed with what is available.
