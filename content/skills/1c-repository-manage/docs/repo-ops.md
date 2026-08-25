# repo-ops — Operation Reference

One script drives every repository operation:

```powershell
powershell -NoProfile -File "skills/1c-repository-manage/tools/1c-repo-ops/scripts/repo-ops.ps1" -Operation <op> [parameters]
```

Connection defaults come from `.dev.env` (`PLATFORM_PATH`, `INFOBASE_KIND`, `INFOBASE_PATH`, `IB_USER`, `IB_PASSWORD`, `REPOSITORY_PATH`, `REPOSITORY_USER`, `REPOSITORY_PASSWORD`); explicit script parameters override them. Repository operations always run through the Designer (`1cv8.exe`) — `ibcmd` has no repository mode, and the script refuses it.

`-Objects` accepts a comma-separated string of exact metadata full names (Russian or English variants as used by the project): `"Справочник.Номенклатура,Документ.ЗаказКлиента"`. The script builds the temporary `-Objects` XML itself and deletes it afterwards.

For an **extension repository** add `-Extension "<Name>"` (its own `REPOSITORY_PATH` — pass `-RepositoryPath` if it differs from the main one). Not applicable to `diff`.

## Operations

### status — connectivity check and latest version

```powershell
... -Operation status
```

Latest-version report (`/ConfigurationRepositoryReport -NBegin -1`). The cheapest full check of the chain platform → infobase → repository → credentials. Run it first in a session before planning repository work, and after any failure before retrying.

### history — version report

```powershell
... -Operation history -BeginVersion 120 -EndVersion 140 -GroupBy object
```

`-BeginVersion` / `-EndVersion` bound the range (omit for full history — on a long-lived repository prefer explicit bounds), `-GroupBy version|object|comment` selects the grouping (`/ConfigurationRepositoryReport [-NBegin] [-NEnd] [-GroupByObject|-GroupByComment]`).

### diff — local main configuration vs repository version

```powershell
... -Operation diff                       # against the latest version
... -Operation diff -Version 135          # against version 135
... -Operation diff -Objects "Справочник.Номенклатура"   # narrowed to objects
```

`/CompareCfg -FirstConfigurationType MainConfiguration -SecondConfigurationType ConfigurationRepository`, Brief report with changed/added/deleted objects. Use before `commit` to verify the change set matches the plan, and before `lock` to see whether local copies are stale.

### lock — take objects for editing

```powershell
... -Operation lock -Objects "Справочник.Номенклатура" [-IncludeChildObjects] [-Revised]
```

`/ConfigurationRepositoryLock`. `-Revised` pre-updates the objects to the repository head before locking (recommended: locking a stale copy invites a merge at commit). `-IncludeChildObjects` extends the lock to subordinate objects — use when the plan touches forms/templates/commands of the object.

### update — refresh local copies from the repository

```powershell
... -Operation update -Objects "Справочник.Номенклатура" [-Version 135] [-Revised]
```

`/ConfigurationRepositoryUpdateCfg -Objects …`. Omitted `-Version` = repository head. After an update that changed objects, the DB structure may need `/update1cbase` (see [repo-sdlc.md](repo-sdlc.md)).

### commit — put changes into the repository

```powershell
... -Operation commit -Objects "Справочник.Номенклатура" -Comment "TASK-123: добавлен реквизит Артикул" [-KeepLocked] [-IncludeChildObjects]
```

`/ConfigurationRepositoryCommit`. `-Comment` is mandatory (task reference + what changed; multi-line comments allowed — each line is passed separately). `-KeepLocked` keeps the lock after commit for continued work. Commit only objects that are verified (`verification-gates.md`) — a commit is visible to the whole team immediately.

### unlock — release locks

```powershell
... -Operation unlock -Objects "Справочник.Номенклатура" [-IncludeChildObjects]
```

`/ConfigurationRepositoryUnLock` without force releases **own** locks on unchanged objects. Releasing a lock while local changes exist loses nothing by itself, but leaves the local configuration diverged — run `diff` first when unsure.

### dump — export a repository version to CF/CFE

```powershell
... -Operation dump -OutputFile "C:\Release\1.2.3.cf" [-Version 135]
```

`/ConfigurationRepositoryDumpCfg`. Extension `.cf` (main) / `.cfe` (extension repository with `-Extension`). Use for release builds from a fixed repository version instead of the local working copy.

Unbind (`/ConfigurationRepositoryUnbindCfg`) is **not** an operation of this script and must not be composed ad-hoc while `REPOSITORY_PATH` is set — canon [SKILL.md → Safety invariant 5](../SKILL.md).

## Force variants — user-approved maintenance only

| Call | Effect | Gate |
|---|---|---|
| `update -Force -ConfirmForce` | Overwrites locally changed objects with the repository version | `REPOSITORY_ALLOW_FORCE=true` + switch |
| `commit -Force -ConfirmForce` | Commits despite warnings the platform would otherwise stop on | `REPOSITORY_ALLOW_FORCE=true` + switch |
| `unlock -Force -ConfirmDiscardChanges` | Releases locks **discarding uncommitted changes** (own or, with repository admin rights, another user's) | `REPOSITORY_ALLOW_FORCE=true` + switch |

Both halves of each gate are the user's decision: never edit `REPOSITORY_ALLOW_FORCE` and never add the confirmation switch without the user's explicit approval of that specific operation in that specific call.

## Output contract

- Success = exit `0` **and** no fatal line in the `/Out` log — the script scans the log and elevates hidden failures ("Ошибка работы с хранилищем конфигурации", "уже захвачен", "не захвачен", auth errors, …) to exit `1` even when the platform exits `0`.
- Reports (`status`/`history`/`diff`) go to `%TEMP%\1c-repo-reports\<op>-<stamp>.txt` (override with `-ReportFile`); the console shows the first 16000 chars (`-MaxReportChars`) plus the file path — read the file for anything beyond the excerpt.
- Passwords never appear in the printed command line.
- `-TimeoutSeconds N` kills a hung Designer after N seconds (default: no timeout).

## Failure handling — retry discipline

Same iterative discipline as DB updates (`content/skills/1c-metadata-manage/docs/db-manage.md → Update retry discipline`): read the log lines the script surfaced → classify → fix the cause → re-run. Typical classes:

| Log evidence | Cause | Action |
|---|---|---|
| `уже захвачен пользователем <X>` | Lock conflict | Report to the user; do **not** force-unlock |
| `не захвачен` on commit | Committing objects that were never locked | `lock` the missing objects, re-commit |
| Auth error (`Неправильное имя или пароль…`) | Wrong `REPOSITORY_USER`/`REPOSITORY_PASSWORD` or IB credentials | Re-ask the user once, per the `dev-standards-env.md` credential policy |
| `Не удалось подключиться к хранилищу` | Wrong `REPOSITORY_PATH` / server down | Verify the address with the user |
| Designer exits non-zero, empty log | Startup problem (license, another Configurator session holding the IB) | Close competing sessions; see `db-manage.md` session handling |
| Timeout kill | Hung dialog / dead network | `status` first, then retry once with a larger `-TimeoutSeconds` |

Two identical failures in a row = stop and report; never loop the same failing call.
