---
name: 1c-form-validate
description: "Validate structural correctness of a 1C managed form (Form.xml). Use after generating or editing Form.xml to check for structural errors."
---

# 1C Form Validate — Form Structure Validator

Checks Form.xml of a managed form for structural errors: ID uniqueness, companion element presence, DataPath and command reference correctness.

## Usage

```
1c-form-validate <FormPath>
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| FormPath | yes | — | Path to Form.xml file |
| MaxErrors | no | 30 | Stop after N errors |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-form-validate/scripts/form-validate.ps1 -FormPath "<path>"
```

## Checks Performed

| # | Check | Severity |
|---|-------|----------|
| 1 | Root element `<Form>`, version="2.17" | ERROR / WARN |
| 2 | `<AutoCommandBar>` present, id="-1" | ERROR |
| 3 | Element ID uniqueness (separate pool) | ERROR |
| 4 | Attribute ID uniqueness (separate pool) | ERROR |
| 5 | Command ID uniqueness (separate pool) | ERROR |
| 6 | Companion elements (ContextMenu, ExtendedTooltip, etc.) | ERROR |
| 7 | DataPath → references existing attribute | ERROR |
| 8 | Button CommandName → references existing command | ERROR |
| 9 | Events have non-empty handler names | ERROR |
| 10 | Commands have Action (handler) | ERROR |
| 11 | No more than one MainAttribute | ERROR |

## Output

```
=== Validation: DocumentForm ===

[OK]    Root element: Form version=2.17
[OK]    AutoCommandBar: name='FormCommandBar', id=-1
[OK]    Unique element IDs: 96 elements
[OK]    Unique attribute IDs: 38 entries
[OK]    Unique command IDs: 5 entries
[OK]    Companion elements: 86 elements checked
[OK]    DataPath references: 53 paths checked
[OK]    Command references: 2 buttons checked
[OK]    Event handlers: 41 events checked
[OK]    Command actions: 5 commands checked
[OK]    MainAttribute: 1 main attribute

---
Total: 96 elements, 38 attributes, 5 commands
All checks passed.
```

Return code: 0 = all checks passed, 1 = errors found.

## When to Use

- **After `1c-form-compile`**: verify correctness of generated form
- **After manual Form.xml editing**: ensure IDs are unique, companions are present, references are valid
- **When debugging**: identify structural errors before building

## Workflow

1. `1c-form-compile` or `1c-form-edit` — generate/modify form
2. `1c-form-validate` — run validation
3. Fix any reported errors
4. `1c-form-info` — verify structure visually
