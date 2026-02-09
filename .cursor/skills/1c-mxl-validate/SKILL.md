---
name: 1c-mxl-validate
description: "Validate structural correctness of a 1C spreadsheet document (MXL/Template.xml). Use after generating or editing layouts to check for structural errors that 1C may silently ignore."
---

# 1C MXL Validate — Layout Validator

Checks Template.xml for structural errors that the 1C platform may silently ignore (potentially causing data loss or layout corruption).

## Usage

```
1c-mxl-validate <TemplatePath>
1c-mxl-validate <ProcessorName> <TemplateName>
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| TemplatePath | no | — | Direct path to Template.xml |
| ProcessorName | no | — | Processor name (alternative to path) |
| TemplateName | no | — | Template name (alternative to path) |
| SrcDir | no | `src` | Source directory |
| MaxErrors | no | 20 | Stop after N errors |

Specify either `-TemplatePath`, or both `-ProcessorName` and `-TemplateName`.

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-mxl-validate/scripts/mxl-validate.ps1 -TemplatePath "<path>"
```

Or by processor/template name:
```powershell
powershell.exe -NoProfile -File skills/1c-mxl-validate/scripts/mxl-validate.ps1 -ProcessorName "<Name>" -TemplateName "<Template>" [-SrcDir "<dir>"]
```

## Checks Performed

| # | Check | Severity |
|---|-------|----------|
| 1 | `<height>` >= max row index + 1 | ERROR |
| 2 | `<vgRows>` <= `<height>` | WARN |
| 3 | Cell format indices (`<f>`) within format palette | ERROR |
| 4 | Row/column `<formatIndex>` within palette | ERROR |
| 5 | Cell column indices (`<i>`) within column count (accounting for column set) | ERROR |
| 6 | Row `<columnsID>` references existing column set | ERROR |
| 7 | Merge/namedItem `<columnsID>` references existing set | ERROR |
| 8 | Named area ranges within document boundaries | ERROR |
| 9 | Merge ranges within document boundaries | ERROR |
| 10 | Font indices in formats within font palette | ERROR |
| 11 | Border line indices in formats within line palette | ERROR |
| 12 | Drawing `pictureIndex` references existing picture | ERROR |

## Output

```
=== Validation: TemplateName ===

[OK]    height (40) >= max row index + 1 (40), rowsItem count=34
[OK]    Font refs: max=3, palette size=4
[ERROR] Row 15: cell format index 38 > format palette size (37)
[OK]    Column indices: max in default set=32, default column count=33
---
Errors: 1, Warnings: 0
```

Return code: 0 = all checks passed, 1 = errors found.

## When to Use

- **After layout generation**: run validator to find structural errors before building
- **After editing Template.xml**: ensure indices and references remain valid
- **When debugging**: fix found issues and re-run until all checks pass

## Overflow Protection

Stops after 20 errors by default (configurable via `-MaxErrors`). Summary line with error/warning counts is always shown.
