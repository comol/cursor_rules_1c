---
description: 1C anti-patterns, performance guidelines, and code review scoring
alwaysApply: false
category: quality
---

# 1C Anti-Patterns and Performance Guidelines

> **Ownership.** This file owns the anti-pattern **catalog**: severity, detection hints, before/after fix templates. The normative query rules themselves (no queries in loops, parameterization, `КАК` aliases, virtual-table filters via parameters, intermediate result variable, `ВТ_*` naming, `ПЕРВЫЕ N`) are owned by `dev-standards-architecture.md §3 → "Queries"`; the dot-notation ban — by `dev-standards-architecture.md §4`. On conflict, the owner file wins — update rules there, update examples here.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="anti-patterns")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/anti-patterns.md>

## Sections

Every heading this file has always had, reproduced so that existing `anti-patterns.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

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
