---
description: Managed locks, transaction boundaries, lock ordering, deadlock prevention, shared / exclusive lock modes, monitoring via the technological log. Load when designing posting / multi-document operations, debugging lock conflicts, or extending an existing transactional path.
alwaysApply: false
category: quality
---

# Locks and Transactions — Design Rules

The 1C platform offers two locking subsystems (automatic / managed) and an implicit-transaction model around object writes. Most production lock incidents come from mixing the two, opening unintended transactions, or holding locks across user dialogs. This file is the canonical home for those rules.

> **Scope.** This file owns the design rules. The narrow case "set a lock before reading balances during posting" lives as a worked example in `platform-solutions.md §9 → "Managed locks and deadlock prevention"` — that section now points back here for the general theory.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/locks-and-transactions.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/locks-and-transactions.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `locks-and-transactions.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Lock mode of the configuration

## 2. Transaction boundaries

### Implicit transactions

### Explicit transactions in calling code

### Forbidden inside transactions

## 3. Managed-lock primitives

### Modes

## 4. Lock ordering — the deadlock contract

## 5. Locking patterns

### Pattern: posting a document that touches several registers

### Pattern: mass operation across many documents

### Pattern: status update outside posting

## 6. Diagnosing lock conflicts and deadlocks

### Symptoms

### Diagnostic tools

## 7. Companion rules
