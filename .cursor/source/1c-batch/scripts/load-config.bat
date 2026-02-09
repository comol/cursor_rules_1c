@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Загрузка конфигурации из XML в базу с обновлением БД
REM
REM Параметры:
REM   %1 - каталог с XML-файлами конфигурации
REM   %2 - (опционально) список файлов через запятую ИЛИ "skipdbupdate"
REM   %3 - (опционально) "skipdbupdate" для пропуска обновления БД
REM
REM По умолчанию после загрузки выполняется обновление конфигурации БД.
REM
REM Требует: .1c-devbase.bat в текущем каталоге
REM ============================================================

REM Загружаем настройки
if not exist ".1c-devbase.bat" (
    echo Ошибка: не найден .1c-devbase.bat в текущем каталоге
    echo Скопируйте .1c-devbase.bat.example в корень проекта как .1c-devbase.bat
    exit /b 1
)
call .\.1c-devbase.bat

if "%~1"=="" (
    echo Использование: load-config.bat ^<XML_DIR^> [FILES] [skipdbupdate]
    echo.
    echo Примеры:
    echo   Полная загрузка:      load-config.bat "src\cf"
    echo   Частичная загрузка:   load-config.bat "src\cf" "CommonModules/Мод1/Ext/Module.bsl"
    echo   Без обновления БД:    load-config.bat "src\cf" skipdbupdate
    exit /b 1
)

set "XML_DIR=%~1"
set "FILES="
set "SKIP_UPDATE=0"

REM Разбираем параметры: %2 может быть FILES или "skipdbupdate", %3 - только "skipdbupdate"
if /i "%~2"=="skipdbupdate" (
    set "SKIP_UPDATE=1"
) else if not "%~2"=="" (
    set "FILES=%~2"
)

if /i "%~3"=="skipdbupdate" (
    set "SKIP_UPDATE=1"
)

REM Определяем тип подключения: сервер или файловая база
if not "%ONEC_SERVER%"=="" (
    set "IB_PARAMS=/S "%ONEC_SERVER%\%ONEC_BASE%""
) else if not "%ONEC_FILEBASE_PATH%"=="" (
    set "IB_PARAMS=/F "%ONEC_FILEBASE_PATH%""
) else (
    echo Ошибка: не указан ни сервер ^(ONEC_SERVER^), ни путь к файловой базе ^(ONEC_FILEBASE_PATH^)
    exit /b 1
)

REM Формируем параметры авторизации
set "AUTH_PARAMS="
if not "%ONEC_USER%"=="" set AUTH_PARAMS=/N"%ONEC_USER%"
if not "%ONEC_PASSWORD%"=="" set AUTH_PARAMS=!AUTH_PARAMS! /P"%ONEC_PASSWORD%"

REM Формируем параметры загрузки
set "LOAD_PARAMS="
if not "%FILES%"=="" (
    set "LOAD_PARAMS=-files "%FILES%" -Format Hierarchical"
    echo Частичная загрузка конфигурации...
    echo   Источник: %XML_DIR%
    echo   Файлы: %FILES%
) else (
    echo Полная загрузка конфигурации...
    echo   Источник: %XML_DIR%
)

REM Добавляем обновление БД если не указан skipdbupdate
set "UPDATE_PARAMS="
if "%SKIP_UPDATE%"=="0" (
    set "UPDATE_PARAMS=/UpdateDBCfg"
    echo   Обновление БД: да
) else (
    echo   Обновление БД: нет
)

"%ONEC_PATH%" DESIGNER !IB_PARAMS! !AUTH_PARAMS! /DisableStartupDialogs /LoadConfigFromFiles "%XML_DIR%" %LOAD_PARAMS% -updateConfigDumpInfo !UPDATE_PARAMS!

if %ERRORLEVEL% equ 0 (
    echo Загрузка завершена успешно
) else (
    echo Ошибка загрузки
    exit /b 1
)

exit /b 0
