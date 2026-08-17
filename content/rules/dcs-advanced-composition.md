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

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/dcs-advanced-composition.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dcs-advanced-composition.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `dcs-advanced-composition.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

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
