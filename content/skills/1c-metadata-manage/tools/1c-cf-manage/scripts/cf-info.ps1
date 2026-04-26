# cf-info v1.0 — Compact summary of 1C configuration root
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills
param(
	[Parameter(Mandatory=$true)][string]$ConfigPath,
	[ValidateSet("overview","brief","full")]
	[string]$Mode = "overview",
	[int]$Limit = 150,
	[int]$Offset = 0,
	[string]$OutFile
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Output helper (always collect, paginate at the end) ---
$script:lines = @()
function Out([string]$text) { $script:lines += $text }

# --- Resolve path ---
if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
	$ConfigPath = Join-Path (Get-Location).Path $ConfigPath
}

# Directory -> find Configuration.xml
if (Test-Path $ConfigPath -PathType Container) {
	$candidate = Join-Path $ConfigPath "Configuration.xml"
	if (Test-Path $candidate) {
		$ConfigPath = $candidate
	} else {
		Write-Host "[ERROR] No Configuration.xml found in directory: $ConfigPath"
		exit 1
	}
}

if (-not (Test-Path $ConfigPath)) {
	Write-Host "[ERROR] File not found: $ConfigPath"
	exit 1
}

# --- Load XML ---
[xml]$xmlDoc = Get-Content -Path $ConfigPath -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
$ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
$ns.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
$ns.AddNamespace("xr", "http://v8.1c.ru/8.3/xcf/readable")
$ns.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
$ns.AddNamespace("xs", "http://www.w3.org/2001/XMLSchema")
$ns.AddNamespace("app", "http://v8.1c.ru/8.2/managed-application/core")

$mdRoot = $xmlDoc.SelectSingleNode("/md:MetaDataObject", $ns)
if (-not $mdRoot) {
	Write-Host "[ERROR] Not a valid 1C metadata XML file (no MetaDataObject root)"
	exit 1
}

$cfgNode = $mdRoot.SelectSingleNode("md:Configuration", $ns)
if (-not $cfgNode) {
	Write-Host "[ERROR] No <Configuration> element found"
	exit 1
}

$version = $mdRoot.GetAttribute("version")
$propsNode = $cfgNode.SelectSingleNode("md:Properties", $ns)
$childObjNode = $cfgNode.SelectSingleNode("md:ChildObjects", $ns)

# --- Helpers ---
function Get-MLText($node) {
	if (-not $node) { return "" }
	$item = $node.SelectSingleNode("v8:item/v8:content", $ns)
	if ($item -and $item.InnerText) { return $item.InnerText }
	return ""
}

function Get-PropText([string]$propName) {
	$n = $propsNode.SelectSingleNode("md:$propName", $ns)
	if ($n -and $n.InnerText) { return $n.InnerText }
	return ""
}

function Get-PropML([string]$propName) {
	$n = $propsNode.SelectSingleNode("md:$propName", $ns)
	return (Get-MLText $n)
}

# --- Type name maps (canonical order, 44 types) ---
$typeOrder = @(
	"Language","Subsystem","StyleItem","Style",
	"CommonPicture","SessionParameter","Role","CommonTemplate",
	"FilterCriterion","CommonModule","CommonAttribute","ExchangePlan",
	"XDTOPackage","WebService","HTTPService","WSReference",
	"EventSubscription","ScheduledJob","SettingsStorage","FunctionalOption",
	"FunctionalOptionsParameter","DefinedType","CommonCommand","CommandGroup",
	"Constant","CommonForm","Catalog","Document",
	"DocumentNumerator","Sequence","DocumentJournal","Enum",
	"Report","DataProcessor","InformationRegister","AccumulationRegister",
	"ChartOfCharacteristicTypes","ChartOfAccounts","AccountingRegister",
	"ChartOfCalculationTypes","CalculationRegister",
	"BusinessProcess","Task","IntegrationService"
)

$typeRuNames = @{
	"Language"="Языки"; "Subsystem"="Подсистемы"; "StyleItem"="Элементы стиля"; "Style"="Стили"
	"CommonPicture"="Общие картинки"; "SessionParameter"="Параметры сеанса"; "Role"="Роли"
	"CommonTemplate"="Общие макеты"; "FilterCriterion"="Критерии отбора"; "CommonModule"="Общие модули"
	"CommonAttribute"="Общие реквизиты"; "ExchangePlan"="Планы обмена"; "XDTOPackage"="XDTO-пакеты"
	"WebService"="Веб-сервисы"; "HTTPService"="HTTP-сервисы"; "WSReference"="WS-ссылки"
	"EventSubscription"="Подписки на события"; "ScheduledJob"="Регламентные задания"
	"SettingsStorage"="Хранилища настроек"; "FunctionalOption"="Функциональные опции"
	"FunctionalOptionsParameter"="Параметры ФО"; "DefinedType"="Определяемые типы"
	"CommonCommand"="Общие команды"; "CommandGroup"="Группы команд"; "Constant"="Константы"
	"CommonForm"="Общие формы"; "Catalog"="Справочники"; "Document"="Документы"
	"DocumentNumerator"="Нумераторы"; "Sequence"="Последовательности"; "DocumentJournal"="Журналы документов"
	"Enum"="Перечисления"; "Report"="Отчёты"; "DataProcessor"="Обработки"
	"InformationRegister"="Регистры сведений"; "AccumulationRegister"="Регистры накопления"
	"ChartOfCharacteristicTypes"="ПВХ"; "ChartOfAccounts"="Планы счетов"
	"AccountingRegister"="Регистры бухгалтерии"; "ChartOfCalculationTypes"="ПВР"
	"CalculationRegister"="Регистры расчёта"; "BusinessProcess"="Бизнес-процессы"
	"Task"="Задачи"; "IntegrationService"="Сервисы интеграции"
}

# --- Count objects in ChildObjects ---
$objectCounts = [ordered]@{}
$totalObjects = 0

if ($childObjNode) {
	foreach ($child in $childObjNode.ChildNodes) {
		if ($child.NodeType -ne 'Element') { continue }
		$typeName = $child.LocalName
		if (-not $objectCounts.Contains($typeName)) {
			$objectCounts[$typeName] = 0
		}
		$objectCounts[$typeName] = $objectCounts[$typeName] + 1
		$totalObjects++
	}
}

# --- Read key properties ---
$cfgName = Get-PropText "Name"
$cfgSynonym = Get-PropML "Synonym"
$cfgVersion = Get-PropText "Version"
$cfgVendor = Get-PropText "Vendor"
$cfgCompat = Get-PropText "CompatibilityMode"
$cfgExtCompat = Get-PropText "ConfigurationExtensionCompatibilityMode"
$cfgDefaultRun = Get-PropText "DefaultRunMode"
$cfgScript = Get-PropText "ScriptVariant"
$cfgDefaultLang = Get-PropText "DefaultLanguage"
$cfgDataLock = Get-PropText "DataLockControlMode"
$dash = [char]0x2014
$cfgModality = Get-PropText "ModalityUseMode"
$cfgIntfCompat = Get-PropText "InterfaceCompatibilityMode"
$cfgAutoNum = Get-PropText "ObjectAutonumerationMode"
$cfgSyncCalls = Get-PropText "SynchronousPlatformExtensionAndAddInCallUseMode"
$cfgDbSpaces = Get-PropText "DatabaseTablespacesUseMode"
$cfgWindowMode = Get-PropText "MainClientApplicationWindowMode"

# --- BRIEF mode ---
if ($Mode -eq "brief") {
	$synPart = if ($cfgSynonym) { " $dash `"$cfgSynonym`"" } else { "" }
	$verPart = if ($cfgVersion) { " v$cfgVersion" } else { "" }
	$compatPart = if ($cfgCompat) { " | $cfgCompat" } else { "" }
	Out "Конфигурация: ${cfgName}${synPart}${verPart} | $totalObjects объектов${compatPart}"
}

# --- OVERVIEW mode ---
if ($Mode -eq "overview") {
	$synPart = if ($cfgSynonym) { " $dash `"$cfgSynonym`"" } else { "" }
	$verPart = if ($cfgVersion) { " v$cfgVersion" } else { "" }
	Out "=== Конфигурация: ${cfgName}${synPart}${verPart} ==="
	Out ""

	# Key properties
	Out "Формат:         $version"
	if ($cfgVendor)     { Out "Поставщик:      $cfgVendor" }
	if ($cfgVersion)    { Out "Версия:         $cfgVersion" }
	Out "Совместимость:  $cfgCompat"
	Out "Режим запуска:  $cfgDefaultRun"
	Out "Язык скриптов:  $cfgScript"
	Out "Язык:           $cfgDefaultLang"
	Out "Блокировки:     $cfgDataLock"
	Out "Модальность:    $cfgModality"
	Out "Интерфейс:      $cfgIntfCompat"
	Out ""

	# Object counts table
	Out "--- Состав ($totalObjects объектов) ---"
	Out ""
	$maxTypeLen = 0
	foreach ($typeName in $typeOrder) {
		if ($objectCounts.Contains($typeName)) {
			$ruName = $typeRuNames[$typeName]
			if ($ruName.Length -gt $maxTypeLen) { $maxTypeLen = $ruName.Length }
		}
	}
	if ($maxTypeLen -lt 10) { $maxTypeLen = 10 }

	foreach ($typeName in $typeOrder) {
		if ($objectCounts.Contains($typeName)) {
			$count = $objectCounts[$typeName]
			$ruName = $typeRuNames[$typeName]
			$padded = $ruName.PadRight($maxTypeLen)
			Out "  $padded  $count"
		}
	}
}

# --- FULL mode ---
if ($Mode -eq "full") {
	$synPart = if ($cfgSynonym) { " $dash `"$cfgSynonym`"" } else { "" }
	$verPart = if ($cfgVersion) { " v$cfgVersion" } else { "" }
	Out "=== Конфигурация: ${cfgName}${synPart}${verPart} ==="
	Out ""

	# --- Section: Identification ---
	Out "--- Идентификация ---"
	Out "UUID:           $($cfgNode.GetAttribute('uuid'))"
	Out "Имя:            $cfgName"
	if ($cfgSynonym)  { Out "Синоним:        $cfgSynonym" }
	$cfgComment = Get-PropText "Comment"
	if ($cfgComment)  { Out "Комментарий:    $cfgComment" }
	$cfgPrefix = Get-PropText "NamePrefix"
	if ($cfgPrefix)   { Out "Префикс:        $cfgPrefix" }
	if ($cfgVendor)   { Out "Поставщик:      $cfgVendor" }
	if ($cfgVersion)  { Out "Версия:         $cfgVersion" }
	$cfgUpdateAddr = Get-PropText "UpdateCatalogAddress"
	if ($cfgUpdateAddr) { Out "Каталог обн.:   $cfgUpdateAddr" }
	Out ""

	# --- Section: Modes ---
	Out "--- Режимы работы ---"
	Out "Формат:              $version"
	Out "Совместимость:       $cfgCompat"
	Out "Совм. расширений:    $cfgExtCompat"
	Out "Режим запуска:       $cfgDefaultRun"
	Out "Язык скриптов:       $cfgScript"
	Out "Блокировки:          $cfgDataLock"
	Out "Автонумерация:       $cfgAutoNum"
	Out "Модальность:         $cfgModality"
	Out "Синхр. вызовы:       $cfgSyncCalls"
	Out "Интерфейс:           $cfgIntfCompat"
	Out "Табл. пространства:  $cfgDbSpaces"
	Out "Режим окна:          $cfgWindowMode"
	Out ""

	# --- Section: Language, roles, purposes ---
	Out "--- Назначение ---"
	Out "Язык по умолч.:  $cfgDefaultLang"

	# UsePurposes
	$purposeNode = $propsNode.SelectSingleNode("md:UsePurposes", $ns)
	if ($purposeNode) {
		$purposes = @()
		foreach ($val in $purposeNode.SelectNodes("v8:Value", $ns)) {
			$purposes += $val.InnerText
		}
		if ($purposes.Count -gt 0) { Out "Назначения:      $($purposes -join ', ')" }
	}

	# DefaultRoles
	$rolesNode = $propsNode.SelectSingleNode("md:DefaultRoles", $ns)
	if ($rolesNode) {
		$roles = @()
		foreach ($item in $rolesNode.SelectNodes("xr:Item", $ns)) {
			$roles += $item.InnerText
		}
		if ($roles.Count -gt 0) {
			Out "Роли по умолч.:  $($roles.Count)"
			foreach ($r in $roles) { Out "  - $r" }
		}
	}

	# Booleans
	$useMF = Get-PropText "UseManagedFormInOrdinaryApplication"
	$useOF = Get-PropText "UseOrdinaryFormInManagedApplication"
	Out "Управл.формы в обычн.: $useMF"
	Out "Обычн.формы в управл.: $useOF"
	Out ""

	# --- Section: Storages & default forms ---
	Out "--- Хранилища и формы по умолчанию ---"
	$storageProps = @("CommonSettingsStorage","ReportsUserSettingsStorage","ReportsVariantsStorage","FormDataSettingsStorage","DynamicListsUserSettingsStorage","URLExternalDataStorage")
	foreach ($sp in $storageProps) {
		$val = Get-PropText $sp
		if ($val) { Out "  ${sp}: $val" }
	}
	$formProps = @("DefaultReportForm","DefaultReportVariantForm","DefaultReportSettingsForm","DefaultReportAppearanceTemplate","DefaultDynamicListSettingsForm","DefaultSearchForm","DefaultDataHistoryChangeHistoryForm","DefaultDataHistoryVersionDataForm","DefaultDataHistoryVersionDifferencesForm","DefaultCollaborationSystemUsersChoiceForm","DefaultConstantsForm","DefaultInterface","DefaultStyle")
	foreach ($fp in $formProps) {
		$val = Get-PropText $fp
		if ($val) { Out "  ${fp}: $val" }
	}
	Out ""

	# --- Section: Info ---
	$cfgBrief = Get-PropML "BriefInformation"
	$cfgDetail = Get-PropML "DetailedInformation"
	$cfgCopyright = Get-PropML "Copyright"
	$cfgVendorAddr = Get-PropML "VendorInformationAddress"
	$cfgInfoAddr = Get-PropML "ConfigurationInformationAddress"
	if ($cfgBrief -or $cfgDetail -or $cfgCopyright -or $cfgVendorAddr -or $cfgInfoAddr) {
		Out "--- Информация ---"
		if ($cfgBrief)      { Out "Краткая:         $cfgBrief" }
		if ($cfgDetail)     { Out "Подробная:       $cfgDetail" }
		if ($cfgCopyright)  { Out "Copyright:       $cfgCopyright" }
		if ($cfgVendorAddr) { Out "Сайт поставщика: $cfgVendorAddr" }
		if ($cfgInfoAddr)   { Out "Адрес информ.:   $cfgInfoAddr" }
		Out ""
	}

	# --- Section: Mobile functionalities ---
	$mobileFunc = $propsNode.SelectSingleNode("md:UsedMobileApplicationFunctionalities", $ns)
	if ($mobileFunc) {
		$enabledFuncs = @()
		$disabledFuncs = @()
		foreach ($func in $mobileFunc.SelectNodes("app:functionality", $ns)) {
			$fName = $func.SelectSingleNode("app:functionality", $ns)
			$fUse = $func.SelectSingleNode("app:use", $ns)
			if ($fName -and $fUse) {
				if ($fUse.InnerText -eq "true") {
					$enabledFuncs += $fName.InnerText
				} else {
					$disabledFuncs += $fName.InnerText
				}
			}
		}
		$totalFunc = $enabledFuncs.Count + $disabledFuncs.Count
		Out "--- Мобильные функциональности ($totalFunc, включено: $($enabledFuncs.Count)) ---"
		if ($enabledFuncs.Count -gt 0) {
			foreach ($f in $enabledFuncs) { Out "  [+] $f" }
		}
		foreach ($f in $disabledFuncs) { Out "  [-] $f" }
		Out ""
	}

	# --- Section: InternalInfo ---
	$internalInfo = $cfgNode.SelectSingleNode("md:InternalInfo", $ns)
	if ($internalInfo) {
		$contained = $internalInfo.SelectNodes("xr:ContainedObject", $ns)
		Out "--- InternalInfo ($($contained.Count) ContainedObject) ---"
		foreach ($co in $contained) {
			$classId = $co.SelectSingleNode("xr:ClassId", $ns).InnerText
			$objectId = $co.SelectSingleNode("xr:ObjectId", $ns).InnerText
			Out "  $classId -> $objectId"
		}
		Out ""
	}

	# --- Section: ChildObjects (full list) ---
	Out "--- Состав ($totalObjects объектов) ---"
	Out ""

	foreach ($typeName in $typeOrder) {
		if (-not $objectCounts.Contains($typeName)) { continue }
		$count = $objectCounts[$typeName]
		$ruName = $typeRuNames[$typeName]
		Out "  $ruName ($typeName): $count"

		# Collect names for this type
		$names = @()
		foreach ($child in $childObjNode.ChildNodes) {
			if ($child.NodeType -eq 'Element' -and $child.LocalName -eq $typeName) {
				$names += $child.InnerText
			}
		}
		foreach ($n in $names) { Out "    $n" }
	}
}

# --- Pagination and output ---
$total = $script:lines.Count
if ($Offset -gt 0 -or $Limit -lt $total) {
	$start = [Math]::Min($Offset, $total)
	$end = [Math]::Min($start + $Limit, $total)
	$page = $script:lines[$start..($end - 1)]
	$result = ($page -join "`n")
	if ($end -lt $total) {
		$result += "`n`n... ($end of $total lines, use -Offset $end to continue)"
	}
} else {
	$result = ($script:lines -join "`n")
}

Write-Host $result

if ($OutFile) {
	$utf8Bom = New-Object System.Text.UTF8Encoding $true
	[System.IO.File]::WriteAllText($OutFile, $result, $utf8Bom)
	Write-Host "`nWritten to: $OutFile"
}
