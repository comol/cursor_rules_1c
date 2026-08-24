---
description: Exporting configuration objects (metadata) from an infobase to the repository — `ibcmd infobase config export` (preferred) or Designer `/DumpConfigToFiles` fallback. Load when extracting source from a live infobase.
alwaysApply: false
category: workflow
---

# Exporting Objects from an Infobase to the Repository

## Parameters (defined in `.dev.env` or supplied by the user at task start)

| Placeholder | Purpose |
|---|---|
| `{PLATFORM_PATH}` | 1C platform installation directory containing `bin\1cv8.exe` (example: `C:\Program Files\1cv8\8.3.23.1997`) — **blocking** |
| `{INFOBASE_PATH}` | File infobase path or server connection string — **blocking** |
| `{IB_USER}` / `{IB_PASSWORD}` | Credentials (empty = no authentication / no password; `/N` / `/P` / `--user` / `--password` are omitted) |
| `{EXPORT_PATH}` | Directory where object sources are exported (empty = repository root) |
| `{EXTENSION_NAME}` | Extension name when exporting from an extension; otherwise omit the `-Extension` argument |
| `{LOG_PATH}` | Designer log file (empty = `$env:TEMP\1cv8.log` on Windows / `$TMPDIR/1cv8.log` on POSIX) |
| `{IBCMD_CONFIG}` | Standalone server `config.yml` for `ibcmd` (empty = Designer fallback) |

Ask-policy (canon — `dev-standards-env.md`): only `INFOBASE_PATH` and `PLATFORM_PATH` are blocking — if either is empty, **ask the user** (do not guess) and write the value to `.dev.env`. **Never ask up front** about the defaulted keys — apply the defaults from the table silently; re-ask `IB_USER` / `IB_PASSWORD` only if the platform itself returns an authentication error, `LOG_PATH` only if the resolved path turns out to be non-writable. An empty password is a fully valid configuration for dev / test infobases. When substituting templates: if `LOG_PATH` is empty, replace `{LOG_PATH}` with `"$env:TEMP\1cv8.log"`.

## Steps

**Step 1.** Compose the list of objects to export in `repoobjects.txt` (one full metadata-object name per line, e.g. `Справочник.Контрагенты`). Build the list via `metadatasearch` or `search_metadata` (see `content/skills/mcp-1c-tools/SKILL.md`). Write the file as UTF-8; blank lines are ignored.

### Minimal closure — expand the list from evidence, not from guessing

A partial export is only cheaper than a full dump if the list stays small. Do not pre-emptively list every form, template and command an object owns, and do not fall back to a full `/DumpConfigToFiles` "to be safe" — that trades a 30-second export for a multi-minute one and buries the relevant files.

1. Export the **root objects** only (`Справочник.Контрагенты`, `Документ.ЗаказПокупателя`, `РегистрСведений.ЦеныНоменклатуры`).
2. Read the exported root XML to see which forms, commands and templates actually exist.
3. Read only the modules relevant to the task, and search *those files* for concrete references to other metadata and common modules.
4. Run a **second** export listing only the names that evidence turned up — a child form as `Справочник.Контрагенты.Форма.ФормаЭлемента`, a common module as `ОбщийМодуль.<Имя>`.
5. Repeat until every conclusion has source behind it.

Which children matter depends on the task: an object-manager change rarely needs any form; a form-event change needs that exact form and usually no templates.

**Two accuracy rules.** A name the platform rejects is *unresolved*, not misspelled — confirm it from `metadatasearch` or ask, instead of trying spelling variants in a loop. And names here are **metadata names, not synonyms** shown to users.

**Stated limit.** Static inspection cannot find dynamic dispatch — `Вычислить`, string-built metadata lookup, behaviour selected by functional options, or a handler wired only at runtime. When a conclusion depends on one of those, say so and confirm it with a focused check against a live base (`verification-gates.md → Gate 3a`) rather than presenting a text search as complete.

**Step 2.** Choose the export tool:

- If `Test-Path '{PLATFORM_PATH}\bin\ibcmd.exe'` succeeds **and** `IBCMD_CONFIG` is set in `.dev.env` — use **Step 2a (ibcmd)**.
- Otherwise — use **Step 2b (Designer)**. `ibcmd infobase config` does not work with clustered server infobases — for those, always use Designer.

**Step 2a.** Partial export via `ibcmd`. The object list is read from `repoobjects.txt` and passed as positional arguments:

```powershell
$objects = Get-Content repoobjects.txt | Where-Object { $_.Trim() -ne '' }
& '{PLATFORM_PATH}\bin\ibcmd.exe' infobase config export objects `
    --config='{IBCMD_CONFIG}' `
    --user='{IB_USER}' `
    --password='{IB_PASSWORD}' `
    --recursive `
    --out='{EXPORT_PATH}' `
    --extension={EXTENSION_NAME} `
    @objects *>&1 | Tee-Object -FilePath '{LOG_PATH}'
```

Drop unset optional flags (`--user`, `--password`, `--extension`). `--recursive` exports subordinate objects (attributes, tabular sections, forms, templates).

**Step 2b.** Partial export via Designer (fallback). Objects are exported **in full**, strictly into the specified directory — **do NOT create new subdirectories**.

```powershell
& '{PLATFORM_PATH}\bin\1cv8.exe' DESIGNER `
    /F '{INFOBASE_PATH}' `
    /N '{IB_USER}' `
    /P '{IB_PASSWORD}' `
    /DisableStartupMessages `
    /DumpConfigToFiles {EXPORT_PATH} `
    -listFile repoobjects.txt `
    -Extension {EXTENSION_NAME} `
    /Out {LOG_PATH} `
    /DumpResult {RESULT_PATH}
```

When exporting from the main configuration (not from an extension) — drop the `-Extension {EXTENSION_NAME}` argument.

**Step 3.** Inspect the result before starting any edits: the process exit code, the number in `{RESULT_PATH}` (`0` = success), and `{LOG_PATH}`. All three must agree — and in the log, classify the platform's success phrases (`Ошибок не обнаружено`, `Предупреждений: 0`) before its error stems, or a clean export reads as a failure. Canon — `content/rules/designer-batch-checks.md → The verdict is three signals, not the exit code`. Delete a stale `{RESULT_PATH}` before the run; an old file reads as this run's verdict.
