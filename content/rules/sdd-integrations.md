---
description: "OpenSpec integration. Load when working with the openspec/ workspace (specs and change proposals)."
alwaysApply: false
category: integrations
---

# SDD Integration — OpenSpec

[OpenSpec](https://github.com/Fission-AI/OpenSpec) is the only SDD framework supported by this project. Other SDD frameworks (Memory Bank, Spec Kit, TaskMaster, etc.) are **not** supported — do not generate or update artifacts for them, even if the corresponding folders or MCP servers happen to be present.

## Canonical sources

Layout, spec format, delta format, and the full workflow are described in the workspace itself — do not duplicate them here:

| Topic | File |
|-------|------|
| Workspace layout, slash commands, refresh policy | [`openspec/README.md`](../../openspec/README.md) |
| Spec format and conventions for `openspec/specs/` | [`openspec/specs/README.md`](../../openspec/specs/README.md) |
| Change-proposal layout and delta format for `openspec/changes/` | [`openspec/changes/README.md`](../../openspec/changes/README.md) |

Read those files before writing or editing OpenSpec artifacts.

## Subagent → OpenSpec artifact mapping

Each subagent owns specific OpenSpec artifacts. Use this table to decide where a given subagent must write.

| Subagent | Reads | Writes |
|----------|-------|--------|
| **analytic** | existing `specs/` for context | `changes/<id>/proposal.md`, new entries under `specs/` (via deltas) |
| **planner** | `specs/`, `changes/<id>/proposal.md`, `design.md` | `changes/<id>/tasks.md` |
| **architect** | `specs/`, `changes/<id>/proposal.md` | `changes/<id>/design.md` |
| **arch-reviewer** | `changes/<id>/design.md`, `proposal.md`, `specs/` | review notes (no artifact writes) |
| **developer** | `specs/`, active `changes/<id>/` | code; updates `changes/<id>/specs/` deltas and ticks `tasks.md` |
| **metadata-manager** | `specs/`, active `changes/<id>/` | metadata XML/forms; spec deltas under `changes/<id>/specs/` for new/changed metadata objects |
| **refactoring** | `specs/`, active `changes/<id>/` | code; updates deltas only when observable behaviour changes |
| **performance-optimizer** | `specs/` (NFR/perf requirements) | code; deltas only when a perf NFR changes |
| **error-fixer** | active `changes/<id>/` | code; usually no spec changes (bug fix preserves intended behaviour) |
| **tester** | `specs/` (scenarios), `changes/<id>/tasks.md` | test results, ticks in `tasks.md` |
| **code-reviewer** | `specs/`, `changes/<id>/specs/` deltas | review verdict against requirements (no artifact writes) |
| **doc-writer** | `specs/`, `changes/archive/` | user-facing docs derived from specs |

## Phase → subagent mapping

The default `propose → apply → archive` workflow maps to subagents as follows:

| Phase | Driver subagent(s) | Output |
|-------|-------------------|--------|
| Requirements | `analytic` | `proposal.md` + initial deltas under `changes/<id>/specs/` |
| Design | `architect` (optionally reviewed by `arch-reviewer`) | `design.md` |
| Planning | `planner` | `tasks.md` |
| Implementation | `developer`, `metadata-manager`, `refactoring`, `performance-optimizer`, `error-fixer` | code + updated deltas + ticked `tasks.md` |
| Verification | `tester`, `code-reviewer` | test results, review verdict |
| Documentation & archive | `doc-writer`, then `/opsx:archive` | user docs; deltas merged into `specs/`, change moved to `changes/archive/` |
