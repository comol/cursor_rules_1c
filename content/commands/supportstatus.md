---
description: Show the status of your support tickets about MCP servers and the 1c-rules ruleset, and close a ticket you no longer need
argumentHint: "[новый|закрыт|<id тикета>|close <id тикета>]"
---

# /supportstatus — статус обращений в поддержку

Показывает обращения, отправленные командой `/support` с этого `SUPPORT_EMAIL`.
Статусы всего два: **`новый`** (принято, ещё не разобрано) и **`закрыт`** (разобрано;
в поле `answer` может лежать ответ оператора).

## Предусловия

Те же, что у `/support`: в `.dev.env` заполнены `SUPPORT_KEY` и `SUPPORT_EMAIL`
(`SUPPORT_API_URL` пустой = `https://d5ds85pood7ob80g5fd9.nnekmrav.apigw.yandexcloud.net`).
Пусто — не ходи в сеть, скажи чего не хватает и откуда взять (`/support` → *Предусловия*).

Клиентский ключ видит **только свои** обращения: сервис отбирает их по `SUPPORT_EMAIL`.
Чужие тикеты по этому ключу не отдаются — это не сбой.

## Аргументы

| Аргумент | Действие |
|---|---|
| пусто | последние 50 обращений, свежие сверху |
| `новый` / `new` | только неразобранные |
| `закрыт` / `closed` | только закрытые, с ответами оператора |
| `<id>` | одно обращение целиком: текст, `context`, ответ |
| `close <id>` | закрыть своё обращение (проблема отпала / решилась сама) |

Статус можно писать латиницей — сервис принимает `new` / `closed` наравне с
кириллическими значениями. Так надёжнее: кириллица в query-строке из PowerShell
регулярно приезжает в чужой кодировке.

## Выполнение

Скрипт держи в **чистом ASCII**: Windows PowerShell 5.1 читает `.ps1` без BOM как ANSI и
калечит любую кириллицу в литералах — метки вывода поэтому английские. Нужна кириллица
прямо в скрипте — сохраняй файл в UTF-8 **с BOM**. Вывод переключай на UTF-8, иначе
кириллица, пришедшая с сервера, превратится в консоли в мусор.

### Список

```powershell
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$devEnv = @{}
Get-Content '.dev.env' | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=(.*)$') { $devEnv[$Matches[1]] = $Matches[2].Trim() }
}
$key   = $devEnv['SUPPORT_KEY']
$email = $devEnv['SUPPORT_EMAIL']
$api   = $devEnv['SUPPORT_API_URL']
if (-not $api) { $api = 'https://d5ds85pood7ob80g5fd9.nnekmrav.apigw.yandexcloud.net' }
if (-not $key -or -not $email) { throw 'SUPPORT_KEY / SUPPORT_EMAIL are empty in .dev.env' }

# $status: '' | 'new' | 'closed'
$status = ''
$url = "$api/api/tickets?email=$([Uri]::EscapeDataString($email))&limit=50"
if ($status) { $url += "&status=$status" }

$resp = Invoke-RestMethod -Uri $url -Headers @{ 'X-Support-Key' = $key }
"Total: $($resp.total), new: $($resp.total_new)"
$resp.tickets | Select-Object @{n='id';e={$_.id.Substring(0,8)}}, status, kind, component, title, created_at |
    Format-Table -AutoSize
```

### Одно обращение

```powershell
$resp = Invoke-RestMethod -Uri "$api/api/tickets/$id`?email=$([Uri]::EscapeDataString($email))" `
    -Headers @{ 'X-Support-Key' = $key }
$resp.ticket | Format-List id, status, kind, component, channel, image_tag, title, text, context, answer, created_at, closed_at
```

### Закрыть своё обращение

Закрытие — действие пользователя, не твоя инициатива. Спроси подтверждение
(«Закрываю обращение `<id>` — `<заголовок>`?») и только потом отправляй. Тело здесь
короткое и без кириллицы, поэтому `-Body` достаточно:

```powershell
$body = "{""status"":""closed"",""email"":""$email""}"
$resp = Invoke-RestMethod -Uri "$api/api/tickets/$id/status" -Method Post `
    -Headers @{ 'X-Support-Key' = $key } `
    -ContentType 'application/json; charset=utf-8' -Body $body
$resp.ticket | Select-Object id, status, closed_at | Format-List
```

Вернуть закрытое обращение в статус `новый` клиентским ключом нельзя — это право
оператора (`403 admin_key_required`). Если проблема повторилась, отправь новое
обращение через `/support` и сошлись в тексте на `id` прежнего.

## Отчёт

- Есть закрытые с непустым `answer` — покажи ответ оператора отдельным блоком, это главное
  в выводе команды.
- Пусто — так и скажи: «обращений с этого e-mail нет». Не выдумывай тикеты и не показывай
  чужие.
- Ошибки — таблица в `/support` → *Шаг 6*. `401 invalid_support_key` чаще всего значит, что
  ключ устарел после обновления дистрибутива.

Никогда не выводи `SUPPORT_KEY` в чат и в логи.
