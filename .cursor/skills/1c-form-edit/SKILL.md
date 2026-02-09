---
name: 1c-form-edit
description: "Add elements, attributes, and commands to an existing 1C managed form (Form.xml). Use when modifying an existing form by inserting new UI elements, data attributes, or commands."
---

# 1C Form Edit — Modify Existing Forms

Adds elements, attributes, and/or commands to an existing Form.xml. Automatically allocates IDs from the correct pool, generates companion elements (ContextMenu, ExtendedTooltip, etc.) and event handlers.

## Usage

```
1c-form-edit <FormPath> <JsonPath>
```

| Parameter | Required | Description |
|-----------|:--------:|-------------|
| FormPath | yes | Path to existing Form.xml |
| JsonPath | yes | Path to JSON with additions |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-form-edit/scripts/form-edit.ps1 -FormPath "<path>" -JsonPath "<path>"
```

## JSON Format

```json
{
  "into": "HeaderGroup",
  "after": "Contractor",
  "elements": [
    { "input": "Warehouse", "path": "Object.Warehouse", "on": ["OnChange"] }
  ],
  "attributes": [
    { "name": "TotalAmount", "type": "decimal(15,2)" }
  ],
  "commands": [
    { "name": "Calculate", "action": "CalculateHandler" }
  ]
}
```

### Element Positioning

| Key | Default | Description |
|-----|---------|-------------|
| `into` | root ChildItems | Name of group/table/page to insert into |
| `after` | at end | Name of element to insert after |

### Element Types

Same DSL keys as in `1c-form-compile`:

| Key | XML Tag | Companions |
|-----|---------|------------|
| `input` | InputField | ContextMenu, ExtendedTooltip |
| `check` | CheckBoxField | ContextMenu, ExtendedTooltip |
| `label` | LabelDecoration | ContextMenu, ExtendedTooltip |
| `labelField` | LabelField | ContextMenu, ExtendedTooltip |
| `group` | UsualGroup | ExtendedTooltip |
| `table` | Table | ContextMenu, AutoCommandBar, Search*, ViewStatus* |
| `pages` | Pages | ExtendedTooltip |
| `page` | Page | ExtendedTooltip |
| `button` | Button | ExtendedTooltip |

Groups and tables support `children`/`columns` for nested elements.

### Buttons: command and stdCommand

- `"command": "CommandName"` → `Form.Command.CommandName`
- `"stdCommand": "Close"` → `Form.StandardCommand.Close`
- `"stdCommand": "Items.Add"` → `Form.Item.Items.StandardCommand.Add` (standard item command)

### Allowed Events (`on`)

The compiler warns about errors in event names. Main events:

- **input**: `OnChange`, `StartChoice`, `ChoiceProcessing`, `Clearing`, `AutoComplete`, `TextEditEnd`
- **check**: `OnChange`
- **table**: `OnStartEdit`, `OnEditEnd`, `OnChange`, `Selection`, `BeforeAddRow`, `BeforeDeleteRow`, `OnActivateRow`
- **label/picture**: `Click`, `URLProcessing`
- **pages**: `OnCurrentPageChange`
- **button**: `Click`

### Type System (for attributes)

`string`, `string(100)`, `decimal(15,2)`, `boolean`, `date`, `dateTime`, `CatalogRef.XXX`, `DocumentObject.XXX`, `ValueTable`, `DynamicList`, `Type1 | Type2` (composite).

## Output

```
=== form-edit: FormName ===

Added elements (into HeaderGroup, after Contractor):
  + [Input] Warehouse -> Object.Warehouse {OnChange}

Added attributes:
  + TotalAmount: decimal(15,2) (id=12)

---
Total: 1 element(s) (+2 companions), 1 attribute(s)
Run 1c-form-validate to verify.
```

## When to Use

- **After `1c-form-compile`**: add elements not included in the original JSON
- **Modifying existing forms**: add a field, attribute, or command to a form from configuration
- **Batch additions**: one JSON can contain elements + attributes + commands

## Workflow

1. `1c-form-info` — view current form structure
2. Create JSON with addition descriptions
3. `1c-form-edit` — add to form
4. `1c-form-validate` — verify correctness
5. `1c-form-info` — confirm additions are correct

## MCP Integration

Use `search_metadata` MCP tool to verify attribute types and object names. Use `1c-form-info` skill to analyze form structure before editing.
