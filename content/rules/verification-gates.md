---
description: Verification execution gates for BSL and metadata — evidence reuse, syntax, logic, style, impact analysis, XML validation, and the platform batch check before an infobase apply
alwaysApply: false
category: quality
---

# Verification Gates — BSL, Impact, and Metadata

**When to load this file:** before validating or declaring a BSL / metadata change done. Determine depth and promotion triggers first via `verification-policy.md`.

Delivery-only soft gates and the final report contract live in `verification-delivery.md`.

## Gate execution and evidence reuse

A gate is a requirement for the current artifact state, not a request to call the same tool
again. The agent that makes the final edit to an artifact owns its applicable validator run and
records the artifact path, validator result and run count in the handoff / implementation report.

The parent closing gate MUST reuse that evidence when it was produced after the latest edit.
It runs only missing or stale gates and MUST NOT repeat a validator against unchanged content
(`AGENTS.md → MCP Tool Calling → C.2`). Any later edit invalidates the affected validator
evidence; the final editor becomes the new owner. The same rule applies to `verify_xml` and
impact-analysis evidence.


## Hard gates — run on every full-cycle change

You MUST run all five gates in order. Each gate has an explicit pass / fail criterion and an explicit retry budget. When a required validator is not exposed in the current session, follow the graceful-degradation subsections (after Gate 3 and inside Gate 4) instead of silently skipping. **Gates 3a and 6 are conditional** — each runs only when its own trigger fires and its prerequisite (an exposed server, or a reachable platform + infobase) is present; neither ever replaces Gates 1–3.

The gate descriptions below state the `full` behaviour — the strictest level, and the one a promotion-trigger path always gets. The project default is `standard`: same three validators, one mandatory confirmation after a blocking fix instead of an open-ended retry budget. When `VERIFICATION_DEPTH` is `standard` or `lite`, Gates 1–3 are modulated per `verification-policy.md → "Verification depth levels"` — but a full-cycle change on any promotion-trigger path always runs the complete chain regardless of the level (the safety floor).

### Gate 1 — Syntax (`syntaxcheck`)

- Run `syntaxcheck` on every touched `.bsl` module. No exceptions.
- Pass criterion: zero `error` items. `warning` items are reviewed in Gate 3.
- Retry budget: canon — `AGENTS.md → MCP Tool Calling → B.1`. An `error` is blocking: after fixing it, obtain a clean confirming run on the changed module. Under `full`, allow 3 calls total; under `standard`, 2. If the limit is exhausted without a clean pass on the latest state, Gate 1 fails. Gates 2 and 3 use the same policy with their own blocking severities.

### Gate 2 — Logic & performance (`check_1c_code`)

- Run on every touched module. Always after Gate 1 passes — never before, otherwise the AI checker drowns in syntax noise.
- Pass criterion: no `critical` or `error` severity items.
- `warning` items: triage. Inside-scope warnings (introduced by your change) — fix. Pre-existing warnings outside your scope — leave alone (Surgical Changes).
- AI non-determinism rule: if `check_1c_code` returns inconsistent results across runs on the **same** code, do not loop on it. Take the strictest result, fix what is fixable, document the rest.

### Gate 3 — Style & ITS compliance (`review_1c_code`)

- Run on every touched module after Gate 2 passes.
- Pass criterion: no `error` severity items.
- `warning` items: same triage rule as Gate 2.
- For specific warnings that are intentional and justified: add a `//BSLLS:<rule>` suppression with a 1-line explanation, per `dev-standards-code-style.md → "Formatting"`. Blanket suppressions without justification are forbidden.

### Graceful degradation for Gates 1–3 — when a validator is not exposed

Gates 1–3 are mandatory only when the corresponding validator is exposed in the current session (`AGENTS.md → MCP Tool Calling → A.1`: a server counts as available only when its tools are visible in the tool schema). When a validator is missing, do **not** silently skip its gate:

1. Record the fact in the delivery summary under **Risks** as a fixed line: *"Gate N skipped — `<tool>` (`<server>`) not exposed in this session."*
2. Compensate with what is available. **The platform itself is the first fallback, not manual reading**: when `PLATFORM_PATH` and `INFOBASE_PATH` are configured, `/CheckModules` against the base answers the Gate 1 question directly and `/CheckConfig` covers much of Gate 2's structural half — `content/rules/designer-batch-checks.md → The check ladder`. Record the batch check as the evidence (log path + `/DumpResult` code) exactly as a validator result. Only when no platform / infobase is reachable either: for Gate 1 — a careful manual syntax review of every touched module (paired keywords, directives, parameter lists); for Gates 2–3 — the internal review checklist below.

   **Internal review checklist (inlined on purpose).** This is the fallback for a missing validator, so it must hold when nothing else is reachable — including the Help MCP server. It is the canonical text of `dev-standards-code-style.md §8`, kept here verbatim rather than routed:

   - **Quick-fix** — correctness and edge cases of the changed fragment; plus locks / transactions when the edit sits near transactional code. That is enough — do not run the full checklist on a 10-line fix.
   - **Full-cycle** — the full list: style, readability, correctness, edge cases, security, concurrency / locks / transactions, BSL-LS compliance.
   - Always consider whether an external transaction already exists (e.g. an object-write transaction) before opening a new one.
   - Findings follow the validator budget of `AGENTS.md → MCP Tool Calling → B.1`: a blocking defect needs a clean confirming run on the changed state; non-blocking style noise does not start another review loop. If the limit is exhausted without a clean pass after a blocking fix, do not declare the gate passed — report the artifact as unverified.
3. Delivery is not blocked, but a transactional / metadata / public-API change that went through without Gate 2 must be flagged as needing a follow-up validation run in a session where the server is exposed.

Skipping a gate without recording it under Risks is a defect — the same rule as Gate 4's graceful degradation below.

### Gate 3a — Live-IB smoke check (conditional, `1c-data-mcp`)

Gates 1–3 are static: they confirm that the code parses, follows standards, and has no detectable logic smell. They cannot confirm that a **query actually resolves against this configuration's metadata**. Gate 3a closes exactly that gap, and only that gap.

**Triggers — run when all of the following hold:**

1. The change authored or modified 1C **query text** (module code, DCS scheme, dynamic list) **or** a self-contained BSL function with no side effects whose result the static validators cannot confirm.
2. `1c-data-mcp` is exposed in the current session (`validatequery` / `vcexecutecode` visible in the tool schema).
3. The connected infobase is a development / test base. **On a production infobase this gate is not run** — record the skip and move on.

**Execution:**

- **Query text → `validatequery`.** Pass criterion: `"нет ошибок"`. This parses the query and resolves parameters; it does **not** execute it, does not verify that tables / fields exist, and does not evaluate RLS (`docs/1c-data-mcp.md`).
- **Pure function → `vcexecutecode`** with a **read-only** fragment. Pass criterion: `"ошибок нет"`, or the expected value returned via `Результат`.
- **Mutations are out of scope for this gate.** No `Записать()` / `Удалить()` / `НачалоТранзакции` / register movements — the read-only discipline and the consent rules of `docs/1c-data-mcp.md → Safety and discipline` apply unchanged. If confirming the change requires a mutation, that is a task for `1c-tester` against a test base, not for this gate.
- **Budget:** one call per artifact. Re-run only after the artifact changed — the no-change-repeat rule (`AGENTS.md → MCP Tool Calling → C.2`) applies.

**Failure is blocking for the artifact,** the same as a Gate 1 `error`: fix the query / fragment and re-run once against the changed state.

**When a trigger fired but the gate could not run** (server not exposed, or a production IB), record one line in the delivery summary under **Risks**: *"Gate 3a not run — `<reason>`; query text validated statically only."* Delivery is not blocked. This gate never substitutes for Gates 1–3 and never justifies lowering them.

### Gate 4 — Impact analysis (only when public surface changed)

Skip this gate **only** when the change is fully internal:

- a private procedure of a non-export common module;
- a procedure of a form module that has no `Экспорт`;
- a comment / docstring / `//BSLLS:` suppression edit.

In every other case run impact analysis:

- For every changed export procedure / function, use **`trace_call_chain(routine_name=..., object_name=..., direction="callers")`** to find callers; use `direction="callees"` only when the routine's dependencies may have changed. Fallback to **`get_method_call_hierarchy(method_name=...)`**.
- For a changed metadata or module object, use **`trace_impact(object_name=..., direction="downstream")`** to find dependents; use `direction="upstream"` when its dependency tree also needs review. Fallback to **`graph_dependencies(object_name=...)`**.
- For metadata changes (new attribute, renamed object, removed attribute): **`find_objects_using_object`** + **`find_usages_of_object`** to list every metadata reference that needs to be reviewed.

Pass criterion: every caller / dependent listed by impact analysis was either not affected by the change, or explicitly handled in the plan, or explicitly noted as a follow-up risk in the delivery summary. Silent breakage of downstream code is a defect.

**Graceful degradation — when no applicable impact-analysis tool is exposed.** For routine changes, the applicable pair is `trace_call_chain` / `get_method_call_hierarchy`; for object changes it is `trace_impact` / `graph_dependencies`, plus `find_objects_using_object` / `find_usages_of_object` for metadata references. If neither tool in the applicable branch is available, do **not** silently skip the gate. Instead:

1. State the fact explicitly in the Delivery summary under **Risks** as a fixed line: *"Impact analysis not run — no graph / code-metadata MCP exposed in this session; downstream callers and metadata references were not enumerated."*
2. For metadata changes, perform a best-effort manual review based on what the agent already knows about the change (which forms / modules / queries touch the affected object) — list those callers as candidates that still need review, marked as such.
3. Do not promote a quick-fix to "verified" if a metadata or public-API change went through without impact analysis. If the change is risky and the user cannot accept the residual risk, hand off to a session that has the MCP exposed.

Skipping the gate without recording it under Risks is a defect.

### Gate 5 — Metadata XML validation (only when XML was edited)

Skip this gate **only** when no metadata XML was touched.

When XML was edited:

- **`verify_xml`** on every modified XML file. Pass criterion: zero schema violations.
- **Execution-path check.** Metadata mutations (new objects, attributes, tabular sections, forms, layouts) must have gone through the `1c-metadata-manage` skill / `1c-metadata-manager` subagent — hard gate per `AGENTS.md → Skills and Subagents`. If hand edits were used, this gate passes only when the exception is one of those documented in `SKILL.md → Hard rule` **and** is stated in the delivery summary (`Metadata tooling: hand-edit — <exception>`); additionally cross-check `metadata-xml-workarounds.md` for the recurring traps (LineNumber, PagesGroupExtInfo, Page.enabled, UID uniqueness). Hand-edited metadata without a stated documented exception is a gate failure — the same class as a skipped validator.
- For `Form.xml` edits: also confirm the form opens in Configurator without warnings — schema validity is necessary but not sufficient.

**EDT-format sources (`USE_EDT=true`, MDO tree).** `verify_xml` does not apply to `*.mdo` / `*.form`. The equivalent evidence is EDT's own validation — `revalidate_objects` on the changed objects → `get_project_errors` / `get_problem_summary` — recorded in the delivery summary exactly as `verify_xml` evidence is. The execution-path check is unchanged in spirit: the mutation must have gone through EDT (EDT-MCP, the EDT UI, or a confirmed export/import round trip), and a hand-edited `*.mdo` is a gate failure with no documented exception. Canon — `content/rules/edt-workflow.md → Validation`. Gates 1–3 on BSL are unaffected: modules are plain `.bsl` in both formats. The same substitution applies to Gate 6 below: EDT's validation and `update_database` are that project's applicability evidence, and the batch ladder must not run as a second deployment owner in the same run.

### Gate 6 — Platform batch check (only when the change reaches an infobase)

Gates 1–5 read source. They cannot answer the question the platform answers: does this configuration or extension **apply** to the target infobase. Run this gate when either trigger fires:

1. **An extension is about to be applied** to an infobase — by `/deploy-and-test`, `/update1cbase`, `/restore-testbase`, `/build-release`, or a `db-ops` load. A `&Вместо` / `&ИзменениеИКонтроль` interceptor naming a method that no longer exists in the vendor original passes Gates 1–5 untouched: the source is well-formed and the XML is schema-valid. Only `/CheckCanApplyConfigurationExtensions` sees it.
2. **The main configuration is about to be loaded and applied**, and the change touched metadata or module code that the MCP validators did not cover (a whole-snapshot deploy, a large refactor, a release build).

Execution and pass criterion — `content/rules/designer-batch-checks.md`: the ladder (`/CheckModules` → `/CheckCanApplyConfigurationExtensions` → `/CheckConfig`), stop at the first failure, and the **three-signal verdict** (process exit code + `/DumpResult` + `/Out` diagnostics, success phrases classified before error stems). Warnings fail this gate — `-WarningsAsErrors` will reject the same content at apply time.

Evidence recorded in the delivery summary is the log path plus the `/DumpResult` code, treated exactly like a validator result and subject to the same reuse rule: a later edit invalidates it.

**When the trigger fired but the gate could not run** (no `PLATFORM_PATH` / `INFOBASE_PATH`, or the base is production and no dev/test copy is available), record one line under **Risks**: *"Gate 6 not run — `<reason>`; extension applicability was not verified against an infobase."* Delivery is not blocked, but an extension change delivered without it must be flagged as unverified against a real base. This gate never substitutes for Gates 1–5.
