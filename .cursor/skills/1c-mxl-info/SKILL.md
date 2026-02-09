---
name: 1c-mxl-info
description: "Analyze 1C spreadsheet document (MXL/Template.xml) structure — areas, parameters, column sets. Use to understand layout structure before writing fill code or modifying templates."
---

# 1C MXL Info — Layout Structure Analyzer

Reads Template.xml of a spreadsheet document and outputs a compact summary: named areas, parameters, column sets. Replaces the need to read thousands of XML lines.

## Usage

```
1c-mxl-info <TemplatePath>
1c-mxl-info <ProcessorName> <TemplateName>
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| TemplatePath | no | — | Direct path to Template.xml |
| ProcessorName | no | — | Processor name (alternative to path) |
| TemplateName | no | — | Template name (alternative to path) |
| SrcDir | no | `src` | Source directory |
| Format | no | `text` | Output format: `text` or `json` |
| WithText | no | false | Include static text and templates |
| MaxParams | no | 10 | Max parameters per area in listing |
| Limit | no | 150 | Max output lines (overflow protection) |
| Offset | no | 0 | Skip N lines (for pagination) |

Specify either `-TemplatePath`, or both `-ProcessorName` and `-TemplateName`.

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-mxl-info/scripts/mxl-info.ps1 -TemplatePath "<path>"
```

Or by processor/template name:
```powershell
powershell.exe -NoProfile -File skills/1c-mxl-info/scripts/mxl-info.ps1 -ProcessorName "<Name>" -TemplateName "<Template>" [-SrcDir "<dir>"]
```

Additional flags:
```powershell
... -WithText              # include text cell content
... -Format json           # JSON output for programmatic processing
... -MaxParams 20          # show more parameters per area
... -Offset 150            # pagination: skip first 150 lines
```

## Reading the Output

### Areas — Sorted Top to Bottom

Areas are listed in document order (by row position), not alphabetically. This matches the area output order in fill code — top to bottom.

```
--- Named areas ---
  Header             Rows     rows 1-4     (1 params)
  Supplier           Rows     rows 5-6     (1 params)
  Row                Rows     rows 14-14   (8 params)
  Total              Rows     rows 16-17   (1 params)
```

Area types:
- **Rows** — horizontal area (row range). Access: `Template.GetArea("Name")`
- **Columns** — vertical area (column range). Access: `Template.GetArea("Name")`
- **Rectangle** — fixed area (rows + columns). Usually uses a separate column set.
- **Drawing** — named drawing/barcode.

### Column Sets

When the layout has multiple column sets, their sizes are shown in the header and per area:

```
  Column sets: 7 (default=19 cols + 6 additional)
    f01e015f...: 17 cols
    0adf41ed...: 4 cols
  ...
  Footer             Rows     rows 30-34  (5 params) [colset 14cols]
  PageNumbering      Rows     rows 59-59  (0 params) [colset 4cols]
```

### Intersections

When both Rows and Columns areas exist (labels, price tags), the script outputs intersection pairs:

```
--- Intersections (use with GetArea) ---
  LabelHeight|LabelWidth
```

In BSL: `Template.GetArea("LabelHeight|LabelWidth")`

### Parameters and detailParameter

Parameters are listed per area. If a parameter has a `detailParameter` (drill-down), it is shown below:

```
--- Parameters by area ---
  Supplier: SupplierPresentation
    detail: SupplierPresentation->Supplier
  Row: RowNumber, Product, Quantity, Price, Amount, ... (+3)
    detail: Product->Nomenclature
```

This means: parameter `Product` displays a value, and when clicked opens `Nomenclature` (drill-down object).

In BSL:
```bsl
Area.Parameters.Product = TableRow.Nomenclature;
Area.Parameters.ProductDrillDown = TableRow.Nomenclature; // detailParameter
```

### Template Parameters (suffix `[tpl]`)

Some parameters are embedded in template text: `"Inv No. [InventoryNumber]"`. They are filled via fillType=Template, not fillType=Parameter. The script always extracts them and marks with suffix `[tpl]`:

```
  PageNumbering: Number [tpl], Date [tpl], PageNumber [tpl]
```

In BSL, template parameters are filled the same way as regular ones:
```bsl
Area.Parameters.Number = DocumentNumber;
Area.Parameters.Date = DocumentDate;
```

Numeric substitutions like `[5]`, `[6]` (footnote references in official forms) are ignored.

### Text Content (`-WithText`)

Shows static text (labels, headers) and template strings with substitutions `[Parameter]`:

```
--- Text content ---
  TableHeader:
    Text: "No.", "Product", "Unit", "Qty", "Price", "Amount"
  Row:
    Templates: "Inv No. [InventoryNumber]"
```

- **Text** — static labels (fillType=Text). Useful for understanding column purposes.
- **Templates** — text with substitutions `[ParameterName]` (fillType=Template). Parameter inside `[]` is filled programmatically.

## When to Use

- **Before writing fill code**: run `1c-mxl-info` to understand area names and parameter lists, then write BSL output code following area order top to bottom
- **With `-WithText`**: when context is needed — column headers, labels near parameters, template strings
- **With `-Format json`**: when structured data is needed for programmatic processing
- **For existing layouts**: analyze loaded or configuration layouts without reading raw XML

## Overflow Protection

Output is limited to 150 lines by default. When exceeded:
```
[TRUNCATED] Shown 150 of 220 lines. Use -Offset 150 to continue.
```

Use `-Offset N` and `-Limit N` for paginated viewing.
