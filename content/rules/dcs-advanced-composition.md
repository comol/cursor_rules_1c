---
description: Advanced programmatic composition in СКД — two-pass preprocessing of detail records before roll-up (hiding zero-total crosstab rows / columns), and executing the composition query directly instead of the DCS output processor for memory-heavy reports. Load only when the standard `ПриКомпоновкеРезультата` override of `dcs-design.md §5` is not enough.
alwaysApply: false
category: development
---

# СКД — advanced composition techniques

Two techniques that go beyond the standard programmatic override. Both are **escalations**: reach for them only after the ordinary route of `dcs-design.md §5` (override `ПриКомпоновкеРезультата`, manipulate settings, output through `ПроцессорВыводаРезультатаКомпоновкиДанныхВТабличныйДокумент`) has been shown insufficient. Both give up part of the standard DCS semantics, and that cost is the reason they are not the default.

| Technique | Solves | Gives up |
|---|---|---|
| **Two-pass preprocessing** (§1) | Filtering / transforming **detail records before the engine rolls them up** | A second full composition pass; the schema must stay query-based |
| **Direct query execution** (§2) | Memory blow-up of the DCS engine on large reports; a flat "raw" result | Groupings, conditional appearance, drill-down (расшифровка), DCS totals |

---

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="dcs-advanced-composition")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dcs-advanced-composition.md>

## Sections

Every heading this file has always had, reproduced so that existing `dcs-advanced-composition.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Two-pass preprocessing

### The problem it solves

### Algorithm

### Gotchas

## 2. Direct query execution instead of the DCS engine

### When

### Algorithm

### Two sources for query and parameters

### Gotchas

### Wiring a command into the БСП report form

## 3. Companion rules
