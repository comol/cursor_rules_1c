# 1C Rules — Installation, Migration and File Layout

This document covers installation, update and migration mechanics of the `1c-rules` toolkit and the layout of the files it manages. It is not part of the LLM always-on context; refer here only when working on the installer itself or troubleshooting installed files.

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
