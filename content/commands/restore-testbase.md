---
description: Rebuild the test infobase to the effective snapshot — optional DT data baseline, then the current cf + cfe sources from git
argumentHint: "[<path-to-snapshot.dt>|nodata]"
---

# /restore-testbase — actualize the test infobase from the snapshot

Bring the test infobase defined in `.dev.env` to the **effective snapshot**: a data baseline from a `.dt` (optional) plus the current configuration sources from git — main configuration and every extension from `EXTENSION_NAMES`. Use it when the test base drifted (broken by experiments, stale data, wrong config state) and you want a reproducible state before the next develop-deploy cycle.

## Step 0. Check `.dev.env` parameters

Parameters, classes and defaults — `content/rules/dev-standards-env.md §1`; Defaulted keys are never asked for. Blocking keys: `PLATFORM_PATH`, `INFOBASE_PATH`. Also read: `INFOBASE_KIND`, `IB_USER` / `IB_PASSWORD`, `DT_SNAPSHOT_PATH`, `EXTENSION_NAMES`, `EXTENSIONS_PATH`, `EXPORT_PATH`, `LOG_PATH`, `IBCMD_CONFIG`.

**Dev/test only — hard requirement.** This command overwrites data and forcibly terminates sessions. The target must be an explicitly identified dev/test infobase; if the current context does not establish that, stop and ask the user to confirm the target. Never run it against production.

## Step 1. Data baseline (optional)

Resolve the baseline: explicit `.dt` path argument → `DT_SNAPSHOT_PATH` from `.dev.env` → none. The `nodata` argument forces "none" even when `DT_SNAPSHOT_PATH` is filled.

When a baseline `.dt` is resolved:

1. **Offer a rollback point first**: dump the current base with the `db-ops` script `db-dump-dt.ps1` (canon — `content/skills/1c-metadata-manage/docs/db-manage.md §9`). The user may decline; record the decline in the report.
2. **Ask for explicit confirmation** — loading a `.dt` completely overwrites the base, configuration *and* data (irreversible; §10 of the same doc).
3. Load via `db-load-dt.ps1` (the 1C-infobase-operations hard gate — `AGENTS.md → Skills and Subagents`; no ad-hoc command lines). If the base is busy, follow §10 of the same doc (free the base / `-UnlockCode`), not blind retries.

When no baseline is resolved — skip this step and state in the report that only the configuration was refreshed.

## Step 2. Configuration snapshot from git

Report in one line which git state is being deployed (`git rev-parse --short HEAD` + whether the working tree is dirty — deploying uncommitted changes is normal in development, but it must be visible in the report).

Then run the `/update1cbase` procedure (`content/commands/update1cbase.md` — single source of truth for the load / UpdateDBCfg command lines, tool selection, and the **Update retry loop**):

- with `EXTENSION_NAMES` filled — in **full-snapshot mode** (`/update1cbase all`): main configuration from `{EXPORT_PATH}`, then each extension in list order from `{EXTENSIONS_PATH}\<Name>\`;
- with `EXTENSION_NAMES` empty — the regular single-target run.

The retry loop (log-first, PID-scoped Configurator termination, fix-before-retry, 3 attempts) applies as written there. A `.dt` loaded in Step 1 already has its DB configuration in sync — the load in this step still runs, because the point of the command is to bring the base to the **git** state, which may be newer than the snapshot.

## Step 3. Smoke check

Mandatory: the three-signal verdict of the `/update1cbase` procedure for the last launch of every pass — `{RESULT_PATH}` = `0`, exit code `0`, and a log whose success phrases are classified before error stems (`content/rules/designer-batch-checks.md → The verdict is three signals`); a bare "contains `Ошибка`" test is not a verdict.

Optional, only when already available in the session: one read-only `vcexecutecode` ping via `1c-data-mcp` to confirm the base opens and executes code (same read-only discipline as `verification-gates.md → Gate 3a`). Web-client login checks are UI testing — they run only per the `UI_TESTING` gate (`dev-standards-env.md`), never automatically here.

## Step 4. Final report

Report: the data baseline used (`.dt` path, or "config-only refresh"), whether a rollback `.dt` was taken, the git state deployed, extensions loaded in order, retry-loop attempts and fixes, smoke result. On failure — the standard retry-loop failure report; never present a failed restore as done.
