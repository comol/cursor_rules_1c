#Requires -Version 5.1
<#
.SYNOPSIS
    Focused regression tests for the meta-edit / meta-compile tools of the
    1c-metadata-manage skill.

.DESCRIPTION
    Two defects are pinned here, both reported against rules_version 81cc1d5:

      A. meta-edit re-serialized the whole document through System.Xml.XmlWriter
         and wrote it back unconditionally. On a UTF-8 BOM + LF Configurator dump
         a one-attribute edit therefore produced unrelated formatting churn:
         `<Tag />` instead of Configurator's `<Tag/>`, CRLF mixed into an LF file
         (the script inserts "`r`n" whitespace nodes), and - on the rename /
         retype / synonym paths - two logically separate child elements glued
         onto one line, because InsertAfter + Remove-NodeWithWhitespace drops the
         *leading* whitespace of the replaced position.

      B. meta-compile always appended a newly registered object after the last
         element of its own type in Configuration.xml, and saved the file through
         the DOM - rewriting declaration case, self-closing form and EOL of a
         file it was only supposed to add one line to. There was no way to ask
         for the by-name order the platform standard (APK:1108) expects.

    Every case materializes a fixture into a temp directory with exact bytes
    (BOM + chosen EOL), runs the real tool script, and asserts on the raw bytes
    of the result. The fixtures under fixtures/ are stored LF-only; the runner
    applies the target EOL itself, so the tests are immune to the checkout EOL
    policy (core.autocrlf) of the machine they run on.

    NOTE: this file is deliberately pure ASCII, like tools/validate-rules.ps1 -
    Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI, which would mangle
    non-ASCII source characters. Every Cyrillic identifier the tests need is read
    from a fixture file instead of being written here.

.PARAMETER Filter
    Run only cases whose name matches this wildcard pattern.

.PARAMETER KeepWorkDir
    Do not delete the temp working directory - useful when a case fails.

.EXAMPLE
    powershell -NoProfile -File tools\tests\metadata-tools-regression.ps1
    powershell -NoProfile -File tools\tests\metadata-tools-regression.ps1 -Filter 'meta-edit*'
#>
[CmdletBinding()]
param(
    [string]$Filter = '*',
    [switch]$KeepWorkDir
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot    = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$FixturesDir = Join-Path $PSScriptRoot 'fixtures'
$ToolsDir    = Join-Path $RepoRoot 'content\skills\1c-metadata-manage\tools'
$MetaEdit    = Join-Path $ToolsDir '1c-meta-edit\scripts\meta-edit.ps1'
$MetaCompile = Join-Path $ToolsDir '1c-meta-compile\scripts\meta-compile.ps1'

foreach ($required in @($MetaEdit, $MetaCompile, (Join-Path $FixturesDir 'config-dump'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing prerequisite: $required" }
}

# ---------------------------------------------------------------- infrastructure

$script:Cases    = @()
$script:Failures = @()

function Register-Case([string]$Name, [scriptblock]$Body) {
    $script:Cases += [pscustomobject]@{ Name = $Name; Body = $Body }
}

function Fail([string]$Message) { throw [System.Exception]::new($Message) }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { Fail $Message }
}

function Assert-Equal($Expected, $Actual, [string]$What) {
    if ("$Expected" -ne "$Actual") { Fail "$What : expected [$Expected], got [$Actual]" }
}

# Reads a file as raw bytes and reports the byte-level properties the two defects
# are about. Deliberately byte-based: a String round-trip would hide BOM and EOL.
function Get-FileFacts([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $offset = if ($hasBom) { 3 } else { 0 }
    $text   = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset)
    $crlf   = ([regex]::Matches($text, "`r`n")).Count
    $allLf  = ([regex]::Matches($text, "`n")).Count
    return [pscustomobject]@{
        Path       = $Path
        Bom        = $hasBom
        Text       = $text
        Crlf       = $crlf
        Lf         = $allLf
        LoneLf     = $allLf - $crlf
        LooseClose = ([regex]::Matches($text, ' />')).Count
        Lines      = $text -split "`r`n|`n"
    }
}

# Materializes a fixture tree into $Dest with the requested EOL. Fixture sources are
# stored LF-only with a UTF-8 BOM; text files are rewritten here so the test controls
# the exact bytes the tool sees regardless of how git checked the fixture out.
function Copy-Fixture([string]$Name, [string]$Dest, [string]$Eol = "`n") {
    $src = Join-Path $FixturesDir $Name
    if (-not (Test-Path -LiteralPath $src)) { throw "Fixture not found: $src" }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    $bom = New-Object System.Text.UTF8Encoding($true)
    foreach ($file in (Get-ChildItem -LiteralPath $src -Recurse -File)) {
        $rel = $file.FullName.Substring($src.Length).TrimStart('\', '/')
        $out = Join-Path $Dest $rel
        New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force | Out-Null
        if ($file.Extension -eq '.bin') {
            # Support-state blob: copy byte-for-byte, it is not ours to restyle.
            Copy-Item -LiteralPath $file.FullName -Destination $out -Force
            continue
        }
        $facts = Get-FileFacts $file.FullName
        $text  = ($facts.Text -replace "`r`n", "`n")
        if ($Eol -ne "`n") { $text = $text -replace "`n", $Eol }
        [System.IO.File]::WriteAllText($out, $text, $bom)
    }
}

function Invoke-Tool([string]$Script, [string[]]$ToolArgs, [string]$WorkDir) {
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        # Start-Process joins -ArgumentList with plain spaces, so quote here: an unquoted
        # `-Value "Baza: synonym=X"` would reach the script as two tokens and the second
        # one would bind positionally to -DefinitionFile.
        $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Script`"")
        foreach ($a in $ToolArgs) {
            if ($a -match '\s') { $psArgs += "`"$a`"" } else { $psArgs += $a }
        }
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs `
            -WorkingDirectory $WorkDir -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut   = (Get-Content -LiteralPath $stdout -Raw -Encoding UTF8)
            StdErr   = (Get-Content -LiteralPath $stderr -Raw -Encoding UTF8)
        }
    } finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

# A Configurator-written line carries exactly one tag construct: an open tag, a close
# tag, an empty element, or an open/text/close triple. Anything else means two
# logically separate elements ended up glued onto one line - defect A's third symptom.
$script:WellFormedLine = [regex]'^[ \t]*(<\?[^<>]*\?>|<[^<>]+>[^<>]*</[^<>]+>|<[^<>]+/>|<[^<>]+>|</[^<>]+>)[ \t]*$'

function Assert-NoGluedTags($Facts, [string]$What) {
    $bad = @()
    for ($i = 0; $i -lt $Facts.Lines.Count; $i++) {
        $line = $Facts.Lines[$i]
        if ($line -eq '') { continue }
        if (-not $script:WellFormedLine.IsMatch($line)) { $bad += "line $($i + 1): $line" }
    }
    if ($bad.Count -gt 0) {
        Fail "$What : $($bad.Count) glued / malformed line(s):`n  " + ($bad -join "`n  ")
    }
}

function Assert-StyleKept($Before, $After, [string]$What, [string]$Eol = "`n") {
    Assert-True $After.Bom "$What : BOM lost"
    if ($Eol -eq "`n") {
        Assert-Equal 0 $After.Crlf "$What : CRLF introduced into an LF file"
    } else {
        Assert-Equal 0 $After.LoneLf "$What : lone LF introduced into a CRLF file"
        Assert-True ($After.Crlf -gt 0) "$What : CRLF file lost its CRLF"
    }
    Assert-Equal 0 $After.LooseClose "$What : Configurator writes <Tag/>, found <Tag />"
    Assert-NoGluedTags $After $What
}

# Line-level delta between two states of the same file. Returns added / removed line
# lists, so a case can assert "the diff is exactly the semantic change and nothing else".
function Get-LineDelta($Before, $After) {
    $beforeLines = @($Before.Lines)
    $afterLines  = @($After.Lines)
    $bag = @{}
    foreach ($l in $beforeLines) { if ($bag.ContainsKey($l)) { $bag[$l]++ } else { $bag[$l] = 1 } }
    $added = New-Object System.Collections.ArrayList
    foreach ($l in $afterLines) {
        if ($bag.ContainsKey($l) -and $bag[$l] -gt 0) { $bag[$l]-- } else { [void]$added.Add($l) }
    }
    $removed = New-Object System.Collections.ArrayList
    foreach ($key in $bag.Keys) { for ($i = 0; $i -lt $bag[$key]; $i++) { [void]$removed.Add($key) } }
    return [pscustomobject]@{ Added = $added.ToArray(); Removed = $removed.ToArray() }
}

# <ChildObjects> entries of a Configuration.xml in document order.
function Get-ChildObjectEntries([string]$Path) {
    $facts = Get-FileFacts $Path
    $block = [regex]::Match($facts.Text, '(?s)<ChildObjects\s*>(.*?)</ChildObjects>')
    if (-not $block.Success) { return @() }
    $entries = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches($block.Groups[1].Value, '<(\w+)>([^<]*)</\1>')) {
        [void]$entries.Add([pscustomobject]@{ Tag = $m.Groups[1].Value; Name = $m.Groups[2].Value })
    }
    return $entries.ToArray()
}

function Read-JsonFixture([string]$RelPath) {
    $path = Join-Path $FixturesDir $RelPath
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $offset = if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 }
    return ([System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset) | ConvertFrom-Json)
}

function Write-DevEnv([string]$Dir, [string]$Body) {
    [System.IO.File]::WriteAllText((Join-Path $Dir '.dev.env'), $Body, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- A. meta-edit

Register-Case 'meta-edit: add-attribute keeps BOM, LF and tight self-closing tags' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'add-attribute', '-Value', 'RegrFlag: Boolean', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    $after = Get-FileFacts $target
    Assert-StyleKept $before $after 'add-attribute'

    $delta = Get-LineDelta $before $after
    Assert-Equal 0 $delta.Removed.Count "add-attribute removed lines: $($delta.Removed -join ' | ')"
    Assert-True (($delta.Added | Where-Object { $_ -match '<Name>RegrFlag</Name>' }).Count -eq 1) 'added block does not carry the new attribute name'
    Assert-True (($delta.Added | Where-Object { $_ -notmatch '^\s*$' }).Count -eq $delta.Added.Count) 'blank lines added'
}

Register-Case 'meta-edit: add-attribute on a CRLF dump keeps CRLF' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`r`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target
    Assert-Equal 0 $before.LoneLf 'fixture was not materialized as CRLF'

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'add-attribute', '-Value', 'RegrFlag: Boolean', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    Assert-StyleKept $before (Get-FileFacts $target) 'add-attribute (CRLF)' "`r`n"
}

Register-Case 'meta-edit: remove-attribute leaves no glued or blank lines' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'remove-attribute', '-Value', 'Baza', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    $after = Get-FileFacts $target
    Assert-StyleKept $before $after 'remove-attribute'
    $delta = Get-LineDelta $before $after
    # Removing the first of two attributes must not pull its leading whitespace into the
    # sibling: the surviving <Attribute> has to keep starting a line of its own.
    Assert-Equal 0 $delta.Added.Count "remove-attribute added lines: $($delta.Added -join ' | ')"
    Assert-True (($delta.Removed | Where-Object { $_ -match '<Name>Baza</Name>' }).Count -eq 1) 'removed block does not contain the removed attribute'
    Assert-True ($after.Text -match '(?m)^\s*<Attribute uuid="[^"]+">\s*$') 'surviving <Attribute> no longer starts its own line'
    Assert-True ($after.Text -match '<Name>Vtoroy</Name>') 'the sibling attribute was removed too'
}

Register-Case 'meta-edit: modify-attribute synonym does not glue the replaced element' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'modify-attribute', '-Value', 'Baza: synonym=Regr synonym', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    $after = Get-FileFacts $target
    Assert-StyleKept $before $after 'modify-attribute synonym'
    # The element right before <Synonym> in the fixture is <Name>; gluing showed up as
    # `<Name>Baza</Name><Synonym>` on one line and one fewer line in the file.
    Assert-Equal $before.Lines.Count $after.Lines.Count 'synonym replacement changed the line count'
    Assert-True ($after.Text -match '(?m)^\s*<Synonym>\s*$') '<Synonym> no longer starts its own line'
}

Register-Case 'meta-edit: modify-attribute type does not glue the replaced element' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'modify-attribute', '-Value', 'Baza: type=Boolean', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    $after = Get-FileFacts $target
    Assert-StyleKept $before $after 'modify-attribute type'
    Assert-True ($after.Text -match '(?m)^\s*<Comment/>\s*$') '<Comment/> no longer stands on its own line'
    Assert-True ($after.Text -match '<v8:Type>xs:boolean</v8:Type>') 'type was not changed'
}

Register-Case 'meta-edit: rename keeps the auto-synonym block on its own lines' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'
    $before = Get-FileFacts $target

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'modify-attribute', '-Value', 'Baza: name=BazaNew', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"

    $after = Get-FileFacts $target
    Assert-StyleKept $before $after 'rename'
    Assert-Equal $before.Lines.Count $after.Lines.Count 'rename changed the line count'
    Assert-True ($after.Text -match '<Name>BazaNew</Name>') 'attribute was not renamed'
}

Register-Case 'meta-edit: downstream meta-validate invocation still runs' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $target = Join-Path $Work 'Catalogs\TestCatalog.xml'

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'add-attribute', '-Value', 'RegrFlag: Boolean') $Work
    Assert-Equal 0 $run.ExitCode "meta-edit exit code (stderr: $($run.StdErr))"
    Assert-True ($run.StdOut -match 'meta-validate') 'meta-validate was not invoked after the edit'
    Assert-StyleKept (Get-FileFacts $target) (Get-FileFacts $target) 'validated edit'
}

# ---------------------------------------------------------------- B. meta-compile

Register-Case 'meta-compile: default position appends after the last object of the type' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $configPath = Join-Path $Work 'Configuration.xml'
    $before  = Get-FileFacts $configPath
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    $enums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })
    Assert-Equal 3 $enums.Count 'enum entry count'
    Assert-Equal $newEnum $enums[2].Name 'default position must append after the last Enum'

    $after = Get-FileFacts $configPath
    Assert-StyleKept $before $after 'meta-compile default'
    Assert-True ($after.Text -match 'encoding="utf-8"') 'XML declaration was rewritten'
    $delta = Get-LineDelta $before $after
    Assert-Equal 0 $delta.Removed.Count "registration removed lines: $($delta.Removed -join ' | ')"
    Assert-Equal 1 $delta.Added.Count "registration must add exactly one line, added: $($delta.Added -join ' | ')"
}

Register-Case 'meta-compile: NEW_OBJECT_POSITION=byName inserts inside the type group' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    Write-DevEnv $Work "NEW_OBJECT_POSITION=byName`r`n"
    $configPath = Join-Path $Work 'Configuration.xml'
    $before  = Get-FileFacts $configPath
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name
    $baseEnums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    $enums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })
    Assert-Equal 3 $enums.Count 'enum entry count'
    Assert-Equal $baseEnums[0].Name $enums[0].Name 'first enum moved'
    Assert-Equal $newEnum          $enums[1].Name 'byName must place the new enum between the two existing ones'
    Assert-Equal $baseEnums[1].Name $enums[2].Name 'last enum moved'

    $after = Get-FileFacts $configPath
    Assert-StyleKept $before $after 'meta-compile byName'
    $delta = Get-LineDelta $before $after
    Assert-Equal 0 $delta.Removed.Count "registration removed lines: $($delta.Removed -join ' | ')"
    Assert-Equal 1 $delta.Added.Count "registration must add exactly one line, added: $($delta.Added -join ' | ')"
}

Register-Case 'meta-compile: NEW_OBJECT_POSITION=end is the backward-compatible default' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    Write-DevEnv $Work "NEW_OBJECT_POSITION=end`r`n"
    $configPath = Join-Path $Work 'Configuration.xml'
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    $enums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })
    Assert-Equal $newEnum $enums[2].Name 'explicit end must behave like the default'
}

Register-Case 'meta-compile: an invalid .dev.env value resolves to end, not to the fallback' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    # A typo in .dev.env must not hand the decision to .v8-project.json: the documented
    # contract is that .dev.env is authoritative and an unrecognized value means `end`.
    Write-DevEnv $Work "NEW_OBJECT_POSITION=by-name`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Work '.v8-project.json'), '{ "newObjectPosition": "byName" }', (New-Object System.Text.UTF8Encoding($false)))
    $configPath = Join-Path $Work 'Configuration.xml'
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    $enums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })
    Assert-Equal 3 $enums.Count 'enum entry count'
    Assert-Equal $newEnum $enums[2].Name 'invalid .dev.env value must fall back to end, not to .v8-project.json byName'
}

Register-Case 'meta-compile: a missing .dev.env key still honours the .v8-project.json fallback' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    # Key absent entirely (not merely invalid): the vendored upstream registry stays in force.
    Write-DevEnv $Work "SUPPORT_GUARD=`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Work '.v8-project.json'), '{ "newObjectPosition": "byName" }', (New-Object System.Text.UTF8Encoding($false)))
    $configPath = Join-Path $Work 'Configuration.xml'
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    $enums = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Tag -eq 'Enum' })
    Assert-Equal $newEnum $enums[1].Name 'missing .dev.env key must leave the .v8-project.json fallback in charge'
}

Register-Case 'meta-compile: a brand-new type group lands in canonical type order' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    $configPath = Join-Path $Work 'Configuration.xml'
    $before = Get-FileFacts $configPath

    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-report.json') (Join-Path $Work 'new-report.json')
    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-report.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $run.ExitCode "meta-compile exit code (stderr: $($run.StdErr))"

    # Canonical order of kinds: ... Catalog, ... Enum, Report, ... AccumulationRegister.
    # Appending to the end of the block would have put Report after AccumulationRegister.
    $tags = @(Get-ChildObjectEntries $configPath | ForEach-Object { $_.Tag })
    Assert-Equal 'Language Catalog Enum Enum Report AccumulationRegister' ($tags -join ' ') 'kind order in ChildObjects'

    $after = Get-FileFacts $configPath
    Assert-StyleKept $before $after 'meta-compile new type group'
    $delta = Get-LineDelta $before $after
    Assert-Equal 0 $delta.Removed.Count "registration removed lines: $($delta.Removed -join ' | ')"
    Assert-Equal 1 $delta.Added.Count "registration must add exactly one line, added: $($delta.Added -join ' | ')"
}

Register-Case 'meta-compile: re-registering the same object is a no-op' {
    param($Work)
    Copy-Fixture 'config-dump' $Work "`n"
    Write-DevEnv $Work "NEW_OBJECT_POSITION=byName`r`n"
    $configPath = Join-Path $Work 'Configuration.xml'
    $newEnum = (Read-JsonFixture 'meta-compile\new-enum.json').name
    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')

    $first = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $first.ExitCode "first meta-compile exit code (stderr: $($first.StdErr))"
    $afterFirst = Get-FileFacts $configPath

    $second = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-Equal 0 $second.ExitCode "second meta-compile exit code (stderr: $($second.StdErr))"
    $afterSecond = Get-FileFacts $configPath

    $hits = @(Get-ChildObjectEntries $configPath | Where-Object { $_.Name -eq $newEnum })
    Assert-Equal 1 $hits.Count 'object registered twice'
    Assert-Equal $afterFirst.Text $afterSecond.Text 'second run rewrote Configuration.xml'
}

# ------------------------------------------------- downstream support guard

Register-Case 'support guard: meta-edit still refuses a locked vendor object' {
    param($Work)
    Copy-Fixture 'on-support' $Work "`n"
    $target = Join-Path $Work 'Catalogs\Locked.xml'
    $before = [System.IO.File]::ReadAllBytes($target)

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'add-attribute', '-Value', 'RegrFlag: Boolean', '-NoValidate') $Work
    Assert-True ($run.ExitCode -ne 0) 'guard let a locked object through'
    Assert-True ($run.StdErr -match 'support-guard') "stderr does not name the guard: $($run.StdErr)"
    Assert-Equal ([System.Convert]::ToBase64String($before)) ([System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($target))) 'refused edit still touched the file'
}

Register-Case 'support guard: .dev.env SUPPORT_GUARD=off still wins over the default' {
    param($Work)
    Copy-Fixture 'on-support' $Work "`n"
    Write-DevEnv $Work "SUPPORT_GUARD=off`r`n"
    $target = Join-Path $Work 'Catalogs\Locked.xml'

    $run = Invoke-Tool $MetaEdit @('-ObjectPath', $target, '-Operation', 'add-attribute', '-Value', 'RegrFlag: Boolean', '-NoValidate') $Work
    Assert-Equal 0 $run.ExitCode "guard did not honour SUPPORT_GUARD=off (stderr: $($run.StdErr))"
    Assert-True ((Get-FileFacts $target).Text -match '<Name>RegrFlag</Name>') 'edit was not applied with the guard off'
}

Register-Case 'support guard: meta-compile still refuses to write into a locked dump' {
    param($Work)
    Copy-Fixture 'on-support' $Work "`n"
    Copy-Item (Join-Path $FixturesDir 'meta-compile\new-enum.json') (Join-Path $Work 'new-enum.json')
    $configPath = Join-Path $Work 'Configuration.xml'
    $before = Get-FileFacts $configPath

    $run = Invoke-Tool $MetaCompile @('-JsonPath', (Join-Path $Work 'new-enum.json'), '-OutputDir', $Work) $Work
    Assert-True ($run.ExitCode -ne 0) 'guard let a compile into a locked dump through'
    Assert-True ($run.StdErr -match 'support-guard') "stderr does not name the guard: $($run.StdErr)"
    Assert-Equal $before.Text (Get-FileFacts $configPath).Text 'refused compile still edited Configuration.xml'
}

# ---------------------------------------------------------------- run

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("1c-rules-regr-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $root -Force | Out-Null
Write-Host "Work dir: $root" -ForegroundColor DarkGray
Write-Host ''

$index = 0
foreach ($case in $script:Cases) {
    if ($case.Name -notlike $Filter) { continue }
    $index++
    $work = Join-Path $root ("case{0:d2}" -f $index)
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        & $case.Body $work
        Write-Host "[PASS] $($case.Name)" -ForegroundColor Green
    } catch {
        $script:Failures += "$($case.Name): $($_.Exception.Message)"
        Write-Host "[FAIL] $($case.Name)" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
if ($index -eq 0) {
    Write-Host "No case matched filter '$Filter'." -ForegroundColor Yellow
    exit 1
}
if ($script:Failures.Count -eq 0) {
    Write-Host "$index/$index passed." -ForegroundColor Green
    if (-not $KeepWorkDir) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    exit 0
}
Write-Host "$($index - $script:Failures.Count)/$index passed, $($script:Failures.Count) failed." -ForegroundColor Red
Write-Host "Work dir kept for inspection: $root" -ForegroundColor Yellow
exit 1
