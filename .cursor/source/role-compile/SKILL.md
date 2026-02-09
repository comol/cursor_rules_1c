---
name: role-compile
description: Создание роли 1С — метаданные и Rights.xml из описания прав
argument-hint: <RoleName> <RolesDir>
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
---

# /role-compile — создание роли 1С

Создаёт файлы роли (метаданные + Rights.xml) по описанию прав. Скрипта нет — агент генерирует XML по шаблонам ниже.

## Использование

```
/role-compile <RoleName> <RolesDir>
```

- **RoleName** — программное имя роли
- **RolesDir** — каталог `Roles/` в исходниках конфигурации

## Файловая структура и регистрация

```
Roles/
  ИмяРоли.xml           ← метаданные (uuid, имя, синоним)
  ИмяРоли/
    Ext/
      Rights.xml         ← определение прав
```

В `Configuration.xml` добавить `<Role>ИмяРоли</Role>` в секцию `<ChildObjects>`.

## Шаблон метаданных: Roles/ИмяРоли.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses"
        xmlns:v8="http://v8.1c.ru/8.1/data/core"
        xmlns:xr="http://v8.1c.ru/8.3/xcf/readable"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        version="2.17">
    <Role uuid="GENERATE-UUID-HERE">
        <Properties>
            <Name>ИмяРоли</Name>
            <Synonym>
                <v8:item>
                    <v8:lang>ru</v8:lang>
                    <v8:content>Отображаемое имя роли</v8:content>
                </v8:item>
            </Synonym>
            <Comment/>
        </Properties>
    </Role>
</MetaDataObject>
```

**UUID:** `powershell.exe -Command "[guid]::NewGuid().ToString()"`

## Шаблон прав: Roles/ИмяРоли/Ext/Rights.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Rights xmlns="http://v8.1c.ru/8.2/roles"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:type="Rights" version="2.17">
    <setForNewObjects>false</setForNewObjects>
    <setForAttributesByDefault>true</setForAttributesByDefault>
    <independentRightsOfChildObjects>false</independentRightsOfChildObjects>
    <!-- блоки <object> -->
</Rights>
```

NB: namespace `http://v8.1c.ru/8.2/roles` (исторически 8.2, не 8.3).

## Формат блока прав

```xml
<object>
    <name>Catalog.Номенклатура</name>
    <right><name>Read</name><value>true</value></right>
    <right><name>View</name><value>true</value></right>
</object>
```

Имя объекта — dot-нотация: `ТипОбъекта.Имя[.ТипВложенного.ИмяВложенного]`.

## Практические наборы прав

### Catalog / ExchangePlan

| Набор | Права |
|-------|-------|
| Чтение | Read, View, InputByString |
| Полные | Read, Insert, Update, Delete, View, Edit, InputByString, InteractiveInsert, InteractiveSetDeletionMark, InteractiveClearDeletionMark |

### Document

| Набор | Права |
|-------|-------|
| Чтение | Read, View, InputByString |
| Полные | Read, Insert, Update, Delete, View, Edit, InputByString, Posting, UndoPosting, InteractiveInsert, InteractiveSetDeletionMark, InteractiveClearDeletionMark, InteractivePosting, InteractivePostingRegular, InteractiveUndoPosting, InteractiveChangeOfPosted |

### InformationRegister / AccumulationRegister / AccountingRegister

| Набор | Права |
|-------|-------|
| Чтение | Read, View |
| Полные | Read, Update, View, Edit |

TotalsControl — только для управления итогами, обычно не нужно.

### Простые типы

| Тип | Права |
|-----|-------|
| `DataProcessor` / `Report` | Use, View |
| `Constant` | Read, Update, View, Edit (чтение: Read, View) |
| `CommonForm` / `CommonCommand` / `Subsystem` / `FilterCriterion` | View |
| `DocumentJournal` | Read, View |
| `Sequence` | Read, Update |
| `SessionParameter` | Get (+ Set если пишет) |
| `CommonAttribute` | View (+ Edit если редактирует) |
| `WebService` / `HTTPService` / `IntegrationService` | Use |
| `CalculationRegister` | Read, View |

### Редкие ссылочные типы

| Тип | Особенности (относительно Catalog) |
|-----|-------|
| `ChartOfAccounts`, `ChartOfCharacteristicTypes`, `ChartOfCalculationTypes` | + Predefined-права (InteractiveDeletePredefinedData и др.) |
| `BusinessProcess` | + Start, InteractiveStart, InteractiveActivate |
| `Task` | + Execute, InteractiveExecute, InteractiveActivate |

### Типы БЕЗ прав в ролях

Enum, FunctionalOption, DefinedType, CommonModule, CommonPicture, CommonTemplate — не фигурируют в Rights.xml.

### Вложенные объекты (права: View, Edit)

```
Catalog.Контрагенты.Attribute.ИНН
Document.Реализация.StandardAttribute.Posted
Document.Реализация.TabularSection.Товары
InformationRegister.Цены.Dimension.Номенклатура
InformationRegister.Цены.Resource.Цена
Catalog.Контрагенты.Command.ОткрытьКарточку          ← только View
Task.Задача.AddressingAttribute.Исполнитель
```

Используются для точечного запрета: `<value>false</value>` на конкретный реквизит.

### Configuration

Объект: `Configuration.ИмяКонфигурации`. Ключевые права: Administration, DataAdministration, ThinClient, WebClient, ThickClient, MobileClient, ExternalConnection, Output, SaveUserData, InteractiveOpenExtDataProcessors, InteractiveOpenExtReports, MainWindowModeNormal, MainWindowModeWorkplace, MainWindowModeEmbeddedWorkplace, MainWindowModeFullscreenWorkplace, MainWindowModeKiosk, AnalyticsSystemClient.

> DataHistory-права (ReadDataHistory, UpdateDataHistory и др.) существуют у Catalog, Document, Register, Constant — но используются крайне редко, в типовых ролях практически не встречаются.

## RLS (ограничения на уровне записей)

Внутрь `<right>`, после `<value>`. Применяется к Read, Update, Insert, Delete.

```xml
<right>
    <name>Read</name>
    <value>true</value>
    <restrictionByCondition>
        <condition>#ИмяШаблона("Параметр1", "Параметр2")</condition>
    </restrictionByCondition>
</right>
```

Шаблоны — в конце Rights.xml, после всех `<object>`:

```xml
<restrictionTemplate>
    <name>ИмяШаблона(Параметр1, Параметр2)</name>
    <condition>Текст шаблона</condition>
</restrictionTemplate>
```

`&` в условии → `&amp;`. Типичные шаблоны: ДляОбъекта, ПоЗначениям, ДляРегистра.

## Пример: роль для регламентного задания

```xml
<object>
    <name>Catalog.Валюты</name>
    <right><name>Read</name><value>true</value></right>
</object>
<object>
    <name>InformationRegister.КурсыВалют</name>
    <right><name>Read</name><value>true</value></right>
    <right><name>Update</name><value>true</value></right>
</object>
<object>
    <name>Constant.ОсновнаяВалюта</name>
    <right><name>Read</name><value>true</value></right>
</object>
```

Фоновые задания не требуют Interactive/View/Edit-прав и прав конфигурации (ThinClient, WebClient и др.) — только программные (Read, Insert, Update, Delete, Posting).
