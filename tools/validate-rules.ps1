#Requires -Version 5.1
<#
.SYNOPSIS
    Structural validator for the 1c-rules ruleset. Intended for CI and for a
    pre-commit run by maintainers.

.DESCRIPTION
    The ruleset is ~1.4 MB of interlinked Markdown whose consistency is otherwise
    only checked by a human running /doctor. This script makes the mechanical part
    of that check automatic and fast:

      1. Frontmatter - every rule / agent / command / skill file carries the keys
         the adapters in adapters/*.yaml expect, with allowed values only.
         Unknown keys are reported: an adapter that does not list a key in
         keep/drop silently loses it on install.
      2. Cross-references - every `content/...` path mentioned anywhere in the
         ruleset resolves to a file that exists, and every relative Markdown link
         resolves from the file that contains it. A broken reference turns a hard
         gate into a dangling pointer without any visible error.
      3. Section anchors - "<file>.md -> Section" references point at a heading
         that exists in the target file. Reported as warnings: the ruleset also
         uses non-heading anchors (section signs, "A.7"), which cannot be
         resolved mechanically.
      4. Routed standards - every rule in content/rules that carries the
         help-mcp-router marker has its body in content/standards, every body
         there has a router, and the two heading trees agree. A router keeps
         its headings and drops its text, so a heading on one side only is
         either a reference resolving to an empty section or a section no
         reference can reach - and neither shows up otherwise, because the
         router parses fine alone.
      5. Always-on budget - AGENTS.md stays under a byte ceiling. This is the one
         file loaded into every request; unbounded growth there is a silent,
         permanent cost on every task.

    Generated trees (content/openspec-bundle/) are excluded: they are produced by
    tools/refresh-openspec-bundle.ps1 from the OpenSpec CLI and are not authored
    here.

    NOTE: this file is deliberately pure ASCII. Windows PowerShell 5.1 reads a
    BOM-less .ps1 as ANSI, which mangles non-ASCII source characters and breaks
    parsing. Unicode characters used in patterns are built with [char] instead.

.PARAMETER Root
    Repository root. Defaults to the parent directory of this script.

.PARAMETER AgentsMaxBytes
    Byte ceiling for AGENTS.md. Ratchet it downward as the file shrinks; never
    raise it without a deliberate decision.

.PARAMETER Strict
    Treat warnings as errors (exit code 1).

.EXAMPLE
    powershell -NoProfile -File tools\validate-rules.ps1
    powershell -NoProfile -File tools\validate-rules.ps1 -Strict
#>
[CmdletBinding()]
param(
    [string]$Root,
    [int]$AgentsMaxBytes = 62000,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path

$BT    = [string][char]0x60    # backtick
$ARROW = [string][char]0x2192  # right arrow used by the ruleset for anchors

$script:Errors = New-Object System.Collections.ArrayList
$script:Warnings = New-Object System.Collections.ArrayList

function Add-Problem {
    param(
        [ValidateSet('error', 'warning')][string]$Level,
        [string]$File,
        [int]$Line = 0,
        [string]$Message
    )
    $rel = $File
    if ($rel.StartsWith($Root)) { $rel = $rel.Substring($Root.Length).TrimStart('\', '/') }
    $rel = $rel -replace '\\', '/'
    $where = $rel
    if ($Line -gt 0) { $where = $rel + ':' + $Line }
    $entry = $where + ' - ' + $Message
    if ($Level -eq 'error') { [void]$script:Errors.Add($entry) } else { [void]$script:Warnings.Add($entry) }
}

# --------------------------------------------------------------------------
# Frontmatter
# --------------------------------------------------------------------------

function Get-Frontmatter {
    # Minimal top-level YAML reader: "key: value" pairs between the opening and
    # closing "---". Enough for the flat frontmatter this ruleset uses; nested
    # structures are not expected and surface as unknown keys.
    param([string]$Path)

    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }

    $map = [ordered]@{}
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '---') { return [pscustomobject]@{ Keys = $map; EndLine = $i + 1 } }
        if ($line -match '^\s*#') { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            $map[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $null
}

function Test-Frontmatter {
    param(
        [string]$Path,
        [string[]]$Required,
        [string[]]$Optional,
        [hashtable]$AllowedValues = @{}
    )

    $fm = Get-Frontmatter -Path $Path
    if ($null -eq $fm) {
        Add-Problem -Level error -File $Path -Line 1 -Message 'no closing YAML frontmatter block'
        return
    }

    foreach ($key in $Required) {
        if (-not $fm.Keys.Contains($key)) {
            Add-Problem -Level error -File $Path -Line 1 -Message ("frontmatter: required key '" + $key + "' is missing")
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$fm.Keys[$key])) {
            Add-Problem -Level error -File $Path -Line 1 -Message ("frontmatter: key '" + $key + "' is empty")
        }
    }

    $known = @($Required) + @($Optional)
    foreach ($key in $fm.Keys.Keys) {
        if ($known -notcontains $key) {
            Add-Problem -Level warning -File $Path -Line 1 -Message ("frontmatter: unknown key '" + $key + "' - no adapter lists it in keep/drop, so it is dropped silently on install")
        }
    }

    foreach ($key in $AllowedValues.Keys) {
        if ($fm.Keys.Contains($key)) {
            $value = ([string]$fm.Keys[$key]).Trim('"', "'")
            if ($AllowedValues[$key] -notcontains $value) {
                $allowed = ($AllowedValues[$key] -join ' | ')
                Add-Problem -Level error -File $Path -Line 1 -Message ("frontmatter: '" + $key + "' = '" + $value + "' is not one of: " + $allowed)
            }
        }
    }
}

# --------------------------------------------------------------------------
# File inventory
# --------------------------------------------------------------------------

$excludedDirs = @('openspec-bundle')

function Get-RulesetFiles {
    param([string]$Subpath, [string]$Filter = '*.md')
    $dir = Join-Path $Root $Subpath
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    Get-ChildItem -LiteralPath $dir -Filter $Filter -File -Recurse |
        Where-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
            $hit = $false
            foreach ($skip in $excludedDirs) { if ($relative -like ('*/' + $skip + '/*')) { $hit = $true } }
            -not $hit
        }
}

Write-Host ('1c-rules validator - root: ' + $Root) -ForegroundColor Cyan
Write-Host ''

# --- rules ---------------------------------------------------------------
$ruleFiles = @(Get-RulesetFiles -Subpath 'content/rules')
foreach ($file in $ruleFiles) {
    Test-Frontmatter -Path $file.FullName `
        -Required @('description', 'alwaysApply', 'category') `
        -Optional @('globs') `
        -AllowedValues @{ alwaysApply = @('true', 'false') }
}

# --- agents --------------------------------------------------------------
# Source files declare the abstract "modelTier"; the installer resolves it into
# "modelHint" before the adapters' keep/rename ops run (AGENT-INSTALL.md, Lean
# placement, step 4). A source file carrying "modelHint" or "model" directly has
# skipped that resolution and pins a model name inside the ruleset.
$agentFiles = @(Get-RulesetFiles -Subpath 'content/agents')
foreach ($file in $agentFiles) {
    Test-Frontmatter -Path $file.FullName `
        -Required @('name', 'description', 'modelTier', 'tools', 'isSubagent', 'allowParallel') `
        -Optional @('reasoningEffort') `
        -AllowedValues @{
            modelTier     = @('coding', 'analysis', 'light')
            isSubagent    = @('true', 'false')
            allowParallel = @('true', 'false')
        }

    $fm = Get-Frontmatter -Path $file.FullName
    if ($fm -and ($fm.Keys.Contains('modelHint') -or $fm.Keys.Contains('model'))) {
        Add-Problem -Level error -File $file.FullName -Line 1 -Message 'frontmatter pins a concrete model - source agents declare modelTier only; the installer resolves it from .dev.env'
    }

    if ($fm -and $fm.Keys.Contains('name')) {
        $expected = $file.BaseName
        $declared = ([string]$fm.Keys['name']).Trim('"', "'")
        if ($declared -ne ('1c-' + $expected) -and $declared -ne $expected) {
            Add-Problem -Level warning -File $file.FullName -Line 1 -Message ("frontmatter: name '" + $declared + "' does not match the file name ('" + $expected + "' / '1c-" + $expected + "') - subagents.md maps ids to file names")
        }
    }
}

# --- commands ------------------------------------------------------------
$commandFiles = @(Get-RulesetFiles -Subpath 'content/commands')
foreach ($file in $commandFiles) {
    Test-Frontmatter -Path $file.FullName `
        -Required @('description') `
        -Optional @('argumentHint', 'allowedTools')
}

# --- skills --------------------------------------------------------------
$skillFiles = @(Get-RulesetFiles -Subpath 'content/skills' -Filter 'SKILL.md')
foreach ($file in $skillFiles) {
    Test-Frontmatter -Path $file.FullName `
        -Required @('name', 'description') `
        -Optional @('license', 'allowed-tools', 'argument-hint', 'metadata')
}

# --------------------------------------------------------------------------
# Cross-references
# --------------------------------------------------------------------------

# Index of every Markdown basename that exists in the repo. A bare "<name>.md"
# reference is accepted when the file exists anywhere - the ruleset legitimately
# points at skill docs, command files and root documents from a rule file.
$mdIndex = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in (Get-ChildItem -LiteralPath $Root -Filter '*.md' -File -Recurse |
        Where-Object {
            $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
            $rel -notlike '.git/*' -and $rel -notlike 'content/openspec-bundle/*'
        })) {
    [void]$mdIndex.Add($f.Name.ToLowerInvariant())
}

# Names that are referenced by design and are NOT expected to exist in this repo.
$bareRefWhitelist = @(
    # OpenSpec artifacts - created per change under openspec/changes/<id>/.
    'proposal.md', 'design.md', 'tasks.md', 'spec.md', 'conflict.md', 'project.md',
    # Entry points the installer generates in the TARGET project, per adapter.
    'CLAUDE.md', 'AGENTS.md', 'QWEN.md', 'INSTALL.md',
    # Generic form used when talking about "a skill's SKILL.md".
    'SKILL.md',
    # Legacy file the migration rules deliberately still name so that projects
    # carrying it get migrated. Removing the mention would drop the migration.
    'infobasesettings.md',
    # Created by /build-release in the TARGET project (release changelog).
    'CHANGELOG.md'
) | ForEach-Object { $_.ToLowerInvariant() }

$scanned = @()
$scanned += $ruleFiles
$scanned += $agentFiles
$scanned += $commandFiles
$scanned += @(Get-RulesetFiles -Subpath 'content/skills')
foreach ($name in @('AGENTS.md', 'README.md', 'AGENT-INSTALL.md', 'memory.md', 'LLM-RULES.md')) {
    $path = Join-Path $Root $name
    if (Test-Path -LiteralPath $path) { $scanned += Get-Item -LiteralPath $path }
}

# "content/..." paths mentioned anywhere in the text.
$contentRefPattern = '(content/[A-Za-z0-9._\-]+(?:/[A-Za-z0-9._\-]+)*\.(?:md|ps1|py|json|txt))'
# Windows-style "content\..." references: the ruleset convention is forward
# slashes (portable across tools), so these are flagged; their targets are
# still resolved so a broken one surfaces as an error, not just a style nit.
$contentRefBackslashPattern = '(content\\[A-Za-z0-9._\-]+(?:\\[A-Za-z0-9._\-]+)*\.(?:md|ps1|py|json|txt))'
# Bare "<name>.md" inside backticks - resolved against the file's own directory,
# then against content/rules/ (the ruleset's shorthand for sibling rules).
$bareRefPattern = $BT + '([A-Za-z0-9._\-]+\.md)' + $BT
# "<file>.md -> Section" anchors.
$anchorPattern = $BT + '([A-Za-z0-9._\-/]+\.md)\s*' + $ARROW + '\s*([^' + $BT + ']+)' + $BT
# Relative Markdown links [text](target.md).
$mdLinkPattern = '\]\((?!https?:)([^)#]+\.md)(?:#[^)]*)?\)'
# Characters stripped before comparing heading text.
$decorationPattern = '[' + $BT + '*_"]'

$headingCache = @{}
function Get-Headings {
    param([string]$Path)
    if ($headingCache.ContainsKey($Path)) { return $headingCache[$Path] }
    $found = New-Object System.Collections.ArrayList
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        if ($line -match '^#{1,6}\s+(.+?)\s*$') {
            [void]$found.Add((($Matches[1] -replace $decorationPattern, '').Trim().ToLowerInvariant()))
        }
    }
    $headingCache[$Path] = $found
    return $found
}

foreach ($file in $scanned) {
    $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
    $ownDir = Split-Path -Parent $file.FullName
    $relPath = $file.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'

    # The bare "<name>.md" shorthand is the ruleset's own way of pointing at a
    # sibling rule, so it is only checked inside the ruleset's own prose. Skill
    # docs and installer docs use Markdown filenames as examples and generated
    # names ("input.md", "postanovka-enhanced.md", "AGENTS.md.bak.md"), which are
    # indistinguishable from rule names and would be pure noise here. Fully
    # qualified "content/..." paths and Markdown links stay checked everywhere.
    $checkBareRefs = $relPath -match '^(content/(rules|agents|commands)/|AGENTS\.md$)'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNo = $i + 1

        foreach ($m in [regex]::Matches($line, $contentRefPattern)) {
            $target = Join-Path $Root ($m.Groups[1].Value -replace '/', '\')
            if (-not (Test-Path -LiteralPath $target)) {
                Add-Problem -Level error -File $file.FullName -Line $lineNo -Message ('broken reference: ' + $m.Groups[1].Value)
            }
        }

        foreach ($m in [regex]::Matches($line, $contentRefBackslashPattern)) {
            $raw = $m.Groups[1].Value
            $target = Join-Path $Root $raw
            if (-not (Test-Path -LiteralPath $target)) {
                Add-Problem -Level error -File $file.FullName -Line $lineNo -Message ('broken reference (backslash form): ' + $raw)
            }
            else {
                Add-Problem -Level warning -File $file.FullName -Line $lineNo -Message ('backslash path reference: ' + $raw + ' - use forward slashes (ruleset convention, portable across tools)')
            }
        }

        if ($checkBareRefs) {
            foreach ($m in [regex]::Matches($line, $bareRefPattern)) {
                $name = $m.Groups[1].Value
                $key = $name.ToLowerInvariant()
                if ($bareRefWhitelist -contains $key) { continue }
                if (-not $mdIndex.Contains($key)) {
                    Add-Problem -Level error -File $file.FullName -Line $lineNo -Message ('dangling reference: ' + $name + ' - no file with this name exists in the repo')
                    continue
                }
                # Guard against basename false-pass: a bare reference must resolve
                # from the canonical shorthand locations (own directory, sibling
                # rules/commands/agents, repo root) - not merely share a basename
                # with an unrelated file somewhere else in the repo.
                $resolved = $false
                foreach ($dir in @($ownDir, (Join-Path $Root 'content\rules'), (Join-Path $Root 'content\commands'), (Join-Path $Root 'content\agents'), $Root)) {
                    if (Test-Path -LiteralPath (Join-Path $dir $name)) { $resolved = $true; break }
                }
                if (-not $resolved) {
                    Add-Problem -Level warning -File $file.FullName -Line $lineNo -Message ('bare reference resolves only by repo-wide basename: ' + $name + ' - qualify the path (content/...)')
                }
            }
        }

        foreach ($m in [regex]::Matches($line, $mdLinkPattern)) {
            $target = Join-Path $ownDir ($m.Groups[1].Value -replace '/', '\')
            if (-not (Test-Path -LiteralPath $target)) {
                Add-Problem -Level error -File $file.FullName -Line $lineNo -Message ('broken Markdown link: ' + $m.Groups[1].Value)
            }
        }

        foreach ($m in [regex]::Matches($line, $anchorPattern)) {
            $refFile = $m.Groups[1].Value
            $section = $m.Groups[2].Value
            # Nested anchors ("A -> B -> C"): only the first segment is reliably a
            # heading; deeper ones are often list items (A.7, Gate 3a, section 8).
            $section = ($section -split $ARROW)[0]
            $section = ($section -replace $decorationPattern, '').Trim().TrimEnd('.', ',', ';').ToLowerInvariant()
            if (-not $section) { continue }

            # Anchors that are correct but cannot resolve to a heading:
            #   "A.7" / "C.1"  - numbered list items inside AGENTS.md sections
            #   section sign   - numbered sections of a rule file
            #   "<...>"        - placeholders in command / template text
            if ($section -match '^[a-z]\.\d+$') { continue }
            if ($section.StartsWith([string][char]0xA7)) { continue }
            if ($section -match '[<>]') { continue }
            # memory.md and LLM-RULES.md gain their sections at runtime.
            if ($refFile -match '(?i)(memory|LLM-RULES)\.md$') { continue }

            $candidates = @(
                (Join-Path $ownDir ($refFile -replace '/', '\')),
                (Join-Path $Root ($refFile -replace '/', '\')),
                (Join-Path $Root ('content\rules\' + $refFile))
            )
            $targetPath = $null
            foreach ($candidate in $candidates) {
                if (Test-Path -LiteralPath $candidate) { $targetPath = $candidate; break }
            }
            if (-not $targetPath) { continue }  # the path itself is reported above

            $headings = Get-Headings -Path $targetPath
            $hit = $false
            foreach ($heading in $headings) {
                if ($heading -eq $section -or $heading.Contains($section) -or $section.Contains($heading)) { $hit = $true; break }
            }
            if (-not $hit) {
                Add-Problem -Level warning -File $file.FullName -Line $lineNo -Message ("anchor '" + $section + "' not found as a heading in " + $refFile)
            }
        }
    }
}

# --------------------------------------------------------------------------
# Routed standards - router in content/rules <-> body in content/standards
# --------------------------------------------------------------------------
# A routed rule keeps its heading tree and drops its text; the text lives in
# content/standards and is what the 1c-standards collection indexes. The pair
# only works while the two heading trees agree: a heading present in one and
# not the other is either a "<file>.md -> Section" reference that resolves to
# nothing, or a section of the standard no reference can reach. Neither shows
# up anywhere else, because the router parses fine on its own.

function Get-HeadingSet {
    param([string]$Path, [string[]]$Ignore = @())
    $set = New-Object System.Collections.ArrayList
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        if ($line -match '^#{2,4}\s+(.+?)\s*$') {
            $title = $Matches[1]
            if ($Ignore -notcontains $title) { [void]$set.Add($title) }
        }
    }
    return $set
}

$standardsDir = Join-Path $Root 'content/standards'
$routerMarker = '<!-- help-mcp-router -->'
$scaffold     = @('Where this standard lives', 'Sections')
$routedCount  = 0

$routers = @($ruleFiles | Where-Object {
    [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8).Contains($routerMarker)
})

foreach ($router in $routers) {
    $routedCount++
    $bodyPath = Join-Path $standardsDir $router.Name
    if (-not (Test-Path -LiteralPath $bodyPath)) {
        Add-Problem -Level error -File $router.FullName -Line 1 -Message (
            'routed rule has no body at content/standards/' + $router.Name +
            ' - the router points at text that is not in the corpus source')
        continue
    }

    $routerHeadings = Get-HeadingSet -Path $router.FullName -Ignore $scaffold
    $bodyHeadings   = Get-HeadingSet -Path $bodyPath

    foreach ($h in $routerHeadings) {
        if ($bodyHeadings -notcontains $h) {
            Add-Problem -Level error -File $router.FullName -Message (
                'heading "' + $h + '" has no counterpart in content/standards/' + $router.Name +
                ' - references to it resolve to an empty section')
        }
    }
    foreach ($h in $bodyHeadings) {
        if ($routerHeadings -notcontains $h) {
            Add-Problem -Level error -File $bodyPath -Message (
                'heading "' + $h + '" is missing from the router content/rules/' + $router.Name +
                ' - no reference in the ruleset can reach it')
        }
    }
}

if (Test-Path -LiteralPath $standardsDir) {
    foreach ($body in Get-ChildItem -LiteralPath $standardsDir -Filter *.md -File) {
        if ($body.Name -eq 'README.md') { continue }
        $routerPath = Join-Path (Join-Path $Root 'content/rules') $body.Name
        $isRouter = (Test-Path -LiteralPath $routerPath) -and
            [System.IO.File]::ReadAllText($routerPath, [System.Text.Encoding]::UTF8).Contains($routerMarker)
        if (-not $isRouter) {
            Add-Problem -Level error -File $body.FullName -Line 1 -Message (
                'no routed rule in content/rules refers to this body - an inlined rule must not ' +
                'also live here (one rule, one body), and an unreferenced body is indexed but unreachable')
        }
    }
}

# --------------------------------------------------------------------------
# Always-on budget
# --------------------------------------------------------------------------

$agentsPath = Join-Path $Root 'AGENTS.md'
if (Test-Path -LiteralPath $agentsPath) {
    $size = (Get-Item -LiteralPath $agentsPath).Length
    $approxTokens = [math]::Round($size / 3.7)
    Write-Host ('AGENTS.md: {0:N0} bytes (~{1:N0} tokens), ceiling {2:N0}' -f $size, $approxTokens, $AgentsMaxBytes)
    if ($size -gt $AgentsMaxBytes) {
        Add-Problem -Level error -File $agentsPath -Message ('always-on budget exceeded: ' + $size + ' bytes > ' + $AgentsMaxBytes + '. This file is loaded into every request - move detail into an on-demand rule instead of raising the ceiling.')
    }
}

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------

Write-Host ('Checked: {0} rules ({1} routed to the standards corpus), {2} agents, {3} commands, {4} skills.' -f `
    $ruleFiles.Count, $routedCount, $agentFiles.Count, $commandFiles.Count, $skillFiles.Count)
Write-Host ''

if ($script:Warnings.Count -gt 0) {
    Write-Host ('WARNINGS (' + $script:Warnings.Count + '):') -ForegroundColor Yellow
    foreach ($entry in $script:Warnings) { Write-Host ('  ' + $entry) -ForegroundColor Yellow }
    Write-Host ''
}

if ($script:Errors.Count -gt 0) {
    Write-Host ('ERRORS (' + $script:Errors.Count + '):') -ForegroundColor Red
    foreach ($entry in $script:Errors) { Write-Host ('  ' + $entry) -ForegroundColor Red }
    Write-Host ''
    Write-Host 'FAILED' -ForegroundColor Red
    exit 1
}

if ($Strict -and $script:Warnings.Count -gt 0) {
    Write-Host 'FAILED (-Strict: warnings are errors)' -ForegroundColor Red
    exit 1
}

Write-Host 'OK' -ForegroundColor Green
exit 0
