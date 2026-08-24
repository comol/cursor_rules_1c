---
description: Systematic 4-phase debugging methodology adapted for 1C (reproduce → hypothesize → experiment → fix), with a fast path for directly evidenced root causes (DEBUG_FAST_PATH in .dev.env)
alwaysApply: false
category: quality
---

# Systematic Debugging — 1C Adaptation

**When to load this file:** any task that involves diagnosing a bug, runtime error, regression, performance regression, or unexpected behavior — whether the parent agent is debugging directly or delegating to the `1c-error-fixer` / `1c-performance-optimizer` subagent.

**Goal:** replace ad-hoc trial-and-error with a structured root-cause loop. Skipping a phase is a defect — unless the bug qualifies for the **fast path** below, which is a documented shortcut, not a skipped phase.

The methodology is adapted from the `systematic-debugging` skill of [obra/superpowers](https://github.com/obra/superpowers) and combined with 1C platform mechanics (debugger, `ЖурналРегистрации`, `ОтчетПоЖурналуРегистрации`, `ПоказатьЗначение`, `СообщитьПользователю`, `Replay` of background jobs, technological log).

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="systematic-debugging")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/systematic-debugging.md>

## Sections

Every heading this file has always had, reproduced so that existing `systematic-debugging.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## Core principle

## Fast path — for directly evidenced root causes

## The four phases (full loop)

### Phase 1 — Reproduce

### Phase 2 — Hypothesize

### Phase 3 — Experiment

### Phase 4 — Fix

## Anti-patterns

## Process flow

## Companion rules
