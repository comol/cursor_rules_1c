# MetadataAddress.ps1 — logical 1C metadata addresses to physical dump paths.
#
# The vendored tools address a Designer XML dump by file path: the caller has to
# know that `Справочник.Контрагенты` lives in `Catalogs\Контрагенты.xml` and that
# its form is `Catalogs\Контрагенты\Forms\ФормаЭлемента\Ext\Form.xml`. The MCP
# servers of this toolkit already speak the logical name (`object_name`), so the
# two halves of one task used two addressing schemes. This file is the bridge:
# one logical address, resolved the same way everywhere.
#
# Dot-sourced (`. (Join-Path $PSScriptRoot 'MetadataAddress.ps1')`) — same
# self-contained patch style as DevEnv.ps1, so an upstream sync has nothing to
# merge here.
#
# Address grammar:
#   <Kind>.<Name>                      -> the object's own XML
#   <Kind>.<Name>.Форма.<FormName>     -> Forms\<FormName>\Ext\Form.xml
#   <Kind>.<Name>.Макет.<TemplateName> -> Templates\<TemplateName>\Ext\Template.xml
#   <Kind>.<Name>.Права                -> Ext\Rights.xml (roles)
#   <Kind>.<Name>.МодульОбъекта        -> Ext\ObjectModule.bsl
#   <Kind>.<Name>.МодульМенеджера      -> Ext\ManagerModule.bsl
#   Kind, and every segment keyword, may be written in Russian or English.

$script:OneCKindFolders = [ordered]@{
    'Справочник'                      = 'Catalogs'
    'Catalog'                         = 'Catalogs'
    'Документ'                        = 'Documents'
    'Document'                        = 'Documents'
    'ЖурналДокументов'                = 'DocumentJournals'
    'DocumentJournal'                 = 'DocumentJournals'
    'Перечисление'                    = 'Enums'
    'Enum'                            = 'Enums'
    'Отчет'                           = 'Reports'
    'Отчёт'                           = 'Reports'
    'Report'                          = 'Reports'
    'Обработка'                       = 'DataProcessors'
    'DataProcessor'                   = 'DataProcessors'
    'ПланВидовХарактеристик'          = 'ChartsOfCharacteristicTypes'
    'ChartOfCharacteristicTypes'      = 'ChartsOfCharacteristicTypes'
    'ПланСчетов'                      = 'ChartsOfAccounts'
    'ChartOfAccounts'                 = 'ChartsOfAccounts'
    'ПланВидовРасчета'                = 'ChartsOfCalculationTypes'
    'ПланВидовРасчёта'                = 'ChartsOfCalculationTypes'
    'ChartOfCalculationTypes'         = 'ChartsOfCalculationTypes'
    'РегистрСведений'                 = 'InformationRegisters'
    'InformationRegister'             = 'InformationRegisters'
    'РегистрНакопления'               = 'AccumulationRegisters'
    'AccumulationRegister'            = 'AccumulationRegisters'
    'РегистрБухгалтерии'              = 'AccountingRegisters'
    'AccountingRegister'              = 'AccountingRegisters'
    'РегистрРасчета'                  = 'CalculationRegisters'
    'РегистрРасчёта'                  = 'CalculationRegisters'
    'CalculationRegister'             = 'CalculationRegisters'
    'БизнесПроцесс'                   = 'BusinessProcesses'
    'BusinessProcess'                 = 'BusinessProcesses'
    'Задача'                          = 'Tasks'
    'Task'                            = 'Tasks'
    'Константа'                       = 'Constants'
    'Constant'                        = 'Constants'
    'ОбщийМодуль'                     = 'CommonModules'
    'CommonModule'                    = 'CommonModules'
    'Подсистема'                      = 'Subsystems'
    'Subsystem'                       = 'Subsystems'
    'Роль'                            = 'Roles'
    'Role'                            = 'Roles'
    'ОбщаяФорма'                      = 'CommonForms'
    'CommonForm'                      = 'CommonForms'
    'ОбщийМакет'                      = 'CommonTemplates'
    'CommonTemplate'                  = 'CommonTemplates'
    'ОбщаяКоманда'                    = 'CommonCommands'
    'CommonCommand'                   = 'CommonCommands'
    'ГруппаКоманд'                    = 'CommandGroups'
    'CommandGroup'                    = 'CommandGroups'
    'ОбщийРеквизит'                   = 'CommonAttributes'
    'CommonAttribute'                 = 'CommonAttributes'
    'ОбщаяКартинка'                   = 'CommonPictures'
    'CommonPicture'                   = 'CommonPictures'
    'ПланОбмена'                      = 'ExchangePlans'
    'ExchangePlan'                    = 'ExchangePlans'
    'КритерийОтбора'                  = 'FilterCriteria'
    'FilterCriterion'                 = 'FilterCriteria'
    'ПодпискаНаСобытие'               = 'EventSubscriptions'
    'EventSubscription'               = 'EventSubscriptions'
    'РегламентноеЗадание'             = 'ScheduledJobs'
    'ScheduledJob'                    = 'ScheduledJobs'
    'ФункциональнаяОпция'             = 'FunctionalOptions'
    'FunctionalOption'                = 'FunctionalOptions'
    'ПараметрФункциональныхОпций'     = 'FunctionalOptionsParameters'
    'FunctionalOptionsParameter'      = 'FunctionalOptionsParameters'
    'ОпределяемыйТип'                 = 'DefinedTypes'
    'DefinedType'                     = 'DefinedTypes'
    'ПараметрСеанса'                  = 'SessionParameters'
    'SessionParameter'                = 'SessionParameters'
    'HTTPСервис'                      = 'HTTPServices'
    'HTTPService'                     = 'HTTPServices'
    'WebСервис'                       = 'WebServices'
    'WebService'                      = 'WebServices'
    'XDTOПакет'                       = 'XDTOPackages'
    'XDTOPackage'                     = 'XDTOPackages'
    'ХранилищеНастроек'               = 'SettingsStorages'
    'SettingsStorage'                 = 'SettingsStorages'
    'Последовательность'              = 'Sequences'
    'Sequence'                        = 'Sequences'
    'ВнешнийИсточникДанных'           = 'ExternalDataSources'
    'ExternalDataSource'              = 'ExternalDataSources'
    'Стиль'                           = 'Styles'
    'Style'                           = 'Styles'
    'ЭлементСтиля'                    = 'StyleItems'
    'StyleItem'                       = 'StyleItems'
    'Язык'                            = 'Languages'
    'Language'                        = 'Languages'
}

$script:OneCMemberKeywords = @{
    'Форма'          = 'form'
    'Form'           = 'form'
    'Макет'          = 'template'
    'Template'       = 'template'
    'Права'          = 'rights'
    'Rights'         = 'rights'
    'МодульОбъекта'  = 'objectmodule'
    'ObjectModule'   = 'objectmodule'
    'МодульМенеджера' = 'managermodule'
    'ManagerModule'  = 'managermodule'
    'МодульНабораЗаписей' = 'recordsetmodule'
    'RecordSetModule' = 'recordsetmodule'
}

function Resolve-1CDumpRoot {
    # Configuration dump root: explicit -Root, then EXPORT_PATH from .dev.env,
    # then the nearest ancestor holding a Configuration.xml. Returns $null when
    # none of the three answers - the caller reports that, never guesses.
    param([string]$Root)

    if ($Root) {
        $full = [System.IO.Path]::GetFullPath($Root)
        if (Test-Path -LiteralPath (Join-Path $full 'Configuration.xml')) { return $full }
        if (Test-Path -LiteralPath $full -PathType Container) { return $full }
        return $null
    }

    $fromEnv = ''
    if (Get-Command Get-1CDevEnvValue -ErrorAction SilentlyContinue) {
        $fromEnv = Get-1CDevEnvValue 'EXPORT_PATH'
    }
    if ($fromEnv) {
        $candidate = if ([System.IO.Path]::IsPathRooted($fromEnv)) { $fromEnv } else { Join-Path (Get-Location).Path $fromEnv }
        if (Test-Path -LiteralPath $candidate -PathType Container) { return [System.IO.Path]::GetFullPath($candidate) }
    }

    $dir = (Get-Location).Path
    for ($i = 0; $i -lt 20 -and $dir; $i++) {
        if (Test-Path -LiteralPath (Join-Path $dir 'Configuration.xml')) { return $dir }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Resolve-1CObjectPath {
    # Logical address -> physical path inside the dump. Throws with the list of
    # accepted kinds when the kind is unknown: a wrong path silently pointing at
    # nothing is the failure mode this exists to remove.
    param(
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $parts = @($Address -split '\.' | Where-Object { $_ -ne '' })
    if ($parts.Count -lt 2) {
        throw "Address '$Address' is not <Kind>.<Name>, e.g. Справочник.Контрагенты."
    }

    $kind = $parts[0]
    if (-not $script:OneCKindFolders.Contains($kind)) {
        $known = ($script:OneCKindFolders.Keys | Sort-Object) -join ', '
        throw "Unknown metadata kind '$kind'. Accepted: $known"
    }
    $folder = $script:OneCKindFolders[$kind]
    $name = $parts[1]
    $objectDir = Join-Path (Join-Path $Root $folder) $name
    $objectXml = Join-Path (Join-Path $Root $folder) "$name.xml"

    if ($parts.Count -eq 2) { return $objectXml }

    $member = $parts[2]
    if (-not $script:OneCMemberKeywords.ContainsKey($member)) {
        $known = ($script:OneCMemberKeywords.Keys | Sort-Object) -join ', '
        throw "Unknown member '$member' in '$Address'. Accepted: $known"
    }
    $memberKind = $script:OneCMemberKeywords[$member]
    $memberName = if ($parts.Count -ge 4) { $parts[3] } else { $null }

    switch ($memberKind) {
        'form' {
            if (-not $memberName) { throw "'$Address' needs a form name: <Kind>.<Name>.Форма.<FormName>." }
            return (Join-Path $objectDir (Join-Path 'Forms' (Join-Path $memberName (Join-Path 'Ext' 'Form.xml'))))
        }
        'template' {
            if (-not $memberName) { throw "'$Address' needs a template name: <Kind>.<Name>.Макет.<TemplateName>." }
            return (Join-Path $objectDir (Join-Path 'Templates' (Join-Path $memberName (Join-Path 'Ext' 'Template.xml'))))
        }
        'rights'          { return (Join-Path $objectDir (Join-Path 'Ext' 'Rights.xml')) }
        'objectmodule'    { return (Join-Path $objectDir (Join-Path 'Ext' 'ObjectModule.bsl')) }
        'managermodule'   { return (Join-Path $objectDir (Join-Path 'Ext' 'ManagerModule.bsl')) }
        'recordsetmodule' { return (Join-Path $objectDir (Join-Path 'Ext' 'RecordSetModule.bsl')) }
    }
    throw "Cannot resolve '$Address'."
}

function Get-1CWatchPaths {
    # What a run against this target may touch: the file itself, the object's
    # own folder (forms, templates, modules live there) and the root
    # Configuration.xml, which every registering tool rewrites.
    param([Parameter(Mandatory = $true)][string]$TargetPath)

    $paths = @($TargetPath)

    $dir = Split-Path $TargetPath -Parent
    $leaf = [System.IO.Path]::GetFileNameWithoutExtension($TargetPath)
    $sibling = Join-Path $dir $leaf
    if (Test-Path -LiteralPath $sibling -PathType Container) { $paths += $sibling }

    $probe = $dir
    for ($i = 0; $i -lt 12 -and $probe; $i++) {
        $cfg = Join-Path $probe 'Configuration.xml'
        if (Test-Path -LiteralPath $cfg) {
            $paths += $cfg
            $objectRoot = Join-Path (Split-Path $TargetPath -Parent) $leaf
            if (Test-Path -LiteralPath $objectRoot -PathType Container) { $paths += $objectRoot }
            break
        }
        $parent = Split-Path $probe -Parent
        if (-not $parent -or $parent -eq $probe) { break }
        $probe = $parent
    }

    return @($paths | Where-Object { $_ } | Sort-Object -Unique)
}
