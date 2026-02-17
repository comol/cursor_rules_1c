# 1C SKD Manage — Compile, Edit, Info, Validate

Comprehensive Data Composition Schema (DCS/SKD) management: create from JSON, modify existing schemas, analyze structure, validate correctness.

---
## 1. Compile — Create from JSON

Takes a JSON definition of a Data Composition Schema and generates Template.xml (DataCompositionSchema).

### Parameters and Command

| Parameter | Description |
|-----------|-------------|
| `DefinitionFile` | Path to JSON definition file (mutually exclusive with Value) |
| `Value` | JSON string with DCS definition (mutually exclusive with DefinitionFile) |
| `OutputPath` | Path to output Template.xml |

```powershell
# From file
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-skd-compile/scripts/skd-compile.ps1 -DefinitionFile "<json>" -OutputPath "<Template.xml>"

# From string (no intermediate file)
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-skd-compile/scripts/skd-compile.ps1 -Value '<json-string>' -OutputPath "<Template.xml>"
```

### JSON DSL — Quick Reference

Full specification is embedded below.

#### Root Structure

```json
{
  "dataSets": [...],
  "calculatedFields": [...],
  "totalFields": [...],
  "parameters": [...],
  "dataSetLinks": [...],
  "settingsVariants": [...]
}
```

Defaults: `dataSources` → auto `ИсточникДанных1/Local`; `settingsVariants` → auto "Основной" with details.

#### Data Sets

Type by key: `query` → DataSetQuery, `objectName` → DataSetObject, `items` → DataSetUnion.

```json
{ "name": "Продажи", "query": "ВЫБРАТЬ ...", "fields": [...] }
```

#### Fields — Shorthand

```
"Наименование"                              — just name
"Количество: decimal(15,2)"                  — name + type
"Организация: CatalogRef.Организации @dimension"  — + role
"Служебное: string #noFilter #noOrder"       — + restrictions
```

Types: `string`, `string(N)`, `decimal(D,F)`, `boolean`, `date`, `dateTime`, `CatalogRef.X`, `DocumentRef.X`, `EnumRef.X`, `StandardPeriod`. Reference types are emitted with inline namespace `d5p1:` (`http://v8.1c.ru/8.1/data/enterprise/current-config`). Building an EPF with reference types requires a database with the corresponding configuration.

**Type synonyms** (Russian and alternatives): `число` = decimal, `строка` = string, `булево` = boolean, `дата` = date, `датаВремя` = dateTime, `СтандартныйПериод` = StandardPeriod, `СправочникСсылка.X` = CatalogRef.X, `ДокументСсылка.X` = DocumentRef.X, `int`/`number` = decimal, `bool` = boolean. Case-insensitive.

Roles: `@dimension`, `@account`, `@balance`, `@period`.
Restrictions: `#noField`, `#noFilter`, `#noGroup`, `#noOrder`.

#### Totals (shorthand)

```json
"totalFields": ["Количество: Сумма", "Стоимость: Сумма(Кол * Цена)"]
```

#### Parameters (shorthand + @autoDates)

```json
"parameters": [
  "Период: StandardPeriod = LastMonth @autoDates"
]
```

`@autoDates` — automatically generates `ДатаНачала` and `ДатаОкончания` parameters with expressions `&Период.ДатаНачала` / `&Период.ДатаОкончания` and `availableAsField=false`. Replaces 5 lines with 1.

#### Filters — Shorthand

```json
"filter": [
  "Организация = _ @off @user",
  "Дата >= 2024-01-01T00:00:00",
  "Статус filled"
]
```

Format: `"Field operator value @flags"`. Value `_` = empty (placeholder). Flags: `@off` (use=false), `@user` (userSettingID=auto), `@quickAccess`, `@normal`, `@inaccessible`.

#### Structure — String Shorthand

```json
"structure": "Организация > details"
"structure": "Организация > Номенклатура > details"
```

`>` separates grouping levels. `details` (or `детали`) = detail records.

#### Settings Variants

```json
"settingsVariants": [{
  "name": "Основной",
  "settings": {
    "selection": ["Номенклатура", "Количество", "Auto"],
    "filter": ["Организация = _ @off @user"],
    "order": ["Количество desc", "Auto"],
    "conditionalAppearance": [
      {
        "filter": ["Просрочено = true"],
        "appearance": { "ЦветТекста": "style:ПросроченныеДанныеЦвет" },
        "presentation": "Highlight overdue",
        "viewMode": "Normal",
        "userSettingID": "auto"
      }
    ],
    "outputParameters": { "Заголовок": "My Report" },
    "dataParameters": ["Период = LastMonth @user"],
    "structure": "Организация > details"
  }
}]
```

### Examples

#### Minimal

```json
{
  "dataSets": [{
    "query": "ВЫБРАТЬ Номенклатура.Наименование КАК Наименование ИЗ Справочник.Номенклатура КАК Номенклатура",
    "fields": ["Наименование"]
  }]
}
```

#### With Resources, Parameters, and @autoDates

```json
{
  "dataSets": [{
    "query": "ВЫБРАТЬ Продажи.Номенклатура, Продажи.Количество, Продажи.Сумма ИЗ РегистрНакопления.Продажи КАК Продажи",
    "fields": ["Номенклатура: СправочникСсылка.Номенклатура @dimension", "Количество: число(15,3)", "Сумма: число(15,2)"]
  }],
  "totalFields": ["Количество: Сумма", "Сумма: Сумма"],
  "parameters": ["Период: СтандартныйПериод = LastMonth @autoDates"],
  "settingsVariants": [{
    "name": "Основной",
    "settings": {
      "selection": ["Номенклатура", "Количество", "Сумма", "Auto"],
      "filter": ["Организация = _ @off @user"],
      "dataParameters": ["Период = LastMonth @user"],
      "structure": "Организация > details"
    }
  }]
}
```

---
## 2. Edit — Modify Existing Schema

Atomic modification operations on an existing Data Composition Schema: add, remove, and modify fields, totals, filters, parameters, variant settings, structure management, query replacement.

### Parameters and Command

| Parameter | Description |
|-----------|-------------|
| `TemplatePath` | Path to Template.xml (or folder — auto-completes to Ext/Template.xml) |
| `Operation` | Operation (see list below) |
| `Value` | Operation value (shorthand string or query text) |
| `DataSet` | (opt.) Data set name (default: first) |
| `Variant` | (opt.) Settings variant name (default: first) |
| `NoSelection` | (opt.) Don't add field to variant selection |

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-skd-edit/scripts/skd-edit.ps1 -TemplatePath "<path>" -Operation <op> -Value "<value>"
```

### Batch Mode

Multiple values in one call via `;;` separator:

```powershell
-Operation add-field -Value "Цена: decimal(15,2) ;; Количество: decimal(15,3) ;; Сумма: decimal(15,2)"
```

Works for all operations except `set-query`, `set-structure`, and `add-dataSet`.

### Operations

#### add-field — Add Field to Data Set

Shorthand: `"Name [Title]: type @role #restriction"`.

#### add-total — Add Total

```
"Цена: Среднее"
"Стоимость: Сумма(Кол * Цена)"
```

#### add-calculated-field — Add Calculated Field

Shorthand: `"Name [Title]: type = Expression"`.

#### add-parameter — Add Parameter

```
"Период: StandardPeriod = LastMonth @autoDates"
```

#### add-filter — Add Filter to Variant

Shorthand: `"Field operator value @flags"`. Flags: `@off`, `@user`, `@quickAccess`, `@normal`, `@inaccessible`.

#### add-dataParameter — Add Data Parameter to Variant

Shorthand: `"Name [= value] @flags"`.

#### add-order — Add Sort Order

Shorthand: `"Field [desc]"`. Default is asc. `Auto` — auto element.

#### add-selection — Add Selection Element

#### add-dataSetLink — Add Data Set Link

Shorthand: `"Source > Target on SrcExpr = DstExpr [param Name]"`.

#### add-dataSet — Add Data Set

Shorthand: `"Name: QUERY_TEXT"` or `"QUERY_TEXT"` (auto-name). Does not support batch mode.

#### add-variant — Add Settings Variant

Shorthand: `"Name [Presentation]"`.

#### add-conditionalAppearance — Add Conditional Appearance

Shorthand: `"Parameter = value [when condition] [for Field1, Field2]"`.

#### set-query — Replace Query Text

Value = full query text. Does not support batch mode.

#### set-outputParameter — Set Output Parameter

```
"Заголовок = My Report"
```

#### set-structure — Set Variant Structure

Shorthand: `"Field1 > Field2 > details"`. Replaces entire structure. Does not support batch mode.

#### modify-field — Modify Existing Field

Same shorthand as `add-field`. Finds by dataPath, merges properties.

#### modify-filter / modify-dataParameter — Modify Existing Filter/Parameter

#### remove-* and clear-*

| Operation | Value | Action |
|-----------|-------|--------|
| `remove-field` | dataPath | Remove field from set + variant selection |
| `remove-total` | dataPath | Remove total |
| `remove-calculated-field` | dataPath | Remove calculated field + selection |
| `remove-parameter` | name | Remove parameter |
| `remove-filter` | field | Remove first filter with this field |
| `clear-selection` | `*` | Clear all selection elements |
| `clear-order` | `*` | Clear all order elements |
| `clear-filter` | `*` | Clear all filter elements |

---
## 3. Info — Analyze Structure

Reads a Template.xml Data Composition Schema (DCS) and outputs a compact summary. Replaces the need to read thousands of XML lines.

### Parameters and Command

| Parameter | Description |
|-----------|-------------|
| `TemplatePath` | Path to Template.xml or template directory (auto-resolves to `Ext/Template.xml`) |
| `Mode` | Analysis mode (default `overview`) |
| `Name` | Name of data set (query), field (fields/calculated/resources/trace), variant (variant), or grouping/field (templates) |
| `Batch` | Query batch number, 0 = all (query mode only) |
| `Limit` / `Offset` | Pagination (default 150 lines) |
| `OutFile` | Write result to file (UTF-8 BOM) |

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-skd-info/scripts/skd-info.ps1 -TemplatePath "<path>"
```

With mode specified:
```powershell
... -Mode query -Name DataSetName
... -Mode fields -Name FieldName
... -Mode trace -Name "Field Title"
... -Mode variant -Name 1
```

### Modes

| Mode | Without `-Name` | With `-Name` |
|------|-----------------|--------------|
| `overview` | Navigation map of the schema + Next hints | — |
| `query` | — | Query text of the data set (with batch index) |
| `fields` | Map: field names by data set | Field detail: set, type, role, format |
| `links` | All data set links | — |
| `calculated` | Map: calculated field names | Expression + title + restrictions |
| `resources` | Map: resource field names (`*` = group formulas) | Aggregation formulas by groupings |
| `params` | Parameters table: type, value, visibility | — |
| `variant` | Variant list | Grouping structure + filters + output |
| `templates` | Template binding map (field/group) | Template content: rows, cells, expressions |
| `trace` | — | Full chain: data set → calculation → resource |
| `full` | Full summary: overview + query + fields + resources + params + variant | — |

Pattern: without `-Name` — map/index, with `-Name` — detail of a specific element. `full` mode combines 6 key modes in one call.

Detailed output examples for each mode are in `skills/1c-metadata-manage/tools/1c-skd-info/modes-reference.md`.

---
## 4. Validate — Check Correctness

Checks structural correctness of a Template.xml Data Composition Schema. Detects format errors, broken references, duplicate names.

### Parameters and Command

| Parameter | Description |
|-----------|-------------|
| `TemplatePath` | Path to Template.xml or template directory (auto-resolves to `Ext/Template.xml`) |
| `MaxErrors` | Max errors before stopping (default 20) |
| `OutFile` | Write result to file |

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-skd-validate/scripts/skd-validate.ps1 -TemplatePath "<path>"
```

### Checks (~30)

| Group | What Is Checked |
|-------|-----------------|
| **Root** | XML parse, root element `DataCompositionSchema`, default namespace, ns prefixes |
| **DataSource** | Presence, name not empty, type valid (Local/External), name uniqueness |
| **DataSet** | Presence, xsi:type valid, name not empty, uniqueness, dataSource reference, query not empty |
| **Fields** | dataPath not empty, field not empty, dataPath uniqueness per set |
| **Links** | source/dest reference existing sets, expressions not empty |
| **CalcFields** | dataPath not empty, expression not empty, uniqueness, collisions with set fields |
| **TotalFields** | dataPath not empty, expression not empty |
| **Parameters** | name not empty, uniqueness |
| **Templates** | name not empty, uniqueness |
| **GroupTemplates** | template references existing template, templateType valid |
| **Variants** | Presence, name not empty, settings element present |
| **Settings** | selection/filter/order reference known fields, comparisonType valid, structure items typed |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No errors (warnings may exist) |
| 1 | Errors found |

---
## Typical Workflow

1. **Create new DCS**: `1c-skd-compile` from JSON → `1c-skd-validate` → `1c-skd-info` for visual summary
2. **Modify existing DCS**: `1c-skd-edit` with operations → `1c-skd-validate` → `1c-skd-info`
3. **Analyze structure**: `1c-skd-info` overview → `1c-skd-info -Mode trace -Name <field>` for field calculation chain → `1c-skd-info -Mode query -Name <dataset>` for query text → `1c-skd-info -Mode variant -Name <N>` for variant groupings and filters

---
## MCP Integration

- **search_metadata** — Verify object and attribute names used in queries; cross-reference field names with actual metadata objects
- **templatesearch** — Find similar DCS patterns in the codebase
- **docsearch** — Look up valid DCS element types and properties when investigating validation errors; DCS platform documentation

## SDD Integration

When creating or modifying DCS/SKD schemas as part of a feature, update SDD artifacts if present (see `rules/sdd-integrations.mdc` for detection):

- **OpenSpec**: Add spec deltas describing report requirements, data sets, and expected output in `openspec/changes/`.
- **Memory Bank**: Update `memory-bank/progress.md` with report/DCS creation status.
- **TaskMaster**: Call `set_task_status` after the DCS is created and validated.
