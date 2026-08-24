---
description: Send a problem report about a 1C MCP server or about the 1c-rules ruleset to the support service (Yandex Cloud Function -> Yandex Database)
argumentHint: "[mcp|rules] <краткое описание проблемы>"
---

# /support — сообщить о проблеме в MCP или в правилах

Команда отправляет обращение в сервис поддержки: **Yandex Cloud Function → Yandex Database**.
Новое обращение создаётся со статусом **`новый`**; оператор разбирает его и переводит в
**`закрыт`**, при необходимости приложив ответ. Статус своих обращений — `/supportstatus`.

Полный контракт канала (предусловия, что можно и нельзя отправлять, правила
инициативы модели) — `content/rules/support-feedback.md`. Здесь — процедура.

## Предусловия (жёсткие)

Читай `.dev.env` в корне проекта. Обращение отправляется **только** когда заполнены
**оба** параметра:

| Параметр | Смысл |
|---|---|
| `SUPPORT_KEY` | общий ключ поддержки; приходит с дистрибутивом MCP (`config.env` из `MCP_Distr`) |
| `SUPPORT_EMAIL` | рабочий e-mail автора обращения; на него отвечает оператор |
| `SUPPORT_API_URL` | адрес сервиса; пустое значение = `https://d5ds85pood7ob80g5fd9.nnekmrav.apigw.yandexcloud.net` |

Если пуст `SUPPORT_KEY` **или** `SUPPORT_EMAIL` — **не отправляй ничего**. Ответь одним
сообщением, чего не хватает и откуда взять:

> Обращение не отправлено: в `.dev.env` не заполнен `<SUPPORT_KEY|SUPPORT_EMAIL|оба>`.
> `SUPPORT_KEY` и `SUPPORT_API_URL` лежат в `config.env` дистрибутива MCP (по умолчанию
> `C:\Work\MCP_Distr\config.env`, раздел 6), перенос описан в `INSTALL.md` → ШАГ 6.
> `SUPPORT_EMAIL` — ваш рабочий e-mail, укажите его сами. Свежий дистрибутив с ключом —
> личный кабинет https://vibecoding1c.ru/.

Не придумывай ключ, не бери его из чужого проекта и не предлагай отправить обращение
без ключа «напрямую разработчику».

## Шаг 1. Определи тип обращения

Аргумент команды или суть проблемы дают `kind`:

- `mcp` — MCP-сервер: не стартует, не отвечает, отдаёт мусор, отсутствует инструмент,
  результат поиска явно неверный, ошибка лицензии;
- `rules` — правила `1c-rules`: правило противоречит платформе или другому правилу,
  команда описывает несуществующий шаг, инструкция приводит к неработающему коду;
- `other` — всё остальное (дистрибутив, документация, личный кабинет).

Тип не угадывается из одного слова — спроси одним вопросом.

## Шаг 2. Собери фактуру окружения

Без окружения обращение почти бесполезно, поэтому соберём его сами, а не спросим у
пользователя.

### Для `kind = mcp` — обязательно зафиксируй канал и тег

Каналов два, и **бета-образы отличаются суффиксом `-beta`** (`latest-beta`, `light-beta`,
`arm64-beta`; у части серверов встречается слитное написание вида `latestbeta`). Ошибка,
воспроизводящаяся только в beta, и та же ошибка в stable — разные обращения, поэтому тег
берётся из **фактически запущенного контейнера**, а не из `config.env`:

```powershell
docker ps --format '{{.Names}}' | ForEach-Object {
    [pscustomobject]@{
        Container = $_
        Image     = (docker inspect $_ --format '{{.Config.Image}}')
    }
} | Format-Table -AutoSize
```

Из `Image` вида `comol/1c_help_mcp:light-beta` получаются:

- `component` — id сервера по каталогу `/checkmcp` (`1c-help-mcp`, `1c-code-metadata-mcp`, …);
- `image_tag` — `light-beta`;
- `channel` — `beta`, если тег содержит `beta` в любом написании, иначе `stable`.

Добавь в `context` цифровой отпечаток: локальный digest образа
(`docker image inspect <образ> --format '{{index .RepoDigests 0}}'`), точный текст ошибки
из логов (`docker logs --tail 50 <контейнер>`) и имя инструмента MCP, на котором проблема
воспроизвелась.

### Для `kind = rules`

- `component` — имя файла правила или команды (`mcp-first-search.md`, `updatemcp.md`);
- `channel` / `image_tag` — не заполняются;
- в `context` — `version` и `updatedAt` из `.ai-rules.json`, активный инструмент
  (cursor / claude-code / opencode / …), `AGENT_MODEL` из `.dev.env`.

## Шаг 3. Составь текст обращения

`title` — одна строка, суть проблемы. `text` — по этой структуре:

```
Что делал:      <минимальный сценарий, по шагам>
Что ожидал:     <ожидаемое поведение и на чём оно основано — пункт правила / документации>
Что получилось: <фактическое поведение, дословный текст ошибки>
Воспроизводимость: <всегда / иногда / один раз>
```

**Что нельзя отправлять.** Всё уходит на внешний сервис, поэтому вычищай из `title`,
`text` и `context`:

- лицензионные ключи (`LICENSE_KEY_*`), API-ключи (`EMBEDDING_API_KEY`, `CHAT_API_KEY`,
  `ONEC_AI_TOKEN`), `SUPPORT_KEY`, пароли, токены;
- строки подключения к ИБ, логины, пути с именами пользователей, если они не нужны для сути;
- персональные данные из базы;
- большие листинги. Модуль целиком не нужен: достаточно фрагмента в 10–30 строк вокруг
  проблемного места. Предел поля `text` — 60 000 символов, `context` — 40 000.

## Шаг 4. Покажи и подтверди

Обращение покидает машину, поэтому отправка **всегда** подтверждается человеком — и когда
команду вызвал пользователь, и когда инициатором был ты сам. Покажи готовое тело целиком
(e-mail, тип, компонент, канал/тег, заголовок, текст, context) и спроси одной строкой:

> Отправляю обращение в поддержку с этим текстом? (да / нет / поправить)

На «поправить» — правь текст и показывай снова. Без явного «да» ничего не отправляется.

## Шаг 5. Отправь

Тело формируется **отдельным JSON-файлом в UTF-8**, а сам скрипт держится в чистом ASCII:
Windows PowerShell 5.1 читает `.ps1` без BOM как ANSI и калечит кириллицу в литералах.
Файл пиши своим инструментом записи файлов, не через `Set-Content` с кириллицей внутри.

`<TEMP>\support-ticket.json`:

```json
{
  "email": "dev@example.com",
  "kind": "mcp",
  "component": "1c-help-mcp",
  "channel": "beta",
  "image_tag": "light-beta",
  "title": "standards не находит раздел про блокировки",
  "text": "Что делал: ...\nЧто ожидал: ...\nЧто получилось: ...\nВоспроизводимость: всегда",
  "source": "user",
  "context": "{\"digest\":\"sha256:...\",\"tool\":\"cursor\",\"rules_version\":\"6f5a738\"}"
}
```

- `source` — `user`, когда команду вызвал человек; `model`, когда инициатива твоя
  (см. `support-feedback.md`). Поле не для украшения: по нему оператор отделяет
  найденное моделью от найденного человеком.

Отправка (скрипт — ASCII, значения читаются из `.dev.env`):

```powershell
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$devEnv = @{}
Get-Content '.dev.env' | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=(.*)$') { $devEnv[$Matches[1]] = $Matches[2].Trim() }
}
$key = $devEnv['SUPPORT_KEY']
$api = $devEnv['SUPPORT_API_URL']
if (-not $api) { $api = 'https://d5ds85pood7ob80g5fd9.nnekmrav.apigw.yandexcloud.net' }
if (-not $key -or -not $devEnv['SUPPORT_EMAIL']) { throw 'SUPPORT_KEY / SUPPORT_EMAIL are empty in .dev.env' }

$file = Join-Path $env:TEMP 'support-ticket.json'
$resp = Invoke-RestMethod -Uri "$api/api/tickets" -Method Post `
    -Headers @{ 'X-Support-Key' = $key } `
    -ContentType 'application/json; charset=utf-8' -InFile $file
Remove-Item $file -ErrorAction SilentlyContinue
$resp.ticket | Select-Object id, status, kind, component, created_at | Format-List
```

`-InFile` вместо `-Body` — обязательно: так тело уходит байтами файла и кириллица не
перекодируется по дороге.

## Шаг 6. Отчитайся

Успех (`201`) — покажи `id`, `status` (`новый`) и время. Скажи, что статус смотрится через
`/supportstatus`, а ответ оператора придёт на `SUPPORT_EMAIL`.

Ошибки:

| Ответ | Что случилось | Что делать |
|---|---|---|
| `401 invalid_support_key` | ключ неверен или отозван | взять свежий `SUPPORT_KEY` из нового дистрибутива (личный кабинет https://vibecoding1c.ru/) и перенести в `.dev.env` |
| `400 email_required` | `SUPPORT_EMAIL` пуст или не похож на адрес | поправить `.dev.env` |
| `400 field_too_long` | превышен лимит поля | сократить текст / убрать листинг |
| `400 invalid_kind` / `invalid_channel` | недопустимое значение | `kind` — `mcp`/`rules`/`other`, `channel` — `stable`/`beta` |
| сеть недоступна | нет интернета или сервис лежит | сохранить готовый текст обращения в ответе пользователю, чтобы не потерять, и предложить повтор позже |

Никогда не выводи `SUPPORT_KEY` в чат, в лог и в текст обращения.
