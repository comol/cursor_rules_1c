---
description: use when you need to get some objects from infobase to repository
alwaysApply: false
category: workflow
---

# Exporting Objects from an Infobase to the Repository

## Parameters (defined in `.dev.env` or supplied by the user at task start)

| Placeholder | Purpose |
|---|---|
| `{PLATFORM_PATH}` | Path to the 1C platform installation directory (containing `bin\1cv8.exe`). Example: `C:\Program Files\1cv8\8.3.23.1997` |
| `{INFOBASE_PATH}` | Path to a file infobase or the connection string of a server infobase |
| `{IB_USER}` | Infobase user name |
| `{IB_PASSWORD}` | Password (when required) |
| `{EXPORT_PATH}` | Directory where object sources are exported |
| `{EXTENSION_NAME}` | Extension name when exporting from an extension; otherwise omit the `-Extension` argument |
| `{LOG_PATH}` | Designer log file |

If a value is unknown — **ask the user**, do not guess. Project-stable values go into `.dev.env`.

## Steps

**Step 1.** Compose the list of objects to export in `repoobjects.txt` (one full metadata-object name per line, e.g. `Справочник.Контрагенты`). Build the list via `metadatasearch` or `search_metadata` (see `AGENTS.md → Tooling`).

**Step 2.** Run the export through Designer. Objects are exported **in full**, strictly into the specified directory — **do NOT create new subdirectories**.

```powershell
& '{PLATFORM_PATH}\bin\1cv8.exe' DESIGNER `
    /F '{INFOBASE_PATH}' `
    /N '{IB_USER}' `
    /P '{IB_PASSWORD}' `
    /DisableStartupMessages `
    /DumpConfigToFiles {EXPORT_PATH} `
    -listFile repoobjects.txt `
    -Extension {EXTENSION_NAME} `
    /Out {LOG_PATH}
```

When exporting from the main configuration (not from an extension) — drop the `-Extension {EXTENSION_NAME}` argument.

**Step 3.** Inspect `{LOG_PATH}` for errors before starting any edits.
