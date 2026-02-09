---
name: 1c-form-scaffold
description: "Create or remove a managed form for any 1C object (DataProcessor, Document, Catalog, InformationRegister, etc.). Use when adding a new form or removing an existing form from any 1C metadata object."
---

# 1C Form Scaffold — Create/Remove Managed Forms

Creates a managed form (metadata XML + Form.xml + Module.bsl) and registers it in the root XML of a 1C metadata object. Supports all object types: DataProcessor, Document, Catalog, InformationRegister, and more. Also supports form removal.

## Adding a Form

### For Configuration Objects

```
1c-form-scaffold add <ObjectPath> <FormName> [Purpose] [Synonym] [--set-default]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ObjectPath | yes | — | Path to object XML file (e.g., `Documents/Doc.xml`) |
| FormName | yes | — | Form name |
| Purpose | no | Object | Purpose: Object, List, Choice, Record |
| Synonym | no | = FormName | Form synonym |
| --set-default | no | auto | Set as default form |

**Command:**
```powershell
powershell.exe -NoProfile -File skills/1c-form-scaffold/scripts/form-add.ps1 -ObjectPath "<ObjectPath>" -FormName "<FormName>" [-Purpose "<Purpose>"] [-Synonym "<Synonym>"] [-SetDefault]
```

### For External Data Processors (EPF)

```
1c-form-scaffold add-epf <ProcessorName> <FormName> [Synonym] [--main]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ProcessorName | yes | — | Processor name (must exist) |
| FormName | yes | — | Form name |
| Synonym | no | = FormName | Form synonym |
| --main | no | auto | Set as default form (auto for first form) |
| SrcDir | no | `src` | Source directory |

**Command:**
```powershell
pwsh -NoProfile -File skills/1c-form-scaffold/scripts/add-form.ps1 -ProcessorName "<ProcessorName>" -FormName "<FormName>" [-Synonym "<Synonym>"] [-Main] [-SrcDir "<SrcDir>"]
```

### Purpose — Form Assignment

| Purpose | Allowed Object Types | Main Attribute | DefaultForm Property |
|---------|---------------------|---------------|---------------------|
| Object | Document, Catalog, DataProcessor, Report, ChartOf*, ExchangePlan, BusinessProcess, Task | Object (type: *Object.Name) | DefaultObjectForm (DefaultForm for DataProcessor/Report) |
| List | All except DataProcessor | List (DynamicList) | DefaultListForm |
| Choice | Document, Catalog, ChartOf*, ExchangePlan, BusinessProcess, Task | List (DynamicList) | DefaultChoiceForm |
| Record | InformationRegister | Record (InformationRegisterRecordManager) | DefaultRecordForm |

### What Gets Created

```
<ObjectDir>/Forms/
├── <FormName>.xml                    # Form metadata (UUID)
└── <FormName>/
    └── Ext/
        ├── Form.xml                  # Form description (logform namespace)
        └── Form/
            └── Module.bsl           # BSL module with 5 regions + OnCreateAtServer
```

### What Gets Modified

- `<ObjectPath>` — adds `<Form>` to `ChildObjects` (before `<Template>` or `<TabularSection>`), updates Default*Form (auto if empty, or explicit with `--set-default`)

### Details

- FormType: Managed
- UsePurposes: PlatformApplication, MobilePlatformApplication
- AutoCommandBar with id=-1
- "Object" attribute with MainAttribute=true
- BSL module contains 5 regions: FormEventHandlers, FormItemEventHandlers, FormCommandHandlers, NotificationHandlers, PrivateProceduresAndFunctions

### Supported Object Types

Document, Catalog, DataProcessor, Report, InformationRegister, ChartOfAccounts, ChartOfCharacteristicTypes, ExchangePlan, BusinessProcess, Task

---

## Removing a Form

### From Configuration Objects

Remove form files and unregister from the object's root XML.

### From External Data Processors (EPF)

```
1c-form-scaffold remove-epf <ProcessorName> <FormName>
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ProcessorName | yes | — | Processor name |
| FormName | yes | — | Form name to remove |
| SrcDir | no | `src` | Source directory |

**Command:**
```powershell
pwsh -NoProfile -File skills/1c-form-scaffold/scripts/remove-form.ps1 -ProcessorName "<ProcessorName>" -FormName "<FormName>" [-SrcDir "<SrcDir>"]
```

### What Gets Removed

```
<SrcDir>/<ProcessorName>/Forms/<FormName>.xml     # Form metadata
<SrcDir>/<ProcessorName>/Forms/<FormName>/         # Form directory (recursive)
```

### What Gets Modified

- `<SrcDir>/<ProcessorName>.xml` — removes `<Form>` from `ChildObjects`
- If removed form was DefaultForm — clears DefaultForm value

---

## Examples

```bash
# Document form
1c-form-scaffold add Documents/SalesOrder.xml DocumentForm --purpose Object

# Catalog list form
1c-form-scaffold add Catalogs/Contractors.xml ListForm --purpose List

# Information register record form
1c-form-scaffold add InformationRegisters/CurrencyRates.xml RecordForm --purpose Record

# Choice form with synonym
1c-form-scaffold add Catalogs/Products.xml ChoiceForm --purpose Choice --synonym "Product Selection"

# Set as default form
1c-form-scaffold add Documents/Order.xml NewDocumentForm --purpose Object --set-default

# EPF form
1c-form-scaffold add-epf MyProcessor MainForm "Main Form" --main

# Remove EPF form
1c-form-scaffold remove-epf MyProcessor OldForm
```

## Workflow

1. `1c-form-scaffold` — create form skeleton
2. `1c-form-compile` or `1c-form-edit` — populate Form.xml with elements
3. `1c-form-validate` — verify correctness
4. `1c-form-info` — analyze the result

## MCP Integration

Use `search_metadata` MCP tool to verify metadata object existence and structure before creating forms. Use `templatesearch` to find similar form implementations in the codebase.
