---
name: 1c-epf-scaffold
description: "Create a new empty 1C external data processor (scaffold XML sources). Use when initializing a new EPF/ERF project from scratch."
---

# 1C EPF Scaffold — New Data Processor Creation

Generates the minimal set of XML source files for a 1C external data processor: root metadata file and the processor directory structure.

## Usage

```
1c-epf-scaffold <Name> [Synonym] [SrcDir]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| Name | yes | — | Processor name (Latin/Cyrillic) |
| Synonym | no | = Name | Synonym (display name) |
| SrcDir | no | `src` | Source directory relative to CWD |

## Command

```powershell
pwsh -NoProfile -File skills/1c-epf-scaffold/scripts/init.ps1 -Name "<Name>" [-Synonym "<Synonym>"] [-SrcDir "<SrcDir>"]
```

## What Gets Created

```
<SrcDir>/
├── <Name>.xml          # Root metadata file (4 UUIDs)
└── <Name>/
    └── Ext/
        └── ObjectModule.bsl  # Object module with 3 regions
```

- Root XML contains `MetaDataObject/ExternalDataProcessor` with empty `DefaultForm` and `ChildObjects`
- ClassId is fixed: `c3831ec8-d8d5-4f93-8a22-f9bfae07327f`
- File is created in UTF-8 with BOM

## Next Steps

After scaffolding, use these skills to build out the processor:

- **Add a form**: `1c-form-scaffold` skill
- **Add a template/layout**: `1c-template-manage` skill
- **Register with SSL (BSP)**: `1c-bsp-registration` skill
- **Build EPF**: `1c-platform-ops` skill (build-epf command)

## MCP Integration

Use `search_metadata` MCP tool to verify metadata object names and types when setting up the processor for integration with existing configuration objects.
