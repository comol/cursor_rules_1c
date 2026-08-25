# repo-ops v1.0 — 1C configuration repository (хранилище конфигурации) operations
# Part of the 1c-repository-manage skill (1c-rules).
# Conventions follow 1c-metadata-manage/tools/1c-db-ops (encoding fallback,
# non-interactive launch, secret masking, exit-0 log-lie detection).
<#
.SYNOPSIS
    Операции с хранилищем конфигурации 1С в пакетном режиме Конфигуратора.

.DESCRIPTION
    Единственная санкционированная точка выполнения команд хранилища
    (/ConfigurationRepository*) в наборе 1c-rules. Скрипт инкапсулирует то, что
    теряет ad-hoc командная строка: точный XML списка объектов, кодировки /Out,
    ложный код возврата 0, маскирование паролей, запрет операций над всей
    конфигурацией и двойное подтверждение -force.

    Параметры подключения по умолчанию читаются из .dev.env (поиск вверх от
    текущего каталога): PLATFORM_PATH, INFOBASE_KIND, INFOBASE_PATH, IB_USER,
    IB_PASSWORD, REPOSITORY_PATH, REPOSITORY_USER, REPOSITORY_PASSWORD,
    REPOSITORY_ALLOW_FORCE. Явные параметры скрипта имеют приоритет.

.PARAMETER Operation
    status  — отчёт по последней версии хранилища (проверка подключения)
    history — отчёт по истории версий (BeginVersion/EndVersion/GroupBy)
    diff    — сравнение основной конфигурации с версией хранилища
    lock    — захват точного списка объектов
    update  — получение точного списка объектов из хранилища
    commit  — помещение точного списка объектов (Comment обязателен)
    unlock  — отмена захвата точного списка объектов
    dump    — выгрузка версии хранилища в CF/CFE

.PARAMETER Objects
    Точные полные имена метаданных (Справочник.Номенклатура,
    Document.SalesOrder). Обязателен для lock/commit/unlock/update, опционален
    для diff. Пустой список, `*` и корень Configuration запрещены: без -Objects
    платформа применяет операцию ко ВСЕЙ конфигурации.

.EXAMPLE
    .\repo-ops.ps1 -Operation status

.EXAMPLE
    .\repo-ops.ps1 -Operation lock -Objects "Справочник.Номенклатура,Документ.ЗаказКлиента"

.EXAMPLE
    .\repo-ops.ps1 -Operation commit -Objects "Справочник.Номенклатура" -Comment "Задача 123: новый реквизит"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("status", "history", "diff", "lock", "update", "commit", "unlock", "dump")]
    [string]$Operation,

    [Parameter(Mandatory=$false)]
    [string[]]$Objects = @(),

    [Parameter(Mandatory=$false)]
    [string]$Comment,

    # -1 = latest version (the -v / -SecondVersion key is omitted entirely)
    [Parameter(Mandatory=$false)]
    [int]$Version = -1,

    # history bounds; 0 = unset (key omitted). status always reports -NBegin -1.
    [Parameter(Mandatory=$false)]
    [int]$BeginVersion = 0,

    [Parameter(Mandatory=$false)]
    [int]$EndVersion = 0,

    [Parameter(Mandatory=$false)]
    [ValidateSet("", "version", "object", "comment")]
    [string]$GroupBy = "",

    [Parameter(Mandatory=$false)]
    [switch]$IncludeChildObjects,

    [Parameter(Mandatory=$false)]
    [switch]$Revised,

    [Parameter(Mandatory=$false)]
    [switch]$KeepLocked,

    # Force is double-gated: REPOSITORY_ALLOW_FORCE=true in .dev.env AND the
    # per-call confirmation switch. Both must be present.
    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$ConfirmForce,

    # unlock -Force discards other people's / local uncommitted changes — its
    # confirmation switch is named after the consequence, not the mechanism.
    [Parameter(Mandatory=$false)]
    [switch]$ConfirmDiscardChanges,

    # dump target (.cf / .cfe)
    [Parameter(Mandatory=$false)]
    [string]$OutputFile,

    # report target for status/history/diff; default: %TEMP%\1c-repo-reports\<op>-<stamp>.txt (kept)
    [Parameter(Mandatory=$false)]
    [string]$ReportFile,

    # how much of the report to print inline; the full file always stays on disk
    [Parameter(Mandatory=$false)]
    [int]$MaxReportChars = 16000,

    # 0 = no timeout. On expiry the Designer process is killed and exit is 1.
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 0,

    # connection overrides (.dev.env wins otherwise)
    [Parameter(Mandatory=$false)]
    [string]$V8Path,

    [Parameter(Mandatory=$false)]
    [string]$InfoBasePath,

    [Parameter(Mandatory=$false)]
    [string]$InfoBaseServer,

    [Parameter(Mandatory=$false)]
    [string]$InfoBaseRef,

    [Parameter(Mandatory=$false)]
    [string]$UserName,

    [Parameter(Mandatory=$false)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath,

    [Parameter(Mandatory=$false)]
    [string]$RepositoryUser,

    [Parameter(Mandatory=$false)]
    [string]$RepositoryPassword,

    # extension repository (adds -Extension to /ConfigurationRepository* commands)
    [Parameter(Mandatory=$false)]
    [string]$Extension
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- .dev.env (self-contained copy of the DevEnv contract: nearest file walking
# up, '' when absent, quotes stripped, never throws) ---
function Find-DevEnvFile {
    $dir = (Get-Location).Path
    for ($i = 0; $i -lt 20 -and $dir; $i++) {
        $candidate = Join-Path $dir '.dev.env'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-DevEnvValue {
    param([Parameter(Mandatory = $true)][string]$Name)
    try {
        $file = Find-DevEnvFile
        if (-not $file) { return '' }
        foreach ($line in (Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction Stop)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $trim = $line.TrimStart()
            if ($trim.StartsWith('#')) { continue }
            if ($trim -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                if ($Matches[1] -ne $Name) { continue }
                $val = $Matches[2].Trim()
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

# --- Shared helpers (same contracts as 1c-db-ops) ---
function Protect-Secrets {
    param([string]$Text, [string[]]$Secrets)
    foreach ($s in $Secrets) { if ($s) { $Text = $Text.Replace($s, '***') } }
    return $Text
}

function ConvertTo-CleanPath {
    param([string]$Value, [string]$ParamName)
    if (-not $Value) { return $Value }
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v[0] -eq $v[-1] -and ($v[0] -eq '"' -or $v[0] -eq "'")) {
        $v = $v.Substring(1, $v.Length - 2).Trim()
    }
    if ($v.Length -gt 3 -and ($v[-1] -eq '\' -or $v[-1] -eq '/')) { $v = $v.Substring(0, $v.Length - 1) }
    if ($v.Contains('"')) {
        Write-Host "Error: $ParamName contains a quote character: $Value" -ForegroundColor Red
        exit 1
    }
    return $v
}

function Get-ExitAnnotation {
    param([int]$Code)
    $win = @{
        -1073741819 = "0xC0000005 (access violation)"
        -1073741515 = "0xC0000135 (missing DLL)"
        -1073740791 = "0xC0000409 (stack overrun)"
    }
    if ($win.ContainsKey($Code)) {
        return " — abnormal termination, exception $($win[$Code]); repository locks may be left half-applied; run -Operation status before retrying"
    }
    return ""
}

function ConvertFrom-PlatformBytes {
    # Strict UTF-8 first, cp866 fallback — guessing outright mangles Cyrillic.
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return '' }
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        return $strict.GetString($Bytes)
    } catch {
        return [System.Text.Encoding]::GetEncoding(866).GetString($Bytes)
    }
}

function Read-PlatformTextFile {
    # /Out logs and txt reports: BOM decides when present; otherwise strict UTF-8
    # with cp1251 fallback (older platforms write ANSI). Deterministic on both
    # Windows PowerShell 5.1 and pwsh 7.
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return '' }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        return $strict.GetString($bytes)
    } catch {
        return [System.Text.Encoding]::GetEncoding(1251).GetString($bytes)
    }
}

function Invoke-PlatformProcess {
    # Non-interactive launch: closed stdin makes an auth prompt fast-fail instead
    # of hanging; both pipes are drained async (sequential reads deadlock).
    # The caller pre-quotes tokens the 1C way (File="C:\a b", /N"user").
    param([string]$Exe, [string[]]$ProcArgs, [int]$TimeoutSec)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = $ProcArgs -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $outMs = New-Object System.IO.MemoryStream
    $errMs = New-Object System.IO.MemoryStream
    $outTask = $p.StandardOutput.BaseStream.CopyToAsync($outMs)
    $errTask = $p.StandardError.BaseStream.CopyToAsync($errMs)
    $timedOut = $false
    if ($TimeoutSec -gt 0) {
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $timedOut = $true
            try { $p.Kill() } catch { }
            $p.WaitForExit()
        }
    } else {
        $p.WaitForExit()
    }
    [System.Threading.Tasks.Task]::WaitAll(@($outTask, $errTask))
    $out = ConvertFrom-PlatformBytes $outMs.ToArray()
    $err = ConvertFrom-PlatformBytes $errMs.ToArray()
    if ($err) { $out += $err }
    return [pscustomobject]@{ Output = $out; ExitCode = $p.ExitCode; TimedOut = $timedOut }
}

function Write-PlatformOutput {
    param([string]$Text)
    if (-not $Text) { return }
    $t = $Text.TrimEnd()
    if (-not $t) { return }
    $limit = 65536
    if ($t.Length -gt $limit) {
        $t = "[... обрезано, показаны последние $limit символов ...]`r`n" + $t.Substring($t.Length - $limit)
    }
    Write-Host "--- Вывод платформы ---"
    Write-Host $t
    Write-Host "--- End ---"
}

# --- Resolve connection parameters (explicit > .dev.env > autodetect) ---
$V8Path = ConvertTo-CleanPath $V8Path '-V8Path'
$InfoBasePath = ConvertTo-CleanPath $InfoBasePath '-InfoBasePath'
$RepositoryPath = ConvertTo-CleanPath $RepositoryPath '-RepositoryPath'

if (-not $V8Path) { $V8Path = Get-DevEnvValue 'PLATFORM_PATH' }
if (-not $V8Path) {
    $found = Get-ChildItem @("C:\Program Files\1cv8\*\bin\1cv8.exe", "C:\Program Files (x86)\1cv8\*\bin\1cv8.exe") -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Directory.Parent.Name } catch { [version]"0.0" } } -Descending |
        Select-Object -First 1
    if ($found) {
        $V8Path = $found.FullName
        Write-Host "Auto-selected platform $($found.Directory.Parent.Name): $V8Path" -ForegroundColor Yellow
    } else {
        Write-Host "Error: 1C executable not found. Set PLATFORM_PATH in .dev.env or pass -V8Path" -ForegroundColor Red
        exit 1
    }
}
if (Test-Path $V8Path -PathType Container) {
    $v8Candidate = Join-Path $V8Path "1cv8.exe"
    if (-not (Test-Path $v8Candidate)) { $v8Candidate = Join-Path $V8Path "bin\1cv8.exe" }
    $V8Path = $v8Candidate
}
if (-not (Test-Path $V8Path)) {
    Write-Host "Error: 1C executable not found at $V8Path" -ForegroundColor Red
    exit 1
}
if ((Split-Path $V8Path -Leaf) -match '^ibcmd') {
    Write-Host "Error: repository operations require the Designer (1cv8.exe); ibcmd has no configuration-repository mode" -ForegroundColor Red
    exit 1
}

$connectionToken = $null
if ($InfoBaseServer -and $InfoBaseRef) {
    $connectionToken = "/S `"$InfoBaseServer/$InfoBaseRef`""
} elseif ($InfoBasePath) {
    $connectionToken = "/F `"$InfoBasePath`""
} else {
    $devIbPath = Get-DevEnvValue 'INFOBASE_PATH'
    $devIbKind = Get-DevEnvValue 'INFOBASE_KIND'
    if (-not $devIbKind) { $devIbKind = 'file' }
    if (-not $devIbPath) {
        Write-Host "Error: infobase connection is not configured. Set INFOBASE_PATH in .dev.env or pass -InfoBasePath / -InfoBaseServer + -InfoBaseRef" -ForegroundColor Red
        exit 1
    }
    if ($devIbKind -eq 'server') {
        $connectionToken = "/S `"$devIbPath`""
    } else {
        $InfoBasePath = $devIbPath
        $connectionToken = "/F `"$devIbPath`""
    }
}
if ($InfoBasePath -and -not (Test-Path (Join-Path $InfoBasePath "1Cv8.1CD"))) {
    Write-Host "Error: information base not found at $InfoBasePath (no 1Cv8.1CD)" -ForegroundColor Red
    exit 1
}

if (-not $UserName) { $UserName = Get-DevEnvValue 'IB_USER' }
if (-not $Password) { $Password = Get-DevEnvValue 'IB_PASSWORD' }
if (-not $RepositoryPath) { $RepositoryPath = Get-DevEnvValue 'REPOSITORY_PATH' }
if (-not $RepositoryUser) { $RepositoryUser = Get-DevEnvValue 'REPOSITORY_USER' }
if (-not $RepositoryPassword) { $RepositoryPassword = Get-DevEnvValue 'REPOSITORY_PASSWORD' }

if (-not $RepositoryPath) {
    Write-Host "Error: the configuration is not bound to a repository in this project (.dev.env REPOSITORY_PATH is empty and -RepositoryPath was not passed)." -ForegroundColor Red
    Write-Host "If the project does use a configuration repository, set REPOSITORY_PATH in .dev.env (local path or tcp://server/alias)." -ForegroundColor Red
    exit 1
}

# --- Operation-specific validation ---
$objectOps = @('lock', 'update', 'commit', 'unlock')

# Comma-separated convention: `powershell.exe -File` cannot bind arrays.
$Objects = @($Objects | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$seen = @{}
$objectList = @()
foreach ($name in $Objects) {
    if ($name -eq '*') {
        Write-Host "Error: wildcard '*' is forbidden — repository operations run only on an explicit object list" -ForegroundColor Red
        exit 1
    }
    if ($name -ieq 'Configuration' -or $name -ieq 'Конфигурация') {
        Write-Host "Error: the configuration root is forbidden as an object — that would apply the operation to the whole configuration" -ForegroundColor Red
        exit 1
    }
    if ($name -notmatch '\.') {
        Write-Host "Error: '$name' is not a metadata full name (expected Type.Name, e.g. Справочник.Номенклатура / Catalog.Products)" -ForegroundColor Red
        exit 1
    }
    if ($name.Contains('"')) {
        Write-Host "Error: object name contains a quote character: $name" -ForegroundColor Red
        exit 1
    }
    if (-not $seen.ContainsKey($name.ToLowerInvariant())) {
        $seen[$name.ToLowerInvariant()] = $true
        $objectList += $name
    }
}

if (($objectOps -contains $Operation) -and $objectList.Count -eq 0) {
    Write-Host "Error: -Objects is required for '$Operation'. An empty list is forbidden: the platform without -Objects applies the operation to the WHOLE configuration." -ForegroundColor Red
    exit 1
}

if ($Operation -eq 'commit') {
    if (-not $Comment -or -not $Comment.Trim()) {
        Write-Host "Error: -Comment is required for commit (task reference + what changed)" -ForegroundColor Red
        exit 1
    }
}

if ($Operation -eq 'dump') {
    if (-not $OutputFile) {
        Write-Host "Error: -OutputFile is required for dump" -ForegroundColor Red
        exit 1
    }
    $OutputFile = [System.IO.Path]::GetFullPath($OutputFile)
    $ext = [System.IO.Path]::GetExtension($OutputFile).ToLowerInvariant()
    if ($ext -ne '.cf' -and $ext -ne '.cfe') {
        Write-Host "Error: -OutputFile must have a .cf or .cfe extension" -ForegroundColor Red
        exit 1
    }
    $outDir = Split-Path $OutputFile -Parent
    if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
}

if ($Extension -and $Operation -eq 'diff') {
    Write-Host "Error: -Extension is not supported for diff; compare extension configurations via /CompareCfg with ConfigurationExtension types manually (see docs/repo-ops.md)" -ForegroundColor Red
    exit 1
}

# --- Force double opt-in ---
if ($Force) {
    $allowForce = (Get-DevEnvValue 'REPOSITORY_ALLOW_FORCE')
    if ($allowForce -ne 'true') {
        Write-Host "Error: -Force is disabled for this project. Set REPOSITORY_ALLOW_FORCE=true in .dev.env only for an approved maintenance window, with the user's explicit consent." -ForegroundColor Red
        exit 1
    }
    if ($Operation -eq 'unlock') {
        if (-not $ConfirmDiscardChanges) {
            Write-Host "Error: forced unlock can DISCARD uncommitted changes (yours or another developer's). Re-run with -ConfirmDiscardChanges only after the user explicitly approved losing them." -ForegroundColor Red
            exit 1
        }
    } elseif ($Operation -eq 'update' -or $Operation -eq 'commit') {
        if (-not $ConfirmForce) {
            Write-Host "Error: -Force for '$Operation' requires the explicit -ConfirmForce switch in the same call (approved by the user for this specific operation)." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: -Force is not applicable to '$Operation'" -ForegroundColor Red
        exit 1
    }
}

# --- Temp workspace ---
$tempDir = Join-Path $env:TEMP "repo_ops_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Reports survive the run: the agent reads the file instead of swallowing
# megabytes of history/diff into its context.
$reportOps = @('status', 'history', 'diff')
if (($reportOps -contains $Operation) -and -not $ReportFile) {
    $reportRoot = Join-Path $env:TEMP "1c-repo-reports"
    if (-not (Test-Path $reportRoot)) { New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null }
    $ReportFile = Join-Path $reportRoot ("{0}-{1}.txt" -f $Operation, (Get-Date -Format "yyyyMMdd-HHmmss"))
}

function Write-ObjectListXml {
    # Exact object list in the http://v8.1c.ru/8.3/config/objects format. UTF-8
    # with BOM; attribute values XML-escaped. includeChildObjects is explicit on
    # every entry so the file reads unambiguously.
    param([string[]]$Names, [bool]$WithChildren, [string]$Path)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<Objects xmlns="http://v8.1c.ru/8.3/config/objects" version="1.0">')
    $childFlag = 'false'
    if ($WithChildren) { $childFlag = 'true' }
    foreach ($n in $Names) {
        $esc = $n.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
        [void]$sb.AppendLine("  <Object fullName=`"$esc`" includeChildObjects=`"$childFlag`"/>")
    }
    [void]$sb.AppendLine('</Objects>')
    $enc = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $sb.ToString(), $enc)
}

try {
    # --- Build the argument line (pre-quoted, 1C style) ---
    $arguments = @("DESIGNER")
    $arguments += $connectionToken
    if ($UserName) { $arguments += "/N`"$UserName`"" }
    if ($Password) { $arguments += "/P`"$Password`"" }
    $arguments += "/ConfigurationRepositoryF `"$RepositoryPath`""
    if ($RepositoryUser) { $arguments += "/ConfigurationRepositoryN`"$RepositoryUser`"" }
    if ($RepositoryPassword) { $arguments += "/ConfigurationRepositoryP`"$RepositoryPassword`"" }

    $objectsXml = $null
    if ($objectList.Count -gt 0) {
        $objectsXml = Join-Path $tempDir "objects.xml"
        Write-ObjectListXml $objectList $IncludeChildObjects.IsPresent $objectsXml
    }

    switch ($Operation) {
        'status' {
            $arguments += "/ConfigurationRepositoryReport `"$ReportFile`""
            $arguments += "-NBegin -1"
            $arguments += "-ReportFormat txt"
        }
        'history' {
            $arguments += "/ConfigurationRepositoryReport `"$ReportFile`""
            if ($BeginVersion -gt 0) { $arguments += "-NBegin $BeginVersion" }
            if ($EndVersion -gt 0) { $arguments += "-NEnd $EndVersion" }
            if ($GroupBy -eq 'object') { $arguments += "-GroupByObject" }
            elseif ($GroupBy -eq 'comment') { $arguments += "-GroupByComment" }
            $arguments += "-ReportFormat txt"
        }
        'diff' {
            $arguments += "/CompareCfg -FirstConfigurationType MainConfiguration -SecondConfigurationType ConfigurationRepository"
            if ($Version -ge 0) { $arguments += "-SecondVersion $Version" }
            if ($objectsXml) { $arguments += "-Objects `"$objectsXml`"" }
            $arguments += "-ReportType Brief -IncludeChangedObjects -IncludeDeletedObjects -IncludeAddedObjects"
            $arguments += "-ReportFormat txt -ReportFile `"$ReportFile`""
        }
        'lock' {
            $arguments += "/ConfigurationRepositoryLock -Objects `"$objectsXml`""
            if ($Revised) { $arguments += "-revised" }
        }
        'update' {
            $arguments += "/ConfigurationRepositoryUpdateCfg"
            if ($Version -ge 0) { $arguments += "-v $Version" }
            $arguments += "-Objects `"$objectsXml`""
            if ($Revised) { $arguments += "-revised" }
            if ($Force) { $arguments += "-force" }
        }
        'commit' {
            $arguments += "/ConfigurationRepositoryCommit -Objects `"$objectsXml`""
            # multi-line comments go as repeated -comment keys; internal quotes
            # escaped the argv way (\") so the platform receives them literally
            foreach ($line in ($Comment.Trim() -replace "`r`n", "`n") -split "`n") {
                $escLine = $line -replace '"', '\"'
                $arguments += "-comment `"$escLine`""
            }
            if ($KeepLocked) { $arguments += "-keepLocked" }
            if ($Force) { $arguments += "-force" }
        }
        'unlock' {
            $arguments += "/ConfigurationRepositoryUnLock -Objects `"$objectsXml`""
            if ($Force) { $arguments += "-force" }
        }
        'dump' {
            $arguments += "/ConfigurationRepositoryDumpCfg `"$OutputFile`""
            if ($Version -ge 0) { $arguments += "-v $Version" }
        }
    }

    if ($Extension -and $Operation -ne 'diff') {
        $arguments += "-Extension `"$Extension`""
    }

    $outFile = Join-Path $tempDir "repo_log.txt"
    $arguments += "/Out `"$outFile`""
    $arguments += "/DisableStartupDialogs"

    # --- Execute ---
    $display = Protect-Secrets ($arguments -join ' ') @($Password, $RepositoryPassword)
    Write-Host "Running: 1cv8.exe $display"
    $run = Invoke-PlatformProcess $V8Path $arguments $TimeoutSeconds
    $exitCode = $run.ExitCode

    if ($run.TimedOut) {
        Write-Host "Error: '$Operation' exceeded $TimeoutSeconds s and the Designer was terminated. The infobase or repository may hold a stale connection — run -Operation status before retrying." -ForegroundColor Red
        Write-PlatformOutput $run.Output
        exit 1
    }

    # --- /Out log: the platform reports here in batch mode, and it can write a
    # failure while still exiting 0 — scan and elevate. ---
    $logContent = Read-PlatformTextFile $outFile
    $fatalLogPatterns = @(
        'Ошибка работы с хранилищем конфигурации',
        'Ошибка соединения с хранилищем конфигурации',
        'Не удалось подключиться к хранилищу',
        'не подключена к хранилищу',
        'Конфигурация не подключена к хранилищу',
        'уже захвачен',
        'не захвачен',
        'Неправильное имя или пароль пользователя',
        'Идентификация пользователя не выполнена',
        'Ошибка формирования отчета',
        'Ошибка сравнения конфигураций',
        'Ошибка обновления конфигурации базы данных',
        'В данной версии не существует указанных объектов'
    )
    $logFailures = @()
    if ($logContent) {
        foreach ($line in ($logContent -split "`r?`n")) {
            foreach ($pat in $fatalLogPatterns) {
                if ($line -match [regex]::Escape($pat)) { $logFailures += $line.Trim(); break }
            }
        }
    }

    if ($exitCode -eq 0 -and $logFailures.Count -gt 0) {
        Write-Host "[error] the /Out log contains $($logFailures.Count) failure line(s) although the platform exited 0:" -ForegroundColor Red
        foreach ($f in $logFailures) { Write-Host "  $f" -ForegroundColor Red }
        $exitCode = 1
    }

    # --- Result ---
    if ($exitCode -eq 0) {
        Write-Host "Repository operation '$Operation' completed successfully" -ForegroundColor Green
        if ($Operation -eq 'dump') {
            if (Test-Path $OutputFile) {
                $size = (Get-Item $OutputFile).Length
                Write-Host "Dump file: $OutputFile ($size bytes)"
            } else {
                Write-Host "[error] the platform exited 0 but $OutputFile was not created" -ForegroundColor Red
                $exitCode = 1
            }
        }
    } else {
        Write-Host "Repository operation '$Operation' failed (code: $exitCode)$(Get-ExitAnnotation $exitCode)" -ForegroundColor Red
    }

    if ($logContent) {
        Write-Host "--- Log (/Out) ---"
        $lt = $logContent.TrimEnd()
        if ($lt.Length -gt 65536) { $lt = "[... обрезано ...]`r`n" + $lt.Substring($lt.Length - 65536) }
        Write-Host $lt
        Write-Host "--- End ---"
    }
    Write-PlatformOutput $run.Output

    # --- Report: print a bounded excerpt, keep the full file for targeted reads ---
    if (($reportOps -contains $Operation) -and $exitCode -eq 0) {
        $report = Read-PlatformTextFile $ReportFile
        if ($null -eq $report) {
            Write-Host "[error] the platform exited 0 but the report file was not created: $ReportFile" -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "Report file: $ReportFile ($($report.Length) chars)"
            Write-Host "--- Report ---"
            if ($report.Length -gt $MaxReportChars) {
                Write-Host $report.Substring(0, $MaxReportChars)
                Write-Host "[... обрезано: показаны первые $MaxReportChars из $($report.Length) символов; полный отчёт — в файле выше ...]"
            } else {
                Write-Host $report
            }
            Write-Host "--- End ---"
        }
    }

    exit $exitCode

} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
