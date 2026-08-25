---
description: 1C Data Composition System (СКД / DCS) design rules — data sets, computed fields vs resources, parameters, settings, variants, programmatic override patterns. Load when designing or reviewing a DCS-based report.
alwaysApply: false
category: development
---

# DCS / СКД — Report Design Rules

The 1C Data Composition System (СхемаКомпоновкиДанных, СКД) is the canonical engine for reports. The rules below cover design decisions that recur in code review and that the structural skill (`content/skills/1c-metadata-manage/docs/skd-manage.md`) intentionally does not opine on.

> **Scope.** This file owns *report design* rules. XML / schema mechanics for `.dcs` files live in the `content/skills/1c-metadata-manage/docs/skd-manage.md` skill (XML structure, datasets API, query parameters API). Anti-patterns of slow queries inside a DCS — `anti-patterns.md` and `dev-standards-architecture.md §3 → "Queries"`.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="dcs-design")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dcs-design.md>

## Sections

Every heading this file has always had, reproduced so that existing `dcs-design.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Choosing the data-set type

## 2. Computed fields vs resources

## 3. Parameters

## 4. Variants and settings

## 5. Programmatic override

## 6. RLS interaction

## 7. Performance checklist

## 8. Companion rules
