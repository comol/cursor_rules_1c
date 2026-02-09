@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM Запуск 1С:Предприятие
REM
REM Параметры:
REM   %1 - (опционально) путь к обработке для автооткрытия
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

set "EPF_FILE=%~1"

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

REM Формируем параметры запуска
set "RUN_PARAMS="
if not "%EPF_FILE%"=="" (
    set RUN_PARAMS=/Execute "%EPF_FILE%"
    echo Запуск предприятия с обработкой...
    echo   Обработка: %EPF_FILE%
) else (
    echo Запуск предприятия...
)

start "" "%ONEC_PATH%" ENTERPRISE !IB_PARAMS! !AUTH_PARAMS! !RUN_PARAMS!

echo Предприятие запущено
exit /b 0
