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

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="form-patterns")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/form-patterns.md>

## Sections

Every heading this file has always had, reproduced so that existing `form-patterns.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

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
