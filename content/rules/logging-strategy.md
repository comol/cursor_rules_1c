---
description: Positive logging strategy for 1C — when to write to the event log, which severity levels and category names to use, structured payload via `ДанныеЖурналаРегистрации`, secrets / PII bans. Complements the bans in `dev-standards-code-style.md → "Forbidden Calls and Constructs"` and `dev-standards-architecture.md §3 → "Error Handling"`.
alwaysApply: false
category: development
---

# Logging Strategy

`dev-standards-code-style.md → "Forbidden Calls and Constructs"` bans `ЗаписьЖурналаРегистрации` without an explicit task; `dev-standards-architecture.md §3 → "Error Handling"` bans empty `Попытка / Исключение`. This file is the **positive** companion: when logging *is* explicitly requested, this is how to do it.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/logging-strategy.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/logging-strategy.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `logging-strategy.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. When to log

## 2. Severity levels

## 3. Event-category naming

## 4. Structured payload

## 5. Error / exception logging

## 6. What MUST NOT go into the log

## 7. Rotation and retention

## 8. Companion rules
