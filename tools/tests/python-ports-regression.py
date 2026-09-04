#!/usr/bin/env python3
"""Behaviour regressions for the Python runtime of the 1c-metadata-manage skill.

The toolchain of that skill is PowerShell-only, so a Linux / macOS install
receives tools it cannot execute. The fix is to ship each tool twice - a
PowerShell script for Windows and a Python port next to it - vendored from
Nikolay-Shirokov/cc-1c-skills (MIT) at the commit the PowerShell family was
synced from: ecd289fe11733028d87b55284ea9fb5feff8f513.

This file is the Python side's regression net. It currently covers the first
ported tool, ``remove-form``, whose upstream port carries a safety regression
against the shipped PowerShell contract: upstream rejects ``-DryRun`` as an
unknown argument, deletes without ``-Force``, and deletes the form files
*before* it parses the root XML, so a parse failure leaves a half-removed tree.
Pinned here:

  1. ``-DryRun`` prints the full removal / reference-cleanup plan and performs
     zero filesystem mutation.
  2. A real deletion without ``-Force`` exits 2 before every mutation;
     ``-Force`` authorizes the deletion of the form itself, and the reference
     cleanup stays explicit (named in the plan) and part of the same atomic
     commit.
  3. Refusals (absent form, form absent from ChildObjects) and a failing
     root-XML commit leave the tree byte-identical - no partial write.
  4. PowerShell / Python parity of that safety contract, where a PowerShell host
     is available.
  5. Packaging - the installer ships the Python entry point, tracks it in
     ``.ai-rules.json``, and the installed copy behaves like the source one.

The remaining metadata tools are ported in follow-up units; add their cases
here as they land.

Cases materialize their own fixtures into a temp directory (exact bytes: BOM and
chosen EOL) and assert on the raw bytes of the result, so no 1C platform is
needed. Fixtures under ``fixtures/`` are stored LF-only; the runner applies the
target EOL itself and is therefore immune to the checkout EOL policy
(``core.autocrlf``) of the machine it runs on.

Usage::

    python tools/tests/python-ports-regression.py
    python tools/tests/python-ports-regression.py --filter 'remove-form*'
    python tools/tests/python-ports-regression.py --keep-work-dir
"""

from __future__ import annotations

import argparse
import base64
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import traceback
import uuid

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FIXTURES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
TOOLS_DIR = os.path.join(REPO_ROOT, "content", "skills", "1c-metadata-manage", "tools")

REMOVE_FORM_PY = os.path.join(TOOLS_DIR, "1c-form-scaffold", "scripts", "remove-form.py")
REMOVE_FORM_PS1 = os.path.join(TOOLS_DIR, "1c-form-scaffold", "scripts", "remove-form.ps1")


# ---------------------------------------------------------------- infrastructure

class CaseFailure(Exception):
    pass


class CaseSkipped(Exception):
    """Raised when a case needs a runtime the machine does not have (e.g. a
    PowerShell host on a bare Linux container). Reported, never fatal."""


CASES: list[tuple[str, "callable"]] = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn

    return wrap


def fail(message):
    raise CaseFailure(message)


def assert_true(condition, message):
    if not condition:
        fail(message)


def assert_equal(expected, actual, what):
    if str(expected) != str(actual):
        fail(f"{what} : expected [{expected}], got [{actual}]")


def file_facts(path):
    """Byte-level properties of a file: BOM, EOL mix, text, lines."""
    with open(path, "rb") as handle:
        raw = handle.read()
    has_bom = raw[:3] == b"\xef\xbb\xbf"
    body = raw[3:] if has_bom else raw
    text = body.decode("utf-8")
    crlf = text.count("\r\n")
    lf = text.count("\n")
    return {
        "path": path,
        "bom": has_bom,
        "text": text,
        "crlf": crlf,
        "lf": lf,
        "lone_lf": lf - crlf,
        "lines": re.split(r"\r\n|\n", text),
        "sha": base64.b64encode(raw).decode("ascii"),
    }


def copy_fixture(name, dest, eol="\n"):
    """Materialize a fixture tree into *dest* with the requested EOL and a BOM."""
    src = os.path.join(FIXTURES_DIR, name)
    if not os.path.isdir(src):
        raise CaseFailure(f"Fixture not found: {src}")
    os.makedirs(dest, exist_ok=True)
    for root, _dirs, files in os.walk(src):
        for fname in files:
            full = os.path.join(root, fname)
            rel = os.path.relpath(full, src)
            out = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if fname.endswith(".bin"):
                shutil.copyfile(full, out)
                continue
            with open(full, "rb") as handle:
                raw = handle.read()
            if raw[:3] == b"\xef\xbb\xbf":
                raw = raw[3:]
            text = raw.decode("utf-8").replace("\r\n", "\n")
            if eol != "\n":
                text = text.replace("\n", eol)
            with open(out, "wb") as handle:
                handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))


def snapshot_tree(root):
    """Path -> raw bytes for every file under *root*. Used for no-mutation asserts."""
    out = {}
    for dirpath, _dirs, files in os.walk(root):
        for fname in files:
            full = os.path.join(dirpath, fname)
            with open(full, "rb") as handle:
                out[os.path.relpath(full, root).replace("\\", "/")] = handle.read()
    return out


def find_powershell_host():
    """`pwsh` on any OS, Windows PowerShell as the fallback. None when neither exists."""
    for exe in ("pwsh", "powershell.exe" if os.name == "nt" else None):
        if exe and shutil.which(exe):
            return exe
    return None


def run_powershell_tool(script, tool_args, work_dir):
    host = find_powershell_host()
    if not host:
        raise CaseSkipped("no PowerShell host on PATH (pwsh / powershell.exe)")
    proc = subprocess.run(
        [host, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, *tool_args],
        cwd=work_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {"exit_code": proc.returncode, "stdout": proc.stdout or "", "stderr": proc.stderr or ""}


def run_python_tool(script, tool_args, work_dir):
    proc = subprocess.run(
        [sys.executable, script, *tool_args],
        cwd=work_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {"exit_code": proc.returncode, "stdout": proc.stdout or "", "stderr": proc.stderr or ""}


# ---------------------------------------------------------------- remove-form

@case("remove-form: -DryRun prints the full plan and mutates nothing")
def _(work):
    copy_fixture("epf-with-form", work)
    before = snapshot_tree(work)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-DryRun"],
        work,
    )
    assert_equal(0, run["exit_code"], f"dry-run exit code (stderr: {run['stderr']})")

    out = run["stdout"]
    assert_true("Planned changes:" in out, f"plan header missing:\n{out}")
    assert_true("remove ChildObjects/Form 'MainForm'" in out, f"plan does not name the registration removal:\n{out}")
    assert_true("clear DefaultForm" in out, f"plan does not name the default-form cleanup:\n{out}")
    assert_true("Obrabotka/Forms/MainForm.xml" in out.replace("\\", "/"), f"plan does not name the metadata file:\n{out}")
    assert_true("Obrabotka/Forms/MainForm" in out.replace("\\", "/"), f"plan does not name the form directory:\n{out}")
    assert_true("[DRY-RUN]" in out, f"dry-run marker missing:\n{out}")

    after = snapshot_tree(work)
    assert_equal(sorted(before), sorted(after), "dry-run changed the file list")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after[rel]), f"dry-run modified {rel}")


@case("remove-form: a non-dry run without -Force exits 2 before any mutation")
def _(work):
    copy_fixture("epf-with-form", work)
    before = snapshot_tree(work)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work],
        work,
    )
    assert_equal(2, run["exit_code"], f"missing -Force must exit 2 (stderr: {run['stderr']})")
    assert_true("-Force" in run["stderr"], f"stderr does not name the required switch: {run['stderr']}")

    after = snapshot_tree(work)
    assert_equal(sorted(before), sorted(after), "refused removal changed the file list")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after[rel]), f"refused removal modified {rel}")
    assert_true(
        not any(p.endswith(".remove-form.tmp") for p in after),
        f"refused removal left a temporary file behind: {sorted(after)}",
    )


@case("remove-form: -Force deletes the form and clears the default-form reference")
def _(work):
    copy_fixture("epf-with-form", work)
    root_xml = os.path.join(work, "Obrabotka.xml")
    before = file_facts(root_xml)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-Force"],
        work,
    )
    assert_equal(0, run["exit_code"], f"-Force run exit code (stderr: {run['stderr']})")

    assert_true(not os.path.exists(os.path.join(work, "Obrabotka", "Forms", "MainForm.xml")),
                "form metadata file survived the -Force run")
    assert_true(not os.path.isdir(os.path.join(work, "Obrabotka", "Forms", "MainForm")),
                "form directory survived the -Force run")
    assert_true(os.path.exists(os.path.join(work, "Obrabotka", "Forms", "AuxForm.xml")),
                "the sibling form was deleted too")

    after = file_facts(root_xml)
    assert_true("<Form>MainForm</Form>" not in after["text"], "ChildObjects still registers the removed form")
    assert_true("<Form>AuxForm</Form>" in after["text"], "the sibling registration was removed too")
    assert_true("DataProcessor.Obrabotka.Form.MainForm" not in after["text"],
                "DefaultForm still points at the removed form")
    assert_true(after["bom"], "root XML lost its BOM")
    assert_equal(0, after["crlf"], "CRLF introduced into an LF file")
    assert_true(before["lines"].count("") == after["lines"].count(""), "blank-line structure changed")
    assert_true(not os.path.exists(root_xml + ".remove-form.tmp"), "temporary root XML left behind")


@case("remove-form: every slot referencing the form is named in the plan and cleared")
def _(work):
    copy_fixture("epf-with-form", work)
    root_xml = os.path.join(work, "Obrabotka.xml")
    # form-add writes the purpose-specific slot, so a form can be referenced from
    # more than one place. Clearing only the generic DefaultForm would leave a
    # dangling reference to a file that no longer exists.
    facts = file_facts(root_xml)
    text = facts["text"].replace(
        "<AuxiliarySearchForm/>",
        "<AuxiliarySearchForm>DataProcessor.Obrabotka.Form.MainForm</AuxiliarySearchForm>")
    assert_true(text != facts["text"], "fixture no longer carries AuxiliarySearchForm - the case cannot arm itself")
    with open(root_xml, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))

    dry = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-DryRun"],
        work,
    )
    assert_equal(0, dry["exit_code"], f"dry-run exit code (stderr: {dry['stderr']})")
    assert_true("clear DefaultForm" in dry["stdout"], f"plan omits DefaultForm:\n{dry['stdout']}")
    assert_true("clear AuxiliarySearchForm" in dry["stdout"],
                f"plan omits the second referencing slot:\n{dry['stdout']}")

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-Force"],
        work,
    )
    assert_equal(0, run["exit_code"], f"-Force run exit code (stderr: {run['stderr']})")
    after = file_facts(root_xml)["text"]
    assert_true("DataProcessor.Obrabotka.Form.MainForm" not in after,
                f"a reference to the removed form survived:\n{after}")
    assert_true("<AuxiliarySearchForm></AuxiliarySearchForm>" in after or "<AuxiliarySearchForm/>" in after,
                f"AuxiliarySearchForm was not cleared but dropped:\n{after}")


@case("remove-form: an absent form is refused before any mutation")
def _(work):
    copy_fixture("epf-with-form", work)
    before = snapshot_tree(work)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "NoSuchForm", "-SrcDir", work, "-Force"],
        work,
    )
    assert_equal(1, run["exit_code"], f"absent form must exit 1 (stderr: {run['stderr']})")

    after = snapshot_tree(work)
    assert_equal(sorted(before), sorted(after), "refused run changed the file list")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after[rel]), f"refused run modified {rel}")


@case("remove-form: a form absent from ChildObjects is refused before any mutation")
def _(work):
    copy_fixture("epf-with-form", work)
    root_xml = os.path.join(work, "Obrabotka.xml")
    # Unregister AuxForm but keep its files: upstream would delete them and leave
    # the root XML alone, which is exactly the half-applied state to refuse.
    facts = file_facts(root_xml)
    text = facts["text"].replace("\t\t\t<Form>AuxForm</Form>\n", "")
    assert_true(text != facts["text"], "fixture no longer registers AuxForm - the case cannot arm itself")
    with open(root_xml, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))
    before = snapshot_tree(work)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "AuxForm", "-SrcDir", work, "-Force"],
        work,
    )
    assert_equal(1, run["exit_code"], f"unregistered form must exit 1 (stderr: {run['stderr']})")
    assert_true("ChildObjects" in run["stderr"], f"stderr does not explain the refusal: {run['stderr']}")

    after = snapshot_tree(work)
    assert_equal(sorted(before), sorted(after), "refused run changed the file list")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after[rel]), f"refused run modified {rel}")


def _rename_fixture_to_unicode(sandbox, object_name, form_name):
    """Rewrite the epf-with-form fixture in place to Cyrillic object / form names.

    1C identifiers cannot contain spaces, so the space risk is exercised through
    the containing directory instead - which is where a real project hits it
    (`C:\\My Projects\\...`, `/home/user/1c src/...`)."""
    root_xml = os.path.join(sandbox, "Obrabotka.xml")
    facts = file_facts(root_xml)
    text = facts["text"].replace("Obrabotka", object_name).replace("MainForm", form_name)
    with open(root_xml, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))
    os.replace(root_xml, os.path.join(sandbox, f"{object_name}.xml"))

    obj_dir = os.path.join(sandbox, "Obrabotka")
    forms_dir = os.path.join(obj_dir, "Forms")
    meta = os.path.join(forms_dir, "MainForm.xml")
    meta_facts = file_facts(meta)
    with open(meta, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + meta_facts["text"].replace("MainForm", form_name).encode("utf-8"))
    os.replace(meta, os.path.join(forms_dir, f"{form_name}.xml"))
    os.replace(os.path.join(forms_dir, "MainForm"), os.path.join(forms_dir, form_name))
    os.replace(obj_dir, os.path.join(sandbox, object_name))


@case("remove-form: Cyrillic names under a path with spaces behave identically")
def _(work):
    object_name = "ТестоваяОбработка"
    form_name = "ОсновнаяФорма"
    sandbox = os.path.join(work, "My 1C Sources", "src dump")
    copy_fixture("epf-with-form", sandbox)
    _rename_fixture_to_unicode(sandbox, object_name, form_name)

    before = snapshot_tree(sandbox)
    dry = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", object_name, "-FormName", form_name, "-SrcDir", sandbox, "-DryRun"],
        sandbox,
    )
    assert_equal(0, dry["exit_code"], f"dry-run exit code (stderr: {dry['stderr']})")
    assert_true(form_name in dry["stdout"], f"plan lost the Cyrillic form name:\n{dry['stdout']}")
    assert_true("clear DefaultForm" in dry["stdout"], f"plan lost the reference cleanup:\n{dry['stdout']}")
    after_dry = snapshot_tree(sandbox)
    assert_equal(sorted(before), sorted(after_dry), "dry-run changed the file list")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after_dry[rel]), f"dry-run modified {rel}")

    refused = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", object_name, "-FormName", form_name, "-SrcDir", sandbox],
        sandbox,
    )
    assert_equal(2, refused["exit_code"], f"missing -Force must exit 2 (stderr: {refused['stderr']})")
    assert_equal(sorted(before), sorted(snapshot_tree(sandbox)), "refused run changed the file list")

    forced = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", object_name, "-FormName", form_name, "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(0, forced["exit_code"], f"-Force exit code (stderr: {forced['stderr']})")
    assert_true(not os.path.exists(os.path.join(sandbox, object_name, "Forms", f"{form_name}.xml")),
                "form metadata file survived")
    assert_true(not os.path.isdir(os.path.join(sandbox, object_name, "Forms", form_name)),
                "form directory survived")
    text = file_facts(os.path.join(sandbox, f"{object_name}.xml"))["text"]
    assert_true(f"<Form>{form_name}</Form>" not in text, "registration survived")
    assert_true("<Form>AuxForm</Form>" in text, "sibling registration lost")
    assert_true(f"DataProcessor.{object_name}.Form.{form_name}" not in text,
                "DefaultForm still points at the removed form")


@case("remove-form: a failing root-XML commit deletes nothing and truncates nothing")
def _(work):
    copy_fixture("epf-with-form", work)
    root_xml = os.path.join(work, "Obrabotka.xml")
    before = snapshot_tree(work)

    # Make the atomic rename fail by occupying the temp name with a directory:
    # os.replace() onto a directory raises on every platform, which is the
    # closest reproducible stand-in for "the commit blew up mid-write".
    os.makedirs(root_xml + ".remove-form.tmp", exist_ok=True)
    try:
        run = run_python_tool(
            REMOVE_FORM_PY,
            ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-Force"],
            work,
        )
        assert_true(run["exit_code"] != 0, "a failed commit reported success")
        after = snapshot_tree(work)
        assert_equal(sorted(before), sorted(after), "a failed commit still changed the file list")
        for rel, data in before.items():
            assert_equal(base64.b64encode(data), base64.b64encode(after[rel]),
                         f"a failed commit modified {rel}")
    finally:
        shutil.rmtree(root_xml + ".remove-form.tmp", ignore_errors=True)


@case("remove-form parity: PowerShell and Python agree on the safety contract")
def _(work):
    """Same scenarios through both runtimes, same observable safety outcome.

    Byte equality of the root XML is deliberately NOT asserted: remove-form.ps1
    re-serializes through System.Xml.XmlWriter and loses the Configurator style
    (CRLF into an LF file, `<Tag />` for `<Tag/>`, lower-cased encoding), while
    the Python port keeps upstream's round-trip style preservation. What has to
    match is the safety contract - exit codes, what the plan announces, and which
    files survive."""

    def plan_steps(text, sandbox):
        """The plan is the operator-facing half of the contract: normalize the
        sandbox prefix away and compare what each runtime announces."""
        prefix = os.path.abspath(sandbox)
        steps = []
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped.startswith(("modify:", "delete:")):
                continue
            steps.append(stripped.replace(prefix, "<src>").replace("\\", "/"))
        return steps

    scenarios = [
        ("dry-run", ["-DryRun"], 0),
        ("no-force", [], 2),
        ("force", ["-Force"], 0),
    ]
    for label, extra, expected_exit in scenarios:
        results = {}
        for runtime, script, runner in (
            ("ps", REMOVE_FORM_PS1, run_powershell_tool),
            ("py", REMOVE_FORM_PY, run_python_tool),
        ):
            sandbox = os.path.join(work, f"{label}-{runtime}")
            copy_fixture("epf-with-form", sandbox)
            run = runner(
                script,
                ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, *extra],
                sandbox,
            )
            results[runtime] = (run, sorted(snapshot_tree(sandbox)), sandbox)

        for runtime, (run, _files, _sandbox) in results.items():
            assert_equal(expected_exit, run["exit_code"],
                         f"{label}/{runtime} exit code (stderr: {run['stderr']})")

        ps_run, ps_files, ps_sandbox = results["ps"]
        py_run, py_files, py_sandbox = results["py"]
        assert_equal(ps_files, py_files, f"{label}: surviving file lists differ between runtimes")

        ps_plan = plan_steps(ps_run["stdout"], ps_sandbox)
        py_plan = plan_steps(py_run["stdout"], py_sandbox)
        assert_true(ps_plan, f"{label}: the PowerShell run announced no plan at all")
        assert_true(ps_plan == py_plan,
                    f"{label}: plans differ\n  ps: {ps_plan}\n  py: {py_plan}")

    # And the committed result has to be semantically identical.
    for runtime in ("ps", "py"):
        text = file_facts(os.path.join(work, f"force-{runtime}", "Obrabotka.xml"))["text"]
        assert_true("<Form>MainForm</Form>" not in text, f"force/{runtime}: registration survived")
        assert_true("<Form>AuxForm</Form>" in text, f"force/{runtime}: sibling registration lost")
        assert_true("DataProcessor.Obrabotka.Form.MainForm" not in text,
                    f"force/{runtime}: DefaultForm still points at the removed form")


# ---------------------------------------------------------------- packaging

@case("packaging: install ships remove-form.py, tracks it, and the installed copy runs")
def _(work):
    """The skill tree is copied verbatim by Invoke-PlaceSkill, so a new tool file
    needs no installer change - but "needs no change" is exactly the kind of claim
    that rots silently. Install into a clean project and check the real output."""
    host = find_powershell_host()
    if not host:
        raise CaseSkipped("no PowerShell host on PATH (pwsh / powershell.exe)")

    project = os.path.join(work, "project")
    os.makedirs(project, exist_ok=True)
    installer = os.path.join(REPO_ROOT, "install.ps1")
    proc = subprocess.run(
        [host, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installer, "init",
         "-Tools", "claude-code", "-ProjectRoot", project, "-Source", REPO_ROOT,
         "-NonInteractive", "-AssumeYes", "-McpMode", "managed"],
        cwd=project, capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    assert_equal(0, proc.returncode, f"installer exit code (stderr: {proc.stderr[-800:]})")

    rel = ".claude/skills/1c-metadata-manage/tools/1c-form-scaffold/scripts/remove-form.py"
    installed = os.path.join(project, *rel.split("/"))
    assert_true(os.path.isfile(installed), f"installer did not ship the Python entry point: {rel}")
    with open(installed, "rb") as handle:
        installed_bytes = handle.read()
    with open(REMOVE_FORM_PY, "rb") as handle:
        source_bytes = handle.read()
    assert_equal(base64.b64encode(source_bytes), base64.b64encode(installed_bytes),
                 "installed remove-form.py differs from the source copy")

    manifest_path = os.path.join(project, ".ai-rules.json")
    assert_true(os.path.isfile(manifest_path), "installer wrote no .ai-rules.json manifest")
    with open(manifest_path, "rb") as handle:
        manifest = json.loads(handle.read().decode("utf-8-sig"))
    assert_true(rel in manifest.get("files", {}),
                f"manifest does not track the Python entry point: {rel}")

    # The installed copy is the one users actually run.
    sandbox = os.path.join(work, "installed-run")
    copy_fixture("epf-with-form", sandbox)
    dry = run_python_tool(
        installed,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-DryRun"],
        sandbox,
    )
    assert_equal(0, dry["exit_code"], f"installed copy dry-run (stderr: {dry['stderr']})")
    refused = run_python_tool(
        installed,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox],
        sandbox,
    )
    assert_equal(2, refused["exit_code"], f"installed copy without -Force (stderr: {refused['stderr']})")


# ---------------------------------------------------------------- run

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--filter", default="*", help="Run only cases whose name matches this wildcard pattern.")
    parser.add_argument("--keep-work-dir", action="store_true", help="Do not delete the temp working directory.")
    args = parser.parse_args()

    root = os.path.join(tempfile.gettempdir(), "1c-rules-py-regr-" + uuid.uuid4().hex[:8])
    os.makedirs(root, exist_ok=True)
    print(f"Work dir: {root}")
    print(f"Python:   {sys.version.split()[0]} ({sys.executable})")
    print()

    failures = []
    skipped = []
    index = 0
    for name, body in CASES:
        if not fnmatch.fnmatch(name, args.filter):
            continue
        index += 1
        work = os.path.join(root, f"case{index:02d}")
        os.makedirs(work, exist_ok=True)
        try:
            body(work)
            print(f"[PASS] {name}")
        except CaseSkipped as exc:
            skipped.append(f"{name}: {exc}")
            print(f"[SKIP] {name} - {exc}")
        except Exception as exc:  # noqa: BLE001 - a case may fail in any way
            failures.append(f"{name}: {exc}")
            print(f"[FAIL] {name}")
            print(f"       {exc}")
            if not isinstance(exc, CaseFailure):
                traceback.print_exc()

    print()
    if index == 0:
        print(f"No case matched filter '{args.filter}'.")
        return 1
    passed = index - len(failures) - len(skipped)
    if not failures:
        print(f"{passed}/{index} passed, {len(skipped)} skipped.")
        if not args.keep_work_dir:
            shutil.rmtree(root, ignore_errors=True)
        return 0
    print(f"{passed}/{index} passed, {len(skipped)} skipped, {len(failures)} failed.")
    print(f"Work dir kept for inspection: {root}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
