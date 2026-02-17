# 1C Configuration Manage — Init, Edit, Info, Validate

Comprehensive configuration management: create scaffold, edit properties/composition, analyze structure, validate correctness.

---

## 1. Init — Create Configuration Scaffold

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cf-manage/scripts/cf-init.ps1 -Name "<Name>" [-OutputDir "<path>"]
```

Creates minimal configuration structure: `Configuration.xml`, `Languages/Русский.xml`, and basic directory structure.

---

## 2. Edit — Modify Configuration Properties

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cf-manage/scripts/cf-edit.ps1 -ConfigPath '<path>' -Operation <op> -Value '<value>'
```

| Parameter | Description |
|-----------|-------------|
| `ConfigPath` | Path to Configuration.xml or export directory |
| `Operation` | Operation (see table) |
| `Value` | Value (batch via `;;`) |
| `DefinitionFile` | JSON file with operation array |
| `NoValidate` | Skip auto-validation |

### Operations

| Operation | Value Format | Description |
|-----------|-------------|-------------|
| `modify-property` | `Key=Value` (batch `;;`) | Change property |
| `add-childObject` | `Type.Name` (batch `;;`) | Add object to ChildObjects |
| `remove-childObject` | `Type.Name` (batch `;;`) | Remove object from ChildObjects |
| `add-defaultRole` | `Role.Name` or `Name` | Add default role |
| `remove-defaultRole` | `Role.Name` or `Name` | Remove default role |
| `set-defaultRoles` | Names via `;;` | Replace default roles list |

Full property reference: [cf-edit-reference.md](skills/1c-metadata-manage/tools/1c-cf-manage/cf-edit-reference.md).

### Examples

```powershell
# Change version and vendor
... -Operation modify-property -Value "Version=1.0.0.1 ;; Vendor=Company"

# Add objects
... -Operation add-childObject -Value "Catalog.Товары ;; Document.Заказ"

# Default roles
... -Operation set-defaultRoles -Value "ПолныеПрава ;; Администратор"
```

---

## 3. Info — Analyze Configuration Structure

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cf-manage/scripts/cf-info.ps1 -ConfigPath "<path>"
```

Displays configuration properties, object counts by type, compatibility mode, version, and other key information.

---

## 4. Validate — Check Configuration Correctness

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-cf-manage/scripts/cf-validate.ps1 -ConfigPath "<path>"
```

| Parameter | Description |
|-----------|-------------|
| `ConfigPath` | Path to Configuration.xml or export directory |
| `MaxErrors` | Stop after N errors (default: 30) |
| `OutFile` | Write result to file (UTF-8 BOM) |

### Checks Performed

| # | Check | Severity |
|---|-------|----------|
| 1 | XML well-formedness, MetaDataObject/Configuration, version 2.17/2.20 | ERROR |
| 2 | InternalInfo: 7 ContainedObject, valid ClassId, uniqueness | ERROR |
| 3 | Properties: Name non-empty, Synonym, DefaultLanguage, DefaultRunMode | ERROR/WARN |
| 4 | Properties: enum values (11 properties) | ERROR |
| 5 | ChildObjects: valid type names (44 types), no duplicates, type order | ERROR/WARN |
| 6 | DefaultLanguage references existing Language in ChildObjects | ERROR |
| 7 | Language files Languages/<name>.xml exist | WARN |
| 8 | Object directories from ChildObjects exist (spot-check) | WARN |

Exit code: 0 = OK, 1 = errors.

---

## Typical Workflow

```
1c-cf-manage init        — create configuration scaffold
1c-cf-manage edit        — set properties, add objects
1c-cf-manage validate    — check correctness
1c-cf-manage info        — view structure summary
```

## MCP Integration

Use `search_metadata` MCP tool to explore existing configuration structure. Use `docsearch` for platform documentation on configuration properties.

## SDD Integration

When creating a new configuration as part of a project, update SDD artifacts if present (see `rules/sdd-integrations.mdc` for detection):

- **OpenSpec**: Create initial specs in `openspec/specs/` describing configuration purpose, compatibility, and scope.
- **Memory Bank**: Record configuration creation in `memory-bank/progress.md`; document architectural decisions in `memory-bank/systemPatterns.md`.
- **TaskMaster**: Call `set_task_status` after the configuration is created and validated.
- **Spec Kit**: Verify configuration aligns with `constitution.md` principles and `boundaries.md` scope.
