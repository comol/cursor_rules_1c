#!/usr/bin/env python3
"""Behaviour regressions for the Python runtime of the 1c-metadata-manage skill.

The toolchain of that skill is PowerShell-only, so a Linux / macOS install
receives tools it cannot execute. The fix is to ship each tool twice - a
PowerShell script for Windows and a Python port next to it - vendored from
Nikolay-Shirokov/cc-1c-skills (MIT) at the commit the PowerShell family was
synced from: ecd289fe11733028d87b55284ea9fb5feff8f513.

This file is the regression net for that runtime. It currently covers the first
ported tool, ``remove-form`` - a tool that deletes files, so its contract is
pinned rather than trusted. Upstream rejects ``-DryRun`` as an unknown argument,
deletes without ``-Force``, accepts any string as a name, and deletes the form
files *before* parsing the root XML. Pinned here, for the Python port and, where
the behaviour is shared, for ``remove-form.ps1`` too:

  1. ``-DryRun`` prints the full removal / reference-cleanup plan and performs
     zero filesystem mutation.
  2. A real deletion without ``-Force`` exits 2 before every mutation;
     ``-Force`` authorizes the deletion of the form itself, and the reference
     cleanup stays explicit - every cleared slot is named in the plan.
  3. Input safety: names must be 1C identifiers and every resolved path must
     stay inside the object's own ``Forms`` directory. Traversal, separators,
     absolute and UNC paths, trailing dots / spaces, look-alike letters and
     symlinked targets are refused with exit 2 before any mutation.
  4. Transactionality: a fault injected at *any* mutation step leaves the tree
     either fully original or fully final, never in between, and leaves no
     quarantine behind; a rollback that cannot complete says so instead of
     reporting success; a quarantine left by an interrupted run stops the next
     run rather than being written into.
  5. XML style: the exact ``ChildObjects`` indentation, BOM, EOL, encoding case
     and final newline of the original file survive the edit.
  6. PowerShell / Python parity of all of the above, where a PowerShell host is
     available.
  7. Licensing and packaging - the upstream MIT notice is present, distributable
     and installed; the installer ships the Python entry point, tracks both in
     ``.ai-rules.json``, and the installed copies match the source byte for byte.

The remaining metadata tools are ported in follow-up units; add their cases
here as they land.

Cases materialize their own fixtures into a temp directory (exact bytes: BOM and
chosen EOL) and assert on the raw bytes of the result, so no 1C platform is
needed. Fixtures under ``fixtures/`` are stored LF-only; the runner applies the
target EOL itself and is therefore immune to the checkout EOL policy
(``core.autocrlf``) of the machine it runs on. Nothing here reaches the network.

Usage::

    python -B tools/tests/python-ports-regression.py
    python -B tools/tests/python-ports-regression.py --python-only
    python -B tools/tests/python-ports-regression.py --filter 'remove-form*'
    python -B tools/tests/python-ports-regression.py --keep-work-dir
"""

from __future__ import annotations

import argparse
import base64
import contextlib
import fnmatch
import importlib.util
import io
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


CASES: list[tuple[str, "callable", bool]] = []


def case(name, needs_powershell=False):
    """Register a case. ``needs_powershell`` marks the ones a Python-only host
    (the Linux CI job) has to skip - the PowerShell parity and packaging gates
    belong to the Windows job."""

    def wrap(fn):
        CASES.append((name, fn, needs_powershell))
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
        [sys.executable, "-B", script, *tool_args],
        cwd=work_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {"exit_code": proc.returncode, "stdout": proc.stdout or "", "stderr": proc.stderr or ""}


def load_tool_module(script):
    """Import a tool script as a module so a case can inject a fault into a
    specific filesystem call. Kept out of the tool itself on purpose: shipping a
    fault-injection hook in a script that deletes files is its own hazard."""
    spec = importlib.util.spec_from_file_location("_1c_tool_under_test", script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_tool_in_process(script, tool_args, work_dir, faults=None):
    """Run ``main()`` in-process with ``faults`` patched over ``os`` / ``shutil``.

    ``faults`` maps a callable name (``os.replace``, ``os.remove``,
    ``shutil.copyfile``, ``shutil.rmtree``) to a predicate taking the call's
    positional args; when the predicate is true the call raises OSError instead
    of running. Returns the same shape as the subprocess runners plus the raised
    exception, if any."""
    faults = faults or {}
    module = load_tool_module(script)
    originals = {}
    targets = {"os.replace": os, "os.remove": os, "os.rmdir": os,
               "shutil.copyfile": shutil, "shutil.rmtree": shutil, "shutil.move": shutil}

    def patch(dotted, predicate):
        holder = targets[dotted]
        attr = dotted.split(".", 1)[1]
        real = getattr(holder, attr)
        originals[dotted] = (holder, attr, real)

        def wrapper(*call_args, **call_kwargs):
            if predicate(*call_args):
                raise OSError(5, f"injected failure in {dotted}")
            return real(*call_args, **call_kwargs)

        setattr(holder, attr, wrapper)

    for dotted, predicate in faults.items():
        patch(dotted, predicate)

    out, err = io.StringIO(), io.StringIO()
    exit_code, raised = 0, None
    prev_argv, prev_cwd = sys.argv, os.getcwd()
    try:
        sys.argv = [os.path.basename(script), *tool_args]
        os.chdir(work_dir)
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                module.main()
            except SystemExit as exc:
                exit_code = exc.code if isinstance(exc.code, int) else 1
            except BaseException as exc:  # noqa: BLE001 - the case inspects it
                raised = exc
                exit_code = 1
    finally:
        os.chdir(prev_cwd)
        sys.argv = prev_argv
        for holder, attr, real in originals.values():
            setattr(holder, attr, real)
    return {"exit_code": exit_code, "stdout": out.getvalue(), "stderr": err.getvalue(), "raised": raised}


def assert_tree_identical(before, after, what):
    """Every path and every byte the same - the rollback contract."""
    assert_equal(sorted(before), sorted(after), f"{what}: the file list changed")
    for rel, data in before.items():
        assert_equal(base64.b64encode(data), base64.b64encode(after[rel]), f"{what}: {rel} changed")


def assert_no_leftovers(root, what):
    """No temp / quarantine artifact survives a run, successful or not."""
    stray = sorted(
        p for p in list_all_entries(root)
        if ".remove-form" in os.path.basename(p) or os.path.basename(p).endswith(".tmp")
    )
    assert_true(not stray, f"{what}: temp / quarantine artifacts left behind: {stray}")


def list_all_entries(root):
    """Every file AND directory path under *root*, relative and slash-normalized."""
    entries = []
    for dirpath, dirnames, files in os.walk(root):
        for name in list(dirnames) + list(files):
            full = os.path.join(dirpath, name)
            entries.append(os.path.relpath(full, root).replace("\\", "/"))
    return entries


def childobjects_block(text):
    """The `<ChildObjects>` element with its surrounding indentation, verbatim."""
    match = re.search(r"(?s)([ \t]*<ChildObjects[ >].*?</ChildObjects>|[ \t]*<ChildObjects/>)", text)
    return match.group(1) if match else None


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


@case("remove-form: a leftover quarantine from an interrupted run stops the next one")
def _(work):
    """An interrupted run can leave the quarantine behind - it then holds the only
    copy of the removed files. The next run must refuse and point at it rather
    than write into it or delete it."""
    copy_fixture("epf-with-form", work)
    quarantine = os.path.join(work, ".remove-form-quarantine")
    os.makedirs(quarantine)
    with open(os.path.join(quarantine, "form-meta.xml"), "wb") as handle:
        handle.write(b"<recoverable/>")
    before = snapshot_tree(work)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", work, "-Force"],
        work,
    )
    assert_equal(2, run["exit_code"], f"a stale quarantine did not stop the run: {run['stdout'][:300]!r}")
    assert_true(".remove-form-quarantine" in run["stderr"],
                f"the refusal does not name the quarantine: {run['stderr'][:300]!r}")
    assert_tree_identical(before, snapshot_tree(work), "stale-quarantine refusal")


@case("remove-form parity: PowerShell and Python agree on the safety contract", needs_powershell=True)
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


# ------------------------------------------------- remove-form: input validation

# Names that must never reach the filesystem. 1C identifiers are Latin / Cyrillic
# letters, digits and underscore, not starting with a digit - everything below is
# either a path expression or not an identifier at all.
ADVERSARIAL_NAMES = [
    "../../victim", "..", ".", "../victim",
    "Forms/MainForm", "Forms\\MainForm", "a/b", "a\\b",
    "/etc/passwd", "C:/Windows/System32/drivers", "C:\\Windows",
    "\\\\server\\share\\x", "//server/share/x",
    "MainForm.", "MainForm ", " MainForm", "MainForm\t",
    "\u039cainForm",          # Greek capital Mu - a Latin "M" confusable
    "\u041c\u0430inForm\u200b",  # trailing zero-width space
    "1MainForm", "Main-Form", "Main Form", "",
]

# argv itself cannot carry a NUL on either platform, so this one is asserted
# in-process: the validator must still refuse it (defence in depth).
NUL_NAME = "Main\x00Form"


@case("remove-form: pathlike and non-identifier names are refused with exit 2, no mutation")
def _(work):
    for index, bad in enumerate(ADVERSARIAL_NAMES):
        sandbox = os.path.join(work, f"case{index:02d}")
        copy_fixture("epf-with-form", sandbox)
        before = snapshot_tree(sandbox)
        for slot, argv in (
            ("FormName", ["-ObjectName", "Obrabotka", "-FormName", bad]),
            ("ObjectName", ["-ObjectName", bad, "-FormName", "MainForm"]),
        ):
            run = run_python_tool(REMOVE_FORM_PY, [*argv, "-SrcDir", sandbox, "-Force"], sandbox)
            assert_equal(2, run["exit_code"],
                         f"{slot}={bad!r} must be refused with exit 2 "
                         f"(stdout: {run['stdout'][:200]!r} stderr: {run['stderr'][:200]!r})")
            assert_tree_identical(before, snapshot_tree(sandbox), f"{slot}={bad!r}")
        # -DryRun must refuse just as hard: the plan itself would echo the path.
        run = run_python_tool(
            REMOVE_FORM_PY,
            ["-ObjectName", "Obrabotka", "-FormName", bad, "-SrcDir", sandbox, "-DryRun"],
            sandbox,
        )
        assert_equal(2, run["exit_code"], f"FormName={bad!r} must be refused in -DryRun too")
        assert_tree_identical(before, snapshot_tree(sandbox), f"dry-run {bad!r}")
        assert_no_leftovers(sandbox, f"refused {bad!r}")

    # "nul" is a reserved device name on Windows - do not name a directory that.
    sandbox = os.path.join(work, "nul-name")
    copy_fixture("epf-with-form", sandbox)
    before = snapshot_tree(sandbox)
    run = run_tool_in_process(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", NUL_NAME, "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(2, run["exit_code"], f"FormName={NUL_NAME!r} must be refused with exit 2")
    assert_tree_identical(before, snapshot_tree(sandbox), "NUL name")


@case("remove-form: a traversal name cannot delete anything outside Forms/")
def _(work):
    sandbox = os.path.join(work, "src")
    copy_fixture("epf-with-form", sandbox)
    # `Forms/../../victim` resolves to <SrcDir>/victim - outside the form directory.
    with open(os.path.join(sandbox, "victim.xml"), "w", encoding="utf-8") as handle:
        handle.write("<x/>")
    os.makedirs(os.path.join(sandbox, "victim"), exist_ok=True)
    with open(os.path.join(sandbox, "victim", "payload.txt"), "w", encoding="utf-8") as handle:
        handle.write("data")
    # Register the traversal name so nothing but the identifier check can stop it.
    root_xml = os.path.join(sandbox, "Obrabotka.xml")
    text = file_facts(root_xml)["text"].replace(
        "<Form>AuxForm</Form>", "<Form>AuxForm</Form>\n\t\t\t<Form>../../victim</Form>")
    with open(root_xml, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))
    before = snapshot_tree(sandbox)

    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "../../victim", "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(2, run["exit_code"], f"traversal was not refused (stdout: {run['stdout'][:300]!r})")
    assert_tree_identical(before, snapshot_tree(sandbox), "traversal run")


@case("remove-form: a symlinked form directory or metadata file is refused")
def _(work):
    sandbox = os.path.join(work, "src")
    copy_fixture("epf-with-form", sandbox)
    outside_dir = os.path.join(work, "outside-dir")
    os.makedirs(outside_dir, exist_ok=True)
    with open(os.path.join(outside_dir, "payload.txt"), "w", encoding="utf-8") as handle:
        handle.write("data")

    forms = os.path.join(sandbox, "Obrabotka", "Forms")
    link = os.path.join(forms, "MainForm")
    shutil.rmtree(link)
    try:
        os.symlink(outside_dir, link, target_is_directory=True)
    except (OSError, NotImplementedError, AttributeError) as exc:
        raise CaseSkipped(f"symlinks unavailable on this host ({exc})")

    before = snapshot_tree(sandbox)
    outside_before = snapshot_tree(outside_dir)
    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(2, run["exit_code"],
                 f"a symlinked form directory was not refused (stdout: {run['stdout'][:300]!r})")
    assert_tree_identical(outside_before, snapshot_tree(outside_dir), "symlink target")
    assert_equal(sorted(before), sorted(snapshot_tree(sandbox)), "sandbox file list changed")


# ------------------------------------------------- remove-form: transactionality

def _expected_final_state(work):
    """Tree of a clean, successful removal - the only acceptable non-rollback outcome."""
    reference = os.path.join(work, "_reference")
    copy_fixture("epf-with-form", reference)
    run = run_python_tool(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", reference, "-Force"],
        reference,
    )
    assert_equal(0, run["exit_code"], f"reference removal failed (stderr: {run['stderr']})")
    return snapshot_tree(reference)


def _count_calls(work, primitive):
    """How many times a clean run calls *primitive*, so faults can target each one."""
    sandbox = os.path.join(work, f"_count-{primitive.replace('.', '-')}")
    copy_fixture("epf-with-form", sandbox)
    seen = []

    def counting(*call_args):
        seen.append(call_args)
        return False

    run = run_tool_in_process(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
        sandbox,
        faults={primitive: counting},
    )
    assert_equal(0, run["exit_code"], f"counting run failed (stderr: {run['stderr']})")
    return len(seen)


@case("remove-form: a fault at any mutation step leaves the tree fully original or fully final")
def _(work):
    final_state = _expected_final_state(work)
    checked = 0
    for primitive in ("shutil.copyfile", "os.replace", "os.remove", "shutil.rmtree", "shutil.move"):
        total = _count_calls(work, primitive)
        for nth in range(1, total + 1):
            sandbox = os.path.join(work, f"fault-{primitive.replace('.', '-')}-{nth}")
            copy_fixture("epf-with-form", sandbox)
            original = snapshot_tree(sandbox)
            counter = {"n": 0}

            def boom(*call_args, _c=counter, _n=nth):
                _c["n"] += 1
                return _c["n"] == _n

            run = run_tool_in_process(
                REMOVE_FORM_PY,
                ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
                sandbox,
                faults={primitive: boom},
            )
            after = snapshot_tree(sandbox)
            what = f"fault in {primitive} call #{nth}"
            leftovers = sorted(p for p in after if ".remove-form" in p or p.endswith(".tmp"))
            visible = {k: v for k, v in after.items() if k not in leftovers}
            if sorted(visible) == sorted(original):
                assert_tree_identical(original, visible, f"{what}: partial rollback")
                assert_true(run["exit_code"] != 0, f"{what}: rolled back but reported success")
                assert_true(not leftovers, f"{what}: rollback left artifacts behind: {leftovers}")
            else:
                # Committed. The visible tree must be exactly the successful result;
                # a quarantine may only survive a failure of the post-commit cleanup,
                # and then the run must say so instead of claiming success.
                assert_tree_identical(final_state, visible, f"{what}: neither original nor final")
                if leftovers:
                    assert_true(run["exit_code"] != 0,
                                f"{what}: left {leftovers} behind but reported success")
                    assert_true(".remove-form-quarantine" in (run["stdout"] + run["stderr"]),
                                f"{what}: leftover quarantine is not named in the output")
            checked += 1
    assert_true(checked >= 5, f"only {checked} mutation boundaries exercised - too few to be meaningful")


@case("remove-form: a failing rollback reports loudly and keeps the recoverable copy")
def _(work):
    sandbox = os.path.join(work, "src")
    copy_fixture("epf-with-form", sandbox)

    # Fail the commit, then fail the restore that the rollback attempts.
    counter = {"n": 0}

    def boom(*call_args, _c=counter):
        _c["n"] += 1
        return _c["n"] >= 1

    run = run_tool_in_process(
        REMOVE_FORM_PY,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
        sandbox,
        faults={"os.replace": boom},
    )
    assert_true(run["exit_code"] != 0, "a wholly failed run reported success")
    combined = run["stdout"] + run["stderr"]
    assert_true("rollback" in combined.lower() or "откат" in combined.lower(),
                f"a failed run does not mention the rollback:\n{combined[:600]}")


# ------------------------------------------------- remove-form: XML style

@case("remove-form: ChildObjects keeps its exact indentation for first / middle / last")
def _(work):
    # Three forms so the removed one can be first, middle or last in the block.
    variants = {"MainForm": None, "AuxForm": None}
    for position, form_name in (("first", "MainForm"), ("last", "AuxForm")):
        sandbox = os.path.join(work, position)
        copy_fixture("epf-with-form", sandbox)
        root_xml = os.path.join(sandbox, "Obrabotka.xml")
        before = file_facts(root_xml)

        run = run_python_tool(
            REMOVE_FORM_PY,
            ["-ObjectName", "Obrabotka", "-FormName", form_name, "-SrcDir", sandbox, "-Force"],
            sandbox,
        )
        assert_equal(0, run["exit_code"], f"{position} removal (stderr: {run['stderr']})")

        after = file_facts(root_xml)
        expected_block = (before["text"]
                          .replace(f"\n\t\t\t<Form>{form_name}</Form>", "", 1))
        expected_block = childobjects_block(expected_block)
        assert_equal(expected_block, childobjects_block(after["text"]),
                     f"{position}: ChildObjects block was restyled")
        assert_true(after["bom"], f"{position}: BOM lost")
        assert_equal(0, after["crlf"], f"{position}: CRLF introduced into an LF file")
        assert_true(after["text"].endswith("\n"), f"{position}: final newline lost")
        assert_true('encoding="UTF-8"' in after["text"], f"{position}: encoding declaration restyled")
        assert_true(" />" not in after["text"], f"{position}: Configurator writes <Tag/>, found <Tag />")
        variants[form_name] = childobjects_block(after["text"])

    # Removing the only remaining form must not leave a dangling indentation island.
    sandbox = os.path.join(work, "only")
    copy_fixture("epf-with-form", sandbox)
    root_xml = os.path.join(sandbox, "Obrabotka.xml")
    for form_name in ("MainForm", "AuxForm"):
        run = run_python_tool(
            REMOVE_FORM_PY,
            ["-ObjectName", "Obrabotka", "-FormName", form_name, "-SrcDir", sandbox, "-Force"],
            sandbox,
        )
        assert_equal(0, run["exit_code"], f"removing {form_name} (stderr: {run['stderr']})")
    block = childobjects_block(file_facts(root_xml)["text"])
    assert_true(block.strip() in ("<ChildObjects/>", "<ChildObjects></ChildObjects>"),
                f"an emptied ChildObjects was left malformed: {block!r}")


@case("remove-form style parity: both runtimes emit the same ChildObjects block", needs_powershell=True)
def _(work):
    blocks = {}
    for runtime, script, runner in (
        ("ps", REMOVE_FORM_PS1, run_powershell_tool),
        ("py", REMOVE_FORM_PY, run_python_tool),
    ):
        sandbox = os.path.join(work, runtime)
        copy_fixture("epf-with-form", sandbox)
        run = runner(
            script,
            ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
            sandbox,
        )
        assert_equal(0, run["exit_code"], f"{runtime} removal (stderr: {run['stderr']})")
        block = childobjects_block(file_facts(os.path.join(sandbox, "Obrabotka.xml"))["text"])
        blocks[runtime] = block.replace("\r\n", "\n")
    # EOL is normalized on purpose: remove-form.ps1 rewrites the whole file through
    # XmlWriter and turns an LF dump into CRLF, which the Python-only style case
    # asserts and docs/form-manage.md documents. What must match here is the
    # indentation structure of the block both runtimes produce.
    assert_equal(repr(blocks["ps"]), repr(blocks["py"]),
                 "the two runtimes indent ChildObjects differently")


# ---------------------------------------------------------------- licensing

UPSTREAM_NOTICE_REL = "content/skills/1c-metadata-manage/NOTICE.md"
UPSTREAM_PIN = "ecd289fe11733028d87b55284ea9fb5feff8f513"


@case("remove-form safety parity: PowerShell refuses the same names and paths", needs_powershell=True)
def _(work):
    """The two runtimes ship the same tool; a hole patched only in one of them is
    still a hole for every Windows user."""
    for index, bad in enumerate(["../../victim", "Forms/MainForm", "MainForm ", "1MainForm",
                                 "\u039cainForm", "C:\\Windows"]):
        sandbox = os.path.join(work, f"bad{index:02d}")
        copy_fixture("epf-with-form", sandbox)
        before = snapshot_tree(sandbox)
        run = run_powershell_tool(
            REMOVE_FORM_PS1,
            ["-ObjectName", "Obrabotka", "-FormName", bad, "-SrcDir", sandbox, "-Force"],
            sandbox,
        )
        assert_equal(2, run["exit_code"],
                     f"PowerShell accepted FormName={bad!r} "
                     f"(stdout: {run['stdout'][:200]!r} stderr: {run['stderr'][:200]!r})")
        assert_tree_identical(before, snapshot_tree(sandbox), f"PowerShell refused {bad!r}")
        assert_no_leftovers(sandbox, f"PowerShell refused {bad!r}")

    # And the traversal must not reach outside even when the name is registered.
    sandbox = os.path.join(work, "traversal")
    copy_fixture("epf-with-form", sandbox)
    with open(os.path.join(sandbox, "victim.xml"), "w", encoding="utf-8") as handle:
        handle.write("<x/>")
    root_xml = os.path.join(sandbox, "Obrabotka.xml")
    text = file_facts(root_xml)["text"].replace(
        "<Form>AuxForm</Form>", "<Form>AuxForm</Form>\n\t\t\t<Form>../../victim</Form>")
    with open(root_xml, "wb") as handle:
        handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))
    before = snapshot_tree(sandbox)
    run = run_powershell_tool(
        REMOVE_FORM_PS1,
        ["-ObjectName", "Obrabotka", "-FormName", "../../victim", "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(2, run["exit_code"], f"PowerShell traversal not refused: {run['stdout'][:300]!r}")
    assert_tree_identical(before, snapshot_tree(sandbox), "PowerShell traversal run")


@case("remove-form safety parity: PowerShell rolls a failed removal back", needs_powershell=True)
def _(work):
    """A read-only form metadata file makes the deletion step fail for real. The
    PowerShell run must restore the root XML and the form directory, exactly as
    the Python port does."""
    sandbox = os.path.join(work, "src")
    copy_fixture("epf-with-form", sandbox)
    # A stale quarantine is the one fault both runtimes can be given deterministically
    # and portably: it aborts before the first mutation and must change nothing.
    quarantine = os.path.join(sandbox, ".remove-form-quarantine")
    os.makedirs(quarantine)
    with open(os.path.join(quarantine, "form-meta.xml"), "wb") as handle:
        handle.write(b"<recoverable/>")
    before = snapshot_tree(sandbox)

    run = run_powershell_tool(
        REMOVE_FORM_PS1,
        ["-ObjectName", "Obrabotka", "-FormName", "MainForm", "-SrcDir", sandbox, "-Force"],
        sandbox,
    )
    assert_equal(2, run["exit_code"],
                 f"PowerShell ignored a stale quarantine: {run['stdout'][:300]!r}")
    assert_true(".remove-form-quarantine" in run["stderr"],
                f"the refusal does not name the quarantine: {run['stderr'][:300]!r}")
    assert_tree_identical(before, snapshot_tree(sandbox), "PowerShell stale-quarantine refusal")


@case("licensing: the vendored MIT notice is present and complete in the source tree")
def _(work):
    path = os.path.join(REPO_ROOT, *UPSTREAM_NOTICE_REL.split("/"))
    assert_true(os.path.isfile(path), f"missing upstream notice: {UPSTREAM_NOTICE_REL}")
    with open(path, "rb") as handle:
        text = handle.read().decode("utf-8-sig")
    for required in (
        "MIT License",
        "Copyright (c) 2025-2026 Nick Shirokov",
        "Permission is hereby granted, free of charge",
        "The above copyright notice and this permission notice shall be included",
        'THE SOFTWARE IS PROVIDED "AS IS"',
        "Nikolay-Shirokov/cc-1c-skills",
        UPSTREAM_PIN,
        "remove-form.py",
    ):
        assert_true(required in text, f"upstream notice does not carry: {required!r}")


@case("licensing: the notice is distributable and travels with the committed archive")
def _(work):
    def git(*argv):
        return subprocess.run(["git", *argv], cwd=REPO_ROOT, capture_output=True)

    # A notice that .gitignore swallows would never reach a consumer.
    ignored = git("check-ignore", "-q", UPSTREAM_NOTICE_REL).returncode == 0
    assert_true(not ignored, f"{UPSTREAM_NOTICE_REL} is gitignored and would never be distributed")

    tracked = git("ls-files", "--error-unmatch", UPSTREAM_NOTICE_REL).returncode == 0
    if not tracked:
        # Pre-commit state: the file must at least be a pending addition, not a
        # stray that a clean checkout would lose.
        listed = git("ls-files", "--others", "--exclude-standard", "--", UPSTREAM_NOTICE_REL)
        assert_true(listed.stdout.strip(),
                    f"{UPSTREAM_NOTICE_REL} is neither tracked nor a pending addition")
        return

    proc = git("archive", "HEAD")
    assert_equal(0, proc.returncode, f"git archive failed: {proc.stderr[:400]!r}")
    archive = os.path.join(work, "head.tar")
    with open(archive, "wb") as handle:
        handle.write(proc.stdout)
    import tarfile
    with tarfile.open(archive) as tar:
        names = tar.getnames()
    assert_true(UPSTREAM_NOTICE_REL in names,
                f"the distribution archive carries no upstream notice at {UPSTREAM_NOTICE_REL}")


# ---------------------------------------------------------------- CI wiring

@case("ci: the workflow runs the Python port regression on Windows and on Linux")
def _(work):
    path = os.path.join(REPO_ROOT, ".github", "workflows", "validate-rules.yml")
    with open(path, "rb") as handle:
        text = handle.read().decode("utf-8")
    assert_true("python-ports-regression.py" in text,
                "the workflow never runs tools/tests/python-ports-regression.py")
    assert_true("ubuntu-latest" in text, "the workflow has no Linux job for the Python ports")
    assert_true("windows-latest" in text, "the workflow lost its Windows PowerShell parity job")
    assert_true("--python-only" in text,
                "the Linux job does not skip the PowerShell-bound cases (--python-only)")
    assert_true("python -B" in text or "python3 -B" in text,
                "the workflow runs Python without -B, so CI writes __pycache__ into the tree")
    assert_true("lxml" in text, "the workflow never installs the lxml dependency of the ports")
    # A YAML parser is the real gate; fall back to a structural check when absent.
    try:
        import yaml  # noqa: PLC0415 - optional on the developer machine
    except ImportError:
        assert_true(text.lstrip().startswith("name:"), "workflow does not start with a name: key")
        return
    document = yaml.safe_load(text)
    jobs = document.get("jobs") or {}
    runners = {name: job.get("runs-on") for name, job in jobs.items()}
    assert_true("windows-latest" in runners.values(), f"no windows job: {runners}")
    assert_true("ubuntu-latest" in runners.values(), f"no linux job: {runners}")


# ---------------------------------------------------------------- packaging

@case("packaging: install ships remove-form.py, tracks it, and the installed copy runs", needs_powershell=True)
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

    # The MIT notice has to travel with the distribution the installer produces,
    # not only with the source repository.
    notice_rel = ".claude/skills/1c-metadata-manage/NOTICE.md"
    notice = os.path.join(project, *notice_rel.split("/"))
    assert_true(os.path.isfile(notice), f"installer did not ship the upstream notice: {notice_rel}")
    with open(notice, "rb") as handle:
        installed_notice = handle.read()
    with open(os.path.join(REPO_ROOT, *UPSTREAM_NOTICE_REL.split("/")), "rb") as handle:
        source_notice = handle.read()
    assert_equal(base64.b64encode(source_notice), base64.b64encode(installed_notice),
                 "installed NOTICE.md differs from the source copy")
    assert_true(notice_rel in manifest.get("files", {}),
                f"manifest does not track the upstream notice: {notice_rel}")

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
    parser.add_argument("--python-only", action="store_true",
                        help="Skip cases that need a PowerShell host (Linux CI job).")
    args = parser.parse_args()

    root = os.path.join(tempfile.gettempdir(), "1c-rules-py-regr-" + uuid.uuid4().hex[:8])
    os.makedirs(root, exist_ok=True)
    print(f"Work dir: {root}")
    print(f"Python:   {sys.version.split()[0]} ({sys.executable})")
    print()

    failures = []
    skipped = []
    index = 0
    for name, body, needs_powershell in CASES:
        if not fnmatch.fnmatch(name, args.filter):
            continue
        index += 1
        work = os.path.join(root, f"case{index:02d}")
        os.makedirs(work, exist_ok=True)
        try:
            if needs_powershell and args.python_only:
                raise CaseSkipped("--python-only: case needs a PowerShell host")
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
