# DevEnv.ps1 - read project settings from `.dev.env`.
#
# In the 1c-rules toolkit `.dev.env` at the project root is the single source of
# truth for project parameters. The vendored cc-1c-skills scripts natively read
# `.v8-project.json`; a small patch inside their own lookup functions consults
# this helper first, so a project only ever maintains `.dev.env`.
#
# Dot-sourced from inside those functions (`. (Join-Path $PSScriptRoot
# '..\..\_common\DevEnv.ps1')`), which scopes the definitions to the caller and
# keeps the patch self-contained - no top-level ordering to preserve on the next
# upstream sync.

function Find-1CDevEnvFile {
    # Nearest `.dev.env` walking up from the working directory, like the
    # `.v8-project.json` lookup it complements. Returns $null when absent.
    param([string]$StartDir)

    $dir = if ($StartDir) { $StartDir } else { (Get-Location).Path }
    for ($i = 0; $i -lt 20 -and $dir; $i++) {
        $candidate = Join-Path $dir '.dev.env'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-1CDevEnvValue {
    # Single KEY value from `.dev.env`. Returns '' when the file, the key or the
    # value is missing - every caller treats '' as "not configured" and falls
    # through to its own next source. Never throws: a malformed .dev.env must not
    # break a metadata operation.
    param([Parameter(Mandatory = $true)][string]$Name)

    try {
        $file = Find-1CDevEnvFile
        if (-not $file) { return '' }
        foreach ($line in (Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction Stop)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $trim = $line.TrimStart()
            if ($trim.StartsWith('#')) { continue }
            if ($trim -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                if ($Matches[1] -ne $Name) { continue }
                $val = $Matches[2].Trim()
                # Quoted paths must still resolve with Test-Path: PLATFORM_PATH="C:\1cv8".
                if ($val.Length -ge 2 -and
                    (($val.StartsWith('"') -and $val.EndsWith('"')) -or
                     ($val.StartsWith("'") -and $val.EndsWith("'")))) {
                    $val = $val.Substring(1, $val.Length - 2).Trim()
                }
                return $val
            }
        }
    } catch { }
    return ''
}

function Get-1CDevEnvArgs {
    # Comma-separated argument list from `.dev.env` (PLATFORM_ARGS / IBCMD_ARGS)
    # as a string array. Empty array when unset - same contract as the
    # `.v8-project.json` v8args / ibcmdargs lookup this shadows.
    param([Parameter(Mandatory = $true)][string]$Name)

    $raw = Get-1CDevEnvValue $Name
    if (-not $raw) { return @() }
    return @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
