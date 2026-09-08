# Preview, dry-run and logical addressing — `Invoke-1CEdit.ps1`

Reference for `tools/_common/Invoke-1CEdit.ps1`. The short version lives in [`SKILL.md → Preview before apply, and logical addressing`](../SKILL.md); read this file for the address grammar, the rollback backends, and what the wrapper deliberately does not promise.

## Why a wrapper and not thirty patches

The tools under `tools/` are vendored from upstream `cc-1c-skills`. Each one opens and writes its own files; there is no shared write layer to patch. Adding a preview flag to every mutating script would mean editing thirty-odd files — including `form-compile.ps1` at 355 KB — and losing all of it at the next upstream sync. The wrapper sits in front of them instead, so preview, dry-run and logical addressing are two local files (`Invoke-1CEdit.ps1` and `MetadataAddress.ps1`) that an upstream refresh never touches.

The trade this makes: the wrapper cannot know what a tool *intends* to write, only what it *did* write. So a preview really runs the tool and then undoes it. Everything below follows from that.

## Invocation

```powershell
Invoke-1CEdit.ps1 -Tool <name> [-Object <address>] [-Root <dump>] [-Preview] [-Scope <paths>] [-NoDiff] <tool parameters…>
```

| Parameter | Meaning |
|---|---|
| `-Tool` | Script base name — `meta-edit`, `form-edit`, `skd-edit`, `role-compile`, … Resolved by file name under `tools/`, so a tool added by a later sync works with no edit here. An ambiguous name is an error, never a guess. |
| `-Object` | Logical address (grammar below). Resolved and passed as `-Path`, the alias every path-taking tool of this skill carries. Omit it for tools addressed differently (`meta-remove -ConfigDir -Object`, the `db-*` family) and pass their own parameters. |
| `-Root` | Dump root. Default: `EXPORT_PATH` from `.dev.env`, else the nearest ancestor holding `Configuration.xml`. |
| `-Preview` / `-DryRun` | Run, show the diff, restore the tree. |
| `-Scope` | Extra paths to watch and restore. Only meaningful for the copy backend. |
| `-NoDiff` | Apply without printing the diff. |
| everything else | Passed through to the tool by name. |

Exit code is the tool's own, with one exception: a preview whose rollback did not fully succeed exits `2` and says what is still on disk. Treat `2` as "inspect the tree before doing anything else".

## Address grammar

```
<Kind>.<Name>                        -> Catalogs\Контрагенты.xml
<Kind>.<Name>.Форма.<FormName>       -> …\Forms\<FormName>\Ext\Form.xml
<Kind>.<Name>.Макет.<TemplateName>   -> …\Templates\<TemplateName>\Ext\Template.xml
<Kind>.<Name>.Права                  -> …\Ext\Rights.xml
<Kind>.<Name>.МодульОбъекта          -> …\Ext\ObjectModule.bsl
<Kind>.<Name>.МодульМенеджера        -> …\Ext\ManagerModule.bsl
<Kind>.<Name>.МодульНабораЗаписей    -> …\Ext\RecordSetModule.bsl
```

Kind names and member keywords are accepted in Russian and English (`Справочник` or `Catalog`, `Форма` or `Form`). The full kind table is `tools/_common/MetadataAddress.ps1`; an unknown kind is refused with the accepted list, because a mistyped kind silently resolving to a non-existent path is exactly the failure this removes.

`Роль.ПолныеПрава.Права` is the useful one for `role-info` / `role-validate`: they take `Ext\Rights.xml`, which nobody remembers.

## Rollback backends

The backend is chosen automatically and always named in the output.

**git** — the dump is inside a repository. The whole dump is watched, so a write outside the edited object is caught too. Rollback is `git checkout` plus `git clean` of the watched path.

> The run **refuses to start** (exit `2`) when the watched path already has uncommitted changes. Rolling back over someone's work in progress is the one failure this must never cause. Commit or stash first, or apply without `-Preview`.

**copy** — no repository. The target file, the object's own folder and the root `Configuration.xml` are copied to a temp folder before the run. The watched scope is printed, and additions, modifications and deletions inside it are diffed and restored. A write **outside** that scope is neither shown nor undone; the output says so rather than implying full coverage. Use `-Scope` when a tool is known to reach further.

## What this does not do

- It is **not** a plan produced before execution. The tool runs for real; a preview differs from an apply only in what happens afterwards. Do not preview against a production dump under the assumption that nothing is written — something is written, then reverted.
- It does **not** replace validation. `meta-edit` still runs `meta-validate` and still exits non-zero on a bad object; the preview shows the diff *and* the validator verdict, and both belong in the report.
- It does **not** cover the `db-*` infobase family in any useful way. Those talk to an infobase, not to files, and an infobase change is not restored by putting files back. Preview them with their own switches where they have them (`db-load-git -DryRun`) and treat the rest as the destructive operations they are.
- The Python entry points (`form-add.py`, `remove-form.py`, `form-compile.py`, `meta-edit.py`, `meta-validate.py`) are **not** wrapped: the wrapper is PowerShell. On Linux / macOS use the tools' own `-DryRun` where it exists, and `git diff` after the run otherwise.

## Reporting

A change shown through the wrapper is worth naming in the delivery report, on the existing `Metadata tooling:` line:

```
Metadata tooling: Invoke-1CEdit -Tool meta-edit -Object Справочник.Контрагенты (preview shown, then applied)
```
