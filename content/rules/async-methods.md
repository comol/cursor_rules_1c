---
description: 1C asynchronous methods (`Асинх` / `Ждать` / `Обещание`) — patterns and pitfalls for platform 8.3.18+. Load when writing or reviewing client-side async code.
alwaysApply: false
category: forms
---

# Asynchronous Methods in 1C (Асинх / Ждать / Обещание)

Rules for using the asynchronous mechanism introduced in platform 8.3.18+.

Applies to: client-side code with asynchronous calls (`&НаКлиенте`).

Authoritative reference: `dev-standards-architecture.md §3 → "Async and Modality"`. This file gives the practical patterns and the pitfalls.

---

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="async-methods")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/async-methods.md>

## Sections

Every heading this file has always had, reproduced so that existing `async-methods.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Core principles

## Old vs new method correspondence

## Return values (result of `Ждать`)

## Basic template

## Critical rules

### 1. Without `Ждать`, exceptions are silently lost

### 2. `Асинх` in form event handlers does NOT block

### 3. Command handlers — async is allowed

## Pattern: question on form open

## Pattern: question on form close

## Pattern: file workflow

## HTTP methods (platform 8.3.21+)
