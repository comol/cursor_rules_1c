---
description: Development standards — architecture patterns, extensions, platform standards, code smells
alwaysApply: false
category: development
---

# Development Standards — Architecture & Platform

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="dev-standards-architecture")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/dev-standards-architecture.md>

## Sections

Every heading this file has always had, reproduced so that existing `dev-standards-architecture.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. Architecture Patterns

### Code Placement

### "Result-Structure" Pattern

### "Early Return" Pattern

### "Value Table Search" Pattern

### Event Subscriptions

### New Metadata Objects Placement

### Background Jobs

### Defensive Type Checking

### Safe Structure Property Access

### Collection Normalization

## 2. Extensions

### Modification Priority

### Extension Directives

### Placement Rules (when `{NEW_OBJECTS_IN} = main_configuration`)

### Forms in Extensions

## 3. Platform Standards

### Async and Modality

### Client-Server Interaction

### Security

### Error Handling

### Dates

### Queries

### Cross-Platform Compatibility

### Platform Version Compatibility

## 4. Data Access — Reference Attribute Access

### Caching and Batch Retrieval

## 5. Performance Headlines

## 6. Code Smells (see `anti-patterns` rule for the full catalog)
