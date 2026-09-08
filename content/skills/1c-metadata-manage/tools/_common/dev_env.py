"""dev_env.py — read project settings from `.dev.env` (Python peer of DevEnv.ps1).

In the 1c-rules toolkit `.dev.env` at the project root is the single source of
truth for project parameters. The vendored cc-1c-skills scripts natively read
`.v8-project.json`; a small patch inside their own lookup functions consults
this helper first, so a project only ever maintains `.dev.env`.

Contract mirrored from DevEnv.ps1 one to one, so the two runtimes cannot drift:

  * `find_dev_env_file` — nearest `.dev.env` walking up from the working
    directory (at most 20 levels), `None` when absent;
  * `get_value` — `''` when the file, the key or the value is missing; every
    caller treats `''` as "not configured" and falls through to its own next
    source. Never raises: a malformed `.dev.env` must not break a metadata
    operation;
  * `get_args` — a comma-separated list (PLATFORM_ARGS / IBCMD_ARGS) as a list
    of strings, `[]` when unset.

Imported by the vendored tools through `load()` below, which tolerates the file
being absent (an installed tree that predates this helper) exactly the way the
PowerShell side tolerates a missing `DevEnv.ps1`.
"""

import os
import re

_ASSIGNMENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")

_GUARD_MODES = ("deny", "warn", "off")


def find_dev_env_file(start_dir=None):
    """Nearest `.dev.env` walking up from *start_dir* (default: cwd)."""
    directory = start_dir or os.getcwd()
    for _ in range(20):
        if not directory:
            break
        candidate = os.path.join(directory, ".dev.env")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(directory)
        if not parent or parent == directory:
            break
        directory = parent
    return None


def get_value(name, start_dir=None):
    """Single KEY value from `.dev.env`; `''` when unset. Never raises."""
    try:
        path = find_dev_env_file(start_dir)
        if not path:
            return ""
        with open(path, "r", encoding="utf-8-sig", errors="replace") as handle:
            for line in handle:
                stripped = line.lstrip()
                if not stripped.strip() or stripped.startswith("#"):
                    continue
                match = _ASSIGNMENT_RE.match(stripped.rstrip("\r\n"))
                if not match or match.group(1) != name:
                    continue
                value = match.group(2).strip()
                # Quoted paths must still resolve: PLATFORM_PATH="C:\1cv8".
                if len(value) >= 2 and (
                    (value.startswith('"') and value.endswith('"'))
                    or (value.startswith("'") and value.endswith("'"))
                ):
                    value = value[1:-1].strip()
                return value
    except Exception:  # noqa: BLE001 - a malformed .dev.env is "not configured"
        return ""
    return ""


def get_args(name, start_dir=None):
    """Comma-separated argument list from `.dev.env` as a list; `[]` when unset."""
    raw = get_value(name, start_dir)
    if not raw:
        return []
    return [part.strip() for part in raw.split(",") if part.strip()]


def get_support_guard_mode(start_dir=None):
    """`SUPPORT_GUARD` normalized to deny|warn|off, or `None` when not configured.

    `None` — and only `None` — means "fall through to `.v8-project.json`". An
    unrecognized value is treated as unset rather than as a fourth mode, so a
    typo can never silently disable the guard.
    """
    value = (get_value("SUPPORT_GUARD", start_dir) or "").strip().lower()
    return value if value in _GUARD_MODES else None
