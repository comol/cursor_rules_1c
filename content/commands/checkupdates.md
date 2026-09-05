---
description: Read-only check for available updates of the 1C MCP server images (stable and -beta channels) and of the 1c-rules ruleset, without pulling or installing anything
argumentHint: "[mcp|rules]"
---

# /checkupdates — are there updates for MCP and the rules

The command only **looks**: it compares what is installed with what is published and prints a verdict. It does not `docker pull`, does not recreate containers, does not touch rule files (except the `lastUpdatesCheckAt` field in `.ai-rules.json` — see *Report*). Updating is `/updatemcp` (MCP servers) and `/updaterules` (the ruleset); this command only recommends running them.

The argument narrows the check: `mcp` — images only, `rules` — rules only, empty — both parts.

Proactive run — **about once every 30 days** (plus one-off triggers). The contract and how to count the period — `content/rules/support-feedback.md §4 → "Проактивный /checkupdates"`.

## Part A. The `1c-rules` ruleset

The scripts below are **pure ASCII** (Windows PowerShell 5.1 reads a BOM-less `.ps1` as ANSI and mangles Cyrillic in literals), so the column labels are English; translate them yourself in the report to the user.

1. Read `.ai-rules.json` at the project root: the fields `version` (the result of `git describe --tags --always` of the source at install time) and `updatedAt`. No file — the rules were not installed by this installer; say so and skip Part A.

2. Ask GitHub for the current HEAD and the number of commits since the installation — without cloning:

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

3. Verdict:
   - `version` matches the beginning of `HEAD`, no commits after it → **up to date**;
   - more than zero commits → **update available**: show their count and 3–5 recent subjects (`$commits.commit.message` — the first line of each), then suggest `/updaterules`;
   - `version` = `local` or does not look like a sha → nothing to compare with; say so plainly and suggest `/updaterules` as the safe way to align;
   - GitHub is unreachable or answered `403` (anonymous request limit) → say exactly that; it is not "no updates".

## Part B. MCP images — with the `-beta` channel taken into account

**If MCP is not connected** — no running `comol/*` containers **and** no 1C MCP tools in the current session (`syntaxcheck` / `templatesearch` / `metadatasearch` / `search_metadata` / `check_1c_code` / `ssl_search` / `docsearch`) — Part B has nothing to compare. Do not present that as "images are up to date". Write in the report that MCP is not connected, and if at the same time `SUPPORT_KEY` in `.dev.env` is empty and there is no `integrations.mcp.mode = "external"` — add the reminder:

> Правила работают наиболее эффективно с MCP-серверами для 1С: https://vibecoding1c.ru/mcp_server
> Комплект уже куплен — `/installtools` или `/installmcp`. Нет комплекта — страница покупки по ссылке. Установщик правил ключ MCP не выдаёт.

If the key or an external install is present but there are no tools in the session — briefly: MCP is not connected, `/installmcp` or a client restart; do not repeat the purchase link. Do not go further in Part B.

Every server is published in two channels, and **beta images differ by the `-beta` suffix**: `latest` / `light` / `arm64` versus `latest-beta` / `light-beta` / `arm64-beta` (some servers historically use the joined form `latestbeta`). Compare **tag with tag inside its own channel**. The answer "there is a newer image in `latest` than your `light-beta`" is meaningless: these are different publication branches.

1. Collect what actually runs — the tag is taken from the container, not from `config.env` (the user may have switched the channel by hand):

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

2. For each image ask Docker Hub for the published digest **of the same tag** (public repositories, no authorization needed):

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

3. Verdict per server:
   - the local image digest matches the published one → **up to date**;
   - they differ → **update available**; show `last_updated` of the published tag;
   - there is no local digest (the image was built locally, not pulled from the registry) → nothing to compare; note it separately, do not present it as "update available";
   - the tag was not found (404) → say that this channel has no such tag; for beta that is normal for servers with a truncated tag matrix (SyntaxCheck is published only as `latest` / `latest-beta`).

4. Additionally compare the declared channel with the actual one: `IMAGE_TAG` in the distribution's `config.env` (default `C:\Work\MCP_Distr\config.env`; the channel contract — `/installmcp` → `## Release channel — stable or beta (IMAGE_TAG)`) against the `Channel` column. A mismatch is not an error, but it must be mentioned: containers and keys may have drifted across channels, and the licence keys for stable and beta are **different**.

## Report

One table for the rules, one for the servers (when MCP is connected; otherwise, instead of the servers table — the verdict «MCP не подключены» and the reminder from Part B), then a short conclusion:

- everything is up to date → one line «обновлений нет», without suggesting to run anything;
- there are updates → list exactly what is outdated and suggest exactly what is needed: `/updatemcp` (in the current channel), `/updatemcp beta` / `/updatemcp stable` (only when the user wants to switch the channel), `/updaterules`;
- some checks did not complete (no network, no Docker, GitHub answered `403`) → list exactly what was not checked. Unchecked is not presented as checked.

The command installs nothing itself and does not switch the channel. Even when an update is clearly available, running `/updatemcp` or `/updaterules` is a separate decision of the user.

After any completed check (including a partial run and the verdict «MCP не подключены») write the field `lastUpdatesCheckAt` into `.ai-rules.json` with the current UTC in the same format as `updatedAt` (`yyyy-MM-ddTHH:mm:ssZ`). Do not touch the other fields of the manifest. If the network failed before any verdict — do not update the field, so that the next session retries.
