---
description: Diagnose whether 1c-rules is installed, connected, configured, and usable by the current agent
---

# /doctor — 1c-rules readiness diagnostic

Run a read-only health check for the current project. The goal is to answer one question: **will the current agent actually use this ruleset safely for 1C work?**

Do not modify files, install packages, start containers, or write secrets. If a fix is obvious, report the exact next action instead of applying it.

## Output format

Return a compact status table with these statuses:

| Status | Meaning |
|---|---|
| **OK** | Check passed. |
| **WARN** | Work can continue, but something is incomplete or degraded. |
| **FAIL** | The ruleset or current task environment is not ready. |
| **SKIP** | Check is not applicable to this repository or current tool. |

After the table, list only actionable fixes. Do not include secret values from `.dev.env`.

## Check 1. Current agent and rules loading

1. Identify the current AI tool when possible: Cursor, Claude Code, Codex, OpenCode, Kilo Code, or `other`.
2. Check that `AGENTS.md` exists at the project root and is readable.
3. Check that `USER-RULES.md` and `memory.md` exist at the project root. Check `LLM-RULES.md` too, but report a missing `LLM-RULES.md` as **WARN**, not FAIL — older installs predate it; it is placed by `install.ps1 update` or created by the first `/evolve` write.
4. If `.ai-rules.json` exists, read it and verify:
   - `activeTools` contains the current tool, or explain why the current tool is still supported through `other`;
   - managed files listed in the manifest still exist;
   - the canonical rules directory referenced by the manifest exists.
5. If `.ai-rules.json` is missing:
   - in an installed project, report **FAIL** and recommend `install.ps1 init`;
   - in the source repository of `1c-rules`, report **WARN** and continue with source-layout checks.
6. Verify that the current tool has the files it can actually load:
   - Cursor: `.cursor/rules/`, `.cursor/commands/`, `.cursor/mcp.json` when installed;
   - Claude Code: `.claude/rules-1c/` (on-demand rules referenced through `AGENTS.md` — deliberately **not** `.claude/rules/`, which Claude Code v2.0.64+ auto-loads in full at session start), `.claude/agents/`, `.claude/commands/`, MCP config when installed; managed rule files left in `.claude/rules/` from older installs are **legacy** and the `update` flow removes them (user-authored files there are kept);
   - Codex: `.codex/skills/`, `.codex/config.toml` when installed;
   - OpenCode: `.opencode/command/`, `.opencode/agent/` (also accept `.opencode/agents/` if present), `.opencode/rules/`, and `opencode.json` at the **project root** (top-level `mcp` key) when installed — MCP lives in the root `opencode.json`, **not** `.opencode/opencode.json` (OpenCode does not read a config file under `.opencode/`); a leftover `.opencode/opencode.json` from older installs is **legacy** and the `update` flow removes it;
   - **OpenCode agent frontmatter hard gate** (when `.opencode/agent/` or `.opencode/agents/` exists): every `*.md` agent file must **not** have a `tools` **array** in its YAML frontmatter (`tools: ["Read", …]`). OpenCode validates `tools` as object | undefined; a Cursor-style array makes it reject the whole config and refuse to start (`Configuration is invalid … Expected object | undefined, got […] tools`). Correct installed shape uses a `permission` object (`read`/`edit`/`grep`/`glob`/`bash`: `allow`|`deny`) and `mode: subagent`|`primary` — produced by `adapters/opencode.yaml → toolsToPermission`. Any file still carrying a `tools` array → **FAIL**. Repair: `install.ps1 update -Source <clone> -AssumeYes -ForcePaths .opencode/agent/*` (or re-apply the adapter transform on the agent channel). Do **not** confuse source `content/agents/*.md` (arrays are correct there) with installed `.opencode/agent/*.md`. Quick check:

     ```powershell
     Get-ChildItem .opencode\agent, .opencode\agents -Filter *.md -File -ErrorAction SilentlyContinue |
       ForEach-Object {
         if ((Get-Content $_.FullName -Raw) -match '(?ms)\A---\r?\n.*?^tools:\s*\[') { "FAIL: $($_.Name)" }
       }
     ```
   - Kilo Code: `.kilo/rules-1c/` (on-demand rules referenced through `AGENTS.md`), `.kilo/commands/`, `.kilo/agents/`, `.kilo/skills/`, `.kilo/kilo.json` (top-level `mcp` key) when installed; a leftover `.kilocode/mcp.json` from older installs is **legacy** — current Kilo CLI / Kilo Code v7.x+ no longer reads it and the `update` flow removes it;
   - other: `.ai-agent/rules/`, `.ai-agent/agents/`, `.ai-agent/commands/`, `.ai-agent/skills/`, `.ai-agent/mcp.json`.

Pass criterion: the root always-on files exist, and either the installed tool layout is present or the repository is clearly the `1c-rules` source repository being edited directly.

## Check 2. Ruleset file integrity

Check that these source files or their installed copies exist:

- `content/rules/*.md` or the active tool rules directory;
- `content/agents/*.md` or the active tool agents directory;
- `content/commands/*.md` or the active tool commands directory;
- `content/skills/*/SKILL.md` or the active tool skills directory;
- `content/mcp-servers.json` or the active tool MCP config;
- `.dev.env.example`;
- `openspec/README.md`, `openspec/specs/README.md`, `openspec/changes/README.md`.

Also check:

- all command files have frontmatter with `description`;
- all skill entry files have frontmatter with `name` and `description`;
- the subagent count matches the catalog in `content/rules/subagents.md`;
- every on-demand rule referenced from `AGENTS.md → Additional rules` exists;
- files governed by the source language policy are written in English, except 1C identifiers, Russian platform messages, BSL examples, metadata names, and user-facing Russian strings that are explicitly quoted as data.

## Check 3. `.dev.env` existence and completeness

1. Check that `.dev.env` exists at the project root.
2. If missing, report **FAIL** for operational commands and recommend creating it from `.dev.env.example` or running `install.ps1 init`.
3. If present, verify that critical fields are non-empty:
   - `PLATFORM_PATH`;
   - `INFOBASE_PATH`;
   - `EXPORT_PATH` when the repository root is not the configuration source directory;
   - `PLATFORM_VERSION` when platform-version-specific docs or checks are needed.

   Do **not** treat `INFOBASE_KIND`, `IB_USER`, `IB_PASSWORD`, `LOG_PATH`, `UI_TESTING`, `QUICKFIX_MAX_LINES`, `DEBUG_FAST_PATH`, `AGENT_MODEL`, or `VERIFICATION_DEPTH` as critical even when empty — they are **Defaulted** per `content/rules/dev-standards-env.md`. Empty `INFOBASE_KIND` = `file`, empty `IB_USER` / `IB_PASSWORD` = no authentication / no password (the `/N` / `/P` flags are simply omitted), empty `LOG_PATH` = `$env:TEMP\1cv8.log` (Windows) / `$TMPDIR/1cv8.log` (POSIX), empty `UI_TESTING` = `manual` (UI tests run only on explicit request), empty `QUICKFIX_MAX_LINES` = `40`, empty `DEBUG_FAST_PATH` = `standard`, empty `VERIFICATION_DEPTH` = `standard`, empty `AGENT_MODEL` = no model profile (the base model-neutral ruleset). Report them as "uses default" rather than as a missing value.
4. Verify that `PLATFORM_PATH` contains `bin\1cv8.exe`.
5. When `INFOBASE_KIND` is non-empty, verify that it is `file` or `server`.
6. When `UI_TESTING` is non-empty, verify that it is `manual`, `auto`, or `off`; any other value is treated as `manual` (report **WARN**).
7. When `VERIFICATION_DEPTH` is non-empty, verify that it is `full`, `standard`, or `lite`; any other value is treated as `standard` (report **WARN**).
8. When `AGENT_MODEL` is non-empty, verify that it is `opus5`, `sonnet5`, `fable5`, or `gpt56` and that the matching rule file (`model-<slug>.md`, or `.mdc` on Cursor) exists in the rules directory. An unrecognised value means no profile is applied — report **WARN** with the fix `/rulesmodel <модель>`. A missing profile file for a set value is **FAIL** (the install is incomplete — run `/updaterules`). When the value names a model different from the one you are running, report **WARN**, say which profile you actually apply per `model-adaptation.md → §2`, and suggest `/rulesmodel auto`. Empty is **OK** ("uses default"), never a WARN.
9. **Optional UI tooling (non-blocking).** When `UI_TESTING=auto` or the user is about to run web UI tests: if `agent-browser` is not on `PATH` and no `agent-browser` MCP entry is in the active client config — report **WARN** and suggest `/install-agent-browser` (token-efficient default per `ui-testing-tools.md`). Absence of `windows-mcp` is not a WARN (desktop CV is last resort only).
10. **EDT flag (non-blocking).** Report `USE_EDT` as `true` / `false` / `unknown` (missing or invalid). When `true`: check that `edt-workflow.md` exists in the rules directory (missing = **FAIL**, the install is incomplete — run `/updaterules`), and report whether EDT-MCP tools are exposed in this session (not exposed = **WARN** with the fix `/install-edt-mcp`; a closed EDT is a valid reason, not a broken install). Also report a **WARN** when `USE_EDT=true` but the working tree looks like a Designer XML dump only, or when it holds an EDT workspace (`.project`, `DT-INF/`, `src/Configuration.mdo`) while `USE_EDT` is `false` / `unknown` — the flag and the tree disagree, and the fix is one line in `.dev.env`. When `USE_EDT=false` and no EDT workspace is present, say nothing about EDT.
11. **Support channel (non-blocking).** Report whether `SUPPORT_KEY` and `SUPPORT_EMAIL` are set — never their values. Both set = **OK**. Both empty = **OK** ("канал поддержки не настроен"), not a WARN: the channel is optional and blocks no development task. Exactly one of the two set = **WARN**, because `/support` needs both — the fix is one line in `.dev.env` (`SUPPORT_KEY` — раздел 6 `config.env` дистрибутива MCP, `SUPPORT_EMAIL` — рабочий e-mail пользователя). A non-empty `SUPPORT_API_URL` that is not an `https://` URL is a **WARN**; empty is **OK** (default endpoint).
12. Never print `IB_PASSWORD`, `SUPPORT_KEY`, tokens, license keys, or full connection strings. Report only whether they are set.

Pass criterion: `.dev.env` exists, has the critical operational fields needed for load/dump/deploy/test commands, and does not require guessing.

## Check 4. OpenSpec workspace and `project.md`

1. Check that `openspec/README.md`, `openspec/specs/README.md`, and `openspec/changes/README.md` exist.
2. Check that `openspec/project.md` exists and is not empty.
3. If `Configuration.xml` or `ConfigurationExtension.xml` exists in the source tree, `openspec/project.md` must contain generated project context such as configuration name, compatibility mode / platform version, form mode, BSP version when known, top-level subsystems, and metadata counts.
4. If the repository is not a 1C source dump and has no `Configuration.xml` / `ConfigurationExtension.xml`, absence of rich project context is **WARN**, not **FAIL**.
5. If `openspec/project.md` is missing or empty in a 1C source dump, report **FAIL** and recommend running the project-context generation step from `install.ps1 init` / `install.ps1 update`.

Pass criterion: OpenSpec exists, and `openspec/project.md` is present and meaningful whenever a 1C source dump is available.

## Check 5. MCP session connectivity

Check MCP at two levels:

1. **Current session tools** — verify that expected tools are visible in the current agent tool schema when the server is configured:
   - `syntaxcheck` for `1c-syntax-checker-mcp`;
   - `templatesearch`, `remember`, `recall` for `1c-templates-mcp`;
   - `ssl_search` for `1c-ssl-mcp`;
   - `docinfo`, `docsearch`, `standards`, `formatspec` for `1C-docs-mcp`. **`standards` missing while `docsearch` is present is a WARN of its own**, not a rounding error: the fourteen routed rules of `content/rules/` have no bodies in the project and this image cannot serve them. Report the ruleset as degraded and recommend pulling a current `comol/1c_help_mcp`;
   - `metadatasearch`, `codesearch`, `search_function`, `get_module_structure` for `1c-code-metadata-mcp`;
   - `search_metadata`, `get_object_dossier`, `trace_impact`, `trace_call_chain` for `1c-graph-metadata-mcp`;
   - `check_1c_code`, `review_1c_code`, `its_help`, `fetch_its` for `1c-code-check-mcp`.
2. **Transport fallback** — when tools are missing but MCP config lists the server, run the `/checkmcp` algorithm: HTTP endpoint check, Docker state, and exact next action.

Pass criterion: required MCP tools for the expected 1C workflow are visible in the current session. HTTP-only availability is **WARN** because the agent still cannot call the tools until the client reconnects.

When **no** 1C MCP tools are visible and `.dev.env` `SUPPORT_KEY` is empty and `integrations.mcp.mode` is not `external`, add the same MCP-effectiveness reminder as after install / `/updaterules` / `/checkupdates` (https://vibecoding1c.ru/mcp_server). This is **WARN**, not FAIL — the ruleset has graceful fallbacks. If the key or an external install is present but tools are still missing, report **WARN** with `/installmcp` or a client restart, without the purchase page.

## Check 6. Active rules suitability

Evaluate whether the installed rules match the current repository and current agent:

1. If the repository contains 1C source files or metadata XML, confirm the 1C ruleset is appropriate.
2. If the repository is only the `1c-rules` source repository, report that BSL validators are not applicable to docs-only edits unless BSL examples are changed.
3. Confirm that `AGENTS.md` points to source or installed on-demand rules that the current agent can read.
4. Confirm that command names in `content/commands/` are available in the active tool's command location after installation.
5. Confirm that `caveman` matches the `.dev.env` `CAVEMAN` mode: `on` (default) — active on all tasks; `auto` — dev-only (on for implementation / debugging / deployment, off for review / analysis / documentation); `off` — never auto-on until an explicit force (`/caveman on` or "caveman please").
6. Confirm the active-model layer: report which profile is in force (`AGENT_MODEL` from `.dev.env`, or none) and whether it matches the model you are running. State in one line the 2–3 behaviour deltas currently applied. If no profile is set and the model you run has one (`opus5` / `sonnet5` / `fable5` / `gpt56`), report **WARN** — not FAIL — and suggest `/rulesmodel auto`; the base ruleset is fully functional without it. Never report a profile as weakening a gate: if a profile file appears to relax a hard gate, that is a **FAIL** on the ruleset, per `model-adaptation.md → §4`.

Pass criterion: the current agent has the always-on rules, can reach on-demand rules or their source copies, and the rule triggers match the current task type.

## Check 7. Cross-reference and Markdown integrity

Static check that the rule corpus is internally consistent. Operate on the **source layout** when running inside the `1c-rules` source repository, or on the installed copies under the canonical rules directory when running inside an installed project.

Scope:

1. **Rule index completeness.** Every file under `content/rules/*.md` (source) or the canonical rules directory (installed) is listed in `AGENTS.md → Additional rules`. Any file present on disk but missing from the index is an **orphan**; any name in the index without a matching file is a **dangling reference**. Report both.
2. **Subagent index completeness.** Every file under `content/agents/*.md` is listed in `content/rules/subagents.md → Subagent catalog`. The subagent count claimed in `AGENTS.md` and `subagents.md` matches the actual file count.
3. **Skill index completeness.** Every SKILL package under `content/skills/<name>/SKILL.md` is mentioned at least once in `AGENTS.md` (in the always-on or supplementary skill list) or in `README.md → Сопутствующие скиллы`.
4. **Inline path references resolve.** For every reference in the form `` `content/rules/<name>.md` ``, `` `content/agents/<name>.md` ``, `` `content/skills/<name>/SKILL.md` ``, `` `content/skills/<name>/docs/<doc>.md` ``, `` `<name>.md` `` (rule-style bare references), or `` `<name>` `` (skill alias) inside `AGENTS.md`, `README.md`, `AGENT-INSTALL.md`, files under `content/rules/`, `content/agents/`, `content/skills/`, the target file exists.
5. **Anchor convention.** Every section reference of the form `<file>.md §N` and `<file>.md §N → "Title"` resolves: `§N` corresponds to a `## N. ...` heading in the target file; `§N → "Title"` corresponds to a `### Title` (or any `###`/`####` whose stripped title matches) inside that `## N.` section. References that mix old styles (`§3 Queries` without quotes, `§3 "Queries"` without arrow, `§3.6 Queries`) are reported as **stale**.
6. **Markdown link integrity.** Standard `[text](path)` and `[text](path#anchor)` links resolve to existing files; anchors normalize (lowercase, spaces → `-`, punctuation stripped) and must match a heading in the target file.
7. **Script path integrity.** PowerShell examples in skill docs reference scripts that exist under the source skill folder or the active tool's installed skill folder. Examples must not point to a non-existent root-level `skills/` directory unless that directory is part of the installed layout.
8. **Adapter-layout consistency.** Paths mentioned in `README.md`, `AGENT-INSTALL.md`, `openspec/README.md`, command docs, and skill docs match `adapters/*.yaml`. Check Codex, Kilo Code, OpenCode, Qwen, Command Code, Cline, Pi, and `other` explicitly because their command / skill / MCP locations differ from the common `.cursor` / `.claude` layout.
9. **Policy drift.** Flag duplicate or conflicting rule wording for the same behavior, especially `.dev.env`, `infobasesettings.md` migration, MCP fallback order, and docs-fix vs BSL validation.
10. **Convention checks.** Topics declared as a single source of truth (`.dev.env`, `mcp-1c-tools` skill, `dev-standards-code-style.md → "Forbidden Calls and Constructs"`, `dev-standards-architecture.md §3 → "Queries"`, `coding-standards.md` as the index of detail files, etc.) are claimed by **exactly one** file; the same topic is not declared authoritative in two different places. Flag any duplicate authoritative claims. A **routed** owner (a `content/rules/` file carrying the `help-mcp-router` marker) still counts as the single owner — its text lives in `content/standards/<name>.md`, not in a second claimant.
11. **Routed standards.** For every `content/rules/*.md` carrying `<!-- help-mcp-router -->`: a body exists at `content/standards/<name>.md`, and the two heading trees agree (the router adds only *Where this standard lives* and *Sections*). Every file in `content/standards/` except `README.md` has a matching router — an **inlined** rule must not also have a body there (one rule, one body). `tools/validate-rules.ps1` runs this check mechanically; report **FAIL** on any mismatch and point at the script rather than re-deriving it by hand. Also confirm no rule instructs retrieval through `docsearch` / `docinfo` or with a `corpus` argument — the standards collection is reached **only** by the `standards` tool (`content/rules/help-corpus-retrieval.md`).

For each finding, report file and line. Group by severity: **FAIL** for broken paths, dangling index entries, orphan rules, missing scripts, and stale adapter-layout descriptions; **WARN** for stale anchor styles, missing skill mentions, policy drift, and conventional-style violations. Do not auto-fix — produce a fix list with concrete edits. External HTTP links are **SKIP** unless the user explicitly asks for live link checking.

This check is read-only. Implementation hint for the agent: a single PowerShell or shell pass with `Select-String`/`rg` over the relevant directories is sufficient — there is no need for a parser.

## Check 8. Final recommendation

Classify the project:

- **Ready** — all required checks are **OK** or non-blocking **SKIP**.
- **Usable with warnings** — at least one **WARN**, no **FAIL**.
- **Not ready** — at least one **FAIL**.

For **Not ready**, provide the shortest safe repair path, for example:

1. Run `install.ps1 init` or `/updaterules`.
2. If OpenCode agent frontmatter gate failed — re-run `install.ps1 update -Source <clone> -AssumeYes -ForcePaths .opencode/agent/*` (do not copy `content/agents/*.md` verbatim).
3. Fill `.dev.env` critical fields.
4. Fix Markdown integrity findings from Check 7.
5. Generate or refresh `openspec/project.md`.
6. Start/reconnect MCP servers with `/checkmcp`.
7. Restart the AI client so MCP tools and rules are reloaded.
