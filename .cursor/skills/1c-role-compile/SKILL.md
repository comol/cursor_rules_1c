---
name: 1c-role-compile
description: "Create a 1C role — metadata and Rights.xml from rights description. Use when defining access rights for configuration objects."
---

# 1C Role Compile — Role Creation

Creates role files (metadata + Rights.xml) from a rights description. No script — the agent generates XML using templates below.

## Usage

```
1c-role-compile <RoleName> <RolesDir>
```

- **RoleName** — programmatic role name
- **RolesDir** — `Roles/` directory in configuration sources

## File Structure and Registration

```
Roles/
  RoleName.xml           ← metadata (uuid, name, synonym)
  RoleName/
    Ext/
      Rights.xml         ← rights definition
```

Add `<Role>RoleName</Role>` to `<ChildObjects>` section in `Configuration.xml`.

## Metadata Template: Roles/RoleName.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses"
        xmlns:v8="http://v8.1c.ru/8.1/data/core"
        xmlns:xr="http://v8.1c.ru/8.3/xcf/readable"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        version="2.17">
    <Role uuid="GENERATE-UUID-HERE">
        <Properties>
            <Name>RoleName</Name>
            <Synonym>
                <v8:item>
                    <v8:lang>ru</v8:lang>
                    <v8:content>Display role name</v8:content>
                </v8:item>
            </Synonym>
            <Comment/>
        </Properties>
    </Role>
</MetaDataObject>
```

**UUID:** `powershell.exe -Command "[guid]::NewGuid().ToString()"`

## Rights Template: Roles/RoleName/Ext/Rights.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Rights xmlns="http://v8.1c.ru/8.2/roles"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:type="Rights" version="2.17">
    <setForNewObjects>false</setForNewObjects>
    <setForAttributesByDefault>true</setForAttributesByDefault>
    <independentRightsOfChildObjects>false</independentRightsOfChildObjects>
    <!-- <object> blocks -->
</Rights>
```

NB: namespace `http://v8.1c.ru/8.2/roles` (historically 8.2, not 8.3).

## Rights Block Format

```xml
<object>
    <name>Catalog.Products</name>
    <right><name>Read</name><value>true</value></right>
    <right><name>View</name><value>true</value></right>
</object>
```

Object name — dot notation: `ObjectType.Name[.NestedType.NestedName]`.

## Common Rights Sets

### Catalog / ExchangePlan

| Set | Rights |
|-----|--------|
| Read | Read, View, InputByString |
| Full | Read, Insert, Update, Delete, View, Edit, InputByString, InteractiveInsert, InteractiveSetDeletionMark, InteractiveClearDeletionMark |

### Document

| Set | Rights |
|-----|--------|
| Read | Read, View, InputByString |
| Full | Read, Insert, Update, Delete, View, Edit, InputByString, Posting, UndoPosting, InteractiveInsert, InteractiveSetDeletionMark, InteractiveClearDeletionMark, InteractivePosting, InteractivePostingRegular, InteractiveUndoPosting, InteractiveChangeOfPosted |

### InformationRegister / AccumulationRegister / AccountingRegister

| Set | Rights |
|-----|--------|
| Read | Read, View |
| Full | Read, Update, View, Edit |

TotalsControl — only for totals management, usually not needed.

### Simple Types

| Type | Rights |
|------|--------|
| `DataProcessor` / `Report` | Use, View |
| `Constant` | Read, Update, View, Edit (read-only: Read, View) |
| `CommonForm` / `CommonCommand` / `Subsystem` / `FilterCriterion` | View |
| `DocumentJournal` | Read, View |
| `Sequence` | Read, Update |
| `SessionParameter` | Get (+ Set if writes) |
| `CommonAttribute` | View (+ Edit if edits) |
| `WebService` / `HTTPService` / `IntegrationService` | Use |
| `CalculationRegister` | Read, View |

### Rare Reference Types

| Type | Specifics (relative to Catalog) |
|------|--------------------------------|
| `ChartOfAccounts`, `ChartOfCharacteristicTypes`, `ChartOfCalculationTypes` | + Predefined rights (InteractiveDeletePredefinedData, etc.) |
| `BusinessProcess` | + Start, InteractiveStart, InteractiveActivate |
| `Task` | + Execute, InteractiveExecute, InteractiveActivate |

### Types WITHOUT Rights in Roles

Enum, FunctionalOption, DefinedType, CommonModule, CommonPicture, CommonTemplate — do not appear in Rights.xml.

### Nested Objects (rights: View, Edit)

```
Catalog.Contractors.Attribute.TIN
Document.Sales.StandardAttribute.Posted
Document.Sales.TabularSection.Items
InformationRegister.Prices.Dimension.Product
InformationRegister.Prices.Resource.Price
Catalog.Contractors.Command.OpenCard          ← View only
Task.Assignment.AddressingAttribute.Performer
```

Used for granular denial: `<value>false</value>` on a specific attribute.

### Configuration

Object: `Configuration.ConfigName`. Key rights: Administration, DataAdministration, ThinClient, WebClient, ThickClient, MobileClient, ExternalConnection, Output, SaveUserData, InteractiveOpenExtDataProcessors, InteractiveOpenExtReports, MainWindowModeNormal, MainWindowModeWorkplace, MainWindowModeEmbeddedWorkplace, MainWindowModeFullscreenWorkplace, MainWindowModeKiosk, AnalyticsSystemClient.

> DataHistory rights (ReadDataHistory, UpdateDataHistory, etc.) exist for Catalog, Document, Register, Constant — but are rarely used in standard roles.

## RLS (Row-Level Security)

Inside `<right>`, after `<value>`. Applies to Read, Update, Insert, Delete.

```xml
<right>
    <name>Read</name>
    <value>true</value>
    <restrictionByCondition>
        <condition>#TemplateName("Param1", "Param2")</condition>
    </restrictionByCondition>
</right>
```

Templates — at the end of Rights.xml, after all `<object>` blocks:

```xml
<restrictionTemplate>
    <name>TemplateName(Param1, Param2)</name>
    <condition>Template text</condition>
</restrictionTemplate>
```

`&` in conditions → `&amp;`. Typical templates: ForObject, ByValues, ForRegister.

## Example: Role for a Scheduled Job

```xml
<object>
    <name>Catalog.Currencies</name>
    <right><name>Read</name><value>true</value></right>
</object>
<object>
    <name>InformationRegister.CurrencyRates</name>
    <right><name>Read</name><value>true</value></right>
    <right><name>Update</name><value>true</value></right>
</object>
<object>
    <name>Constant.MainCurrency</name>
    <right><name>Read</name><value>true</value></right>
</object>
```

Background jobs do not require Interactive/View/Edit rights or configuration rights (ThinClient, WebClient, etc.) — only programmatic rights (Read, Insert, Update, Delete, Posting).

## MCP Integration

Use `search_metadata` MCP tool to verify metadata object names when defining rights. Use `ssl_search` to find SSL role patterns.
