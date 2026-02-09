---
name: 1c-batch
description: Пакетные операции с платформой 1С:Предприятие 8. Сборка/разборка внешних обработок (.epf/.erf) в XML, загрузка/выгрузка конфигураций и расширений, запуск предприятия и конфигуратора. Используй когда нужно: (1) собрать или разобрать обработку/отчёт, (2) загрузить или выгрузить конфигурацию в XML, (3) работать с расширениями 1С, (4) запустить 1С:Предприятие или конфигуратор.
---

# 1c-batch

Пакетные операции с платформой 1С.

## Запуск скриптов

Скрипты: `.claude/skills/1c-batch/scripts/`

Запускать **из корня проекта**:

```bash
.claude/skills/1c-batch/scripts/build-epf.bat src/epf/МояОбработка.xml build/МояОбработка.epf
```

---

## Работа с обработками

### build-epf.bat — сборка обработки из XML

```bat
.claude/skills/1c-batch/scripts/build-epf.bat <XML_FILE> <OUTPUT_FILE>
```

- `XML_FILE` — корневой XML-файл обработки
- `OUTPUT_FILE` — путь к результирующему файлу `.epf` или `.erf`

### dump-epf.bat — разборка обработки в XML

```bat
.claude/skills/1c-batch/scripts/dump-epf.bat <XML_FILE> <EPF_FILE>
```

- `XML_FILE` — корневой XML-файл для выгрузки (папка создастся автоматически)
- `EPF_FILE` — путь к исходной обработке `.epf` или `.erf`

---

## Работа с конфигурацией

### load-config.bat — загрузка конфигурации из XML

```bat
.claude/skills/1c-batch/scripts/load-config.bat <XML_DIR> [FILES] [skipdbupdate]
```

- `XML_DIR` — папка с XML-файлами конфигурации
- `FILES` — (опционально) список файлов через запятую для частичной загрузки
- `skipdbupdate` — (опционально) пропустить обновление конфигурации БД

**По умолчанию после загрузки выполняется обновление конфигурации БД.**

Примеры:
```bat
REM Полная загрузка
load-config.bat src/cf

REM Частичная загрузка одного модуля
load-config.bat src/cf "CommonModules/МойМодуль/Ext/Module.bsl"

REM Частичная загрузка нескольких файлов
load-config.bat src/cf "CommonModules/Мод1/Ext/Module.bsl,CommonModules/Мод2/Ext/Module.bsl"
```

### dump-config.bat — выгрузка конфигурации в XML

```bat
.claude/skills/1c-batch/scripts/dump-config.bat <XML_DIR> [update]
```

- `XML_DIR` — папка для выгрузки
- `update` — (опционально) инкрементальная выгрузка (только изменения)

---

## Работа с расширениями

### load-extension.bat — загрузка расширения из XML

```bat
.claude/skills/1c-batch/scripts/load-extension.bat <XML_DIR> <EXT_NAME> [skipdbupdate]
```

- `XML_DIR` — папка с XML-файлами расширения
- `EXT_NAME` — имя расширения в базе (если не существует — будет создано)
- `skipdbupdate` — (опционально) пропустить обновление расширения в БД

**По умолчанию после загрузки выполняется обновление расширения в БД.**

### dump-extension.bat — выгрузка расширения в XML

```bat
.claude/skills/1c-batch/scripts/dump-extension.bat <XML_DIR> <EXT_NAME> [update]
```

- `XML_DIR` — папка для выгрузки
- `EXT_NAME` — имя расширения в базе
- `update` — (опционально) инкрементальная выгрузка (только изменения)

---

## Запуск 1С

### run-enterprise.bat — запуск предприятия

```bat
.claude/skills/1c-batch/scripts/run-enterprise.bat [EPF_FILE]
```

- `EPF_FILE` — (опционально) обработка для автооткрытия

### run-designer.bat — запуск конфигуратора

```bat
.claude/skills/1c-batch/scripts/run-designer.bat
```

---

## Сценарии использования

### Исправить ошибку в обработке

1. Разобрать: `.claude/skills/1c-batch/scripts/dump-epf.bat src/epf/МояОбработка.xml D:/Исходная.epf`
2. Отредактировать BSL-файлы в `src/epf/МояОбработка/`
3. Собрать: `.claude/skills/1c-batch/scripts/build-epf.bat src/epf/МояОбработка.xml build/МояОбработка.epf`
4. Проверить: `.claude/skills/1c-batch/scripts/run-enterprise.bat build/МояОбработка.epf`

### Загрузка изменённого модуля

После редактирования BSL-файла загрузить его в базу:
```bat
.claude/skills/1c-batch/scripts/load-config.bat src/cf "CommonModules/МойМодуль/Ext/Module.bsl"
```

### Обновить расширение

1. Выгрузить: `.claude/skills/1c-batch/scripts/dump-extension.bat src/cfe/МоёРасширение МоёРасширение`
2. Внести изменения
3. Загрузить: `.claude/skills/1c-batch/scripts/load-extension.bat src/cfe/МоёРасширение МоёРасширение`

---

## Правила использования

**При выгрузке конфигурации или расширения:** если пользователь явно не указал тип выгрузки (полная или инкрементальная), спросить его перед выполнением:
- Полная выгрузка — выгружает все объекты заново
- Инкрементальная (`update`) — выгружает только изменённые объекты (быстрее)

---

## Важно

- **Обработки:** первый параметр — XML-файл, второй — выходной файл
- **Конфигурация/расширения:** первый параметр — папка
- При ошибке — код возврата `1`
- **НЕ ЧИТАЙ СКРИПТЫ, А ТОЛЬКО ЗАПУСКАЙ ИХ**