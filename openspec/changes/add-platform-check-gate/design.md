# Design — platform batch-check gate and three-signal verdict

## Architecture decisions

### 1. The gate runs against the infobase, between load and DB update

`/CheckModules`, `/CheckConfig`, and `/CheckCanApplyConfigurationExtensions` evaluate the
configuration **stored in the infobase**, not a directory of XML. That fixes the placement:
the gate belongs after `/LoadConfigFromFiles` (or `/LoadCfg -Extension`) and before
`/UpdateDBCfg`. Running it earlier checks the previous state; running it later means the
restructuring already happened.

Consequence for the commands: `/update1cbase` and `/deploy-and-test` grow a check step
between their existing load and update steps, inside the same session-termination and retry
discipline they already apply. A failed check aborts before the update, which is precisely
the value — a bad configuration never reaches restructuring.

### 2. One new tool, not one per profile

`db-check.ps1` in `1c-db-ops` takes a `-Profile` parameter (`quick`, `apply`, `full`) and an
optional `-Extension <Имя>`. `1c-db-ops` already owns IB-bound operations, `.dev.env`
resolution, platform discovery, log capture, and the connection/authentication argument
shapes, so a new sibling script inherits all of it. A separate `cfe-check` in `1c-cfe-manage`
was rejected: it would duplicate the connection layer, and the same checks apply to the main
configuration, which is not that tool's domain. `cfe-manage.md` points at `db-check` instead.

### 3. Profiles

| Profile | Designer command | Applies to |
|---|---|---|
| `quick` | `/CheckModules` with the context switches from decision 4 | main config, extension |
| `apply` | `/CheckCanApplyConfigurationExtensions -Extension <Имя>` | extension only |
| `full` | `/CheckConfig -ConfigLogIntegrity -IncorrectReferences -HandlersExistence -ExtendedModulesCheck` plus the context switches | main config, extension |

`full` deliberately omits `-UnreferenceProcedures`, `-EmptyHandlers`, `-CheckUseModality`,
`-CheckUseSynchronousCalls`, `-DistributiveModules`, and `-UnsupportedFunctional` from the
default set. They are legitimate switches, but on a typical configuration they produce
warning volume that costs context and blocks nothing (warnings are non-blocking by the locked
decision). They are reachable through a pass-through parameter for release-oriented runs.

`apply` is a separate command, not a switch of the other two. Omitting `-Extension` makes it
check every extension in load order, which is the right behaviour when several extensions
coexist and the new one must not break the chain.

### 4. Context switches follow the configuration's form mode

`/CheckModules` checks nothing unless at least one context switch is given, and the useful set
depends on how the configuration runs. Default for a managed-forms configuration:
`-ThinClient -Server -ExternalConnection -ExtendedModulesCheck`. For an ordinary-forms or
mixed configuration the thick-client ordinary context is the meaningful one, so the script
derives the set from the form mode recorded in `openspec/project.md`, and exposes an override.
Deriving beats hardcoding here because a wrong context set silently checks the wrong thing
rather than failing loudly.

### 5. The verdict is a shared pure function, not another per-script log scan

New file `content/skills/1c-metadata-manage/tools/_common/DesignerVerdict.ps1` exposes
`Get-DesignerVerdict`, taking the process
exit code, the `/DumpResult` file path, and the `/Out` log text, and returning a verdict object
with `Success`, `ProcessCode`, `ResultCode`, and the extracted diagnostic lines. A run is
successful only when all three signals agree.

Two details make it correct rather than merely present. First, the success-phrase list is
matched **before** the error-pattern list: a naive scan for `ошиб` reports `ошибок не
обнаружено` as a failure, which is how log scanning usually gets abandoned as too noisy.
Second, patterns cover both Russian and English platform locales.

Placement in `_common/` follows the `DevEnv.ps1` precedent: the vendored `cc-1c-skills` scripts
dot-source the helper from inside their own functions, so the patch stays self-contained and
survives the next upstream re-sync. `db-check.ps1` (ours) uses it directly.

### 6. Migration of existing scripts is staged

`db-update.ps1` already has a narrow hardcoded log scan and no `/DumpResult`; it is migrated in
this change because it guards the most destructive operation we run. The remaining vendored
scripts that invoke Designer keep their current behaviour and are listed as follow-up work — a
sweep across all of them in one change would be a large diff on vendored code for no additional
safety on the path this change is about.

### 7. Gate 3b mirrors Gate 3a, including its degradation contract

The new gate is written into `verification-gates.md` in the shape the file already uses for the
conditional live-IB gate: explicit trigger, explicit pass criterion, blocking on failure, and a
fixed Risks line when the trigger fired but the gate could not run. Reusing the existing shape
matters more than inventing a better one — the rule file's readers already know it, and the
delivery report contract does not need a new special case.

Depth modulation follows `VERIFICATION_DEPTH`:

- `lite` — gate runs only on promotion-trigger changes.
- `standard` (default) — `quick` for any BSL or metadata change loaded into the IB; `apply` in
  addition whenever an extension is touched.
- `full` — additionally `full`.

Retry budget is the one already defined in `AGENTS.md → MCP Tool Calling → B.1`: one clean pass
on the latest state, and after a blocking fix one confirmation run (`standard`) or two (`full`).
The gate is a script rather than an MCP validator, but the budget logic is identical and there
is no reason to write a second one.

### 8. Timeouts and infobase availability

A `/CheckConfig` run on a large typical configuration is measured in minutes, so the script takes
an explicit timeout with a conservative default and reports a timeout as a failure with the log
path preserved. Infobase contention reuses the existing discipline from
`update1cbase.md → Update retry loop`: terminate the hung Configurator by its own PID, never
blanket-kill `1cv8` processes.

## Risks

- **Platform-version drift in switch names.** The default profiles use switches that have been
  stable across 8.3.x, but the project's platform version must be confirmed at apply time before
  the profiles are frozen; a rejected switch fails the whole batch command, not just that check.
- **Gate cost on large configurations.** The `standard` depth deliberately keeps `full` out of the
  default path for this reason. If `quick` alone turns out to be slow on the target configuration,
  the trigger set — not the verdict logic — is what should be narrowed.
- **False confidence.** The gate proves that the configuration compiles and the extension applies.
  It does not prove behaviour. It never substitutes for Gates 1–3, and the rule text must say so
  explicitly, the same way Gate 3a does.
- **Vendored-script drift.** The `db-update.ps1` patch adds a dependency on a `_common` helper. If
  an upstream re-sync overwrites the file, the patch is lost silently. The task list includes
  recording the patch in the same place the `DevEnv.ps1` patch is recorded.

## Open Questions

None. The three architectural forks (gate status, warning policy, scope) were resolved with the
user before authoring and are recorded in `proposal.md → Decisions locked with the user`.

## Context sources

Switch semantics and signatures verified against the published 1C:Enterprise command-line
reference for Designer batch mode, as listed in `proposal.md → Context sources`; the repository
gap (no check commands, no `/DumpResult`, vendored `Invoke-PlatformProcess` per script, `_common`
containing only `.dev.env` readers) verified by direct inspection of the source tree.
