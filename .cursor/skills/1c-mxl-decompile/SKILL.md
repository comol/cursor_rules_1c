---
name: 1c-mxl-decompile
description: "Decompile a 1C spreadsheet document (MXL/Template.xml) into a JSON definition. Reverse operation of 1c-mxl-compile. Use when analyzing or modifying existing layouts."
---

# 1C MXL Decompile — Layout Decompiler to DSL

Takes a Template.xml of a 1C spreadsheet document and generates a compact JSON definition (DSL). Reverse operation of `1c-mxl-compile`.

## Usage

```
1c-mxl-decompile <TemplatePath> [OutputPath]
```

| Parameter | Required | Description |
|-----------|:--------:|-------------|
| TemplatePath | yes | Path to Template.xml |
| OutputPath | no | Path for JSON output (if not specified — stdout) |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-mxl-decompile/scripts/mxl-decompile.ps1 -TemplatePath "<path>/Template.xml" [-OutputPath "<path>.json"]
```

## Workflow

Decompiling an existing layout for analysis or modification:

1. Run `1c-mxl-decompile` to get JSON from Template.xml
2. Analyze or modify JSON (add areas, change styles)
3. Run `1c-mxl-compile` to generate new Template.xml
4. Run `1c-mxl-validate` to verify

## JSON DSL Schema

Full format specification: **`docs/mxl-dsl-spec.md`** (read via Read tool).

## Name Generation

The script automatically generates meaningful names:

- **Fonts**: `default`, `bold`, `header`, `small`, `italic` — or descriptive names by properties
- **Styles**: `bordered`, `bordered-center`, `bold-right`, `border-top`, etc. — by property combination

## rowStyle Detection

If a row has empty cells (no parameters/text) and all of them share the same format — that format is recognized as `rowStyle`, and empty cells are excluded from output.

## MCP Integration

Use `search_metadata` MCP tool to find template paths in the configuration. Use `1c-mxl-info` skill to analyze layout structure before decompiling.
