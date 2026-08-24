# Add a platform batch-check gate and a three-signal Designer verdict

## Why

The verification chain of this ruleset is entirely static. `syntaxcheck` parses BSL,
`check_1c_code` and `review_1c_code` are AI reviewers, `verify_xml` validates schema
shape, and `cfe-validate.ps1` validates extension XML structure. None of them compiles
the configuration with the platform itself, and none of them answers the single question
that decides whether an extension works at all: *can this extension be applied to this
infobase?*

The consequence is a hole on the project's main road. `AGENTS.md → Skills and Subagents`
makes an extension the default answer for changing a vendor-supported configuration, so
most risky work lands in a `.cfe`. An extension whose `&Вместо("МетодА")` targets a method
that the vendor renamed passes every gate we have today — valid XML, valid BSL, no logic
smell — and then fails at apply time in the infobase.

Two capabilities close it, both already shipped by the platform and both absent from this
repository (confirmed: `/CheckConfig`, `/CheckModules`,
`/CheckCanApplyConfigurationExtensions`, `/DumpResult` appear nowhere in the source tree):

1. **Designer batch checks** — the platform's own compilation of modules across client and
   server contexts, its configuration integrity test, and its extension applicability test.
2. **A three-signal verdict** — the platform lies about success. A batch run can exit with
   code 0 while the `/Out` log records a fatal error. Today only `db-update.ps1` scans the
   log, against a hardcoded list of update-specific messages, and `/DumpResult` — the
   platform's own machine-readable result code — is not requested by any script.

Both were observed in [Muredsa/1C-Enterprise-Agent-Toolkit](https://github.com/Muredsa/1C-Enterprise-Agent-Toolkit)
(MIT) during a comparison review; the switch sets and the log-diagnostics idea are adapted
from it, the integration into this ruleset's gate model is ours.

## What changes

- **New tool `db-check`** under `1c-metadata-manage`, exposing three check profiles against
  the configuration loaded in the dev infobase: module syntax control, extension
  applicability, and the centralized configuration test. Scope covers **both** the main
  configuration and a named extension.
- **New shared verdict helper** in `content/skills/1c-metadata-manage/tools/_common/`: a batch
  Designer run counts as successful only when the process code is zero, `/DumpResult` is zero,
  and the `/Out` log carries no error diagnostics — with success phrases (`ошибок не обнаружено`,
  `предупреждений: 0`) matched **before** error patterns, so a naive substring scan cannot
  report a clean log as failed.
- **New conditional Gate 3b** in `content/rules/verification-gates.md`, modelled on the
  existing Gate 3a (live-IB smoke check): it runs when a dev infobase is reachable, its
  failure blocks the artifact, and its inability to run is recorded as a fixed line under
  **Risks** rather than being silently skipped.
- **Wiring into the IB-bound commands**: `/update1cbase` and `/deploy-and-test` run the gate
  between loading the configuration and updating the database structure, so a broken
  configuration is rejected before restructuring starts.
- **Documentation**: `content/skills/1c-metadata-manage/docs/db-manage.md` gains the check
  profiles and the verdict contract; `content/skills/1c-metadata-manage/docs/cfe-manage.md`
  points extension work at the applicability check.

## Decisions locked with the user

- **Gate status — conditional.** It follows the Gate 3a pattern: it runs when a dev infobase
  is available, a failure is blocking for the artifact, and an unavailable infobase produces
  a Risks line instead of a blocked delivery.
- **Warnings do not block.** Errors and an applicability failure block; warnings are reported.
  A full `/CheckConfig` on a typical configuration emits hundreds of warning lines, and
  treating them as failures would make the gate unusable on the configurations this ruleset
  targets.
- **Scope — extensions and the main configuration.** The applicability check applies only to
  extensions; module and configuration checks apply to both.

## Out of scope

- The sandbox session model (copying `1Cv8.1CD` into an isolated working directory). Our
  IB-bound commands deliberately operate on the developer's real dev base.
- `/RollbackCfg` and the backup-before-load discipline for extensions — a separate change.
- Autodetection of the configuration's default language in `cfe-init.ps1` — a separate bug
  fix, tracked independently.
- Guarded temp-directory cleanup across the vendored scripts — a separate change.
- Porting any part of the external Python CLI. Only the switch sets and the verdict logic
  are adopted.

## Constraints

- The check commands operate on the configuration **loaded into the infobase**, not on the
  file dump. The gate is therefore only meaningful after a configuration load and before the
  database structure update.
- The scripts under `content/skills/1c-metadata-manage/tools/1c-db-ops/scripts/` are vendored
  from [Nikolay-Shirokov/cc-1c-skills](https://github.com/Nikolay-Shirokov/cc-1c-skills) and are
  periodically re-synced upstream. Any change to them must stay a minimal, self-contained patch,
  following the precedent set by
  `content/skills/1c-metadata-manage/tools/_common/DevEnv.ps1`.
- Switch availability is platform-version dependent. The default profiles use only
  long-standing switches; anything newer must be confirmed against the project's platform
  version before it is enabled by default.
- `.dev.env` fields `INFOBASE_PATH` and `PLATFORM_PATH` are Highly desirable, not mandatory.
  Their absence disables the gate; it never turns into a question outside an IB-bound task.

## Impact

Affected areas:

- `content/skills/1c-metadata-manage/tools/1c-db-ops/scripts/` — new `db-check.ps1`, minimal
  patch to `db-update.ps1`.
- `content/skills/1c-metadata-manage/tools/_common/` — new verdict helper.
- `content/skills/1c-metadata-manage/docs/db-manage.md`,
  `content/skills/1c-metadata-manage/docs/cfe-manage.md`,
  `content/skills/1c-metadata-manage/SKILL.md` — tool registration and documentation.
- `content/rules/verification-gates.md`, `content/rules/verification-policy.md` — the new
  conditional gate and its depth modulation.
- `content/commands/update1cbase.md`, `content/commands/deploy-and-test.md` — gate placement
  in the load → check → update sequence.
- `install.ps1` / `tools/validate-rules.ps1` — only if a new file needs registration; verified
  during implementation.

No BSL and no metadata of a target configuration are touched by this change.

## Context sources

Verified against the published 1C:Enterprise command-line reference (Administrator Guide,
Designer batch mode): `/CheckModules [-ThinClient] [-Server] [-ExternalConnection]
[-ExtendedModulesCheck] [-Extension <Имя>] [-AllExtensions]` — at least one mode switch is
required or nothing is checked; `/CheckConfig` with `-ConfigLogIntegrity`,
`-IncorrectReferences`, `-HandlersExistence`, `-EmptyHandlers`, `-UnreferenceProcedures`,
`-ExtendedModulesCheck`, `-Extension`, `-AllExtensions`;
`/CheckCanApplyConfigurationExtensions [-Extension <Имя>] [-AllZones] [-Z ...]` — exists as a
separate command, has no `-AllExtensions`, and checks every extension in load order when
`-Extension` is omitted; `/DumpResult <файл>` — writes a numeric result, 0 on success;
`/UpdateDBCfg [-Dynamic<Режим>] [-WarningsAsErrors] [-Extension <Имя>]`;
`/RollbackCfg [-Extension <Имя>]`; extension operations return 0 on success and 1 otherwise.
Repository state verified by direct search: none of these check commands and no `/DumpResult`
occur anywhere in the source tree; `-listFile` selective export already exists.

The 1C MCP servers (`1C-docs-mcp`, ITS, `1c-templates-mcp`) are not exposed in this session,
so platform facts were confirmed against the published command-line appendix instead of
`docsearch` / `fetch_its`; switch availability must be re-confirmed against the project's own
platform version at apply time. `recall` returned nothing beyond this task.
