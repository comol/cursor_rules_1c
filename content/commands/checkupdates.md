---
description: Read-only check for available updates of the 1C MCP server images (stable and -beta channels) and of the 1c-rules ruleset, without pulling or installing anything
argumentHint: "[mcp|rules]"
---

# /checkupdates — есть ли обновления MCP и правил

Команда только **смотрит**: сравнивает установленное с опубликованным и печатает вердикт.
Она не делает `docker pull`, не пересоздаёт контейнеры, не трогает файлы правил. Обновление —
это `/updatemcp` (серверы MCP) и `/updaterules` (набор правил); их эта команда лишь
рекомендует запустить.

Аргумент сужает проверку: `mcp` — только образы, `rules` — только правила, пусто — обе части.

## Часть A. Правила `1c-rules`

Скрипты ниже — **чистый ASCII** (Windows PowerShell 5.1 читает `.ps1` без BOM как ANSI и
калечит кириллицу в литералах), поэтому метки колонок английские; переводи их в отчёте
для пользователя сам.

1. Прочитай `.ai-rules.json` в корне проекта: поля `version` (результат
   `git describe --tags --always` источника на момент установки) и `updatedAt`.
   Файла нет — правила не установлены этим установщиком; скажи это и пропусти часть A.

2. Спроси у GitHub текущий HEAD и число коммитов после установки — без клонирования:

```powershell
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$manifest = Get-Content '.ai-rules.json' -Raw | ConvertFrom-Json
$repo = 'comol/ai_rules_1c'

$head = (git ls-remote "https://github.com/$repo" HEAD) -split '\s+' | Select-Object -First 1
$since = [Uri]::EscapeDataString($manifest.updatedAt)
$commits = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?since=$since&per_page=100" `
    -Headers @{ 'User-Agent' = '1c-rules-checkupdates' }

[pscustomobject]@{
    Installed    = $manifest.version
    UpdatedAt    = $manifest.updatedAt
    Head         = $head.Substring(0, 7)
    CommitsSince = @($commits).Count
} | Format-List
```

3. Вердикт:
   - `version` совпадает с началом `HEAD`, коммитов после нет → **актуально**;
   - коммитов больше нуля → **есть обновление**: покажи их количество и 3–5 свежих
     заголовков (`$commits.commit.message` — первая строка каждого), затем предложи
     `/updaterules`;
   - `version` = `local` или не похож на sha → сравнить нечем, скажи прямо и предложи
     `/updaterules` как безопасный способ выровняться;
   - GitHub недоступен или ответил `403` (лимит анонимных запросов) → так и скажи;
     это не «обновлений нет».

## Часть B. Образы MCP — с обязательным учётом канала `-beta`

Каждый сервер публикуется в двух каналах, и **бета-образы отличаются суффиксом `-beta`**:
`latest` / `light` / `arm64` против `latest-beta` / `light-beta` / `arm64-beta` (у части
серверов исторически встречается слитное написание вида `latestbeta`). Сравнивать нужно
**тег с тегом внутри своего канала**. Ответ «в `latest` есть образ новее вашего
`light-beta`» бессмысленен: это разные ветки публикации.

1. Собери фактически запущенное — тег берётся из контейнера, а не из `config.env`
   (пользователь мог переключить канал вручную):

```powershell
$containers = docker ps --format '{{.Names}}' | ForEach-Object {
    $image = docker inspect $_ --format '{{.Config.Image}}'
    if ($image -notmatch '^([^:]+):(.+)$') { return }
    $repo, $tag = $Matches[1], $Matches[2]
    [pscustomobject]@{
        Container = $_
        Repo      = $repo
        Tag       = $tag
        Channel   = if ($tag -match 'beta') { 'beta' } else { 'stable' }
        Digest    = (docker image inspect "$repo`:$tag" --format '{{index .RepoDigests 0}}' 2>$null)
    }
} | Where-Object { $_ -and $_.Repo -like 'comol/*' }
$containers | Format-Table -AutoSize
```

2. Для каждого образа спроси опубликованный digest **того же тега** в Docker Hub
   (публичные репозитории, авторизация не нужна):

```powershell
foreach ($c in $containers) {
    $url = "https://hub.docker.com/v2/repositories/$($c.Repo)/tags/$($c.Tag)"
    try {
        $remote = Invoke-RestMethod -Uri $url
    } catch {
        "$($c.Repo):$($c.Tag) - tag not found in Docker Hub (404) or registry unreachable"
        continue
    }
    $local = ($c.Digest -split '@')[-1]
    [pscustomobject]@{
        Server    = $c.Container
        Tag       = $c.Tag
        Channel   = $c.Channel
        Published = $remote.last_updated
        Update    = if ($local -and $local -eq $remote.digest) { 'no' } else { 'YES' }
    }
}
```

3. Вердикт по каждому серверу:
   - digest локального образа совпадает с опубликованным → **актуально**;
   - расходится → **есть обновление**, покажи `last_updated` опубликованного тега;
   - локального digest нет (образ собран локально, не тянулся из реестра) → сравнивать
     нечего, отметь это отдельно, не выдавай за «обновление есть»;
   - тег не найден (404) → скажи, что в этом канале такого тега нет; для beta это обычная
     ситуация у серверов с усечённой матрицей тегов (SyntaxCheck публикуется только как
     `latest` / `latest-beta`).

4. Дополнительно сверь заявленный канал с фактическим: `RELEASE_CHANNEL` в `config.env`
   дистрибутива (по умолчанию `C:\Work\MCP_Distr\config.env`) против колонки `Channel`.
   Расхождение — не ошибка, но о нём надо сказать: контейнеры и ключи могли разъехаться
   по каналам, а лицензионные ключи у stable и beta **разные**.

## Отчёт

Одна таблица на правила, одна на серверы, затем короткий вывод:

- всё актуально → одна строка «обновлений нет», без предложений что-то запускать;
- есть обновления → перечисли что именно устарело и предложи ровно то, что нужно:
  `/updatemcp` (в текущем канале), `/updatemcp beta` / `/updatemcp stable` (только если
  пользователь сам хочет сменить канал), `/updaterules`;
- часть проверок не выполнилась (нет сети, нет Docker, GitHub ответил `403`) → перечисли
  что именно не проверено. Непроверенное не выдаётся за проверенное.

Команда ничего не устанавливает сама и не переключает канал. Даже когда обновление явно
есть, запуск `/updatemcp` или `/updaterules` — отдельное решение пользователя.
