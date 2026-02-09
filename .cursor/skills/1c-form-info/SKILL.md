---
name: 1c-form-info
description: "Analyze 1C managed form structure (Form.xml) — elements, attributes, commands, events. Use to understand form layout before modifications or for navigation through large forms."
---

# 1C Form Info — Compact Form Summary

Reads a Form.xml of a managed form and outputs a compact summary: element tree, typed attributes, commands, events. Replaces the need to read thousands of XML lines.

## Usage

```
1c-form-info <FormPath>
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| FormPath | yes | — | Path to Form.xml file |
| Limit | no | `150` | Max output lines (overflow protection) |
| Offset | no | `0` | Skip N lines (for pagination) |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-form-info/scripts/form-info.ps1 -FormPath "<path to Form.xml>"
```

With pagination:
```powershell
powershell.exe -NoProfile -File skills/1c-form-info/scripts/form-info.ps1 -FormPath "<path>" -Offset 150
```

## Reading the Output

### Header

```
=== Form: DocumentForm — "Sales of Goods and Services" (Documents.SalesInvoice) ===
```

Form name, Title, and object context are determined from the file path and XML.

### Properties — Form Properties

Only non-default properties are shown. Title is shown in the header, not here:

```
Properties: AutoTitle=false, WindowOpeningMode=LockOwnerWindow, CommandBarLocation=Bottom
```

### Events — Form Event Handlers

```
Events:
  OnCreateAtServer -> OnCreateAtServerHandler
  OnOpen -> OnOpenHandler
```

### Elements — UI Element Tree

Compact tree with types, data bindings, flags, and events:

```
Elements:
  ├─ [Group:AH] HeaderGroup
  │  ├─ [Input] Organization -> Object.Organization {OnChange}
  │  └─ [Input] Contract -> Object.Contract [visible:false] {StartChoice}
  ├─ [Table] Items -> Object.Items
  │  ├─ [Input] Product -> Object.Items.Product {OnChange}
  │  └─ [Input] Amount -> Object.Items.Amount [ro]
  └─ [Pages] Pages
     ├─ [Page] Main (5 items)
     └─ [Page] Print (2 items)
```

**Element Type Abbreviations:**

| Abbreviation | Element |
|---|---|
| `[Group:V]` | UsualGroup Vertical |
| `[Group:H]` | UsualGroup Horizontal |
| `[Group:AH]` | UsualGroup AlwaysHorizontal |
| `[Group:AV]` | UsualGroup AlwaysVertical |
| `[Group]` | UsualGroup (default orientation) |
| `[Input]` | InputField |
| `[Check]` | CheckBoxField |
| `[Label]` | LabelDecoration |
| `[LabelField]` | LabelField |
| `[Picture]` | PictureDecoration |
| `[PicField]` | PictureField |
| `[Calendar]` | CalendarField |
| `[Table]` | Table |
| `[Button]` | Button |
| `[CmdBar]` | CommandBar |
| `[Pages]` | Pages |
| `[Page]` | Page (shows item count instead of expanding) |
| `[Popup]` | Popup |
| `[BtnGroup]` | ButtonGroup |

**Flags** (only when deviating from default):
- `[visible:false]` — element is hidden (Visible=false)
- `[enabled:false]` — element is disabled (Enabled=false)
- `[ro]` — ReadOnly=true
- `,collapse` — Behavior=Collapsible (for groups)

**Data binding**: `-> Object.Field` — DataPath

**Command binding**: `-> CommandName [cmd]` — form command, `-> Close [std]` — standard command

**Events**: `{OnChange, StartChoice}` — handler names

**Title**: `[title:Text]` — only if different from element name

### Attributes — Form Attributes

```
Attributes:
  *Object: DocumentObject.SalesInvoice (main)
  Currency: CatalogRef.Currencies
  Total: decimal(15,2)
  Table: ValueTable [Product: CatalogRef.Products, Qty: decimal(10,3)]
  List: DynamicList -> Catalog.Users
```

- `*` and `(main)` — main form attribute (MainAttribute)
- ValueTable/ValueTree types expand columns in `[...]`
- DynamicList shows MainTable via `->`

### Parameters — Form Parameters

```
Parameters:
  Key: DocumentRef.PurchaseOrder (key)
  Basis: DocumentRef.*
```

- `(key)` — key parameter (KeyParameter)

### Commands — Form Commands

```
Commands:
  Print -> PrintDocumentHandler [Ctrl+P]
  Fill -> FillHandler
```

Format: `Name -> Handler [Shortcut]`

## What Gets Skipped

The script removes 80%+ of XML volume:
- Visual properties (Width, Height, Color, Font, Border, Align, Stretch)
- Auto-generated ExtendedTooltip and ContextMenu
- Multilingual wrappers (v8:item/v8:lang/v8:content)
- Namespace declarations
- ID attributes

For detailed inspection — use grep on element name from the summary.

## When to Use

- **Before modifying a form**: understand structure, find the right group for inserting an element
- **Form analysis**: which attributes, commands, handlers are used
- **Navigating large forms**: 28K lines of XML → 50-100 lines of context

## Overflow Protection

Output is limited to 150 lines by default. When exceeded:
```
[TRUNCATED] Shown 150 of 220 lines. Use -Offset 150 to continue.
```

Use `-Offset N` and `-Limit N` for paginated viewing.
