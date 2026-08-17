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

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/extension-patterns.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/extension-patterns.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `extension-patterns.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

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
