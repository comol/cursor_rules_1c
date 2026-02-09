@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Сборка внешней обработки/отчёта из XML
REM
REM Параметры:
REM   %1 - корневой XML-файл обработки
REM   %2 - путь к результирующему EPF/ERF файлу
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
    echo Использование: build-epf.bat ^<XML_FILE^> ^<OUTPUT_FILE^>
    echo.
    echo Пример: build-epf.bat "src\epf\МояОбработка.xml" "build\МояОбработка.epf"
    exit /b 1
)

set "XML_FILE=%~1"
set "OUTPUT_FILE=%~2"

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

echo Сборка обработки...
echo   Источник: %XML_FILE%
echo   Результат: %OUTPUT_FILE%

"%ONEC_PATH%" DESIGNER !IB_PARAMS! !AUTH_PARAMS! /DisableStartupDialogs /LoadExternalDataProcessorOrReportFromFiles "%XML_FILE%" "%OUTPUT_FILE%"

if %ERRORLEVEL% equ 0 (
    echo Сборка завершена успешно
) else (
    echo Ошибка сборки
    exit /b 1
)

exit /b 0
