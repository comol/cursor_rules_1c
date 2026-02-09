@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Выгрузка конфигурации из базы в XML
REM
REM Параметры:
REM   %1 - каталог для выгрузки XML
REM   %2 - (опционально) "update" для инкрементальной выгрузки
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
    echo Использование: dump-config.bat ^<XML_DIR^> [update]
    echo.
    echo Примеры:
    echo   Полная выгрузка:        dump-config.bat "src\cf"
    echo   Инкрементальная:        dump-config.bat "src\cf" update
    exit /b 1
)

set "XML_DIR=%~1"
set "UPDATE_MODE=%~2"

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

REM Формируем параметры выгрузки
set "DUMP_PARAMS="
if /i "%UPDATE_MODE%"=="update" (
    set "DUMP_PARAMS=-update -force"
    echo Инкрементальная выгрузка конфигурации...
) else (
    echo Полная выгрузка конфигурации...
)
echo   Результат: %XML_DIR%

"%ONEC_PATH%" DESIGNER !IB_PARAMS! !AUTH_PARAMS! /DisableStartupDialogs /DumpConfigToFiles "%XML_DIR%" %DUMP_PARAMS%

if %ERRORLEVEL% equ 0 (
    echo Выгрузка завершена успешно
) else (
    echo Ошибка выгрузки
    exit /b 1
)

exit /b 0
