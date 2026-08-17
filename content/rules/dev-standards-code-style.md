---
description: BSL code style — formatting, quality metrics, forbidden constructs, naming, public API documentation, typography, comments, and internal review
alwaysApply: false
category: development
---

# Development Standards — BSL Code Style

**When to load this file:** before writing or reviewing BSL when formatting, naming, forbidden constructs, quality limits, public procedure documentation, typography, comment quality, or the internal review baseline is relevant.

Section numbers 2 and 5–8 are preserved from the former monolithic `dev-standards-core.md` for stable references.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/dev-standards-code-style.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dev-standards-code-style.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `dev-standards-code-style.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 2. Code Style (single source of truth — referenced from `AGENTS.md`)

### Formatting

### Alignment

### Quality Metrics

### String Building

### Forbidden Calls and Constructs

### Naming

### Conditions

### Function Parameters

## 5. Procedure/Function Documentation

## 6. Typography

## 7. Comments — OK / NOT OK Examples

### NOT OK — code paraphrase and noise

### OK — motivation, context, constraints

### Verification rule

## 8. Internal Code Review After Each Edit
