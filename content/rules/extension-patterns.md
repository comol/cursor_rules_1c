---
description: 1C configuration extension (CFE) patterns — interceptor types (`&Перед` / `&После` / `&Вместо` / `&ИзменениеИКонтроль`), `ПродолжитьВызов` rules, change markers, adopted-object constraints. Load when writing or reviewing extension code.
alwaysApply: false
category: architecture
---

# 1C Extension Patterns (CFE)

BSL patterns for working with 1C configuration extensions.

Applies to: extension code (`**/Extensions/**/*.bsl` and similar).

Background reference: `dev-standards-architecture.md §2` (Extensions) — modification priority, directives, placement rules. This file is the **practical** companion: interceptor types, `ПродолжитьВызов` semantics, markers, and adopted-object constraints.

> **Naming convention used in examples.** Below, `Расш1_` / `МоеРасш_` denotes the **extension's own short alias** (set in the extension's properties — typically the `Имя` of the extension or an explicit alias), **not** `{PREFIX}` from `.dev.env`. `{PREFIX}` applies to new metadata objects and attributes; the extension alias applies to procedure / function names introduced by the extension and prevents name collisions between extensions. The two are independent: an extension can both add a new attribute `{PREFIX}Признак` to a typical object and define an interceptor procedure `Расш1_ПриЗаписи` in the same module.
>
> The alias itself MUST NOT contain the letter «ё» — see `dev-standards-code-style.md → Typography`. Use `МоеРасш_`, `Расш1_`, `MyExt_` or any «ё»-free form.

---

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="extension-patterns")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/extension-patterns.md>

## Sections

Every heading this file has always had, reproduced so that existing `extension-patterns.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Interceptor types

### Before / After — simple interceptors

### Вместо — full replacement

### ИзменениеИКонтроль — controlled body edit

## ПродолжитьВызов() rules

## Change markers

## Constraints on adopted (borrowed) objects

## Anti-patterns

### Direct edit of an adopted module

### Forgotten ПродолжитьВызов in &Вместо

### ПродолжитьВызов inside &ИзменениеИКонтроль

### No prefix in extension method names

## Extension purpose tag
