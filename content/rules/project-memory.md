---
description: Project memory — the two stores (`memory.md` and `1c-templates-mcp` `remember` / `recall`), what goes where, the two hard gates (recall-first, correction-capture), the `Memory:` line, availability fallback, note format, promote / demote. Load at the start of any non-trivial 1C task and in every turn where the user corrects you or states a standing condition.
alwaysApply: false
category: workflow
---

# Project memory

Two layers. Every project-specific fact worth keeping lands in one of them, otherwise it is lost between sessions. This file is the single owner of the memory rules; `AGENTS.md` carries only the two gates in one line each.

## Two stores

- **`memory.md`** (project root, strict long-term store) — only rules that are **all** of: global (whole project), critical (violation = production breakage / data leak / regulatory issue), stable (does not change task-to-task), non-derivable (cannot be inferred from `AGENTS.md`, `USER-RULES.md`, or official docs). No TODOs, temporary agreements, style notes, or subsystem-scoped rules. Entry format is documented inside the file itself.
- **`remember` / `recall`** (`1c-templates-mcp`, fine-grained vector memory) — the primary store for everything else: user corrections during work, non-obvious project facts, recurring errors and their fixes, naming and quirks of individual configuration objects, and **standing working conditions** — statements that shape future tasks, not just the current one («I am benchmarking the agent», «objects from task statements may not exist in the configuration», «always prefer built-in platform mechanisms»). Test: *would the next session behave differently if it knew this?* If yes and it is not already in the rules — save it now; deferring loses it.

## Gates (hard)

1. **Recall-first.** For any non-trivial 1C task, call `recall` with the task's key terms (object name, subsystem, error text) **before** solution design — same standing as `templatesearch`. On the session's first non-trivial task also query the standing conditions (`working conditions`, `benchmark`, `conventions`). Skipping `recall` while the server is exposed is a defect.
2. **Correction-capture.** A turn in which the user corrected your output, rejected an approach, clarified a non-obvious fact, or stated a standing condition is **incomplete** until `remember` was called with that fact, in the same turn. Before ending such a turn ask: *did this message change how I or the next session should work? → saved?* Answering the correction while skipping the save is a defect even when the reply is right.
3. **Memory line.** The final answer of a non-trivial task states memory usage in one line: `Memory: recalled <n> notes / nothing relevant; saved <n> notes / nothing to save`. It makes silent skips visible.

Routing of what gets saved: project **facts** → plain `remember` notes; **behaviour / process** corrections and rule friction → notes prefixed `rule-friction:` (consumed by `/evolve`, see `AGENTS.md → Rules self-improvement`). Never edit `AGENTS.md`, the rule files, or `LLM-RULES.md` on the spot.

## Availability and fallback

`1c-templates-mcp` counts as available only when the current session exposes `remember` / `recall` in the tool schema; presence in the client's MCP config proves nothing. Memory write additionally requires an authenticated call — `mutation_auth_required` means the connection lacks the bearer header. When the server is offline, the tools are missing, or the write is unauthorized: append even small particular-case corrections as **dated entries** directly to `memory.md` (eligibility is temporarily relaxed) and migrate them to `remember` once the server is back. Do not loop on a failing memory call.

## Note format

English narrative, one self-contained fact per note, original 1C identifiers and object / module names preserved as-is. No secrets, no PII. Update an existing note instead of adding a near-duplicate; delete notes that turn out to be wrong. Record confirmed approaches as well as corrections — «this pattern worked and why» is as valuable as «do not do this».

## Promote / demote

A `remember` note that later proves to meet all four `memory.md` criteria is promoted to `memory.md` and removed from the vector store. The same fact never lives in both stores.
