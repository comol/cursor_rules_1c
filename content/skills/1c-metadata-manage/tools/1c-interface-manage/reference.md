# /interface-edit — редактирование CommandInterface.xml

Точечное редактирование файла командного интерфейса подсистемы 1С.

## Параметры

| Параметр | Описание |
|----------|----------|
| CIPath | Путь к CommandInterface.xml |
| DefinitionFile | JSON-файл с массивом операций |
| Operation | Одна операция: hide, show, place, order, subsystem-order, group-order |
| Value | Значение для операции |
| CreateIfMissing | Создать файл если не существует |
| NoValidate | Пропустить авто-валидацию |

## Операции

| Операция | Значение | Описание |
|----------|----------|----------|
| hide | Cmd.Name или массив | Скрыть команду (CommandsVisibility, false) |
| show | Cmd.Name или массив | Показать команду (visibility, true) |
| place | {"command":"...","group":"CommandGroup.X"} | Разместить команду в группе |
| order | {"group":"...","commands":[...]} | Задать порядок команд в группе |
| subsystem-order | ["Subsystem.X.Subsystem.A",...] | Порядок дочерних подсистем |
| group-order | ["NavigationPanelOrdinary",...] | Порядок групп |

## Примеры

```powershell
# Скрыть команду
... -CIPath Subsystems/Продажи/Ext/CommandInterface.xml -Operation hide -Value "Catalog.Товары.StandardCommand.OpenList"

# Показать команду
... -Operation show -Value "Report.Продажи.Command.Отчёт"

# Разместить в группе
... -Operation place -Value '{"command":"Report.X.Command.Y","group":"CommandGroup.Отчеты"}'

# Задать порядок подсистем
... -Operation subsystem-order -Value '["Subsystem.X.Subsystem.A","Subsystem.X.Subsystem.B"]'

# Создать новый CI
... -CIPath <new-path> -Operation subsystem-order -Value '[...]' -CreateIfMissing
```

## Авто-валидация

После каждой операции автоматически запускается `/interface-validate`. Подавить: `-NoValidate`.
