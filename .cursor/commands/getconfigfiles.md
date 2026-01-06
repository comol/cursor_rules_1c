# get files from infobase
## to get files from infobase to modify it's code or metadata please use following commands:
commands:

**Step 1 - Load config to base:**

```powershell
& 'C:\Program Files\1cv8\8.3.23.1997\bin\1cv8.exe' DESIGNER /F 'C:\Users\filippov.o\Documents\1C\DemoHRMCorp1' /N'Савинская З.Ю. (Системный программист)' /DisableStartupMessages /DumpConfigToFiles E:\AgenticTest -listFile repoobjects.txt -Extension OneAPA /Out E:\Temp\Update.log
```

Выгружай объекты полностью. Строго в текущий каталог - не создавая нового подкаталога.

Предварительно внеси объекты к выгрузке в файл repoobjects.txt

# Использование инструментов
**search_metadata** нужно использовать для получения списков объектов метаданных необходимых для загрузки в репозиторий