---
description: Model profile for GPT-6 Astra (AGENT_MODEL=gpt6) — follow-through instead of extra questions, user-task over skill process guidance, prose over extra formatting, parallel subagent use, no extra tests beyond the gates, reasoning.effort without none
alwaysApply: false
category: workflow
---

# Model profile — GPT-6 Astra

**When to load this file:** `AGENT_MODEL=gpt6` in `.dev.env`, or you know you are running as GPT-6 Astra (`gpt-6-astra`). Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every gate of `AGENTS.md` stays as written, and what the base ruleset already says is not repeated here.

Baseline: GPT-6 Astra stays coherent on long tasks and follows long instructions more closely than GPT-5.6. The same traits make it likelier to stop for a question, over-format the answer, under-delegate, or widen testing on a small change. Source: OpenAI latest-model guide → *Prompting best practices* (`developers.openai.com/api/docs/guides/latest-model`).

## 1. Follow-through — finish authorized work

This model asks when earlier ones would infer and continue. Infer the user's intent and scope from the request and prior context; persist until that goal is complete.

- Treat "can you…", "help me…", "I want…" and the same in Russian as instructions to do the work — not as a prompt to acknowledge capability, propose a plan, or offer to continue.
- Before a clarifying question, finish the work already authorized so the user is approving a concrete, reviewable result. Reversible local edits, reads, validators, `1c-metadata-manage` tools, OpenSpec artefacts and memory notes do not need a fresh permission ask.
- `CONFUSION` stays reserved for material forks (`AGENTS.md → Development Procedure → 1`). Destructive or hard-to-reverse actions still need confirmation. Do not invent extra warnings, disclaimers, approval flows or safety checklists for hypothetical risk.

## 2. User task vs skill process

GPT-6 Astra is more sensitive to on-demand skills and `AGENTS.md` than prior models: unclear or conflicting process guidance makes it pause or diverge.

- The user's current-task instruction outranks a skill's process guidance, except hard gates and the MUST NOT list in `model-adaptation.md §4`.
- If a skill causes you to ask for permission, pause, leave requested work unfinished, or diverge from the user's intent, name and link the exact `SKILL.md` you read, quote the line, and say whether it is an explicit requirement or your reading of a guideline.
- Load the minimum rule set triage selects. Read an obligation restated in several files as one obligation; resolve a real conflict through the precedence chain, never by averaging.

## 3. Writing style

Default answers run long and lean on lists, tables and recurring stock phrases. Lead with the outcome in concise paragraphs; use a list only when the items are genuinely parallel, sequential or easier to compare. No nested lists unless the hierarchy cannot be said in prose. No slop openers or closers, no contrastive "X, not Y" that the user did not ask about, no invented hyphenated labels. Delivery report: outcome, then files, then material caveats — the shape in `verification-delivery.md`, without extra markdown sections.

## 4. Delegation

This model under-delegates. When independent pieces of work can run in parallel and `content/rules/subagents.md` allows it, delegate. Briefs stay intent-level (goal, constraints, scope, done-when). Messages to other agents are human-readable — normal spacing, no compressed telegram. Under `ORCHESTRATION=economy` the mode's routing wins.

## 5. Testing — gates only, no extra suite

The model tends to write or rerun broader tests than a small change needs. Do not add tests for reversible, low-impact edits that only mirror the implementation. Run the gates `verification-policy.md` asked for; once they pass, do not broaden or repeat unless a new change, a failure, or an unresolved concern justifies it. Mandated validators are tool evidence, not a licence for a self-review pass or a verifier subagent.

## 6. Reasoning effort and client levers

- `reasoning.effort`: this model does not support `none`. `low` for docs-fix and lookups (the replacement for `none` / `minimal`); `medium` for quick-fix BSL and routine metadata; `high` for full-cycle; `xhigh` / `max` for architecture, cross-subsystem refactors and hard debugging.
- Fast mode is unavailable with EU data residency — if the client offers it, leave it off in that region.
- Mid-turn steering, `configuration_update` for effort, async tool calling and pro mode are the user's client choices: recommend in one line when a task would clearly benefit, then proceed with what is available.
