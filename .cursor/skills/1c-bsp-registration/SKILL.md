---
name: 1c-bsp-registration
description: "Add SSL/BSP registration function (ExternalDataProcessorInfo) to a data processor object module. Use when registering an external data processor or report with the Additional Reports and Data Processors SSL subsystem."
---

# 1C BSP Registration — SSL Integration for Data Processors

Adds the `ExternalDataProcessorInfo()` function to the object module, required for registering external data processors/reports in the SSL "Additional Reports and Data Processors" subsystem.

## Usage

```
1c-bsp-registration <ProcessorName> <Kind> [TargetObjects...]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ProcessorName | yes | — | Processor name (must be created via `1c-epf-scaffold`) |
| Kind | yes | — | Processor kind (see mapping below) |
| TargetObjects | * | — | Metadata objects for assignable kinds |
| SrcDir | no | `src` | Source directory |

\* TargetObjects is required for assignable kinds: ObjectFilling, Report, PrintForm, RelatedObjectCreation.

## Kind Mapping

User may specify kind in free form. Determine the correct one from context:

| User Input | Kind | API Method |
|------------|------|------------|
| additional processor, global | AdditionalDataProcessor | `ProcessorKindAdditionalDataProcessor()` |
| additional report, global report | AdditionalReport | `ProcessorKindAdditionalReport()` |
| filling, fill | ObjectFilling | `ProcessorKindObjectFilling()` |
| report (assignable, for object) | Report | `ProcessorKindReport()` |
| print form, printing | PrintForm | `ProcessorKindPrintForm()` |
| related object creation | RelatedObjectCreation | `ProcessorKindRelatedObjectCreation()` |

## Default Command Type by Kind

| Kind | Default Command Type |
|------|---------------------|
| AdditionalDataProcessor | `CommandTypeOpenForm()` |
| AdditionalReport | `CommandTypeOpenForm()` |
| ObjectFilling | `CommandTypeServerMethodCall()` |
| Report | `CommandTypeOpenForm()` |
| PrintForm | `CommandTypeServerMethodCall()` |
| RelatedObjectCreation | `CommandTypeServerMethodCall()` |

## Template: ExternalDataProcessorInfo

Base template — same for all kinds, only API method calls and conditional sections differ.

```bsl
Function ExternalDataProcessorInfo() Export

	ProcessorMetadata = Metadata();

	RegistrationParameters = AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.2.2.1");
	RegistrationParameters.Kind    = AdditionalReportsAndDataProcessorsClientServer.{{ProcessorKind}};
	RegistrationParameters.Version = "1.0";

	{{TARGET_SECTION}}

	NewCommand = RegistrationParameters.Commands.Add();
	NewCommand.Presentation        = ProcessorMetadata.Presentation();
	NewCommand.ID                  = ProcessorMetadata.Name;
	NewCommand.Use                 = AdditionalReportsAndDataProcessorsClientServer.{{CommandType}};
	NewCommand.ShowNotification    = False;
	{{MODIFIER_SECTION}}

	Return RegistrationParameters;

EndFunction
```

### Substitutions

- `{{ProcessorKind}}` — API method from kind mapping table
- `{{CommandType}}` — API method from default command type table

### Conditional Sections

**`{{TARGET_SECTION}}`** — only for assignable kinds (ObjectFilling, Report, PrintForm, RelatedObjectCreation). One line per object:

```bsl
	RegistrationParameters.Purpose.Add("Document.SalesInvoice");
```

Object name format: `MetadataClassName.ObjectName` (e.g., `Document.SalesInvoice`, `Catalog.Contractors`).

For global kinds (AdditionalDataProcessor, AdditionalReport) — remove section with empty line.

**`{{MODIFIER_SECTION}}`** — only for PrintForm:

```bsl
	NewCommand.Modifier = "PrintMXL";
```

For other kinds — remove with empty line.

## Server Handler Templates

For kinds with `ServerMethodCall` command type, add the corresponding handler procedure in the same `PublicInterface` region, after `ExternalDataProcessorInfo`.

### For ObjectFilling / RelatedObjectCreation

```bsl
Procedure ExecuteCommand(CommandID, TargetObjects, CommandExecutionParameters) Export

	// TODO: Implementation

EndProcedure
```

### For PrintForm

```bsl
Procedure Print(ObjectsArray, PrintFormsCollection, PrintObjects, OutputParameters) Export

	// TODO: Implementation

EndProcedure
```

### For AdditionalDataProcessor / AdditionalReport (with ServerMethodCall)

If user explicitly chose server method instead of opening form:

```bsl
Procedure ExecuteCommand(CommandID, CommandExecutionParameters) Export

	// TODO: Implementation

EndProcedure
```

Note: global processors do not have the `TargetObjects` parameter.

## Instructions

1. Find `ObjectModule.bsl` via Glob: `src/{{ProcessorName}}/Ext/ObjectModule.bsl`
2. Read the file
3. If `ExternalDataProcessorInfo` already exists — inform user, do not duplicate
4. If file not found — suggest using `1c-epf-scaffold` skill first
5. Find the region `#Region PublicInterface` ... `#EndRegion`
6. Insert `ExternalDataProcessorInfo()` function inside this region
7. If kind requires server handler — insert it too, after the function
8. Use tabs for indentation (match existing file style)

## Example

User: "Register MyProcessor as a print form for Document.SalesInvoice"

Result in `ObjectModule.bsl`:

```bsl
#Region VariableDeclarations

#EndRegion

#Region PublicInterface

Function ExternalDataProcessorInfo() Export

	ProcessorMetadata = Metadata();

	RegistrationParameters = AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.2.2.1");
	RegistrationParameters.Kind    = AdditionalReportsAndDataProcessorsClientServer.ProcessorKindPrintForm();
	RegistrationParameters.Version = "1.0";

	RegistrationParameters.Purpose.Add("Document.SalesInvoice");

	NewCommand = RegistrationParameters.Commands.Add();
	NewCommand.Presentation        = ProcessorMetadata.Presentation();
	NewCommand.ID                  = ProcessorMetadata.Name;
	NewCommand.Use                 = AdditionalReportsAndDataProcessorsClientServer.CommandTypeServerMethodCall();
	NewCommand.ShowNotification    = False;
	NewCommand.Modifier = "PrintMXL";

	Return RegistrationParameters;

EndFunction

Procedure Print(ObjectsArray, PrintFormsCollection, PrintObjects, OutputParameters) Export

	// TODO: Implementation

EndProcedure

#EndRegion

#Region PrivateProceduresAndFunctions

#EndRegion
```

## Next Steps

- Add more commands: `1c-bsp-command` skill
- Add a form: `1c-form-scaffold` skill
- Add a template: `1c-template-manage` skill
- Build EPF: `1c-platform-ops` skill

## MCP Integration

Use `ssl_search` MCP tool to find SSL module methods for BSP registration and verify correct API method names. Use `search_metadata` to verify target metadata object names.
