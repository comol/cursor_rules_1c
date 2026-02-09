@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Разборка внешней обработки/отчёта в XML
REM
REM Параметры:
REM   %1 - корневой XML-файл для выгрузки
REM   %2 - путь к EPF/ERF файлу
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
    echo Использование: dump-epf.bat ^<XML_FILE^> ^<EPF_FILE^>
    echo.
    echo Пример: dump-epf.bat "src\epf\МояОбработка.xml" "D:\МояОбработка.epf"
    exit /b 1
)

set "XML_FILE=%~1"
set "EPF_FILE=%~2"

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

echo Разборка обработки...
echo   Источник: %EPF_FILE%
echo   Результат: %XML_FILE%

"%ONEC_PATH%" DESIGNER !IB_PARAMS! !AUTH_PARAMS! /DisableStartupDialogs /DumpExternalDataProcessorOrReportToFiles "%XML_FILE%" "%EPF_FILE%"

if %ERRORLEVEL% equ 0 (
    echo Разборка завершена успешно
) else (
    echo Ошибка разборки
    exit /b 1
)

exit /b 0
