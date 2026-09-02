---
description: Model profile for Claude Sonnet 5 (AGENT_MODEL=sonnet5) — literal instruction following and explicit scope, described interfaces over worked examples, code that reads like the surrounding code, effort calibration, keeping adaptive thinking on for tool use, coverage-first review briefs, token-budget awareness and lean context
alwaysApply: false
category: workflow
---

# Model profile — Claude Sonnet 5

**When to load this file:** `AGENT_MODEL=sonnet5` in `.dev.env`, or you know you are running as Claude Sonnet 5. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every hard gate of `AGENTS.md` stays exactly as written.

Baseline: Sonnet 5 runs this ruleset well without tuning, and is more agentic than Sonnet 4.6 by default. The items below are the documented behaviours that most often need it.

## 1. Literal instruction following — state scope explicitly

Sonnet 5 reads instructions literally and does **not** silently generalise one item to another or infer a request that was not made. That is precision, not laziness, and it changes how you write briefs.

- When a task spans several objects, state the scope for **each**: "перепроверь все три модуля из списка, не только первый", "примени маркеры изменения ко всем правкам типового кода в этом файле". A brief that names one example and expects the pattern to spread will get exactly the one example.
- The same when briefing subagents (`content/rules/subagents.md → Bounded sidecar task templates`): enumerate the files / objects / checks in scope, and say explicitly what is out of scope.
- Explicit scope is not the same as worked examples. Enumerate the objects, files and checks, describe the interface (which options exist and what each means), and give an example only to pin an exact output format — on this generation examples narrow the exploration space. Point at code rather than paraphrasing it (module path, `templatesearch` hit, a test). The same shape for every context you author: memory notes, handoffs, OpenSpec artefacts, `/evolve` entries.
- Code style is read from the module you edit, not from the rules alone — `AGENTS.md → Core Principles → "Codebase conventions first"`, the vendor's own guidance for this generation ("write code that reads like the surrounding code: match its comment density, naming, and idiom"). Literalism applies to the floors it names — ВерблюжьяНотация, correctness / security, the hard gates — not to restyling neighbours to the rulebook.
- Apply the same literalism to this ruleset when you read it: when a rule says "load X before Y", load X. Do not treat a mandated step as a suggestion because the task feels small — triage (`content/rules/verification-policy.md`) is what decides size, not intuition.
- Ambiguity handling is unchanged: material fork → `CONFUSION`; low-risk ambiguity → state the assumption in one line and proceed (`AGENTS.md → Development Procedure → 1`).

## 2. Effort calibration (client-side setting)

- `high` is the default and the right setting for BSL / metadata work. Raise to `xhigh` for the hardest coding and agentic tasks (multi-module refactor, architecture, metadata surgery, hard debugging).
- Sonnet 5 respects effort **strictly**, especially at the low end: at `low` and `medium` it scopes work to exactly what was asked. Good for cost, but on a moderately complex task `low` risks under-thinking. Do not use `low` for a full-cycle change; keep it for docs-fix, triage and lookups.
- If you see shallow reasoning on a hard problem, the fix is **raising effort**, not padding the prompt. When effort must stay low for latency, add one targeted line: "это многошаговая задача, продумай последовательность до начала правок".
- Cross-model note for anyone porting settings: Sonnet 5 at `medium` is comparable to Sonnet 4.6 at `high`, and `high` to Sonnet 4.6 at `max`.

## 3. Keep adaptive thinking on

Adaptive thinking is on by default on Sonnet 5 (a change from Sonnet 4.6). **With thinking disabled the model reaches for tools noticeably less** — which directly breaks the MCP-first discipline this ruleset is built on (`AGENTS.md → MCP Tool Calling`, `content/rules/mcp-first-search.md`).

- Keep thinking on. If cost is the concern, lower `effort` instead of turning thinking off.
- If thinking is off for reasons outside your control, compensate explicitly: name the required MCP calls in the plan before you start, and treat every skipped call as a defect to report rather than an economy.
- If the model produces thinking blocks more often than the work warrants (large system prompts can cause this), the steer is "думай только когда это меняет качество ответа; на простых вопросах отвечай сразу" — not disabling thinking.
- Note for whoever configures the client: manual extended thinking (`budget_tokens`) is removed on Sonnet 5, and `temperature` / `top_p` / `top_k` are rejected — tone and variety come from instructions, not sampling.

## 4. Progress updates and verbosity

- Sonnet 5 already gives regular, well-calibrated updates during long agentic runs. Do **not** add scaffolding that forces interim summaries ("итог после каждых трёх вызовов") — it is redundant here. Keep the evidence one-liners the ruleset requires (`Template:`, `Memory:`, `Metadata tooling:`, `IB tooling:`).
- Response length tracks task complexity on this model: short answers on lookups, longer on open analysis. That is the wanted behaviour; if a specific answer runs long, ask for concision on that answer rather than installing a global brevity rule.

## 5. Review tasks — brief for coverage

Sonnet 5 honours a stated severity bar more faithfully than earlier models: "only high-severity" makes it investigate just as deeply and then **withhold** the lower-severity findings.

- When you review BSL yourself or brief `1c-code-reviewer` / `1c-arch-reviewer`: ask for every finding, with severity and confidence attached, and filter in your own report. Never write "only critical", "be conservative" or "не мелочись" in the brief.
- If you do want a single-pass self-filter, define the bar concretely ("сообщай всё, что может привести к неверному поведению, ошибке проведения или неверному результату; опускай только чисто стилевые придирки") instead of a qualitative word like "important".
- Gate semantics are unchanged: `critical` / `error` from `check_1c_code` / `review_1c_code` block per `AGENTS.md → MCP Tool Calling → B.1`.

## 6. Token budget and context

Sonnet 5 tracks its remaining context window (context awareness), and its tokenizer emits roughly 30% more tokens than Sonnet 4.6 for the same text.

- **Do not wrap up work early because context feels tight.** Finish the task; when the window genuinely runs short, save state first — `content/skills/handoff` for a session handoff, `remember` for facts worth keeping (`AGENTS.md → Project memory`) — then continue or hand off cleanly.
- Load on demand: the always-on layer plus the rules triage selects for the task is the whole reading list. Do not preload `content/rules/` "for context", and read an obligation restated in several files as one obligation, not several — the same leanness Anthropic applied to Claude Code's own prompt for this generation, and on this model it also saves the tokens this section is about.
- Spend the budget on evidence that matters: keep MCP queries narrow (`detail_level="L0"`, `names_only`, `project_name` / category filters per `AGENTS.md → MCP Tool Calling → C.3`) instead of pulling whole modules "to be safe". This is the same rule as always; on this model the cost of ignoring it is higher.
- In `ORCHESTRATION=economy`, the offloading of reading to subagents (`content/rules/orchestrator-economy.md`) is a good fit with this constraint — but delegation criteria are unchanged.
