# 1C Extension Manage — Init, Borrow, Diff, Patch, Validate

Comprehensive extension (CFE) management: create scaffold, borrow objects from configuration, analyze changes, generate method interceptors, validate correctness.

---

## 1. Init — Create Extension Scaffold

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cfe-manage/scripts/cfe-init.ps1 -Name "МоёРасширение"
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `Name` | Extension name (required) | — |
| `Synonym` | Synonym | = Name |
| `NamePrefix` | Prefix for own objects | = Name + "_" |
| `OutputDir` | Output directory | `src` |
| `Purpose` | `Patch` / `Customization` / `AddOn` | `Customization` |
| `Version` | Extension version | — |
| `Vendor` | Vendor | — |
| `CompatibilityMode` | Compatibility mode | `Version8_3_24` |
| `NoRole` | Without main role | false |

### What Gets Created

```
<OutputDir>/
├── Configuration.xml         # Extension properties
├── Languages/
│   └── Русский.xml           # Language (borrowed)
└── Roles/                    # If not -NoRole
    └── <Prefix>ОсновнаяРоль.xml
```

**Preparation**: Before creating, get the base configuration version: `1c-cf-manage info <ConfigPath>`.

---

## 2. Borrow — Borrow Objects from Configuration

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cfe-manage/scripts/cfe-borrow.ps1 -ExtensionPath src -ConfigPath <config> -Object "Catalog.Контрагенты"
```

| Parameter | Description |
|-----------|-------------|
| `ExtensionPath` | Path to extension directory (required) |
| `ConfigPath` | Path to source configuration (required) |
| `Object` | What to borrow (required), batch via `;;` |

Format: `Catalog.X`, `CommonModule.Y`, `Document.Z`. All 44 object types supported. Batch: `"Catalog.X ;; CommonModule.Y ;; Enum.Z"`.

Creates XML files with `ObjectBelonging=Adopted` and `ExtendedConfigurationObject`, adds to ChildObjects.

---

## 3. Diff — Analyze Extension Changes

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cfe-manage/scripts/cfe-diff.ps1 -ExtensionPath src -ConfigPath <config> -Mode A
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ExtensionPath` | Path to extension (required) | — |
| `ConfigPath` | Path to configuration (required) | — |
| `Mode` | `A` (overview) / `B` (transfer check) | `A` |

**Mode A** — overview: For each object shows `[BORROWED]` (interceptors, own attributes/TS/forms) or `[OWN]` (counts).

**Mode B** — transfer check: For each `&ИзменениеИКонтроль`, extracts `#Вставка`/`#КонецВставки` blocks and searches for them in the configuration module. Statuses: `[TRANSFERRED]`, `[NOT_TRANSFERRED]`, `[NEEDS_REVIEW]`.

---

## 4. Patch — Generate Method Interceptor

Reads the original method **from the source configuration** and generates the `.bsl` interceptor of the borrowed object: correct context directive, full signature, framing preprocessor instructions and regions. For `ModificationAndControl` it copies the whole original body. Creates the module file, appends to an existing one, or re-syncs an already intercepted method.

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cfe-manage/scripts/cfe-patch-method.ps1 -ExtensionPath src\cfe\ИмяРасширения -ConfigPath src\cf -ModulePath "Catalog.Контрагенты.ObjectModule" -MethodName "ПриЗаписи" -InterceptorType Before
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ExtensionPath` | Path to extension (required) | — |
| `ConfigPath` | Source configuration sources — the original method is read from there | required, unless `ModulePath` is a file path |
| `ModulePath` | Logical name (`Type.Name.Module`) **or** a path to a source `.bsl` module | required for generation |
| `MethodName` | Method to intercept | required for generation |
| `InterceptorType` | `Before` / `After` / `Instead` / `ModificationAndControl` | required for generation |
| `Check` | Report drift of controlled methods (report only) | — |
| `Actualize` | Re-sync drifted controlled methods | — |

`NamePrefix` is taken from the extension's `Configuration.xml`. **Auto-detecting `ConfigPath`**: take `EXPORT_PATH` from `.dev.env` — the configuration XML export directory of this project (empty = repository root); ask the user only when it is not set and no source dump is discoverable. When `ModulePath` is a path to the source `.bsl`, `-ConfigPath` is unnecessary — the original is read from that file and the extension module path is derived automatically.

### ModulePath Format

| ModulePath | File |
|------------|------|
| `Catalog.X.ObjectModule` | `Catalogs/X/Ext/ObjectModule.bsl` |
| `Catalog.X.ManagerModule` | `Catalogs/X/Ext/ManagerModule.bsl` |
| `Catalog.X.Form.Y` | `Catalogs/X/Forms/Y/Ext/Form/Module.bsl` |
| `CommonModule.X` | `CommonModules/X/Ext/Module.bsl` |

Same shape for `Document`, `Report`, `DataProcessor`, `InformationRegister` and other types.

### Interceptor Types

| Type | Decorator | Purpose | Applies to |
|------|-----------|---------|------------|
| `Before` | `&Перед` | Code before the original method call | procedures |
| `After` | `&После` | Code after the original method call | procedures |
| `Instead` | `&Вместо` | Replaces the method; body scaffolds `ПродолжитьВызов(...)` | procedures and functions |
| `ModificationAndControl` | `&ИзменениеИКонтроль` | Copy of the original body, edited with `#Вставка` / `#Удаление` markers | procedures and functions |

Re-running `Before` / `After` / `Instead` on an already intercepted method does not create a duplicate (`[ПРОПУЩЕН]`).

### `#Вставка` / `#Удаление` markers (ModificationAndControl)

`&ИзменениеИКонтроль` inserts a **copy of the original body**; every change you make must be marked, because that is how the platform tells your edit from the untouched original:

- **Adding code** → wrap it in `#Вставка` … `#КонецВставки`.
- **Removing original code** → wrap the lines in `#Удаление` … `#КонецУдаления` **and keep the lines between the markers** — the platform compares them against the original.
- **Replacing** → `#Удаление` old `#КонецУдаления` immediately followed by `#Вставка` new `#КонецВставки`.

Rules: markers go on their **own line at column 0** (no indentation), even inside indented code or query text (`|…`); **unmarked lines must match the original verbatim** — that is the "control" part; touch only your own inserts and deletions.

### Drift control — `-Check` / `-Actualize`

When the vendor changes the original, an `&ИзменениеИКонтроль` interceptor silently desynchronizes — the unmarked context no longer matches. The platform says nothing about it on load, so check it yourself, **routinely after every vendor update**:

```powershell
# Report drift across all controlled methods of the extension (exit 1 on drift/conflict)
... cfe-patch-method.ps1 -ExtensionPath src\cfe\ИмяРасширения -ConfigPath src\cf -Check

# Re-apply the edits onto the new original, extension-wide
... cfe-patch-method.ps1 -ExtensionPath src\cfe\ИмяРасширения -ConfigPath src\cf -Actualize
```

Narrow the scope with `-ModulePath` (one module) or `-ModulePath` + `-MethodName` (one method).

| Status | Meaning |
|--------|---------|
| `[АКТУАЛЕН]` | Original unchanged, nothing to do |
| `[АКТУАЛИЗИРОВАН]` | Body updated against the new original, edits preserved |
| `[АКТУАЛИЗИРОВАН-ЧАСТИЧНО]` | Some edits could not be placed (anchor changed). They are **not lost** — marked `// [РЕСИНК-КОНФЛИКТ]` in the module; the output gives the merge workspace path (start at `index.md`, then each `conflict.md`, place the blocks manually) |
| `[ПЕРЕНЕСЕНО В ОСНОВНУЮ]` | The edit is already in the new original (vendor adopted it) — removed from the body as obsolete. If that happens to every edit of a method, the interceptor can be deleted. Does not fail `-Check` |

**Prerequisite**: Object must be borrowed first (`cfe-borrow`); the source configuration must be reachable via `-ConfigPath`.

---

## 5. Validate — Check Extension Correctness

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cfe-manage/scripts/cfe-validate.ps1 -ExtensionPath src
```

### Checks (9 steps)

| # | Check | Severity |
|---|-------|----------|
| 1 | XML well-formedness, MetaDataObject/Configuration, version | ERROR |
| 2 | InternalInfo: 7 ContainedObject, valid ClassId | ERROR |
| 3 | Extension properties: ObjectBelonging=Adopted, Name, Purpose, NamePrefix, KeepMapping | ERROR |
| 4 | Enum values: CompatibilityMode, DefaultRunMode, ScriptVariant, InterfaceCompatibilityMode | ERROR |
| 5 | ChildObjects: valid types (44), no duplicates, canonical order | ERROR/WARN |
| 6 | DefaultLanguage references Language in ChildObjects | ERROR |
| 7 | Language files exist | WARN |
| 8 | Object directories exist | WARN |
| 9 | Borrowed objects: ObjectBelonging=Adopted, ExtendedConfigurationObject UUID | ERROR/WARN |

Exit code: 0 = OK, 1 = errors.

### What `cfe-validate` cannot see — the platform check is a separate step

All nine checks read **source**: XML shape, ClassIds, ChildObjects ordering, adopted-object markers. They are silent about the one failure mode that actually breaks a base — an interceptor whose target method no longer exists in the main configuration. `&Вместо ПриЗаписи` against a method the vendor renamed is perfectly valid XML and perfectly valid BSL; the platform rejects it only at apply time, and an `&После` in the same position may just stop firing with no error at all.

Before loading an extension into any infobase, run the platform's own ladder — canon `content/rules/designer-batch-checks.md`:

```
/CheckModules -ThinClient -Server -ExternalConnection -Extension <Name>
/CheckCanApplyConfigurationExtensions -Extension <Name>
/CheckConfig -ConfigLogIntegrity -IncorrectReferences ... -Extension <Name>
```

Read the verdict from three signals (process exit code, `/DumpResult`, `/Out` diagnostics) and classify the platform's success phrases before its error stems — `Ошибок не обнаружено` contains the word `ошибок`. `Не найден метод` in the log is a failure even at exit code 0.

For a `&ИзменениеИКонтроль`-heavy extension, `-Check` (section 4) and the applicability check answer related questions from opposite ends: drift detection names the *method* whose original moved, the platform names the *error*. Run `-Check` first — it is cheaper and its output is more actionable.

### Backup and rollback before replacing an existing extension

Loading over an existing extension is a replacement with no platform-side undo. Dump both forms first — `/DumpCfg -Extension <Name>` (editable) and `/DumpDBCfg -Extension <Name>` (database, what running sessions execute) — and recover with `/RollbackCfg -Extension <Name>` before the DB update, or by reloading the saved `.cfe` after it. **Never delete a pre-existing extension as a rollback**: deletion drops its own objects and every mapping along with your change. Details — `content/rules/designer-batch-checks.md → Extension apply and rollback`.

---

## Typical Extension Workflow

```
1c-cf-manage info <config>          — get base config version/compatibility
1c-cfe-manage init                  — create extension scaffold
1c-cfe-manage borrow               — borrow objects to modify
1c-cfe-manage patch                 — generate interceptors
1c-cfe-manage validate              — check correctness (source-level)
1c-cfe-manage diff -Mode A          — review changes overview
1c-cfe-manage diff -Mode B          — check transfer status
1c-cfe-manage patch -Check          — drift against the vendor original
   ↓ before loading into any infobase
/CheckModules → /CheckCanApplyConfigurationExtensions → /CheckConfig
                                    — platform-level ladder, designer-batch-checks.md
```

## Recent Additions (upstream sync `2026-07-30`)

The PowerShell scripts under `tools/1c-cfe-manage/scripts/` were refreshed from [Nikolay-Shirokov/cc-1c-skills](https://github.com/Nikolay-Shirokov/cc-1c-skills). Highlights of this sync (previous base: late May 2026):

### `cfe-patch-method` — v1.1 → v2.5, the biggest change in this group

- **Source-aware generation**: the original method is read from the source configuration (`-ConfigPath`, auto-detectable via `.dev.env` `EXPORT_PATH`), so the interceptor gets the real signature, context directive and — for `ModificationAndControl` — the full original body. `ModulePath` may now be a path to the source `.bsl` instead of a logical name.
- **`Instead` (`&Вместо`)** interceptor type with a `ПродолжитьВызов(...)` scaffold; works for functions too.
- **Drift control** — `-Check` / `-Actualize` over controlled (`&ИзменениеИКонтроль`) methods, extension-wide or narrowed to a module / method. Re-applies your `#Вставка` / `#Удаление` edits onto a changed vendor original, reports what moved, what conflicted and what the vendor has already adopted. Conflicts land in a merge workspace with anchored `conflict.md` files instead of being lost. **Run `-Check` after every vendor update** — the platform never reports this drift itself.
- Repeated interception of an already patched method is skipped instead of duplicated.

Full description in section 4 above.

### `cfe-borrow` — borrowing forms now matches Configurator output

- The borrowed form gets the **complete `ChildItems` tree** (not the previously empty skeleton). Loadable into the target base without manual XML fixes for complex ERP forms.
- **Dependencies are auto-borrowed**: shared pictures, style elements, enums, and enum values used by the borrowed form. No more cascade of "object not found" errors after the first load.
- `DataPath`, `Events`, `TitleDataPath`, `TypeLink`, `CommandName` are stripped from the borrowed form (these caused "invalid data path" / "event not loaded" errors on real ERP forms, also for command-bar buttons).
- Form-level properties (`AutoTitle`, `WindowOpeningMode`, …) are preserved both in the main section and in `BaseForm`.
- **`-BorrowMainAttribute`** (`Form` or `All`) — borrows the form's main attribute (`Object`) and transitively all its attributes, tabular sections, and dependent types. Closes the manual-collection workflow when adding an attribute to a borrowed form.

### `cfe-validate`

- New checks for borrowed-form structure, their dependencies (shared pictures, style elements, enums), and the extension's own subobjects (attributes, tabular sections, enum values, forms).
- False positives removed: `DataPath` / `TitleDataPath` inside `BaseForm` are correct (Configurator emits them); the extension's own subobjects (own attributes, own enum values) are no longer validated as borrowed.

### `cfe-init`

- Interface mode and compatibility mode are inherited from the base configuration (resolved via `-ConfigPath`). The extension matches the base's behaviour by default.

### Vendor support

An extension is the **default answer** when a typical object on vendor support needs a change: support state stays untouched and vendor updates keep flowing. The mutating tools of this skill now enforce that — they refuse to edit a locked object directly and point here. See [support-manage.md](support-manage.md).

## MCP Integration

- **get_object_dossier** — Comprehensive structural passport of the base object before borrowing (structure, forms, dependencies, code modules, roles).
- **metadatasearch** — Find objects to borrow and verify module paths.
- **get_metadata_details** — Get full object structure for objects being borrowed.
- **search_code** — Find methods to intercept (prefer over `codesearch`; supports semantic/fulltext/hybrid search with detail levels L0–L3).
- **codesearch** — Find methods in raw BSL files (fallback when `search_code` is not available).
- **metadatasearch** (`names_only=true`) — Find similar metadata objects for extension XML reference.
- **compare_base_and_extension** — Structural diff between base and extension after borrowing: attributes, forms, and routines added/overridden/unchanged.
- **trace_impact** — Recursive impact analysis of extension changes on the base configuration (preferred over `graph_dependencies` for deep dependency chains).
- **graph_dependencies** — Flat dependency overview before borrowing.
- **syntaxcheck** — Verify generated BSL code.

## SDD Integration

When creating extensions as part of a feature, update SDD artifacts if present (see `content/rules/sdd-integrations.md` for detection):

- **OpenSpec**: Document borrowed objects, interceptors, and extension scope in spec deltas under `openspec/changes/`.
