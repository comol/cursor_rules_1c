---
description: Coding standards — forbidden constructs, comments, code review, module regions, queries, data access, performance (headlines + pointers)
alwaysApply: false
category: development
---

# Coding Standards (headlines)

Authoritative content for code style, naming, comments, queries, data access and performance lives in the detailed on-demand rules: `dev-standards-code-style.md`, `dev-standards-change-markers.md`, `dev-standards-architecture.md`, `module-structure.md`, `anti-patterns.md`, `platform-solutions.md`, `locks-and-transactions.md`, `logging-strategy.md`. Project / process parameters live separately in `dev-standards-env.md`; `dev-standards-core.md` is only their compatibility router. Managed-form work — start at the router `forms.md`, then load companions it selects (`form-patterns.md`, `forms-add.md`, `form-module.md`, `async-methods.md`, …). Query work — start at the router `query-design.md`. This file is the index of headlines and anchors. **Before writing or reviewing code, load the relevant detail file.**

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/coding-standards.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/coding-standards.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `coding-standards.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Forbidden Calls and Constructs (project-wide)

## Comments

## Code Review After Each Edit

## Code Reuse

## Module Regions

## Managed Forms

## Queries

## Data Access — Reference Attributes

## Performance

## Project Rules Stricter Than the ITS Standard
