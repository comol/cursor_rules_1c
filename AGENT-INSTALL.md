# 1C Rules — Installation, Migration and File Layout

This document covers installation, update and migration mechanics of the `1c-rules` toolkit and the layout of the files it manages.

## Installation channels

`1c-rules` is designed to be installed in two equivalent ways:

1. **Agent-driven channel (primary).** The AI agent itself reads this document and `adapters/*.yaml`, then places files into the project. No external CLI required. Use this when the agent has filesystem access and basic git.
2. **PowerShell channel (fallback).** `install.ps1` implements the same protocol deterministically through a CLI. Use it when the agent is unavailable, the environment is restricted, or you want a reproducible CI/CD-friendly run.

Both channels read the same source content (`content/`) and the same per-tool adapters (`adapters/<tool>.yaml`), produce the same file layout in the target project, and write the same `.ai-rules.json` manifest. They are interchangeable: a project installed by one channel can be updated by the other.

## Agent protocol (read this if you are the agent)

If the user asked you to install or update `1c-rules`, follow this protocol from the **project root** (the directory where `AGENTS.md` should live).

### Inputs

- **Source** — a local path to a clone of `1c-rules`, or the GitHub URL `https://github.com/comol/ai_rules_1c` (default if the user did not specify).
- **Active tools** — subset of `{cursor, claude-code, codex, opencode, kilocode}`. If the user did not list them, auto-detect: a tool is active if its detection rule from `adapters/<tool>.yaml` (the `detection:` block) matches the project (e.g. `.cursor/` exists for Cursor, `CLAUDE.md` or `.claude/` for Claude Code, etc.). Confirm the detected list with the user before placing files unless they explicitly asked for a non-interactive run.

### Steps

1. **Resolve the source.** If only a URL was given, clone it locally:

   ```bash
   git clone https://github.com/comol/ai_rules_1c.git <cache-dir>/1c-rules
   ```

   Reuse an existing clone if you already have one. The clone must remain available for the duration of the install.

2. **Read the adapters.** For each active tool open `adapters/<tool>.yaml` from the clone. The adapter defines, in a closed schema:
   - `detection` — how to confirm the tool is active.
   - `rules`, `agents`, `commands`, `skills` — `copyTo` target paths (with `{name}` placeholder), `frontmatter.keep` / `drop` / `rename` operations, and copy `mode` (default per-file with frontmatter ops; `verbatim` for skills).
   - `mcp` — how `content/mcp-servers.json` is rendered into the tool's MCP config (e.g. `.cursor/mcp.json`, `.mcp.json`).
   - `entry` — optional entry-point template (e.g. minimal `CLAUDE.md` pointing at `AGENTS.md`).

3. **Place the content.** For each active tool, walk `content/rules/`, `content/agents/`, `content/commands/`, `content/skills/`, applying the adapter's `copyTo` and frontmatter operations. Skills are copied as whole directories. Place the OpenSpec snapshot from `content/openspec-bundle/<tool>/` at the locations encoded in that snapshot (skip-if-exists). Render the MCP config from `content/mcp-servers.json`.

4. **Place the always-on layer.** Copy `AGENTS.md` to the project root verbatim. Create `USER-RULES.md` and `memory.md` from the templates in this repo if they do not exist; never overwrite existing ones. See *File ownership* below for the rules.

5. **Handle migration.** If a non-empty `AGENTS.md` or `CLAUDE.md` already exists at first install, follow the *Migration on first install* section below: rename to `.bak.md` and inline the original between markers in `USER-RULES.md`.

6. **Scaffold OpenSpec.** Copy `openspec/` into the project in skip-if-exists mode (no overwrites). See *OpenSpec workspace* below.

7. **Write the manifest** `.ai-rules.json` at the project root: list all placed files with their content sources, the active tools, the source version (`git describe --tags --always` from the clone), the protocol version (`1.0`), and any detected foreign user-authored files under `foreignFiles`.

8. **Confirm before destructive actions.** If a target file already exists with user modifications (different from any prior managed copy), ask the user before overwriting. Default for ambiguous cases — keep the user's version.

9. **Report what changed.** List placed/updated files, point to `.ai-rules.json`, and remind the user to restart the IDE so slash commands take effect.

### Update / add / remove

- **Update** — re-read the source clone, re-place all managed files, refresh `AGENTS.md`. Files marked `userModified` in the existing `.ai-rules.json` are preserved.
- **Add `<tool>`** — same as init but for one additional tool only; merge into the existing manifest.
- **Remove `[<tool>]`** — delete the files this tool owns according to the manifest. With no tool argument — delete every managed file and the manifest itself (the user keeps `USER-RULES.md`, `memory.md`, OpenSpec content, and any `*.bak.md`).

### Important constraints

- **Do not edit `AGENTS.md` directly** — it is regenerated on every update.
- **Do not modify `USER-RULES.md` or `memory.md`** outside the migration markers — they belong to the user/project.
- **Manifest is authoritative** — if `.ai-rules.json` exists, trust it for "what is currently managed". A file not in the manifest is a foreign file: record it under `foreignFiles`, do not touch it.
- **Skip-if-exists for OpenSpec** — never overwrite specs or change proposals.

## PowerShell fallback (`install.ps1`)

If the agent cannot do the placement (no FS access, restricted environment, CI run), use the PowerShell channel:

```powershell
git clone https://github.com/comol/ai_rules_1c.git $env:TEMP\1c-rules
& $env:TEMP\1c-rules\install.ps1 init -Source $env:TEMP\1c-rules
```

The script implements the protocol above. Notes:

- `-Source` accepts only an **existing local path** — not a URL. Clone first.
- Run from the **project root**; the script writes there.
- Commands: `init` / `update` / `add <tool>` / `remove [<tool>]` / `doctor` (read-only diagnostic) / `eject` (delete the manifest, leave files in place).
- Flags: `-Tools cursor,claude-code` (explicit list), `-NonInteractive` (auto-resolve prompts), `-AssumeYes` (answer yes to confirmations but still pause on destructive conflicts unless `-NonInteractive` is also set).

A project installed via the agent channel can later be updated via PowerShell and vice versa — both write the same `.ai-rules.json`.

## File ownership

- `AGENTS.md` — shipped as-is by the `1c-rules` installer and refreshed on every update (when safe). **Do not edit it directly** — changes can be overwritten by future updates.
- `USER-RULES.md` — created empty by the installer on first install and **never** overwritten, refreshed, or deleted thereafter. Project- or team-specific conventions go here.
- `memory.md` — project memory file at the project root. Created and maintained by the project; not overwritten by the installer.
- `.ai-rules/rules/*.md` — on-demand rule files placed by the installer in an installed project. In this source repository before installation, the matching files live under `content/rules/*.md`. Tool-specific adapted copies may also exist in `.cursor/rules/`, `.claude/rules/`, `.kilocode/rules/`; all copies contain the same authoritative text.
- `content/agents/<name>.md` — full role descriptions and prompts for the 12 specialized subagents. Each AI tool discovers them from its own agents directory after install.

## USER-RULES.md

AI agents read `USER-RULES.md` together with `AGENTS.md`, so anything added there becomes part of the always-on context.

Typical contents:

- Project- or team-specific conventions and review rules.
- `@-imports` of supplementary files maintained in tool-native locations, for example:

  ```markdown
  @.cursor/rules/<your-rule>.mdc
  @.claude/agents/<your-agent>.md
  ```

The installer detects foreign (user-authored) files and records them in `.ai-rules.json` under `foreignFiles`, but it does **not** modify `AGENTS.md` or `USER-RULES.md` to reference them — such imports must be added manually to `USER-RULES.md`.

## Migration on first install

If at first install the project already had an `AGENTS.md` or `CLAUDE.md` with custom content, the installer renames those files to `AGENTS.md.bak.md` / `CLAUDE.md.bak.md` and inlines their original content into `USER-RULES.md` between migration markers. The migrated block should be reviewed: keep what is needed and remove the rest.

## OpenSpec workspace

The project ships an [OpenSpec](https://github.com/Fission-AI/OpenSpec) workspace at the repository root. The `1c-rules` installer scaffolds it unconditionally on first install (skip-if-exists; existing files are never overwritten) and records the result in `.ai-rules.json` under `integrations.openspec`.

OpenSpec slash commands (`/opsx:propose`, `/opsx:apply`, `/opsx:archive`, `/opsx:explore`) and the matching SKILLs are placed automatically by the `1c-rules` installer for every active tool from a bundled snapshot of `openspec init` output (see `content/openspec-bundle/`); no `npm` and no OpenSpec CLI are required at install time. The snapshot's CLI version is recorded in `.ai-rules.json` under `integrations.openspec.artifactsBundleVersion` and is refreshed whenever `1c-rules` is updated.
