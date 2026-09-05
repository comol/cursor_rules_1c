---
description: Build release artifacts from committed sources — .cf for the main configuration and .cfe per extension, with optional version bump, changelog and git tag
argumentHint: "[<version>] [--no-tag]"
---

# /build-release — release artifacts from the git snapshot

Build distributable artifacts — a `.cf` of the main configuration and a `.cfe` per extension from `EXTENSION_NAMES` — from the **committed** state of the repository, with an optional version bump, `CHANGELOG.md` entry and git tag. The command ends at artifacts + tag; it never deploys to production itself (see the checklist at the end).

## Step 0. Check `.dev.env` parameters

Parameters, classes and defaults — `content/rules/dev-standards-env.md §1`; Defaulted keys are never asked for. Blocking: `PLATFORM_PATH`, `INFOBASE_PATH` (the assembly base — a dev/test base used to materialize the git snapshot; the dev/test confirmation of `/deploy-and-test` applies). Also read: `INFOBASE_KIND`, `IB_USER` / `IB_PASSWORD`, `EXTENSION_NAMES`, `EXPORT_PATH`, `EXTENSIONS_PATH`, `RELEASE_PATH`, `LOG_PATH`, `IBCMD_CONFIG`.

## Step 1. Clean-tree gate

A release artifact must be reproducible from a commit. Check `git status --short` for `{EXPORT_PATH}` and `{EXTENSIONS_PATH}`: uncommitted source changes → stop and ask the user to commit or stash. Record `git rev-parse --short HEAD` — it goes into the report.

## Step 2. Version

Read the current `Version` property from the main configuration's `Configuration.xml` in `{EXPORT_PATH}`.

- No argument → build with the current version as is; offer a bump only if the version equals the previous release tag.
- `<version>` argument (or an explicit bump request) → update the `Version` property in the sources. This is a metadata edit: go through the `1c-metadata-manage` tooling where it covers configuration properties; otherwise a minimal hand edit of the single property value is acceptable — run `verify_xml` on the file afterwards and state `Metadata tooling: hand-edit — Version property` in the report (`verification-gates.md → Gate 5` exception discipline). Commit the bump before building (it is part of the released state).

## Step 3. Materialize the snapshot in the assembly base

Run the `/update1cbase` procedure (single source of truth for command lines, tool selection, and the Update retry loop): full-snapshot mode (`/update1cbase all`) when `EXTENSION_NAMES` is filled, single-target otherwise. This guarantees the artifacts are built from the git state, not from whatever the base happened to contain.

## Step 4. Dump the artifacts

Create `{RELEASE_PATH}` if missing (recommend keeping it in `.gitignore` — the artifacts are binary). Then, via the `db-ops` scripts (the 1C-infobase-operations hard gate — `AGENTS.md → Skills and Subagents`):

- main configuration: `db-dump-cf.ps1 -OutputFile "{RELEASE_PATH}\<ConfigName>_<Version>.cf"`;
- each extension from `EXTENSION_NAMES`, in order: `db-dump-cf.ps1 -Extension <Name> -OutputFile "{RELEASE_PATH}\<Name>_<ExtVersion>.cfe"` (extension version — from that extension's own `Configuration.xml` in its sources; fall back to the main version when absent).

Verify each file exists and is non-empty; check the logs per the retry discipline of `content/skills/1c-metadata-manage/docs/db-manage.md`.

## Step 5. Optional `.cfu` (update file)

Only on an explicit user request **and** when a previous-release `.cf` is available (in `{RELEASE_PATH}` or supplied by the user): build the update file with Designer `/CreateDistributionFiles`. Verify the exact flag syntax for the installed platform version through the docs MCP (`docsearch`) before composing the line — do not write it from memory (platform-capability check). Otherwise skip and note the skip in the report.

## Step 6. Changelog and tag (confirm before any git action)

Unless `--no-tag` was passed, offer in one question: append a `## <Version> — <date>` section to `CHANGELOG.md` built from `git log <last-release-tag>..HEAD --oneline` (create the file if missing), commit it, and tag `v<Version>`. On decline — skip both. Never push unless the user explicitly asks.

## Step 7. Production delivery — checklist only

This command does **not** apply anything to production. Print the checklist for the human-driven delivery instead:

1. Backup of the production base (`.dt` via `db-dump-dt` for file bases / DBMS backup for server bases) taken and verified.
2. Update window agreed with the users.
3. Apply per the `/update1cbase` procedure with the **production overrides stated there**: no forced session termination (`-SessionTerminate` removed / `--session-terminate=prompt`), dynamic-update decision made consciously.
4. Extensions applied in `EXTENSION_NAMES` order after the main configuration.
5. Post-update verification: log check, key user scenario walked through.

## Step 8. Final report

Report: version and commit built, artifact paths with sizes, tag / changelog status, skipped optional steps (`.cfu`, tag) with reasons, retry-loop attempts in Step 3, and the `IB tooling:` line required by `AGENTS.md → Skills and Subagents`.
