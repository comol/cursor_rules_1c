---
description: Detect and optionally install the supported 1C development tools through one guided menu
---

# /installtools — guided tool installation

Use this command after installing the rules, and again after an update announces new tool installers. It detects the supported tools, explains what each one is for, asks one compact selection question, and then runs the corresponding standalone installer procedures.

This command is an orchestrator. Do not duplicate installation steps here and do not silently install anything.

## Tool catalog and order

Always show tools in this order. The 1C MCP bundle is always first.

| # | Tool | Purpose | Recommend when | Standalone command |
|---|---|---|---|---|
| 1 | 1C MCP server bundle | Documentation, metadata and code search, syntax checks, templates/project memory, BSP search, graph analysis and code review | Recommended for every 1C project; this is the primary ruleset tool bundle and requires a purchased distribution | `/installmcp` (`/installmcp beta` for the beta image channel) |
| 2 | Cognee memory MCP | General persistent agent memory with `remember`, `recall` and `forget` | Useful for cross-session or cross-client memory; optional when project memory from `1c-templates-mcp` is sufficient | `/install-cognee` |
| 3 | EDT-MCP | Live access to the EDT workspace, errors, native refactoring, metadata/forms, launches, tests and debugging | Recommended only when the user develops in a locally installed 1C:EDT | `/install-edt-mcp` |
| 4 | agent-browser | Token-efficient browser automation based on accessibility snapshots | Recommended for automated tests of a published 1C web client | `/install-agent-browser` |
| 5 | Windows-MCP | Windows desktop, mouse and keyboard automation | Last resort for thick-client or other non-web UI flows | `/install-windows-mcp` |

Do not list an optional tool as required merely because its installer exists.

## Steps

### 1. Read-only detection

Inspect the active client and host without changing state. Classify each tool as `installed`, `not installed`, or `uncertain`.

Read `USE_EDT` from the project `.dev.env` before evaluating EDT tools. It is a project preference, not an installation probe:

- `true` — the project uses EDT; mark EDT-MCP as recommended.
- `false` — the project does not use EDT; keep EDT-MCP visible but do not recommend or preselect it.
- missing, empty or invalid — in the normal interactive command, ask once whether the project uses EDT and persist `USE_EDT=true|false` without changing any other `.dev.env` key. In `/installtools status`, report `USE_EDT: unknown` and do not ask or write.

- **1C MCP bundle:** check the current tool schema for known 1C MCP tools; then check client MCP configuration, `BASESAI_MCP_GLOBAL_ROOT` / `MCP_GLOBAL_ROOT` plus `install.manifest.json`, and relevant Docker containers. A ruleset-generated MCP config alone does not prove the purchased servers are installed or running.
- **Cognee:** check for a `cognee` / `cognee-memory` MCP entry, a `cognee-mcp` container, and the configured health endpoint (the standalone command defaults to `http://127.0.0.1:8010/health`).
- **EDT-MCP:** check for an `edt-mcp` / `EDT MCP Server` client entry and `http://127.0.0.1:8765/health`. A stopped EDT makes health inconclusive; do not report the plugin missing solely because EDT is closed.
- **agent-browser:** check `agent-browser --version` and the client MCP entry.
- **Windows-MCP:** on Windows, check the client MCP entry and `uvx windows-mcp --help`. On non-Windows, mark it `not applicable`.

Never expose secrets found in MCP configuration or environment files.

### 2. Show the compact menu

Show all five tools with status, the one-line purpose, recommendation, and standalone command. Keep the MCP bundle first even when it is already installed.

If the 1C MCP bundle is not clearly installed, always ask first:

> Have you purchased the 1C MCP server bundle, and should I install it now with `/installmcp`?

If the user has not purchased it, provide `https://vibecoding1c.ru/mcpserver` and continue with the optional tools. Do not ask for Tilda credentials unless the user selected the MCP bundle.

Then ask one consolidated question for all remaining `not installed` or `uncertain` tools:

> Which additional tools should I install? Reply with numbers, `recommended`, `all`, or `none`. Each selected installer may ask only for settings it actually needs.

Treat `recommended` contextually:

- Cognee: select only if the user wants general memory beyond `1c-templates-mcp` project memory.
- EDT-MCP: select when `USE_EDT=true`. If the flag is `false`, select only on an explicit numbered choice; a detected local EDT installation alone does not change the project preference.
- agent-browser: select when a published web-client URL or web UI testing is expected.
- Windows-MCP: never include automatically; it requires an explicit selection.

### 3. Run selected standalone procedures

Execute selected installers sequentially in catalog order by loading and following their command files:

1. `installmcp.md`
2. `install-cognee.md`
3. `install-edt-mcp.md`
4. `install-agent-browser.md`
5. `install-windows-mcp.md`

If a slash-command dispatcher cannot invoke another slash command directly, execute that command file as the procedure. Do not tell the user to repeat the same selection manually.

Skip tools already proven installed unless the user explicitly requests repair or reinstall. For an installed 1C MCP bundle, offer `/updatemcp` only when an update is requested; do not replace it with `/installmcp`.

**MCP release channel.** The bundle installs the **stable** image channel by default. Pass the channel through only when the user asks for it — `/installmcp beta` for a fresh beta install, `/updatemcp beta` / `/updatemcp stable` to switch an installed set. Do not raise the beta option on your own, and never select it for the user; the contract is `/installmcp` → `## Release channel — stable or beta (IMAGE_TAG)`.

Stop only the failing installer, report its blocker, and continue with other independently selected tools when safe.

### 4. Report and restart

Return one line per tool: `installed`, `already present`, `skipped`, or `failed: <reason>`. Mention the standalone command for later use.

When MCP configuration, EDT plugins, or client-side tools changed, ask for one restart at the end rather than after every item. EDT-MCP additionally requires a full EDT restart.

When `USE_EDT` ends the run as `true`, state in one line that the EDT branch of the ruleset is active (`content/rules/edt-workflow.md`) — source-format check before metadata work, EDT-MCP routing, one deployment owner. When it ends as `false`, say nothing about EDT.

## Parameters

- `/installtools` — detect, show the menu, and ask what to install.
- `/installtools recommended` — still show the MCP purchase/install question first, then preselect contextually recommended optional tools.
- `/installtools status` — detection and descriptions only; do not install.
