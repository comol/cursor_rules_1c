---
description: Designing 1C registers — dimensions, resources, attributes, periodicity, indexes, balances vs turnovers, posting / reposting / sequence restoration. Load when creating or restructuring an information / accumulation / accounting register.
alwaysApply: false
category: development
---

# Register Design Rules

Registers are the spine of any non-trivial 1C configuration; mistakes here are expensive to undo because they are usually wired into document posting, RLS, and reports. This file consolidates the design decisions worth thinking through **before** running the metadata skill.

> **Scope.** This file owns *design* rules. XML / schema mechanics live in `content/skills/1c-metadata-manage/docs/meta-manage.md`. Queries against registers — start at the router `query-design.md` (hard rules in `dev-standards-architecture.md §3 → "Queries"`, anti-patterns in `anti-patterns.md`).

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="registers-design")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/registers-design.md>

## Sections

Every heading this file has always had, reproduced so that existing `registers-design.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Choosing the register type

## 2. Dimensions

## 3. Resources

## 4. Attributes

## 5. Indexing

## 6. Subordination to a registrar (only for accumulation / accounting / calculation)

## 7. Balances, turnovers, slices

## 8. Posting / reposting

## 9. Querying registers

## 10. RLS

## 11. Companion rules
