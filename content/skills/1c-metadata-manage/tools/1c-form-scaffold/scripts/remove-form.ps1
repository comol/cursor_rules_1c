# form-remove v1.4 — Remove form from 1C object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills, pinned at
#         ecd289fe11733028d87b55284ea9fb5feff8f513.
# Licence: MIT, Copyright (c) 2025-2026 Nick Shirokov. Full notice and permission
#          text: ../../../NOTICE.md (installed as skills/1c-metadata-manage/NOTICE.md).
# Local: hardening on top of upstream v1.4, kept in step with remove-form.py —
#        1C-identifier validation and path containment, the -DryRun / -Force gate,
#        and a bounded transaction whose deletions are reversible renames into a
#        quarantine on the same filesystem.
param(
	[Parameter(Mandatory)]
	[Alias("ProcessorName")]
	[string]$ObjectName,

	[Parameter(Mandatory)]
	[string]$FormName,

	[string]$SrcDir = "src",

	[switch]$DryRun,

	[switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$QuarantineName = ".remove-form-quarantine"

# A 1C metadata identifier: a Latin or Cyrillic letter or underscore, then letters,
# digits and underscores, up to the platform's 128-character limit. An allowlist on
# purpose - it rejects path separators, "..", drive letters, UNC prefixes, trailing
# dots and spaces (which Windows silently strips) and look-alike letters from other
# scripts. Same expression as remove-form.py.
$IdentifierRe = "^[A-Za-z_А-яЁё][0-9A-Za-z_А-яЁё]{0,127}$"

function Deny([string]$Message, [int]$Code) {
	# Write-Error under $ErrorActionPreference = "Stop" raises a terminating error and
	# always exits 1, so a documented exit code would never be reached. Write to
	# stderr directly instead.
	[Console]::Error.WriteLine($Message)
	exit $Code
}

function Assert-Identifier([string]$Value, [string]$What) {
	if ($Value -cnotmatch $IdentifierRe) {
		Deny "Недопустимое имя ${What}: '$Value'. Ожидается идентификатор 1С (латиница или кириллица, цифры и подчёркивание, не начинается с цифры, до 128 символов)." 2
	}
}

function Test-LinkOrReparse([string]$Path) {
	$item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
	if (-not $item) { return $false }
	return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Resolve-Full([string]$Path) {
	# Join-Path would produce "C:\cwd\C:bs" for an already-rooted path, which
	# GetFullPath rejects outright.
	if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
	return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Assert-Inside([string]$Path, [string]$Parent, [string]$What) {
	$realParent = (Resolve-Full $Parent).TrimEnd('\', '/')
	$real = Resolve-Full $Path
	if ((Split-Path $real -Parent) -ne $realParent) {
		Deny "Путь $What выходит за пределы каталога ${realParent}: $real. Операция отклонена." 2
	}
	if ((Test-Path -LiteralPath $Path) -and (Test-LinkOrReparse $Path)) {
		Deny "Путь $What является символической ссылкой / точкой повторной обработки: $Path. Удаление отклонено — проверьте выгрузку вручную." 2
	}
}

# --- Input validation: before a single path is built ---

Assert-Identifier $ObjectName "объекта (-ObjectName)"
Assert-Identifier $FormName "формы (-FormName)"

# --- Проверки ---

$rootXmlPath = Join-Path $SrcDir "$ObjectName.xml"
if (-not (Test-Path $rootXmlPath)) {
	Deny "Корневой файл обработки не найден: $rootXmlPath" 1
}

$processorDir = Join-Path $SrcDir $ObjectName
$formsDir = Join-Path $processorDir "Forms"
$formMetaPath = Join-Path $formsDir "$FormName.xml"
$formDir = Join-Path $formsDir $FormName

Assert-Inside $rootXmlPath $SrcDir "корневого XML"
Assert-Inside $formsDir $processorDir "каталога Forms"
Assert-Inside $formMetaPath $formsDir "метаданных формы"
Assert-Inside $formDir $formsDir "каталога формы"

if (-not (Test-Path $formMetaPath)) {
	Deny "Метаданные формы не найдены: $formMetaPath" 1
}

# --- Preflight: parse and modify XML in memory before deleting anything ---

$rootXmlFull = Resolve-Path $rootXmlPath
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.PreserveWhitespace = $true
$xmlDoc.Load($rootXmlFull.Path)

$nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
$nsMgr.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")

# Удалить <Form>FormName</Form> из ChildObjects
$formNodes = $xmlDoc.SelectNodes("//md:ChildObjects/md:Form", $nsMgr)
$formNodeFound = $false
foreach ($node in $formNodes) {
	if ($node.InnerText -eq $FormName) {
		$formNodeFound = $true
		$parent = $node.ParentNode
		# Удалить предшествующий whitespace
		$prev = $node.PreviousSibling
		if ($prev -and $prev.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
			$parent.RemoveChild($prev) | Out-Null
		}
		$parent.RemoveChild($node) | Out-Null
		break
	}
}
if (-not $formNodeFound) {
	Deny "Form is not registered in ChildObjects: $FormName" 1
}

# Clear every Default*/Auxiliary* form slot that points to this form. form-add writes
# the slot matching the form purpose (DefaultObjectForm / DefaultListForm /
# DefaultChoiceForm / DefaultRecordForm / DefaultForm), so matching on the generic
# DefaultForm alone would leave a dangling reference to a deleted form.
$clearedDefaultProperties = @()
$formRefRe = "Form\.$([regex]::Escape($FormName))$"
foreach ($node in $xmlDoc.SelectNodes("//md:*", $nsMgr)) {
	if ($node.LocalName -like "*Form" -and $node.InnerText -and $node.InnerText -match $formRefRe) {
		$node.InnerText = ""
		$clearedDefaultProperties += $node.LocalName
	}
}

# --- Safety gate ---

Write-Host "Planned changes:"
Write-Host "  modify: $rootXmlPath (remove ChildObjects/Form '$FormName')"
foreach ($propertyName in $clearedDefaultProperties) {
	Write-Host "  modify: $rootXmlPath (clear $propertyName)"
}
Write-Host "  delete: $formMetaPath"
if (Test-Path $formDir) { Write-Host "  delete: $formDir (recursive)" }

if ($DryRun) {
	Write-Host "[DRY-RUN] No files changed."
	exit 0
}
if (-not $Force) {
	Deny "Removal requires explicit -Force. Run with -DryRun first to review the plan." 2
}

# --- Mutation: one bounded transaction, rolled back as a whole on any failure ---
#
# Deletions are renames into a quarantine directory on the same filesystem, so every
# step is reversible and none can stop half-way. The quarantine is discarded only
# after the whole transaction has committed.

$quarantine = Join-Path (Resolve-Full $SrcDir) $QuarantineName
if (Test-Path -LiteralPath $quarantine) {
	Deny "Найден каталог карантина от прерванного запуска: $quarantine. Проверьте его содержимое и удалите вручную, затем повторите операцию." 2
}

$formDirExisted = Test-Path $formDir
$formDirTarget = Resolve-Full $formDir
$metaTarget = Resolve-Full $formMetaPath
$rootTarget = $rootXmlFull.Path
$backup = Join-Path $quarantine "root-backup.xml"
$parkedDir = Join-Path $quarantine "form-dir"
$parkedMeta = Join-Path $quarantine "form-meta.xml"

$undo = New-Object System.Collections.ArrayList
New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
[void]$undo.Add(@{ What = "remove quarantine"; Action = { Remove-Item -LiteralPath $quarantine -Recurse -Force } })

try {
	Copy-Item -LiteralPath $rootTarget -Destination $backup -Force
	[void]$undo.Add(@{ What = "restore $rootTarget"; Action = { Copy-Item -LiteralPath $backup -Destination $rootTarget -Force } })

	if ($formDirExisted) {
		[System.IO.Directory]::Move($formDirTarget, $parkedDir)
		[void]$undo.Add(@{ What = "put back $formDirTarget"; Action = { [System.IO.Directory]::Move($parkedDir, $formDirTarget) } })
	}

	[System.IO.File]::Move($metaTarget, $parkedMeta)
	[void]$undo.Add(@{ What = "put back $metaTarget"; Action = { [System.IO.File]::Move($parkedMeta, $metaTarget) } })

	# Serialize into the quarantine first, then swap the file in atomically.
	$encBom = New-Object System.Text.UTF8Encoding($true)
	$settings = New-Object System.Xml.XmlWriterSettings
	$settings.Encoding = $encBom
	$settings.Indent = $false
	$staged = Join-Path $quarantine "root-new.xml"
	$stream = New-Object System.IO.FileStream($staged, [System.IO.FileMode]::Create)
	$writer = [System.Xml.XmlWriter]::Create($stream, $settings)
	try { $xmlDoc.Save($writer) } finally { $writer.Close(); $stream.Close() }
	Move-Item -LiteralPath $staged -Destination $rootTarget -Force
}
catch {
	$failure = $_.Exception.Message
	$problems = @()
	for ($i = $undo.Count - 1; $i -ge 0; $i--) {
		try { & $undo[$i].Action } catch { $problems += "$($undo[$i].What): $($_.Exception.Message)" }
	}
	[Console]::Error.WriteLine("[error] Операция прервана: $failure")
	if ($problems.Count -gt 0) {
		[Console]::Error.WriteLine("[error] Откат (rollback) выполнен не полностью — восстановите вручную из ${quarantine}:")
		foreach ($problem in $problems) { [Console]::Error.WriteLine("  - $problem") }
	}
	else {
		[Console]::Error.WriteLine("[error] Откат (rollback) выполнен, дерево исходников не изменено.")
	}
	exit 1
}

try {
	Remove-Item -LiteralPath $quarantine -Recurse -Force
}
catch {
	[Console]::Error.WriteLine("[error] Форма удалена, но каталог карантина не удалён ($($_.Exception.Message)). Удалите вручную: $quarantine")
	exit 1
}

if ($formDirExisted) {
	Write-Host "[OK] Removed directory: $formDir"
}
Write-Host "[OK] Removed file: $formMetaPath"
Write-Host "[OK] Form $FormName removed from $rootXmlPath"
