# Tasks — platform batch-check gate and three-signal verdict

> Where these tasks run: sections 2–7 are authored in the `1c-rules` source repository. Sections
> 1 and 8.3–8.4 need a real 1C platform and a development infobase, which this repository does not
> have — it ships rules, not a configuration. Execute them in a consuming project whose `.dev.env`
> resolves `PLATFORM_PATH` and `INFOBASE_PATH`, and carry the measured numbers and fixtures back
> into the implementation.

## 1. Pre-implementation confirmation

- [ ] 1.1 Confirm the project's platform version and form mode (`openspec/project.md`, `.dev.env`
      `PLATFORM_PATH`), and re-confirm that every switch used by the default profiles exists in
      that version. A rejected switch fails the entire batch command, not only that check.
- [ ] 1.2 Run each profile once by hand against the dev infobase and record the actual wall-clock
      duration and the warning volume of the full profile. These numbers decide the default
      timeout and confirm that the `standard` depth stays affordable.
- [ ] 1.3 Capture one real `/Out` log and one `/DumpResult` file per profile as fixtures for the
      verdict helper, including at least one run that exits 0 while reporting an error.

## 2. Shared verdict helper

- [ ] 2.1 Create `content/skills/1c-metadata-manage/tools/_common/DesignerVerdict.ps1` exposing
      `Get-DesignerVerdict` over the process exit code, the `/DumpResult` path, and the `/Out` log
      text; return `Success`, `ProcessCode`, `ResultCode`, `TimedOut`, and the diagnostic lines.
- [ ] 2.2 Implement success-phrase matching **before** error-pattern matching, covering Russian and
      English platform locales; a log whose only match is a success phrase must yield `Success`.
- [ ] 2.3 Follow the `DevEnv.ps1` precedent for placement and dot-sourcing so the helper survives an
      upstream re-sync of the vendored scripts.
- [ ] 2.4 Validate the helper against the fixtures from task 1.3, including the exit-0-with-error case
      and the `ошибок не обнаружено` case.

## 3. New `db-check` tool

- [ ] 3.1 Create `content/skills/1c-metadata-manage/tools/1c-db-ops/scripts/db-check.ps1` with
      `-Profile quick|apply|full`, optional
      `-Extension <Имя>`, an explicit timeout, and pass-through for additional switches; reuse the
      connection, authentication, and `.dev.env` resolution already used by the sibling scripts.
- [ ] 3.2 Derive the `/CheckModules` context switches from the configuration's form mode, with an
      explicit override parameter.
- [ ] 3.3 Request `/Out` and `/DumpResult` on every invocation and compute the verdict through
      `Get-DesignerVerdict`; report the log and result paths on failure.
- [ ] 3.4 Keep secrets out of any echoed command line, matching the existing `Protect-Secrets` usage.
- [ ] 3.5 Exit non-zero on a failed verdict so the calling command can abort the sequence.

## 4. Migrate the destructive path

- [ ] 4.1 Patch `content/skills/1c-metadata-manage/tools/1c-db-ops/scripts/db-update.ps1` to
      request `/DumpResult` and to compute its
      verdict through the shared helper, replacing the hardcoded fatal-pattern list.
- [ ] 4.2 Keep the patch minimal and self-contained, and record it wherever the `DevEnv.ps1` patch is
      recorded so an upstream re-sync does not drop it silently.
- [ ] 4.3 Confirm that the existing update retry loop still behaves identically on a failing update.

## 5. Rule wiring

- [ ] 5.1 Add Gate 3b to `content/rules/verification-gates.md`, modelled on Gate 3a: trigger, pass
      criterion, blocking failure, the fixed Risks line when the gate cannot run, and an explicit
      statement that it never substitutes for Gates 1–3.
- [ ] 5.2 Add the depth modulation to `content/rules/verification-policy.md`: `lite` on
      promotion-trigger changes only, `standard` for quick plus applicability, `full` adds the full
      profile.
- [ ] 5.3 State the warning policy once, in the gate text: errors and applicability failures block,
      warnings are reported.

## 6. Command wiring

- [ ] 6.1 Insert the check step into `content/commands/update1cbase.md` between the configuration load
      and the database structure update, inside the existing retry loop.
- [ ] 6.2 Insert the same step into `content/commands/deploy-and-test.md` between Step 2 and Step 3,
      for both the `ibcmd` and the Designer branches, and state that UI tests run only after a clean
      gate.

## 7. Documentation

- [ ] 7.1 Document the profiles, the switch sets, and the verdict contract in
      `content/skills/1c-metadata-manage/docs/db-manage.md`.
- [ ] 7.2 Point extension work at the applicability check from
      `content/skills/1c-metadata-manage/docs/cfe-manage.md`, stating that `cfe-validate.ps1` is
      structural validation and does not prove applicability.
- [ ] 7.3 Register the new tool in `content/skills/1c-metadata-manage/SKILL.md`.
- [ ] 7.4 Credit the adapted source (Muredsa/1C-Enterprise-Agent-Toolkit, MIT) in the new script
      header, following the existing `Source:` header convention.

## 8. Change verification

- [ ] 8.1 Run `tools/validate-rules.ps1` and fix every reported frontmatter, path, and cross-reference
      problem introduced by this change.
- [ ] 8.2 Confirm the installer places the new files for every adapter that receives the skill, adding
      registration only if the inventory requires it.
- [ ] 8.3 End-to-end run against the dev infobase: load a deliberately broken extension, confirm the
      gate fails before the database update, fix it, confirm a clean pass and that the update then
      proceeds.
- [ ] 8.4 Confirm the degradation path: with `INFOBASE_PATH` empty, the gate is skipped, delivery is
      not blocked, and the Risks line is emitted.
