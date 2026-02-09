---
name: 1c-form-compile
description: "Compile a 1C managed form (Form.xml) from a compact JSON definition. Use when generating Form.xml from a JSON DSL for any 1C object — data processors, documents, catalogs, registers, etc."
---

# 1C Form Compile — Generate Form.xml from JSON DSL

Takes a compact JSON definition (20–50 lines) and generates a complete, valid Form.xml (100–500+ lines) with namespace declarations, auto-generated companion elements, and sequential IDs.

> **When designing a form from scratch (5+ elements or unclear requirements)** — load the `1c-form-patterns` skill first for archetypes, naming conventions, and advanced patterns. For simple forms (1–3 fields with clear requirements) — not needed.

## Usage

```
1c-form-compile <JsonPath> <OutputPath>
```

| Parameter | Required | Description |
|-----------|:--------:|-------------|
| JsonPath | yes | Path to the form JSON definition |
| OutputPath | yes | Path to output Form.xml file |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-form-compile/scripts/form-compile.ps1 -JsonPath "<json>" -OutputPath "<xml>"
```

## JSON DSL Reference

### Top-Level Structure

```json
{
  "title": "Form Title",
  "properties": { "autoTitle": false, ... },
  "events": { "OnCreateAtServer": "OnCreateAtServerHandler" },
  "excludedCommands": ["Reread"],
  "elements": [ ... ],
  "attributes": [ ... ],
  "commands": [ ... ],
  "parameters": [ ... ]
}
```

- `title` — form title (multilingual). Can also be in `properties`, but top-level is preferred
- `properties` — form properties: `autoTitle`, `windowOpeningMode`, `commandBarLocation`, `saveDataInSettings`, `width`, `height`, etc.
- `events` — form event handlers (key: 1C event name, value: procedure name)
- `excludedCommands` — excluded standard commands

### Elements (key determines type)

| DSL Key | XML Element | Key Value |
|---------|-------------|-----------|
| `"group"` | UsualGroup | `"horizontal"` / `"vertical"` / `"alwaysHorizontal"` / `"alwaysVertical"` / `"collapsible"` |
| `"input"` | InputField | element name |
| `"check"` | CheckBoxField | name |
| `"label"` | LabelDecoration | name (text set via `title`) |
| `"labelField"` | LabelField | name |
| `"table"` | Table | name |
| `"pages"` | Pages | name |
| `"page"` | Page | name |
| `"button"` | Button | name |
| `"picture"` | PictureDecoration | name |
| `"picField"` | PictureField | name |
| `"calendar"` | CalendarField | name |
| `"cmdBar"` | CommandBar | name |
| `"popup"` | Popup | name |

### Common Properties (all element types)

| Key | Description |
|-----|-------------|
| `name` | Override name (default = type key value) |
| `title` | Element title |
| `visible: false` | Hide (synonym: `hidden: true`) |
| `enabled: false` | Disable (synonym: `disabled: true`) |
| `readOnly: true` | Read-only |
| `on: [...]` | Events with auto-named handlers |
| `handlers: {...}` | Explicit handler names: `{"OnChange": "MyHandler"}` |

### Allowed Event Names (`on`)

The compiler warns about unknown events. Names are case-sensitive — use exactly as shown.

**Form** (`events`): `OnCreateAtServer`, `OnOpen`, `BeforeClose`, `OnClose`, `NotificationProcessing`, `ChoiceProcessing`, `OnReadAtServer`, `BeforeWriteAtServer`, `OnWriteAtServer`, `AfterWriteAtServer`, `BeforeWrite`, `AfterWrite`, `FillCheckProcessingAtServer`, `BeforeLoadDataFromSettingsAtServer`, `OnLoadDataFromSettingsAtServer`, `ExternalEvent`, `Opening`

**input / picField**: `OnChange`, `StartChoice`, `ChoiceProcessing`, `AutoComplete`, `TextEditEnd`, `Clearing`, `Creating`, `EditTextChange`

**check**: `OnChange`

**table**: `OnStartEdit`, `OnEditEnd`, `OnChange`, `Selection`, `ValueChoice`, `BeforeAddRow`, `BeforeDeleteRow`, `AfterDeleteRow`, `BeforeRowChange`, `BeforeEditEnd`, `OnActivateRow`, `OnActivateCell`, `Drag`, `DragStart`, `DragCheck`, `DragEnd`

**label / picture**: `Click`, `URLProcessing`

**labelField**: `OnChange`, `StartChoice`, `ChoiceProcessing`, `Click`, `URLProcessing`, `Clearing`

**button**: `Click`

**pages**: `OnCurrentPageChange`

### Input Field

| Key | Description | Example |
|-----|-------------|---------|
| `path` | DataPath — data binding | `"Object.Organization"` |
| `titleLocation` | Title location | `"none"`, `"left"`, `"top"` |
| `multiLine: true` | Multi-line field | text field, comment |
| `passwordMode: true` | Password mode (asterisks) | password input |
| `choiceButton: true` | Choice button ("...") | reference field |
| `clearButton: true` | Clear button ("X") | |
| `spinButton: true` | Spin button | numeric fields |
| `dropListButton: true` | Drop-down list button | |
| `markIncomplete: true` | Mark as incomplete | required fields |
| `skipOnInput: true` | Skip on Tab traversal | |
| `inputHint` | Hint in empty field | `"Enter name..."` |
| `width` / `height` | Size | numbers |
| `autoMaxWidth: false` | Disable auto-width | for fixed fields |
| `horizontalStretch: true` | Stretch horizontally | |

### Checkbox

| Key | Description |
|-----|-------------|
| `path` | DataPath |
| `titleLocation` | Title location |

### Label Decoration

| Key | Description |
|-----|-------------|
| `title` | Label text (required) |
| `hyperlink: true` | Make it a hyperlink |
| `width` / `height` | Size |

### Group

Value of the key sets orientation: `"horizontal"`, `"vertical"`, `"alwaysHorizontal"`, `"alwaysVertical"`, `"collapsible"`.

| Key | Description |
|-----|-------------|
| `showTitle: true` | Show group title |
| `united: false` | Do not unite border |
| `representation` | `"none"`, `"normal"`, `"weak"`, `"strong"` |
| `children: [...]` | Nested elements |

### Table

**Important**: a table requires an associated form attribute of type `ValueTable` with columns (see "Bindings" section).

| Key | Description |
|-----|-------------|
| `path` | DataPath (binding to table attribute) |
| `columns: [...]` | Columns — array of elements (usually `input`) |
| `changeRowSet: true` | Allow adding/removing rows |
| `changeRowOrder: true` | Allow row reordering |
| `height` | Height in table rows |
| `header: false` | Hide header |
| `footer: true` | Show footer |
| `commandBarLocation` | `"None"`, `"Top"`, `"Auto"` |
| `searchStringLocation` | `"None"`, `"Top"`, `"Auto"` |

### Pages (pages + page)

| Key (pages) | Description |
|-------------|-------------|
| `pagesRepresentation` | `"None"`, `"TabsOnTop"`, `"TabsOnBottom"`, etc. |
| `children: [...]` | Array of `page` elements |

| Key (page) | Description |
|------------|-------------|
| `title` | Tab title |
| `group` | Orientation inside page |
| `children: [...]` | Page content |

### Button

| Key | Description |
|-----|-------------|
| `command` | Form command name → `Form.Command.Name` |
| `stdCommand` | Standard command: `"Close"` → `Form.StandardCommand.Close`; with dot: `"Items.Add"` → `Form.Item.Items.StandardCommand.Add` |
| `defaultButton: true` | Default button |
| `type` | `"usual"`, `"hyperlink"`, `"commandBar"` |
| `picture` | Button picture |
| `representation` | `"Auto"`, `"Text"`, `"Picture"`, `"PictureAndText"` |
| `locationInCommandBar` | `"Auto"`, `"InCommandBar"`, `"InAdditionalSubmenu"` |

### Command Bar (cmdBar)

| Key | Description |
|-----|-------------|
| `autofill: true` | Auto-fill with standard commands |
| `children: [...]` | Bar buttons |

### Popup Menu

| Key | Description |
|-----|-------------|
| `title` | Submenu title |
| `children: [...]` | Submenu buttons |

Used inside `cmdBar` to group buttons:
```json
{ "cmdBar": "Panel", "children": [
  { "popup": "Add", "title": "Add", "children": [
    { "button": "AddRow", "stdCommand": "Items.Add" },
    { "button": "AddFromDocument", "command": "AddFromDocument", "title": "From Document" }
  ]}
]}
```

### Attributes

```json
{ "name": "Object", "type": "DataProcessorObject.Import", "main": true }
{ "name": "Total", "type": "decimal(15,2)" }
{ "name": "Table", "type": "ValueTable", "columns": [
    { "name": "Product", "type": "CatalogRef.Products" },
    { "name": "Quantity", "type": "decimal(10,3)" }
]}
```

- `savedData: true` — saved data

### Commands

```json
{ "name": "Import", "action": "ImportHandler", "shortcut": "Ctrl+Enter" }
```

- `title` — title (if different from name)
- `picture` — command picture

### Type System

| DSL | XML |
|-----|-----|
| `"string"` / `"string(100)"` | `xs:string` + StringQualifiers |
| `"decimal(15,2)"` | `xs:decimal` + NumberQualifiers |
| `"decimal(10,0,nonneg)"` | with AllowedSign=Nonnegative |
| `"boolean"` | `xs:boolean` |
| `"date"` / `"dateTime"` / `"time"` | `xs:dateTime` + DateFractions |
| `"CatalogRef.XXX"` | `cfg:CatalogRef.XXX` |
| `"DocumentRef.XXX"` | `cfg:DocumentRef.XXX` |
| `"ValueTable"` | `v8:ValueTable` |
| `"ValueList"` | `v8:ValueListType` |
| `"Type1 \| Type2"` | composite type |

## Bindings: Element + Attribute

Tables and some fields require an associated attribute. Elements reference attributes via `path`.

**Table** — `table` element + `ValueTable` attribute:
```json
{
  "elements": [
    { "table": "Items", "path": "Object.Items", "columns": [
      { "input": "Product", "path": "Object.Items.Product" }
    ]}
  ],
  "attributes": [
    { "name": "Object", "type": "DataProcessorObject.Import", "main": true,
      "columns": [
        { "name": "Items", "type": "ValueTable", "columns": [
          { "name": "Product", "type": "CatalogRef.Products" }
        ]}
      ]
    }
  ]
}
```

Or, if table is bound to a form attribute (not Object):
```json
{
  "elements": [
    { "table": "DataTable", "path": "DataTable", "columns": [
      { "input": "Name", "path": "DataTable.Name" }
    ]}
  ],
  "attributes": [
    { "name": "DataTable", "type": "ValueTable", "columns": [
      { "name": "Name", "type": "string(150)" }
    ]}
  ]
}
```

## Auto-generation

- **Companion elements**: ContextMenu, ExtendedTooltip, etc. are created automatically
- **Event handlers**: `"on": ["OnChange"]` → auto-named handler
- **Namespace**: all 17 namespace declarations
- **IDs**: sequential numbering, AutoCommandBar = id="-1"
- **Unknown keys**: warning about unrecognized keys

## Verification

```
1c-form-validate <OutputPath>    — check XML correctness
1c-form-info <OutputPath>        — visual structure summary
```

## Notes for External Data Processors (EPF)

- **Main attribute type**: `ExternalDataProcessorObject.ProcessorName` (not `DataProcessorObject`)
- **DataPath**: use form attributes (`AttributeName`), not `Object.AttributeName` — external data processors have no object attributes in metadata
- **Reference types**: `CatalogRef.XXX`, `DocumentRef.XXX`, etc. may not build in an empty infobase — use `string` or basic types for standalone builds

## MCP Integration

Use `search_metadata` MCP tool to verify metadata types when defining attributes. Use `templatesearch` to find similar form patterns.
