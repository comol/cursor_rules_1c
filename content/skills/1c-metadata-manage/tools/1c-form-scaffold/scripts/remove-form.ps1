# form-remove v1.4 — Remove form from 1C object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills
# Local: preflight parse + -DryRun / -Force safety gate on top of upstream v1.4.
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

# --- Проверки ---

$rootXmlPath = Join-Path $SrcDir "$ObjectName.xml"
if (-not (Test-Path $rootXmlPath)) {
	Write-Error "Корневой файл обработки не найден: $rootXmlPath"
	exit 1
}

$processorDir = Join-Path $SrcDir $ObjectName
$formsDir = Join-Path $processorDir "Forms"
$formMetaPath = Join-Path $formsDir "$FormName.xml"
$formDir = Join-Path $formsDir $FormName

if (-not (Test-Path $formMetaPath)) {
	Write-Error "Метаданные формы не найдены: $formMetaPath"
	exit 1
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
	Write-Error "Form is not registered in ChildObjects: $FormName"
	exit 1
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
	# Write-Error under $ErrorActionPreference = "Stop" raises a terminating error,
	# so the documented "exit 2" was never reached and the refusal surfaced as exit 1.
	# Write to stderr directly, like the support guard of the sibling tools does.
	[Console]::Error.WriteLine("Removal requires explicit -Force. Run with -DryRun first to review the plan.")
	exit 2
}

# Serialize to a temporary file first. If XML generation fails, the source tree
# remains untouched. Commit the root registration change before deleting files.
$encBom = New-Object System.Text.UTF8Encoding($true)
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = $encBom
$settings.Indent = $false

$tempRootXml = $rootXmlFull.Path + ".remove-form.tmp"
$stream = New-Object System.IO.FileStream($tempRootXml, [System.IO.FileMode]::Create)
$writer = [System.Xml.XmlWriter]::Create($stream, $settings)
try {
	$xmlDoc.Save($writer)
}
finally {
	$writer.Close()
	$stream.Close()
}
Move-Item -Path $tempRootXml -Destination $rootXmlFull.Path -Force

if (Test-Path $formDir) {
	Remove-Item -Path $formDir -Recurse -Force
	Write-Host "[OK] Removed directory: $formDir"
}
Remove-Item -Path $formMetaPath -Force
Write-Host "[OK] Removed file: $formMetaPath"
Write-Host "[OK] Form $FormName removed from $rootXmlPath"
