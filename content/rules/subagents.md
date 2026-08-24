---
description: Subagent catalog — when to delegate to a specialized subagent vs. execute directly; model-tier routing and bounded sidecar task templates
alwaysApply: false
category: workflow
---

# Subagents — catalog and delegation rules

**When to load this file:** if a task feels large / multi-step / multi-module and you suspect it is worth delegating to a specialized subagent — read this file, check the availability of a suitable subagent in the table below, and decide whether to delegate or execute directly.

## Delegation principle

13 specialized subagents are available in the project. Source prompt files live in `content/agents/` and use short file names without the `1c-` prefix:

| Subagent id | Source prompt file |
|---|---|
| `1c-explorer` | `content/agents/explorer.md` |
| `1c-analytic` | `content/agents/analytic.md` |
| `1c-planner` | `content/agents/planner.md` |
| `1c-architect` | `content/agents/architect.md` |
| `1c-arch-reviewer` | `content/agents/arch-reviewer.md` |
| `1c-developer` | `content/agents/developer.md` |
| `1c-metadata-manager` | `content/agents/metadata-manager.md` |
| `1c-refactoring` | `content/agents/refactoring.md` |
| `1c-performance-optimizer` | `content/agents/performance-optimizer.md` |
| `1c-error-fixer` | `content/agents/error-fixer.md` |
| `1c-tester` | `content/agents/tester.md` |
| `1c-code-reviewer` | `content/agents/code-reviewer.md` |
| `1c-doc-writer` | `content/agents/doc-writer.md` |

**Delegate when:**

- the work is large enough to justify the subagent launch overhead;
- the task would otherwise drain the parent agent's context window (long traces, large files, mass edits);
- several independent checks can be run in parallel (most subagents have `allowParallel: true`).

**Do not delegate** when the task is a trivial single-file edit, or a medium full-cycle task that fits the parent's context comfortably — execute it directly (the standard path: the 5-step Development Procedure from `AGENTS.md` plus the closing gate). The pipeline in `subagent-pipeline.md` applies only when delegation is chosen here.

**Model profile.** The active-model profile (`AGENT_MODEL` in `.dev.env` — `content/rules/model-adaptation.md`) may tune **how eagerly** you delegate within these criteria: some models delegate too readily and their profile biases toward direct execution and low spawn counts, others sustain parallel subagents well and their profile encourages independent parallel tracks. The criteria above, the per-subagent "when NOT to call" column, the built-in-explorer ban, and every common obligation stay unchanged — a profile never adds a subagent the rules forbid, and never removes one they require. In particular, no profile authorises a subagent spawned to double-check your own work.

**Economy mode.** When `.dev.env` has `ORCHESTRATION=economy` (toggled by `/economymode`; empty / missing = `standard`), load `content/rules/orchestrator-economy.md`: delegation of execution becomes the default — the parent keeps decisions, specs, and verification, subagents do the reading and writing. Check the key when loading this file for a non-trivial task. The mode only widens delegation; every constraint of this file stays intact, and model selection still resolves from `SUBAGENT_MODEL_*` per tier.

## Host-tool built-in explorers (hard ban)

Cursor (and some other hosts) ship a **built-in** Explore helper — e.g. Cursor Task `subagent_type: "explore"` — with a fixed, non-overridable system prompt. That helper is **not** this project's explorer. It does not run the MCP-first fallback chain, does not prefer 1C graph / code-metadata tools, and does not return the structured report from `content/agents/explorer.md`.

**Hard rule for the parent:**

1. For any delegated read-only exploration that matches the `1c-explorer` row in the catalog below — launch **`1c-explorer`** (source: `content/agents/explorer.md`; installed custom agent under the active tool, e.g. `.cursor/agents/explorer.md`, `.claude/agents/explorer.md`, …).
2. **Do not** launch the host's built-in Explore / `explore` / generic codebase scout for that work. Prefer an explicit custom-agent invocation (`/1c-explorer …`, or the host's "use the 1c-explorer subagent" / Task launch by custom agent name) over a built-in `explore` type.
3. If the session's Task / subagent API only exposes built-in types and **cannot** start the installed `1c-explorer` — **do not** silently substitute built-in Explore. Either (a) run the exploration on the parent with MCP-first search, or (b) tell the user that `1c-explorer` is not launchable in this session. Falling back to built-in Explore is a defect.
4. `AGENTS.md` / project rules steer the **parent**; they do not rewrite the built-in Explore prompt — so "putting explore instructions in rules" is not a substitute for calling `1c-explorer`.

This ban is Cursor-shaped (built-in Explore is the common failure) but applies to **any** host-native generic explorer that bypasses the project agent prompt.

## Common obligations

Every subagent inherits these obligations from `AGENTS.md` even when its own prompt does not repeat them. Parent agents and subagent authors must not weaken them.

### CONFUSION format

Canon — `AGENTS.md → Development Procedure → 1. Think Before Coding` (triggers, format, low-risk assumption rule). Material fork = data integrity, transactions / posting, metadata shape, public contracts, security / RLS, anything hard to reverse, a conflict with existing code / БСП / `РежимСовместимости`, or an under-specified material edge case.

**Subagent-specific:** never resolve a material fork by silently picking one interpretation, returning a partial result, or paraphrasing the question into free-form prose — raise the block and stop. Low-risk ambiguity: state the assumption in one line and proceed.

### MCP-first search

Canon — `content/rules/mcp-first-search.md` (chain: graph → code-metadata → `grep=true` retry → native tools; bounded priority, not a ban).

**Subagent-specific:** the chain binds subagents exactly as it binds the parent; when you fall back to a native discovery tool, state in the report which MCP attempts were tried and why they missed.

### Metadata mutations via the skill (mutating agents)

Canon — `AGENTS.md → Skills and Subagents`; exceptions only per `content/skills/1c-metadata-manage/SKILL.md → Hard rule`.

**Subagent-specific:** the gate binds **every** mutating subagent, not only `1c-metadata-manager`. A `1c-developer` / `1c-error-fixer` / `1c-refactoring` task that turns out to require a form or metadata change either drives it through the skill itself or reports it back to the parent for delegation — it does not hand-edit the XML. Name the path used in the report (`Metadata tooling: …`).

In EDT projects (`.dev.env` `USE_EDT=true`) the binding extends to the source format: before a delegated metadata change, the subagent establishes whether the tree is a Designer XML dump or an EDT (`src/**/*.mdo`) workspace and routes accordingly — `content/rules/edt-workflow.md`. Hand-editing `*.mdo` / `*.form` is a defect with no exception, and the EDT path is named in the report (`EDT tooling: …`).

On repository-bound projects (`.dev.env` `REPOSITORY_PATH` set) the same binding extends to the repository discipline: objects are locked via the `1c-repository-manage` skill before mutation and the lock/commit trail is reported (`Repository tooling: …`); unbind is forbidden while bound — canon `AGENTS.md → Skills and Subagents` and that skill's `docs/repo-sdlc.md`.

### Verification checklist (mutating agents)

Canon — `content/rules/verification-checklist.md` (ordered hard gates: `syntaxcheck` → `check_1c_code` → `review_1c_code` → impact analysis → metadata XML validation, as applicable).

**Subagent-specific:** for every mutated artifact, report each applicable validator's result and run count **after the final edit** — the parent reuses that evidence instead of repeating validators on unchanged content. Read-only agents (`1c-explorer`, `1c-analytic`, `1c-arch-reviewer`, `1c-code-reviewer`, `1c-doc-writer` when not writing project sources) skip the mutating gates and the metadata-skill gate but still follow CONFUSION and MCP-first search.

Each agent prompt ends with a short **Common obligations** pointer to this section — keep that pointer in sync when editing this file.

## Subagent catalog

| Subagent | When to call | When NOT to call |
|---|---|---|
| **1c-explorer** | Read-only exploration across many files, metadata objects, dependencies, or "where/how/who calls" questions before planning, coding, or refactoring. **Mandatory** for delegated exploration — never the host built-in Explore (see *Host-tool built-in explorers*) | Narrow lookup that the parent can answer with one direct read/search; host-tool Cursor-guide / docs lookup (not 1C project source) |
| **1c-analytic** | User asks for a PRD, specification, or analysis of an existing area without writing code | Task is to write code |
| **1c-planner** | A multi-step implementation or refactoring plan is needed before coding | Task is small enough that the plan is 1–2 lines |
| **1c-architect** | Designing the architecture of a sizable modification (new subsystem, integration, multi-module change) | Single-procedure or single-module change |
| **1c-arch-reviewer** | User asks to review or validate an architectural decision before implementation | No architectural design exists yet |
| **1c-developer** | Bulk code writing or modification across multiple modules that would otherwise drain the parent's context | Small local edit (Quick-fix path — see `AGENTS.md → Development Procedure`) |
| **1c-metadata-manager** | Creating, scaffolding, compiling, or multi-step / multi-domain metadata operations (objects, forms, reports, layouts, roles, extensions) | Single info lookup or single XML attribute fix — use a direct edit or the `1c-metadata-manage` skill |
| **1c-refactoring** | Dead-code cleanup, consolidation, or deduplication across multiple modules | Refactor is local to one procedure |
| **1c-performance-optimizer** | User reports slowness, or query / loop optimization is the explicit task | No performance concern was raised |
| **1c-error-fixer** | Quick fix of syntax / runtime errors / BSL LS warnings without architectural changes (tier `light` — runs on the small-tasks model when one is configured) | The fix requires architectural rework — escalate to `1c-architect` / `1c-developer` |
| **1c-tester** | User asks to verify changes via deploy + UI automation against a test infobase, **and** `UI_TESTING` allows it (canon — `dev-standards-env.md`) | No test infobase; purely static task; `UI_TESTING=off`, or `manual` without an explicit UI-test request — never auto-trigger |
| **1c-code-reviewer** | **Only when the user explicitly asks for a code review** | Auto-triggering after edits is forbidden |
| **1c-doc-writer** | User-facing documentation: user guides, admin manuals, tutorials, codemaps, API references | Inline code documentation (module / procedure headers) — that is the developer's responsibility |

## Model-tier routing

Subagent source files do **not** hard-code model names. Each agent declares an abstract tier in its frontmatter — `modelTier: coding`, `modelTier: analysis`, or `modelTier: light` — and the installer resolves the tier into a concrete model from `.dev.env` (`SUBAGENT_MODEL_CODING` / `SUBAGENT_MODEL_ANALYSIS` / `SUBAGENT_MODEL_LIGHT`, all Defaulted: empty = the AI client's default model; see `dev-standards-env.md → "Subagent model parameters"`). Model names live only in project settings, never in rules or agent prompts. On first install the installer proposes a benchmark-based profile (`Balanced` / `Economy` / `Quality`, derived from <https://onec-llm-bench.lovable.app/>); the recommendation lives in the installer / `.dev.env`, not here.

The three tiers:

- **`coding`** — code / metadata authorship and design: writing or editing BSL and metadata, architecture design. Agents: `1c-developer`, `1c-metadata-manager`, `1c-architect`, `1c-performance-optimizer`, `1c-refactoring`. Warrants the strongest model — this tier mutates production code.
- **`analysis`** — reasoning without production-code authorship: planning, analysis, review, testing, documentation. Agents: `1c-planner`, `1c-analytic`, `1c-arch-reviewer`, `1c-code-reviewer`, `1c-doc-writer`, `1c-tester`. A strong-value model is usually enough.
- **`light`** — small bounded tasks where a cheaper / faster model saves limits without hurting quality: repo scouting, search, impact lists, quick error fixes, mechanical post-edit checks. Agents: `1c-explorer`, `1c-error-fixer`.

Routing rules:

- **Good candidates for the `light` tier** (when the active tool supports a per-invocation model override, the parent may route these down even to a `coding`-tier agent): initial project-source scouting and candidate lists; navigation / reference gathering for objects, modules, forms, procedures; impact lists ("where is X used"); mechanical verification after edits; small bounded edits in strictly assigned files.
- **Never use the `light` tier as the final authority** for architecture, metadata / form design, transactions, registers, complex queries, security, data integrity, or release-critical decisions. Output of a light-tier run is working material, not a source of truth — the parent agent owns decomposition, source boundaries, the final decision, verification, and integration.
- **Do not delegate trivial single-step tasks at all** — the launch overhead exceeds the saving.
- The tier system does not change validation obligations: whatever tier produced the change, the applicable validator chain and closing gate from `verification-checklist.md` still apply, including quick-fixes.

## Bounded sidecar task templates

When delegating, the launch prompt must make the task **bounded and self-contained**. Every delegation prompt includes:

- **bounded responsibility** — one verifiable goal, not "help with the task";
- **allowed and forbidden sources** — which MCP servers / files to use; the MCP-first search discipline (`mcp-first-search.md`) applies to subagents too;
- **read/write scope** — explicitly read-only, or an explicit list of files the subagent may edit;
- **expected output format** — what the report must contain;
- a reminder that the subagent **is not alone in the codebase**: it must not revert or overwrite changes outside its scope and must not delete files without an explicit instruction.

Reusable templates (fill in `<...>`; they slot into the matching subagent from the catalog):

### explorer-impact — read-only impact analysis (`1c-explorer`, light-tier candidate)

```text
Read-only impact analysis. Find all references to <object / procedure / attribute>.
Follow the project MCP fallback chain (graph metadata → code metadata → grep=true retry → Grep).
Thoroughness: <quick | medium>. Do not edit files.
Return: locations with file/line references and qualified 1C names, usage categories
(call / query / RLS / form / subscription), risky dependencies, and gaps you could not verify.
```

### explorer-patterns — find existing implementations (`1c-explorer`, light-tier candidate)

```text
Read-only pattern search. Find existing implementations similar to <task>.
Prefer templatesearch / ssl_search / search_code over raw grep. Do not edit files.
Return: 3–7 best examples with paths and qualified names, which pattern to reuse, and what NOT to copy.
```

### metadata-scout — inspect an object / form before a change (`1c-explorer`, light-tier candidate)

```text
Read-only metadata/form scout. Inspect <metadata object / form / layout> via get_object_dossier /
get_metadata_details / inspect_form_layout; confirm against the source XML/BSL when in doubt.
Do not edit files. Return: object structure, form elements / commands / events, related modules,
validation risks, and a suggested write scope for the implementation step.
```

### worker-bounded-edit — implementation within fixed boundaries (`1c-developer` / `1c-error-fixer`)

```text
Bounded implementation. You are not alone in the codebase; do not revert or overwrite edits
outside your scope. Edit only: <files>. Implement <specific change> per the approved plan.
Follow project rules (dev-standards-code-style, module-structure). For BSL run syntaxcheck →
check_1c_code → review_1c_code on every touched module within the verification budget;
for metadata XML run verify_xml (and both chains when it embeds BSL).
Return: changed files, diff summary against the plan, checks performed, unresolved risks.
```

### reviewer-risk — independent review (`1c-code-reviewer`, **only when the user explicitly asked for a review**)

```text
Independent review of the current change for bugs, regressions, missing checks, and project-rule
violations. Review scope: <parent-provided git diff and/or explicit file list>. Do not edit files.
The reviewer has no Shell / Grep / Glob access and must not infer an absent scope. High-confidence
findings only, ordered by severity, with file/line references; then test gaps and residual risk.
```

### smoke-check — mechanical post-change verification (`1c-explorer`, light-tier candidate)

```text
Read-only smoke check. Verify that <feature / rule / artifact> is discoverable and consistent through
its intended entry points (referenced paths exist, names match, wiring is complete). Do not edit files.
Return: exact checks performed, observed result, pass/fail per item.
```
