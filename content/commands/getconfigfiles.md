---
description: Extract configuration objects from infobase to files for editing
---

# Выгрузка объектов конфигурации из ИБ в файлы

См. полное описание правила в `content/rules/getconfigfiles.md` (после установки — `.ai-rules/rules/getconfigfiles.md`).

## Параметры

Все пути и идентификаторы — через плейсхолдеры из `.dev.env`. Если значения неизвестны — запросить у пользователя.

| Плейсхолдер | Назначение |
|---|---|
| `{PLATFORM_PATH}` | Каталог установки платформы 1С (содержит `bin\1cv8.exe`) |
| `{INFOBASE_PATH}` | Путь к файловой ИБ или строка подключения |
| `{IB_USER}` | Имя пользователя ИБ |
| `{IB_PASSWORD}` | Пароль (если задан) |
| `{EXPORT_PATH}` | Каталог выгрузки исходников |
| `{EXTENSION_NAME}` | Имя расширения (опустить, если выгружаем из основной конфигурации) |
| `{LOG_PATH}` | Файл лога Designer’а |

## Шаги

1. Сформировать список объектов к выгрузке в `repoobjects.txt` (одно полное имя метаданного объекта на строку). Списки собирать через `metadatasearch` / `search_metadata`.
2. Запустить выгрузку:

```powershell
& '{PLATFORM_PATH}\bin\1cv8.exe' DESIGNER `
    /F '{INFOBASE_PATH}' `
    /N '{IB_USER}' `
    /P '{IB_PASSWORD}' `
    /DisableStartupMessages `
    /DumpConfigToFiles {EXPORT_PATH} `
    -listFile repoobjects.txt `
    -Extension {EXTENSION_NAME} `
    /Out {LOG_PATH}
```

Объекты выгружаются полностью, строго в `{EXPORT_PATH}` — без создания подкаталогов. При выгрузке из основной конфигурации убрать `-Extension {EXTENSION_NAME}`.

3. Проверить `{LOG_PATH}` на ошибки.
