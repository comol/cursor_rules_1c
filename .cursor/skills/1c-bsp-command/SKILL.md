---
name: 1c-bsp-command
description: "Add a command to an SSL/BSP-registered data processor. Use when adding new commands to ExternalDataProcessorInfo() in the object module."
---

# 1C BSP Command — Add SSL Command

Adds a command to an existing `ExternalDataProcessorInfo()` function and generates the corresponding handler.

The data processor must be initialized with BSP registration first (see `1c-bsp-registration` skill).

## Usage

```
1c-bsp-command <ProcessorName> <Identifier> [CommandType] [Presentation]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ProcessorName | yes | — | Processor name |
| Identifier | yes | — | Internal command name (Latin characters) |
| CommandType | no | from processor kind | Command launch type (see mapping below) |
| Presentation | no | = Identifier | Display name for the user |
| SrcDir | no | `src` | Source directory |

## Command Type Mapping

User may specify type in free form:

| User Input | Command Type |
|------------|-------------|
| open form, form | `CommandTypeOpenForm()` |
| client method, on client | `CommandTypeClientMethodCall()` |
| server method, on server | `CommandTypeServerMethodCall()` |
| form filling, fill form | `CommandTypeFormFilling()` |
| scenario, safe mode | `CommandTypeScenarioInSafeMode()` |

If user does not specify — determine from processor kind in existing `ExternalDataProcessorInfo()` code:

| Processor Kind (from code) | Default Command Type |
|---------------------------|---------------------|
| AdditionalDataProcessor | `CommandTypeOpenForm()` |
| AdditionalReport | `CommandTypeOpenForm()` |
| ObjectFilling | `CommandTypeServerMethodCall()` |
| Report | `CommandTypeOpenForm()` |
| PrintForm | `CommandTypeServerMethodCall()` |
| RelatedObjectCreation | `CommandTypeServerMethodCall()` |

## Command Addition Template

Insert in `ExternalDataProcessorInfo()` **before** the `Return RegistrationParameters` line:

```bsl
	NewCommand = RegistrationParameters.Commands.Add();
	NewCommand.Presentation        = NStr("en = '{{Presentation}}'");
	NewCommand.ID                  = "{{Identifier}}";
	NewCommand.Use                 = AdditionalReportsAndDataProcessorsClientServer.{{CommandType}};
	NewCommand.ShowNotification    = False;
```

For print forms (ProcessorKindPrintForm) also add:

```bsl
	NewCommand.Modifier = "PrintMXL";
```

Note: unlike the first command (from `1c-bsp-registration`), additional commands use string literals `NStr("en = '...'")` for presentation and a string for ID, not `Metadata()`.

## Handler Templates

### ServerMethodCall — handler already exists

If `ExecuteCommand` procedure already exists in the object module, add a branch before `EndIf`:

```bsl
	ElsIf CommandID = "{{Identifier}}" Then
		// TODO: Implementation {{Identifier}}
```

### ServerMethodCall — no handler yet

For global processors (without `TargetObjects`):

```bsl
Procedure ExecuteCommand(CommandID, CommandExecutionParameters) Export

	If CommandID = "{{Identifier}}" Then
		// TODO: Implementation {{Identifier}}
	EndIf;

EndProcedure
```

For assignable processors (with `TargetObjects`):

```bsl
Procedure ExecuteCommand(CommandID, TargetObjects, CommandExecutionParameters) Export

	If CommandID = "{{Identifier}}" Then
		// TODO: Implementation {{Identifier}}
	EndIf;

EndProcedure
```

### PrintForm — Print procedure already exists

Add block before `EndProcedure`:

```bsl
	PrintForm = PrintManagement.PrintFormInfo(PrintFormsCollection, "{{Identifier}}");
	If PrintForm <> Undefined Then
		PrintForm.SpreadsheetDocument = Generate{{Identifier}}(ObjectsArray, PrintObjects);
		PrintForm.TemplateSynonym = NStr("en = '{{Presentation}}'");
	EndIf;
```

### PrintForm — no Print procedure yet

```bsl
Procedure Print(ObjectsArray, PrintFormsCollection, PrintObjects, OutputParameters) Export

	PrintForm = PrintManagement.PrintFormInfo(PrintFormsCollection, "{{Identifier}}");
	If PrintForm <> Undefined Then
		PrintForm.SpreadsheetDocument = Generate{{Identifier}}(ObjectsArray, PrintObjects);
		PrintForm.TemplateSynonym = NStr("en = '{{Presentation}}'");
	EndIf;

EndProcedure
```

### ClientMethodCall

Added to **form module** (`Forms/<FormName>/Ext/Form/Module.bsl`):

For global processors:

```bsl
&AtClient
Procedure ExecuteCommand(CommandID) Export

	If CommandID = "{{Identifier}}" Then
		// TODO: Implementation {{Identifier}}
	EndIf;

EndProcedure
```

For assignable processors:

```bsl
&AtClient
Procedure ExecuteCommand(CommandID, TargetObjectsArray) Export

	If CommandID = "{{Identifier}}" Then
		// TODO: Implementation {{Identifier}}
	EndIf;

EndProcedure
```

If procedure already exists — add `ElsIf` branch.

## Instructions

1. Find and read `ObjectModule.bsl` via Glob: `src/{{ProcessorName}}/Ext/ObjectModule.bsl`
2. Ensure `ExternalDataProcessorInfo()` exists. If not — suggest using `1c-bsp-registration` skill first
3. Determine processor kind from existing code (find the line with `ProcessorKind...()`)
4. Insert command block **before** `Return RegistrationParameters`
5. Add handler:
   - For server handlers — in `ObjectModule.bsl`, `PublicInterface` region
   - For client handlers — in form module (find via Glob: `src/{{ProcessorName}}/Forms/*/Ext/Form/Module.bsl`)
6. If handler (`ExecuteCommand` / `Print`) already exists — add branch, do not duplicate the procedure
7. Use tabs for indentation

## MCP Integration

Use `ssl_search` MCP tool to verify SSL method names. Use `codesearch` to find existing handler patterns in the codebase.
