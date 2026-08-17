---
description: 1C anti-patterns, performance guidelines, and code review scoring
alwaysApply: false
category: quality
---

# 1C Anti-Patterns and Performance Guidelines

> **Ownership.** This file owns the anti-pattern **catalog**: severity, detection hints, before/after fix templates. The normative query rules themselves (no queries in loops, parameterization, `КАК` aliases, virtual-table filters via parameters, intermediate result variable, `ВТ_*` naming, `ПЕРВЫЕ N`) are owned by `dev-standards-architecture.md §3 → "Queries"`; the dot-notation ban — by `dev-standards-architecture.md §4`. On conflict, the owner file wins — update rules there, update examples here.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/anti-patterns.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/anti-patterns.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `anti-patterns.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Critical Anti-Patterns (Must Fix)

### 1. Query in Loop

### 2. Direct Attribute Access (Dot Notation)

### 3. Subquery in SELECT

### 3a. Correlated Subquery in WHERE (per-row semi-join)

## High Priority Anti-Patterns

### 4. Virtual Table Filter in WHERE

### 5. Missing ПЕРВЫЕ N

### 5a. Unindexed Temp Table in Join or Union

### 6. Excessive Client-Server Calls

### 7. Using &НаСервере Instead of &НаСервереБезКонтекста

### 7a. Using `Сообщить()` for User Notifications

## Medium Priority Anti-Patterns

### 7b. Redundant РАЗЛИЧНЫЕ (union / grouping already deduplicates)

### 8. Missing Caching

### 9. O(n²) Algorithm

### 10. Deep Nesting

## Architectural Anti-Patterns

### Big Ball of Mud

### God Module

### Tight Coupling

### Copy-Paste Architecture

### Premature Optimization

## Optimized Patterns

### Batch Query with Temp Table

### Bulk SSL Attribute Access

## Confidence Scoring (for Reviews)

## Quick Reference Checklist
