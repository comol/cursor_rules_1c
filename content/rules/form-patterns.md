---
description: Managed-form layout patterns — archetypes (document, data processor, list, catalog item, wizard), naming conventions, layout principles, and advanced ERP patterns. Load when designing a form layout from scratch or when the requirements do not specify element placement.
alwaysApply: false
category: forms
---

# Managed-Form Layout Patterns

Design guidance for managed forms, distilled from typical 1C configurations. Use when building a form and the user's requirements do not spell out where elements go. This is layout knowledge — it applies whether the form is edited via the `1c-metadata-manage` skill, EDT, or Designer. It complements the entry point `forms.md` and the hand-editing gotchas in `metadata-xml-workarounds.md`.

Element and group names below (`ГруппаШапка`, `Отбор[Поле]`, …) are the conventional 1C identifiers — keep them in Russian as shown; they are real names, not prose.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/form-patterns.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/form-patterns.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `form-patterns.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Form archetypes

### Document form

### Data-processor form (DataProcessor)

### List form

### Catalog item form

### Wizard

## Naming conventions

### Groups

### Elements

### Event handlers

## Layout principles

## Advanced patterns (ERP)

### Collapsible groups

### Status banner

### Popup menu in the command bar

### Form without a standard command bar

### Hyperlink label to open subforms

## Source
