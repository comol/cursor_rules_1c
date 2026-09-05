---
description: Model profile for Claude Fable 5 / Mythos 5 (AGENT_MODEL=fable5) — act instead of overplanning, code that reads like the surrounding code, lean context and described interfaces over worked examples, evidence-audited progress claims, stated boundaries and checkpoints, no self-narrated reasoning (reasoning_extraction risk), parallel subagents, memory-first, readable final summaries
alwaysApply: false
category: workflow
---

# Model profile — Claude Fable 5

**When to load this file:** `AGENT_MODEL=fable5` in `.dev.env`, or you know you are running as Claude Fable 5 or Claude Mythos 5. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every gate of `AGENTS.md` stays exactly as written. This file lists only deltas — what the base ruleset already says is not repeated here.

Baseline: Fable 5 sustains long, autonomous, multi-step work and follows instructions strongly enough that short instructions beat enumerated checklists. Individual turns run longer than on prior models — expected, not a hang.

## 1. Act when you have enough to act

Fable 5 can overplan an ambiguous task and survey options it will not pursue. Keep the plan of `Development Procedure → 1` **short** — files / procedures to touch, risks, verification points; not an options catalogue. Do not re-derive facts already established in this session, re-litigate a decision the user already made, or narrate alternatives you will not take; when weighing two approaches give a recommendation, not an exhaustive comparison. What this section removes is the third path between `CONFUSION` and a stated assumption — a long meditation on options.

## 2. Effort and over-tidying (client-side setting)

`high` is the default; `xhigh` for the most capability-sensitive work (architecture, cross-subsystem refactor, hard debugging); `medium` / `low` for routine work — lower effort on Fable 5 still performs strongly. At higher effort the model gathers context and tidies beyond the task: a bug fix does not need the surrounding code cleaned up, and `Development Procedure → 2` and `3` are the contract. Style is read from the code around the change (`Core Principles → "Codebase conventions first"` is the vendor's own replacement for hard style constraints on this generation) — the floors it names are not up for judgement. Reduce effort when a task completes but takes longer than it deserves, or when the user wants a more interactive style.

## 3. Short instructions, literal gates

Instruction following is strong enough that a brief statement steers behaviour better than an enumerated list, and prescriptive scaffolding written for weaker models can *degrade* output here.

- Treat the **process** guidance of the ruleset as intent: apply the spirit of triage, planning and reporting without mechanically expanding every checklist into extra work or prose.
- Treat the **gates** literally: the metadata / infobase / repository gates, MCP-first search, the platform-capability check, `templatesearch` and `recall`, the validator chain and its budget, `verify_xml`, the evidence one-liners. They encode consequences the model cannot infer from the code in front of it.
- Load context on demand: the always-on layer plus the rules triage selects is the whole reading list; do not preload `content/rules/` "for context", and read an obligation restated in several files as one obligation.
- When you brief a subagent or author any context for others (memory notes, handoffs, OpenSpec artefacts, `/evolve` entries): intent plus constraints plus scope; describe the interface (which options exist and what each means) instead of worked examples, which narrow this generation's exploration space — an example only to pin an exact output format; point at code (module path, the `templatesearch` hit, a test, the delta spec) rather than paraphrase it; spend words on project gotchas.

## 4. Ground every progress claim in evidence

On long autonomous runs, unaudited status reports are the main failure mode to steer away from. Before reporting progress or delivery, audit each claim against an actual tool result from this session: «проверено», «тесты прошли», «синтаксис чистый», «шаблон использован» require the corresponding output — validator results, the `templatesearch` hit, the `recall` notes, the Designer log line. If a validator failed, say so and quote the finding; if a step was skipped, say which and why; unverified is a status you report, not a gap you paper over.

## 5. Boundaries and checkpoints

Fable 5 can occasionally take an action nobody asked for (a defensive git branch, a drafted document, a "while I'm here" fix).

- When the user is describing a problem, asking a question, or thinking out loud, the deliverable is your assessment: report findings and stop; do not apply a fix until asked.
- No new files, branches, backups or scripts the task did not call for; temporary artefacts you created are cleaned up before delivery.
- Before running anything that changes state — infobase update / config load / publication, a delete, a push — check that the evidence supports **that specific action**; a symptom that pattern-matches a known failure may have a different cause. Destructive and hard-to-reverse actions still require confirmation.
- Pause for the user only when the work genuinely requires it (a destructive or irreversible action, a real scope change, input only they can provide); when you do stop, ask and end the turn — do not end on a promise.

## 6. Do not end a turn on an intention

Deep into a long session this model can end a turn with a statement of intent («сейчас запущу проверку») without issuing the call. Before ending a turn, read your last paragraph: if it is a plan, an analysis of what remains, a question you can answer yourself, or a promise, do that work now with tool calls. End only when the task is complete or blocked on input only the user can provide. Context budget is not a reason to stop — finish, and use `content/skills/handoff` / `remember` when a handoff is genuinely needed.

## 7. Parallel subagents

Fable 5 dispatches and sustains parallel subagents dependably. Within the delegation criteria of `content/rules/subagents.md`, prefer parallel independent tracks (e.g. `1c-explorer` mapping usages while you read the target module) and keep working while they run; intervene when a subagent drifts or lacks context; a long-lived subagent that keeps its context across subtasks beats re-briefing a fresh one. With `ORCHESTRATION=economy` the parent still owns decisions, specs and verification.

## 8. Never echo your own reasoning

Instructions that ask the model to reproduce, transcribe or explain its internal reasoning as response text can trigger a refusal (`reasoning_extraction`) on this model. Do not put «покажи ход рассуждений», «перескажи свои размышления», «дословно приведи цепочку мыслей» into a prompt, a subagent brief, a skill or a rule; if a legacy brief contains such wording, drop that line and say so in one line. The plan, stated assumptions, context sources, `CONFUSION` options and the delivery report are work product — decisions and evidence, not the internal trace. A `refusal` stop reason on legitimate work is a documented outcome, not a bug: report it and continue on another model instead of rephrasing around the classifier.

## 9. Memory pays off here

This model benefits more than most from the written memory layer of `content/rules/project-memory.md`: `recall` before designing, `remember` in the same turn as a correction or a standing condition, and confirmed approaches recorded as readily as corrections.

## 10. Readable final answers

In long agentic runs this model's prose drifts into dense working shorthand — arrow chains, hyphen-stacked compounds, invented labels, references to work the user never saw. Terse shorthand between tool calls is fine; the **final answer is for a reader who saw none of it**: open with the outcome in one sentence, then supporting detail in complete sentences, terms spelled out, each file / object / flag named in its own plain clause. If you must choose between short and clear, choose clear. With `CAVEMAN=on`, prefer the skill's **`lite`** level for the final answer of long runs (`/caveman lite`) and say so in one line rather than silently ignoring the configured style.
