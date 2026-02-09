@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Загрузка расширения конфигурации из XML в базу с обновлением БД
REM
REM Параметры:
REM   %1 - каталог с XML-файлами расширения
REM   %2 - имя расширения
REM   %3 - (опционально) "skipdbupdate" для пропуска обновления БД
REM
REM По умолчанию после загрузки выполняется обновление расширения в БД.
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

if "%~2"=="" (
    echo Использование: load-extension.bat ^<XML_DIR^> ^<EXT_NAME^> [skipdbupdate]
    echo.
    echo Примеры:
    echo   Загрузка + обновление БД:      load-extension.bat "src\cfe\МоёРасширение" "МоёРасширение"
    echo   Загрузка БЕЗ обновления БД:    load-extension.bat "src\cfe\МоёРасширение" "МоёРасширение" skipdbupdate
    exit /b 1
)

set "XML_DIR=%~1"
set "EXT_NAME=%~2"
set "SKIP_UPDATE=0"

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

echo Загрузка расширения...
echo   Источник: %XML_DIR%
echo   Расширение: %EXT_NAME%

REM Добавляем обновление БД если не указан skipdbupdate
set "UPDATE_PARAMS="
if "%SKIP_UPDATE%"=="0" (
    set "UPDATE_PARAMS=/UpdateDBCfg"
    echo   Обновление БД: да
) else (
    echo   Обновление БД: нет
)

"%ONEC_PATH%" DESIGNER !IB_PARAMS! !AUTH_PARAMS! /DisableStartupDialogs /LoadConfigFromFiles "%XML_DIR%" -Extension "%EXT_NAME%" -updateConfigDumpInfo !UPDATE_PARAMS!

if %ERRORLEVEL% equ 0 (
    echo Загрузка завершена успешно
) else (
    echo Ошибка загрузки
    exit /b 1
)

exit /b 0
