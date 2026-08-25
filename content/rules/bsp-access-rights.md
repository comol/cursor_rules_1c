---
description: Programmatic work with БСП access-group profiles and rights — `ПрофилиГруппДоступа` structure, the `Роли.Роль` reference type, extension roles, assigning profiles to users, and the right / role / RLS check API. Load when code creates or updates access profiles, assigns them, or checks rights on a БСП-based configuration.
alwaysApply: false
category: development
---

# БСП access-group profiles and rights — programmatic API

Applies to БСП / SSL 3.x configurations (ЗУП 3.1, БП 3.x, ERP 2.x, УТ 11.x): creating and updating `Справочник.ПрофилиГруппДоступа` from a code console or an update handler, assigning profiles to users, and checking rights, roles and RLS access.

> **Scope.** This file owns the *programmatic* side of access rights. Role **design** — which rights a role grants, RLS templates, role composition — lives in `content/skills/1c-metadata-manage/docs/role-manage.md`. Privileged-mode discipline in reports — `dcs-design.md §6`.

<!-- help-mcp-router -->

## Where this standard lives

**The normative text of this file is not inlined here.** It is one document of the `1c-standards` collection on the Help MCP server (`1C-docs-mcp`):

```
standards(name="bsp-access-rights")     # this standard, entire - the normal call
standards(query="<what you need>")  # only when unsure which rule governs
```

`standards` is the tool for this collection. `docsearch` / `docinfo` serve the platform documentation and cannot reach it, and **no tool of this server takes a `corpus` argument**. Name resolution, paging, budget, and what to do when the server is not exposed - **`content/rules/help-corpus-retrieval.md`**.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without the text behind it is inventing the rule, not following it. Fetch the rule once by name rather than a query per section.

Pinned source, readable directly: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/bsp-access-rights.md>

## Sections

Every heading this file has always had, reproduced so that existing `bsp-access-rights.md` section references and anchor links still resolve - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. `Роли.Роль` is a reference, not a string

## 2. Extension roles live in a different catalog

## 3. Create / update template

## 4. Assigning a profile to a user

## 5. Checking rights, roles and RLS

## 6. Anti-patterns

## 7. Companion rules
