---
name: 1c-form-patterns
description: "Reference guide of managed form design patterns for 1C — archetypes, naming conventions, advanced techniques. Use before designing forms via 1c-form-compile when requirements lack UI layout details."
---

# 1C Form Patterns — Design Reference

Reference of standard managed form design patterns for 1C. Load **before** designing a form via `1c-form-compile` when user requirements do not specify element placement details.

**How to use:** pick a matching archetype, apply naming conventions, use advanced patterns as needed.

---

## Form Archetypes

### Document Form

```
Header (horizontal, 2 columns)
├─ Left (vertical): NumberDate (H: Number + Date), Contractor, Contract
├─ Right (vertical): Organization, Department, PricesAndCurrency (hyperlink label)
Pages (pages)
├─ Items: table Object.Items
├─ Services: table Object.Services (optional)
└─ Additional: other attributes
Footer (vertical)
├─ Totals (horizontal): Total, VAT, Discount
└─ CommentResponsible (horizontal): Comment + Responsible
```

**Events:** OnCreateAtServer, OnReadAtServer, OnOpen, BeforeWriteAtServer, AfterWriteAtServer, AfterWrite, NotificationProcessing
**Properties:** autoTitle=false

### Data Processor Form

```
Parameters (vertical)
├─ Input fields group (Organization, Period, operating modes)
├─ Information labels (label, hyperlink)
Working area
├─ Data table or Pages with tabs
Action buttons
├─ Execute / Apply (defaultButton)
├─ Close (stdCommand: Close)
```

**Events:** OnCreateAtServer, OnOpen, NotificationProcessing
**Properties:** windowOpeningMode=LockOwnerWindow (if dialog), autoTitle=false

### List Form

```
Filters (group: alwaysHorizontal)
├─ FilterGroup[Field] (H): Checkbox + InputField (for each filter)
List (table, DynamicList)
├─ Columns: labelField (not input — data is read-only)
```

**Events:** OnCreateAtServer, OnOpen, NotificationProcessing, OnLoadDataFromSettingsAtServer
**Properties:** autoSaveDataInSettings=Use
**Filters:** pair of attributes per filter — `Filter[Field]` (value) + `Filter[Field]Use` (boolean)

### Catalog Item Form

**Simple:**
```
AttributeGroup (horizontal)
├─ Description -> Object.Description
└─ Code -> Object.Code (if needed)
```

**Complex:**
```
Main (vertical)
├─ Description -> Object.Description
├─ Parameters (horizontal, 2 columns)
│  ├─ Left: main attributes
│  └─ Right: additional attributes
└─ ContactInfo / Additional (vertical)
```

**Events:** OnCreateAtServer, OnReadAtServer, BeforeWriteAtServer, NotificationProcessing

### Wizard

```
Pages (pages, OnCurrentPageChange)
├─ Step1: description + parameters
├─ Step2: main work
└─ Step3: result
Buttons (horizontal)
├─ Back (command), Next (command, defaultButton), Execute (command)
└─ Close (stdCommand: Close)
```

**Properties:** windowOpeningMode=LockOwnerWindow, commandBarLocation=None

---

## Naming Conventions

### Groups

| Purpose | Name | Type |
|---------|------|------|
| Header | `HeaderGroup` | horizontal |
| Left column | `HeaderLeftGroup` | vertical |
| Right column | `HeaderRightGroup` | vertical |
| Number+Date | `NumberDateGroup` | horizontal |
| Footer | `FooterGroup` | vertical |
| Totals | `TotalsGroup` | horizontal |
| Buttons | `ButtonsGroup` | horizontal |
| Pages | `PagesGroup` / `Pages` | pages |
| Warning | `WarningGroup` | horizontal, visible:false |
| Additional section | `AdditionalGroup` / `OtherGroup` | vertical, collapse |

### Elements

| Purpose | Name |
|---------|------|
| Field in table | `[Table][Field]` |
| Total | `Totals[Field]` |
| Hyperlink label | `[Field]Label` |
| Filter | `Filter[Field]` |
| Filter checkbox | `Filter[Field]Use` |
| Command button | `[Command]Button` |
| Banner image | `[Banner]Picture` |
| Banner label | `[Banner]Label` |
| Submenu | `Submenu[Action]` |

### Event Handlers

Name = element name + Russian suffix:

| Event | Suffix | Example |
|-------|--------|---------|
| OnChange | ПриИзменении | `ОрганизацияПриИзменении` |
| StartChoice | НачалоВыбора | `КонтрагентНачалоВыбора` |
| Click | Нажатие | `ЦеныИВалютаНажатие` |
| OnEditEnd | ПриОкончанииРедактирования | `ТоварыПриОкончанииРедактирования` |
| OnStartEdit | ПриНачалеРедактирования | `ТоварыПриНачалеРедактирования` |

Form handlers: `ПриСозданииНаСервере`, `ПриОткрытии`, `ПередЗакрытием`, `ОбработкаОповещения`.

---

## Layout Principles

1. **Reading order.** Top to bottom, left to right. Most important — at top.
2. **Two-column header.** Main attributes on left (contractor, warehouse), organizational on right (organization, department).
3. **Action buttons at bottom.** Main button — `defaultButton: true`. Close — always last.
4. **Tables are the main area.** Tabular sections occupy most of the form, usually on Pages.
5. **Totals near table.** In footer, horizontal group, all fields readOnly.
6. **Filters as separate zone.** Above list, alwaysHorizontal, pair of "checkbox + field" per filter.
7. **Hidden elements for states.** Banners, warnings — `visible: false`, shown programmatically.
8. **Hyperlink labels for dialogs.** `labelField` with `hyperlink: true` and Click event.

---

## Advanced Patterns

### Collapsible Groups

For optional sections (signatures, additional, other):

```json
{ "group": "vertical", "name": "SignaturesGroup", "title": "Signatures",
  "behavior": "Collapsible", "collapsed": true, "children": [...] }
```

### Warning Banner

Group "image + label", hidden by default, shown programmatically:

```json
{ "group": "horizontal", "name": "WarningGroup", "showTitle": false,
  "visible": false, "children": [
    { "picture": "WarningPicture" },
    { "label": "WarningLabel", "title": "Text", "maxWidth": 76, "autoMaxWidth": false }
]}
```

### Popup Menu in Command Bar

Grouping related commands (print, send) in one button with icon:

```json
{ "cmdBar": "CommandBar", "children": [
    { "popup": "SubmenuPrint", "title": "Print",
      "picture": "StdPicture.Print", "representation": "Picture", "children": [
        { "button": "PrintInvoice", "command": "Print" },
        { "button": "PrintReceipt", "command": "PrintReceipt" }
    ]}
]}
```

### Form Without Standard Command Bar

For modal dialogs and wizards:

```json
{ "properties": { "commandBarLocation": "None", "windowOpeningMode": "LockWholeInterface" } }
```

### Hyperlink Label

Instead of a button for opening subforms (PricesAndCurrency, AccountingPolicy):

```json
{ "labelField": "PricesAndCurrencyLabel", "path": "PricesAndCurrency", "hyperlink": true, "on": ["Click"] }
```

---

## Full DSL Example: Data Processor Form

```json
{
  "title": "CSV Data Import",
  "properties": { "autoTitle": false, "windowOpeningMode": "LockOwnerWindow" },
  "events": { "OnCreateAtServer": "OnCreateAtServerHandler" },
  "elements": [
    { "group": "vertical", "name": "ParametersGroup", "children": [
      { "input": "ImportFile", "path": "ImportFile", "title": "File", "clearButton": true, "horizontalStretch": true, "on": ["StartChoice"] },
      { "input": "Encoding", "path": "Encoding" },
      { "input": "Delimiter", "path": "Delimiter", "title": "Column Delimiter" }
    ]},
    { "table": "Data", "path": "Object.Data", "on": ["OnStartEdit"], "columns": [
      { "input": "DataRowNumber", "path": "Object.Data.LineNumber", "readOnly": true, "title": "No." },
      { "input": "DataName", "path": "Object.Data.Name" },
      { "input": "DataQuantity", "path": "Object.Data.Quantity", "on": ["OnChange"] },
      { "input": "DataAmount", "path": "Object.Data.Amount", "readOnly": true }
    ]},
    { "group": "horizontal", "name": "ButtonsGroup", "children": [
      { "button": "Import", "command": "Import", "title": "Import from File", "defaultButton": true },
      { "button": "Clear", "command": "Clear", "title": "Clear Table" },
      { "button": "Close", "stdCommand": "Close" }
    ]}
  ],
  "attributes": [
    { "name": "Object", "type": "ExternalDataProcessorObject.CSVImport", "main": true },
    { "name": "ImportFile", "type": "string" },
    { "name": "Encoding", "type": "string(20)" },
    { "name": "Delimiter", "type": "string(5)" }
  ],
  "commands": [
    { "name": "Import", "action": "ImportHandler" },
    { "name": "Clear", "action": "ClearHandler" }
  ]
}
```

## MCP Integration

Use `templatesearch` MCP tool to find real form examples in the codebase. Use `search_metadata` to verify object types and attribute names when designing form layouts.
