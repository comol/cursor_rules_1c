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

**The normative text of this file is not inlined here.** It is indexed as one document in the `ai-rules-1c-standards` corpus of the Help MCP server (`1C-docs-mcp`), pinned at commit `410951e74fd3`, and it is retrieved rather than carried:

```
docsearch(query="<the specific thing you need>", corpus="ai-rules-1c-standards")
docinfo(name="ai-rules-1c-standards/content/rules/bsp-access-rights.md", corpus="ai-rules-1c-standards")
```

`docsearch` for a question, `docinfo` for the whole file. Both accept `corpus="ai-rules-1c-standards"`, which fences the answer to this organisation's standards and keeps platform documentation out of it.

**Retrieve before you apply.** Every section below is a heading with no body: acting on a section title without reading the text behind it is inventing the rule, not following it. One `docsearch` naming the section is enough; do not guess the content from the title.

**If the Help server does not answer — stop and say so.** A standard that cannot be retrieved is a standard that cannot be applied. Do not proceed on memory, do not reconstruct the rule from the section title, and do not silently skip the check. Report that `1C-docs-mcp` is unavailable, name what you were trying to retrieve, and either wait for it or ask how to proceed. Where a hard gate in `verification-policy.md`, `verification-gates.md` or `verification-delivery.md` depends on a standard from this file, an unavailable server **fails the gate** — it does not pass it by default.

Read the pinned text directly if you need to: <https://github.com/comol/ai_rules_1c/blob/410951e74fd3e6b7a763cf49757935b9a34d3f31/content/rules/bsp-access-rights.md>

## Sections

The headings this file has always had, reproduced as headings rather than as a list so that every existing `bsp-access-rights.md §N` reference and every anchor link still resolves - the same compatibility shape `dev-standards-core.md` uses. Each is a retrieval target, not a summary.

## 1. `Роли.Роль` is a reference, not a string

## 2. Extension roles live in a different catalog

## 3. Create / update template

## 4. Assigning a profile to a user

## 5. Checking rights, roles and RLS

## 6. Anti-patterns

## 7. Companion rules
