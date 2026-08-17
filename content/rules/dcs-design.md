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

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/dcs-design.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dcs-design.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `dcs-design.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Choosing the data-set type

## 2. Computed fields vs resources

## 3. Parameters

## 4. Variants and settings

## 5. Programmatic override

## 6. RLS interaction

## 7. Performance checklist

## 8. Companion rules
