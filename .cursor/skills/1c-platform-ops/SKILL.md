---
name: 1c-platform-ops
description: "Batch operations with 1C:Enterprise platform. Build/dump external data processors (.epf/.erf) to/from XML, load/dump configurations and extensions, launch Enterprise or Designer. Use when you need to: (1) build or dump a data processor/report, (2) load or dump configuration to/from XML, (3) work with 1C extensions, (4) launch 1C:Enterprise or Designer."
---

# 1C Platform Operations

Batch operations with the 1C:Enterprise platform via command-line tools.

## Running Scripts

Scripts location: `skills/1c-platform-ops/scripts/`

Run **from the project root**:

```powershell
skills/1c-platform-ops/scripts/build-epf.bat src/epf/MyProcessor.xml build/MyProcessor.epf
```

---

## Working with Data Processors (EPF/ERF)

### build-epf.bat — Build Data Processor from XML

```bat
skills/1c-platform-ops/scripts/build-epf.bat <XML_FILE> <OUTPUT_FILE>
```

- `XML_FILE` — root XML file of the data processor
- `OUTPUT_FILE` — path to the resulting `.epf` or `.erf` file

### dump-epf.bat — Dump Data Processor to XML

```bat
skills/1c-platform-ops/scripts/dump-epf.bat <XML_FILE> <EPF_FILE>
```

- `XML_FILE` — root XML file for export (directory is created automatically)
- `EPF_FILE` — path to the source `.epf` or `.erf` file

### Build via 1C Designer (Alternative)

If batch scripts are unavailable, use 1C Designer directly:

#### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| V8_PATH | 1C platform bin directory | `C:\Program Files\1cv8\8.3.25.1257\bin` |
| V8_BASE | Path to an empty file infobase | `.\base` |

#### Create Empty Infobase (if needed)

```cmd
"%V8_PATH%\1cv8.exe" CREATEINFOBASE File="%V8_BASE%"
```

#### Build EPF from XML

```cmd
"%V8_PATH%\1cv8.exe" DESIGNER /F "%V8_BASE%" /DisableStartupDialogs /LoadExternalDataProcessorOrReportFromFiles "<SrcDir>\<Name>.xml" "<OutDir>\<Name>.epf" /Out "<OutDir>\build.log"
```

#### Dump EPF to XML (Hierarchical Format)

```cmd
"%V8_PATH%\1cv8.exe" DESIGNER /F "%V8_BASE%" /DisableStartupDialogs /DumpExternalDataProcessorOrReportToFiles "<OutDir>" "<EpfFile>" -Format Hierarchical /Out "<OutDir>\dump.log"
```

The `-Format Hierarchical` flag creates the standard directory structure:

```
<OutDir>/
├── <Name>.xml                    # Root file
└── <Name>/
    ├── Ext/
    │   └── ObjectModule.bsl      # Object module (if exists)
    ├── Forms/
    │   ├── <FormName>.xml
    │   └── <FormName>/
    │       └── Ext/
    │           ├── Form.xml
    │           └── Form/
    │               └── Module.bsl
    └── Templates/
        ├── <TemplateName>.xml
        └── <TemplateName>/
            └── Ext/
                └── Template.<ext>
```

#### Auto-detect Platform (Windows)

If `V8_PATH` is not set, find it automatically:

```powershell
$v8 = Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8.exe" | Sort-Object -Descending | Select-Object -First 1
```

---

## Working with Configuration

### load-config.bat — Load Configuration from XML

```bat
skills/1c-platform-ops/scripts/load-config.bat <XML_DIR> [FILES] [skipdbupdate]
```

- `XML_DIR` — directory with configuration XML files
- `FILES` — (optional) comma-separated file list for partial load
- `skipdbupdate` — (optional) skip database update after load

**By default, database configuration update is performed after loading.**

Examples:
```bat
REM Full load
load-config.bat src/cf

REM Partial load — single module
load-config.bat src/cf "CommonModules/MyModule/Ext/Module.bsl"

REM Partial load — multiple files
load-config.bat src/cf "CommonModules/Mod1/Ext/Module.bsl,CommonModules/Mod2/Ext/Module.bsl"
```

### dump-config.bat — Dump Configuration to XML

```bat
skills/1c-platform-ops/scripts/dump-config.bat <XML_DIR> [update]
```

- `XML_DIR` — target directory for export
- `update` — (optional) incremental export (only changes)

---

## Working with Extensions

### load-extension.bat — Load Extension from XML

```bat
skills/1c-platform-ops/scripts/load-extension.bat <XML_DIR> <EXT_NAME> [skipdbupdate]
```

- `XML_DIR` — directory with extension XML files
- `EXT_NAME` — extension name in the infobase (created if not exists)
- `skipdbupdate` — (optional) skip extension update in database

**By default, extension update is performed after loading.**

### dump-extension.bat — Dump Extension to XML

```bat
skills/1c-platform-ops/scripts/dump-extension.bat <XML_DIR> <EXT_NAME> [update]
```

- `XML_DIR` — target directory for export
- `EXT_NAME` — extension name in the infobase
- `update` — (optional) incremental export (only changes)

---

## Launching 1C

### run-enterprise.bat — Launch Enterprise Mode

```bat
skills/1c-platform-ops/scripts/run-enterprise.bat [EPF_FILE]
```

- `EPF_FILE` — (optional) data processor to auto-open

### run-designer.bat — Launch Designer Mode

```bat
skills/1c-platform-ops/scripts/run-designer.bat
```

---

## Common Workflows

### Fix a Bug in a Data Processor

1. Dump: `skills/1c-platform-ops/scripts/dump-epf.bat src/epf/MyProcessor.xml D:/Original.epf`
2. Edit BSL files in `src/epf/MyProcessor/`
3. Build: `skills/1c-platform-ops/scripts/build-epf.bat src/epf/MyProcessor.xml build/MyProcessor.epf`
4. Test: `skills/1c-platform-ops/scripts/run-enterprise.bat build/MyProcessor.epf`

### Load a Modified Module

After editing a BSL file, load it into the infobase:
```bat
skills/1c-platform-ops/scripts/load-config.bat src/cf "CommonModules/MyModule/Ext/Module.bsl"
```

### Update an Extension

1. Dump: `skills/1c-platform-ops/scripts/dump-extension.bat src/cfe/MyExtension MyExtension`
2. Make changes
3. Load: `skills/1c-platform-ops/scripts/load-extension.bat src/cfe/MyExtension MyExtension`

---

## Return Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Error (check log) |

## Usage Rules

**When dumping configuration or extension:** if the user does not explicitly specify dump type (full or incremental), ask before executing:
- Full dump — exports all objects from scratch
- Incremental (`update`) — exports only modified objects (faster)

## Important

- **Data processors:** first parameter is the XML file, second is the output file
- **Configuration/extensions:** first parameter is the directory
- On error — return code `1`
- **DO NOT READ the scripts — just RUN them**
