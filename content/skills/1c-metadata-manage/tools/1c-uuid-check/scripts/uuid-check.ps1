# uuid-check v1.0 — Detect (and optionally repair) duplicate UUIDs in a 1C XML configuration dump
# Ported from check_uuid_duplicates.py of https://github.com/Desko77/claude-code-skills-1c (MIT)
# and adapted to the Configurator XML format: `uuid="..."` attributes plus
# <xr:TypeId> / <xr:ValueId> elements inside <InternalInfo>.
param(
	[Parameter(Mandatory)]
	[Alias('Path')]
	[string]$ConfigPath,

	# Also report / repair duplicates that occur inside a single file.
	[switch]$IncludeIntra,

	# Regenerate every duplicate occurrence except the first. Read the warning
	# printed by the script before using this on sources already loaded into an infobase.
	[switch]$Fix,

	# File mask to scan. The Configurator dump is XML; EDT (*.mdo) is not supported by this ruleset.
	[string]$Filter = "*.xml",

	[int]$MaxReported = 50,

	[string]$OutFile
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Resolve path ---
if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
	$ConfigPath = Join-Path (Get-Location).Path $ConfigPath
}
if (-not (Test-Path $ConfigPath)) {
	Write-Host "[ERROR] Path not found: $ConfigPath"
	exit 1
}
$resolvedPath = (Resolve-Path $ConfigPath).Path

if (Test-Path $resolvedPath -PathType Container) {
	$baseDir = $resolvedPath
	$files = @(Get-ChildItem -LiteralPath $resolvedPath -Filter $Filter -File -Recurse)
} else {
	$baseDir = Split-Path $resolvedPath -Parent
	$files = @(Get-Item -LiteralPath $resolvedPath)
}

if ($files.Count -eq 0) {
	Write-Host "[ERROR] No files matching '$Filter' under: $resolvedPath"
	exit 1
}

# --- Output infrastructure ---
$script:output = New-Object System.Text.StringBuilder 8192
function Out-Line { param([string]$msg) $script:output.AppendLine($msg) | Out-Null }

function Get-RelativePath {
	param([string]$FullName)
	if ($FullName.StartsWith($baseDir, [System.StringComparison]::OrdinalIgnoreCase)) {
		return $FullName.Substring($baseDir.Length).TrimStart('\', '/')
	}
	return $FullName
}

# --- UUID extraction -------------------------------------------------------
# Two carriers in the Configurator XML dump:
#   attribute  uuid="xxxxxxxx-...."         — object / attribute / tabular-section identity
#   elements   <xr:TypeId>, <xr:ValueId>    — generated types inside <InternalInfo>
$guid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$uuidRegex = [regex]("(?:\b(?<attr>uuid)\s*=\s*""(?<gattr>" + $guid + ")"")" +
                     "|(?:<(?:\w+:)?(?<el>TypeId|ValueId)>\s*(?<gel>" + $guid + ")\s*<)")

function Read-FileText {
	# Returns the decoded text plus the encoding needed to write it back byte-identically.
	param([string]$FullName)
	$bytes = [System.IO.File]::ReadAllBytes($FullName)
	$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
	$encoding = New-Object System.Text.UTF8Encoding($hasBom)
	$start = 0
	if ($hasBom) { $start = 3 }
	$text = [System.Text.Encoding]::UTF8.GetString($bytes, $start, $bytes.Length - $start)
	return [pscustomobject]@{ Text = $text; Encoding = $encoding }
}

# Line numbers are resolved with a cursor that only moves forward: regex matches
# arrive in ascending index order, so one pass over the file text is enough.
# (A per-match scan from position 0 is O(text x matches) and stalls on a
# multi-megabyte Configuration.xml with thousands of generated types.)
function New-LineCursor {
	param([string]$Text)
	return [pscustomobject]@{ Text = $Text; Pos = 0; Line = 1 }
}

function Step-LineCursor {
	param($Cursor, [int]$Index)
	$text = $Cursor.Text
	for ($i = $Cursor.Pos; $i -lt $Index; $i++) {
		if ($text[$i] -eq "`n") { $Cursor.Line++ }
	}
	$Cursor.Pos = $Index
	return $Cursor.Line
}

$registry = @{}   # uuid (lower) -> list of occurrences
$scanned = 0

foreach ($file in $files) {
	$content = $null
	try {
		$content = Read-FileText -FullName $file.FullName
	} catch {
		Out-Line ("[WARN]  Cannot read " + (Get-RelativePath $file.FullName) + ": " + $_.Exception.Message)
		continue
	}
	$scanned++
	$cursor = New-LineCursor -Text $content.Text

	foreach ($m in $uuidRegex.Matches($content.Text)) {
		if ($m.Groups['gattr'].Success) {
			$group = $m.Groups['gattr']
			$carrier = 'uuid'
		} else {
			$group = $m.Groups['gel']
			$carrier = $m.Groups['el'].Value
		}
		$key = $group.Value.ToLowerInvariant()
		if (-not $registry.ContainsKey($key)) { $registry[$key] = New-Object System.Collections.ArrayList }
		[void]$registry[$key].Add([pscustomobject]@{
			File    = $file.FullName
			Index   = $group.Index
			Length  = $group.Length
			Carrier = $carrier
			Line    = (Step-LineCursor -Cursor $cursor -Index $group.Index)
		})
	}
}

# --- Classify duplicates ---------------------------------------------------
$crossFile = New-Object System.Collections.ArrayList
$intraFile = New-Object System.Collections.ArrayList

foreach ($key in ($registry.Keys | Sort-Object)) {
	$occurrences = $registry[$key]
	if ($occurrences.Count -lt 2) { continue }
	$distinctFiles = @($occurrences | Select-Object -ExpandProperty File -Unique)
	$entry = [pscustomobject]@{ Uuid = $key; Occurrences = $occurrences }
	if ($distinctFiles.Count -gt 1) { [void]$crossFile.Add($entry) } else { [void]$intraFile.Add($entry) }
}

$targets = New-Object System.Collections.ArrayList
foreach ($e in $crossFile) { [void]$targets.Add($e) }
if ($IncludeIntra) { foreach ($e in $intraFile) { [void]$targets.Add($e) } }

# --- Report ----------------------------------------------------------------
function Write-Group {
	param([string]$Title, $Entries)
	if ($Entries.Count -eq 0) { return }
	Out-Line ""
	Out-Line ("--- " + $Title + " ---")
	$shown = 0
	foreach ($entry in $Entries) {
		if ($shown -ge $MaxReported) {
			Out-Line ("    ... " + ($Entries.Count - $shown) + " more (raise -MaxReported to see them)")
			break
		}
		Out-Line ""
		Out-Line ("  UUID: " + $entry.Uuid)
		foreach ($occ in $entry.Occurrences) {
			Out-Line ("    " + (Get-RelativePath $occ.File) + ":" + $occ.Line + "  [" + $occ.Carrier + "]")
		}
		$shown++
	}
}

Out-Line ("Scanned files: " + $scanned + "  (mask '" + $Filter + "', root " + $resolvedPath + ")")

if ($targets.Count -eq 0) {
	Out-Line "[OK]    No duplicate UUIDs found."
	if (-not $IncludeIntra -and $intraFile.Count -gt 0) {
		Out-Line ("[WARN]  " + $intraFile.Count + " intra-file duplicate(s) suppressed. In the Configurator XML dump these are")
		Out-Line "        usually genuine collisions - re-run with -IncludeIntra to inspect them."
	}
} else {
	Out-Line ("[ERROR] Duplicate UUIDs: " + $targets.Count +
		" (cross-file: " + $crossFile.Count + ", intra-file: " + $(if ($IncludeIntra) { $intraFile.Count } else { 0 }) + ")")
	Write-Group -Title "CROSS-FILE DUPLICATES (two objects claim the same identity)" -Entries $crossFile
	if ($IncludeIntra) { Write-Group -Title "INTRA-FILE DUPLICATES" -Entries $intraFile }
	elseif ($intraFile.Count -gt 0) {
		Out-Line ""
		Out-Line ("[WARN]  " + $intraFile.Count + " intra-file duplicate(s) suppressed - re-run with -IncludeIntra to inspect them.")
	}
}

# --- Fix -------------------------------------------------------------------
$fixedCount = 0
if ($Fix -and $targets.Count -gt 0) {
	Out-Line ""
	Out-Line "--- REPAIR (first occurrence of each UUID is kept) ---"
	Out-Line "[WARN]  A UUID is an object's identity. Regenerating one on sources that were already"
	Out-Line "        loaded into an infobase makes the platform treat the object as a NEW object on the"
	Out-Line "        next load (the old data is orphaned). 'Keep the first occurrence' is positional,"
	Out-Line "        not semantic - verify which object is meant to keep the identity."
	Out-Line ""

	# Group replacements per file, apply from the end so earlier indices stay valid.
	$byFile = @{}
	foreach ($entry in $targets) {
		$rest = @($entry.Occurrences | Select-Object -Skip 1)
		foreach ($occ in $rest) {
			if (-not $byFile.ContainsKey($occ.File)) { $byFile[$occ.File] = New-Object System.Collections.ArrayList }
			[void]$byFile[$occ.File].Add([pscustomobject]@{
				Index = $occ.Index; Length = $occ.Length; Line = $occ.Line
				Carrier = $occ.Carrier; Old = $entry.Uuid
			})
		}
	}

	foreach ($filePath in ($byFile.Keys | Sort-Object)) {
		$content = Read-FileText -FullName $filePath
		$builder = New-Object System.Text.StringBuilder $content.Text
		$replacements = @($byFile[$filePath] | Sort-Object -Property Index -Descending)
		foreach ($r in $replacements) {
			$new = [System.Guid]::NewGuid().ToString()
			$builder.Remove($r.Index, $r.Length) | Out-Null
			$builder.Insert($r.Index, $new) | Out-Null
			$fixedCount++
			Out-Line ("  " + (Get-RelativePath $filePath) + ":" + $r.Line + "  [" + $r.Carrier + "]  " + $r.Old + " -> " + $new)
		}
		[System.IO.File]::WriteAllText($filePath, $builder.ToString(), $content.Encoding)
	}

	Out-Line ""
	Out-Line ("Regenerated UUIDs: " + $fixedCount)
	Out-Line "[NOTE]  Re-run without -Fix to confirm the dump is clean, then validate the"
	Out-Line "        affected objects (meta-validate / cf-validate) before loading."
}

# --- Final output ----------------------------------------------------------
$text = $script:output.ToString()
if ($OutFile) {
	$dir = Split-Path $OutFile -Parent
	if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
	[System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding($false)))
	Write-Host "Report written to: $OutFile"
} else {
	Write-Host $text
}

if ($targets.Count -gt 0 -and -not $Fix) { exit 1 }
if ($Fix -and $fixedCount -gt 0) { exit 0 }
if ($targets.Count -gt 0) { exit 1 }
exit 0
