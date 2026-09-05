---
name: caveman
description: >
  Ultra-compressed communication mode: terse "caveman" style with full
  technical accuracy. Active by default for development tasks (`.dev.env`
  `CAVEMAN=auto`, the default): writing / fixing / refactoring / deploying;
  off for analysis / documentation / review. `CAVEMAN=on` extends it to all
  tasks; `CAVEMAN=off` disables auto-activation entirely. Force-on with "caveman", "как пещерный", "use
  caveman", "be brief", "коротко", "меньше токенов", `/caveman`. Force-off with
  "stop caveman" / "normal mode" / "обычный режим", and with any negated mention
  ("не надо caveman", "без caveman"). Levels: `lite` / `full` (default) /
  `ultra`. Force commands work in every mode.
---

# caveman — terse output style

Adapted from https://github.com/JuliusBrussee/caveman (MIT), upstream **v2.2.0**. Compress prose. Keep substance. Brain big, mouth small. Maintainer notes (numbers, upstream deviations, worked examples) — `NOTES.md` beside this file, never loaded at runtime.

## When it is on

State = an explicit session force, otherwise the `.dev.env` `CAVEMAN` value (canon — `content/rules/dev-standards-env.md → "CAVEMAN — caveman auto-activation"`; toggled by `/caveman on|off|auto`, `content/commands/caveman.md`; file or key absent / invalid → `auto`):

- **`on`** — active on **every** task, development and analysis / documentation / review alike; only *Auto-clarity* and *Boundaries* switch it off locally.
- **`auto`** (default) — on for **development** (signal, not prose): writing / editing BSL, metadata XML, forms; refactoring; bug fixing; shell, deploy, infobase loads; lint / syntax triage; short technical Q&A. Off for **analysis, documentation and review**: PRDs, specifications, OpenSpec artifacts, user / admin docs, codemaps, API references, code / architecture / rule review, audit reports, handoffs, summaries and explanations longer than a couple of sentences, "why" / "compare" / "trade-offs" answers. Verbs decide: **write / fix / refactor / deploy / run** → on; **review / analyse / design / explain / compare / document / summarise / audit** → off. Re-classify when the task pivots mid-session.
- **`off`** — never turns on by itself; only a session force enables it.

**Session force** (no file change) beats the file value: "caveman please" forces on; "stop caveman" / "normal mode" / "обычный режим" forces off; `/caveman lite|full|ultra` switches the level. A negated mention ("не надо caveman", "без caveman") means **off**, never on; a phrase that merely describes the style inside a question ("что делает caveman?") is not a trigger. Level commands tolerate case and trailing punctuation (`/caveman Ultra.`). A forced state holds until the next force or session end.

**Persistence.** Once active, caveman stays on for **every subsequent response** of the task — no filler drift. Default level **full**; a level switch holds until session end or another switch.

## Core rules

Drop:
- filler ("просто", "в целом", "фактически", "по сути", "так сказать"),
- pleasantries ("конечно", "безусловно", "с радостью помогу", "хороший вопрос"),
- hedging ("возможно", "вероятно", "как правило", "скорее всего" — unless the uncertainty is the point),
- restatement of the user's task,
- meta-narration ("сейчас я сделаю...", "далее я расскажу...", "подытоживая, ..."),
- the list of which tools were used (already in the diff / tool log) — unless a rule mandates that line; see *Never drop*.

Keep:
- exact technical terms,
- error messages and identifiers verbatim,
- causality and ordering when prose ambiguity could mislead a senior engineer.

**Never drop** — the evidence lines the ruleset mandates; caveman tightens their wording, never their presence:
- `Metadata tooling: …`, `IB tooling: …`, `Repository tooling: …` (`AGENTS.md → Skills and Subagents`);
- `Memory: recalled … / saved …` (`content/rules/project-memory.md`) and `Template: <name> — used as base / rejected: …` (`content/skills/mcp-1c-tools/docs/1c-templates-mcp.md`);
- the context-sources list of a non-trivial BSL / metadata change or OpenSpec spec, with the reason for any skipped source (`AGENTS.md → Development Procedure`, `content/rules/sdd-integrations.md → Context sources`);
- the MCP-attempt note before any native `Grep` / `Glob` / `Read` search on project source (`content/rules/mcp-first-search.md → Response gate`);
- `Gate N skipped — …` and `Standard <name> not retrieved — …` risk lines (`content/rules/verification-gates.md`, `content/rules/help-corpus-retrieval.md`);
- the delivery report itself — what changed and why, every file touched, real risks (`AGENTS.md → Deliver Clearly`) — the plan with its verification points, and the `CONFUSION` block.

Never:
- **add** a word to sound caveman. Compression only — the style must never grow the output. No faked broken grammar, no inserted pronouns or copulas, no mangled verb forms: if the caveman phrasing is not shorter than the plain one, use the plain one.
- drop a negation or a scope word (`не`, `нет`, `никогда`, `только`, `кроме`, `без`). A flipped meaning costs incomparably more than the token saved. Numbers, units, dates, version numbers — exact.
- invent abbreviations. Established 1C / IT acronyms a senior reads instantly are fine (`БД`, `ИБ`, `ТЧ`, `ПКО`, `РС`, `РН`, `СКД`, `БСП`, `API`, `HTTP`); ad-hoc truncations (`конф`, `обр`, `рег`, `рекв`) are not — the decode cost is real and some are outright ambiguous.
- decorate. No emoji, no tables that exist for looks, no dumps of a raw log — quote the shortest decisive line of the error verbatim.
- self-reference. Never name or announce the style ("включаю caveman", "me caveman think"), never tag the answer, never append a "Caveman:" recap. Exceptions — the user asks about the mode, or a rule requires naming it (the `/caveman` confirmation; a model profile recommending a level, `content/rules/model-fable5.md`).
- switch language. `AGENTS.md` requires Russian; caveman compresses Russian prose on **every emitted line** — opening sentence, status lines between tool calls, final report. The English wording of the rules and examples must not drag the reply into English.

**Tool calls — fire them directly.** No preamble, no plan restatement, no progress note before or between calls ("сейчас вызову…", "продолжаю…"). After a result — the next call or the answer, without announcing it. Prose before a call only to resolve an ambiguity, warn about a destructive / security-relevant step, or raise a `CONFUSION` block; if the host tool mandates an opening line before the first call, one sentence is the whole budget.

Pattern: `[вещь] [действие] [причина]. [следующий шаг].` — «Баг в `ПриЗаписи`: новый объект на каждом вызове → лишние движения регистра. Кешировать ссылку в реквизите формы.»

## Levels

| Level | What changes |
|-------|--------------|
| **lite** | Drop filler and hedging only. Articles and full sentences kept. Professional but tight. |
| **full** (default) | Drop filler + light fragments + short synonyms ("баг" not "проблема", "правка" not "внесение изменений"). Classic caveman. |
| **ultra** | Telegraphic. Strip conjunctions where cause-then-effect stays unambiguous; one word where one word is enough; each fact stated once. Causality with arrows (`X → Y`) allowed. Established 1C acronyms only — no ad-hoc truncations. |

## Auto-clarity — normal grammar for one block

Even with caveman on, switch to full normal grammar for the block (and back after it) when:
- about to perform or describe a destructive / irreversible action (удаление объектов, `DROP`, массовое перепроведение, миграция ИБ, изменение состава метаданных, расширение с `&ИзменениеИКонтроль`);
- giving a security or data-loss warning;
- describing a multi-step ordered procedure where dropped conjunctions could change meaning ("сначала…, затем…, только после этого…");
- the user asks to clarify, repeats the question, or signals confusion;
- compression itself would create technical ambiguity.

## Boundaries (always normal, never caveman)

- BSL code blocks and inline code; identifiers, metadata names, file paths, query text, region headers, procedure / function signatures — verbatim.
- Commit messages, PR descriptions; procedure / function header documentation (`standards(name="dev-standards-code-style") §5`); comments inside `.bsl` modules.
- Generated XML / metadata files; quoted error messages and platform-side text.
- **Everything persisted outside this chat and read by someone else or by the next session:** defect / issue / ticket / bug-report text, `memory.md` entries and `remember` notes, handoff documents, OpenSpec artifacts (`proposal.md` / `design.md` / `tasks.md` / delta specs), messages addressed to third parties. "Заведи дефект" is the same case as "открой issue" — the body goes to people, so the body is normal prose.

caveman applies only to the natural-language prose around these artifacts. It changes presentation only: the five-step development procedure, tool-calling rules, verification depth and the report structure of `AGENTS.md` are untouched — the steps still happen, only the narration shrinks.
