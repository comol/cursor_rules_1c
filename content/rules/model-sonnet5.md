---
description: Model profile for Claude Sonnet 5 (AGENT_MODEL=sonnet5) — literal instruction following and explicit scope, effort calibration, keeping adaptive thinking on for tool use, coverage-first review briefs, token-budget awareness and lean context
alwaysApply: false
category: workflow
---

# Model profile — Claude Sonnet 5

**When to load this file:** `AGENT_MODEL=sonnet5` in `.dev.env`, or you know you are running as Claude Sonnet 5. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every gate of `AGENTS.md` stays as written, and what the base ruleset already says is not repeated here.

Baseline: Sonnet 5 runs this ruleset well without tuning and is more agentic than Sonnet 4.6 by default.

## 1. Literal instruction following — state scope explicitly

Sonnet 5 reads instructions literally and does not generalise one item to another or infer a request that was not made.

- When a task spans several objects, state the scope for **each** («перепроверь все три модуля из списка, не только первый»); a brief that names one example and expects the pattern to spread gets exactly the one example. The same when briefing subagents: enumerate the files / objects / checks in scope and say what is out of scope.
- Explicit scope is not worked examples: describe the interface (which options exist and what each means) and give an example only to pin an exact output format — on this generation examples narrow the exploration space. Point at code rather than paraphrasing it.
- Apply the same literalism to the ruleset: when a rule says "load X before Y", load X. Triage decides task size, not intuition.

## 2. Effort calibration (client-side setting)

`high` is the right setting for BSL / metadata work; `xhigh` for the hardest coding and agentic tasks. Sonnet 5 respects effort strictly at the low end — `low` / `medium` scope work to exactly what was asked, good for docs-fix, triage and lookups, risky for a full-cycle change. Shallow reasoning on a hard problem is fixed by raising effort, not by padding the prompt; when effort must stay low, add one line: «это многошаговая задача, продумай последовательность до начала правок». Porting note: Sonnet 5 at `medium` ≈ Sonnet 4.6 at `high`; `high` ≈ 4.6 at `max`.

## 3. Keep adaptive thinking on

Adaptive thinking is on by default. **With thinking disabled the model reaches for tools noticeably less**, which breaks the MCP-first discipline this ruleset is built on. Lower `effort` for cost, never disable thinking. If thinking is off for reasons outside your control, name the required MCP calls in the plan up front and report every skipped call as a defect. Manual `budget_tokens` is removed on Sonnet 5 and `temperature` / `top_p` / `top_k` are rejected — tone and variety come from instructions.

## 4. Progress updates and verbosity

Sonnet 5 already gives well-calibrated updates during long runs; do not add scaffolding that forces interim summaries. Response length tracks task complexity — the wanted behaviour; ask for concision on a specific answer rather than installing a global brevity rule.

## 5. Review briefs — ask for coverage

Sonnet 5 honours a stated severity bar faithfully: "only high-severity" investigates just as deeply and then **withholds** the lower-severity findings. When reviewing BSL yourself or briefing `1c-code-reviewer` / `1c-arch-reviewer`, ask for every finding with severity and confidence and filter in your own report; if you want a single-pass self-filter, define the bar concretely («сообщай всё, что может привести к неверному поведению или ошибке проведения; опускай только стилевые придирки»), never a qualitative word like "important". Gate semantics are unchanged.

## 6. Token budget and context

Sonnet 5 tracks its remaining context window, and its tokenizer emits roughly 30 % more tokens than Sonnet 4.6 for the same text.

- Do not wrap up early because context feels tight: finish; when the window genuinely runs short, save state first (`content/skills/handoff`, `remember`) and continue or hand off cleanly.
- Load the always-on layer plus what triage selects — nothing "for context"; read an obligation restated in several files as one obligation.
- Keep MCP queries narrow (`detail_level="L0"`, `names_only`, `project_name` / category filters) instead of pulling whole modules "to be safe" — the cost of ignoring this is higher on this model. `ORCHESTRATION=economy` fits this constraint well; delegation criteria are unchanged.
