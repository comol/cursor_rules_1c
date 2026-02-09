---
name: 1c-role-info
description: "Compact summary of 1C role rights from Rights.xml — objects, rights, RLS, restriction templates. Use to analyze existing roles before modification or review."
---

# 1C Role Info — Role Rights Analyzer

Parses a role's `Rights.xml` and outputs a compact summary: objects grouped by type, showing only allowed rights. Compression: thousands of XML lines → 50–150 lines of text.

## Usage

```
1c-role-info <RightsPath>
```

**RightsPath** — path to the role's `Rights.xml` file (typically `Roles/RoleName/Ext/Rights.xml`).

## Command

```powershell
powershell.exe -File skills/1c-role-info/scripts/role-info.ps1 -RightsPath <path> -OutFile <output.txt>
```

### Parameters

| Parameter | Required | Description |
|-----------|:--------:|-------------|
| `-RightsPath` | yes | Path to Rights.xml |
| `-ShowDenied` | no | Show denied rights (hidden by default) |
| `-Limit` | no | Max output lines (default `150`). `0` = unlimited |
| `-Offset` | no | Skip N lines — for pagination (default `0`) |
| `-OutFile` | no | Write result to file (UTF-8 BOM). Without this — console output |

**Important:** Always use `-OutFile` and read result via Read tool. Direct console output may corrupt Cyrillic characters.

For large roles with truncated output:
```powershell
... -Offset 150            # pagination: skip first 150 lines
```

## Output Format

```
=== Role: BasicRightsBP --- "Basic Rights: Enterprise Accounting" ===

Properties: setForNewObjects=false, setForAttributesByDefault=true, independentRightsOfChildObjects=false

Allowed rights:

  Catalog (8):
    Contractors: Read, View, InputByString
    Banks: Read, View, InputByString
    ...

  Document (12):
    SalesInvoice: Read, View, Posting, InteractivePosting
    ...

  InformationRegister (6):
    ProductPrices: Read [RLS], Update
    ...

Denied: 18 rights (use -ShowDenied to list)

RLS: 4 restrictions
Templates: ForRegister, ByValues

---
Total: 138 allowed, 18 denied

[TRUNCATED] Shown 150 of 220 lines. Use -Offset 150 to continue.
```

Use `-Offset N` and `-Limit N` for paginated viewing.

### Notation

- `[RLS]` — right with row-level security restriction (restrictionByCondition)
- `-View`, `-Edit` — denied rights (in Denied section, with `-ShowDenied`)
- Nested objects shown with suffix: `Contractors.StandardAttribute.PredefinedDataName`
