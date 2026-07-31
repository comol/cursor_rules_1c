---
description: Preferred tooling for 1C UI testing — agent-browser for web (token-efficient), Windows-MCP only as last-resort desktop automation; bans home-grown screenshot/OCR
alwaysApply: false
category: tooling
---

# UI testing tools — browser and desktop automation

**When to load this file:** before any web / desktop UI test of a 1C infobase (`1c-tester`, `/deploy-and-test` Step 4, ad-hoc browser checks against `INFOBASE_PUBLISH_URL`), or when choosing / installing a browser-automation MCP.

Whether UI tests run at all is still gated by `UI_TESTING` + `INFOBASE_PUBLISH_URL` — canon: `dev-standards-env.md → "UI_TESTING — web UI-testing mode"`. This file answers **which tool** to drive once a run is allowed, and the **mandatory preflight** before the first browser action.

## Preflight before web UI tests (hard gate)

Runs **every time** Step 4 of `/deploy-and-test`, `1c-tester`, or any ad-hoc web UI check against `INFOBASE_PUBLISH_URL` is about to open the browser. Skipping this check and silently using `cursor-ide-browser` / Playwright / vision is a **defect**.

1. **Detect `agent-browser`.** Available if **either**:
   - CLI on `PATH` (`agent-browser --version` succeeds), **or**
   - MCP server `agent-browser` is configured **and** its tools are exposed in the current session (e.g. `agent_browser_open`, `agent_browser_snapshot`).
2. **If available** — proceed with preference order below. No prompt.
3. **If missing — stop before any browser action** and ask the user in Russian (one message, do not bury it in prose):

   > Для веб-тестов 1С рекомендую поставить `agent-browser` — headless-браузер со снимками accessibility-дерева, сильно экономит токены по сравнению со скриншотами / vision. Установить сейчас через `/install-agent-browser`?  
   > - **да** — установлю и продолжу тесты  
   > - **нет** — продолжу на встроенном browser MCP (дороже по токенам)

4. **On «да» / yes / «установи»** — execute `/install-agent-browser` (`content/commands/install-agent-browser.md`) fully, then continue UI tests with `agent-browser` (after client restart if MCP tools are still missing — tell the user once and pause until they confirm restart, or fall back only if they refuse to restart and explicitly allow the built-in browser).
5. **On «нет» / no / decline** — continue with the built-in browser MCP; state in one line that `agent-browser` was declined and token cost will be higher. Do not ask again in the same session unless the user starts a new UI-test request.
6. **Autonomous / batch / no operator** (cannot ask) — do **not** auto-install. Log one line: `agent-browser missing — using built-in browser MCP (no operator to confirm /install-agent-browser)` and continue. Never invent a screenshotter/OCR stack.

This gate does **not** change `UI_TESTING` or `INFOBASE_PUBLISH_URL`. It only ensures the cheap driver is offered before an expensive run.

Once a driver is chosen, load `web-client-driving.md` before the first action — it owns how the 1C web client itself behaves (snapshot reading, lists / trees / grids, reports, dialogs, anti-loop limits), independently of which driver won the preference order above.

## Preference order (hard)

1. **`agent-browser`** (https://github.com/vercel-labs/agent-browser) — **default for 1C web client tests**. Use accessibility-tree snapshots (`snapshot` / MCP equivalents), refs (`@eN`), and typed interactions. Screenshots only for evidence in the test report, not as the primary observe loop. Install: `/install-agent-browser`.
2. **Built-in browser MCP** of the active client (`cursor-ide-browser`, Playwright / `browser-use`, etc.) — fallback only after the preflight gate above (user declined, or no operator). Same human-like typing / TAB / wait rules as in `1c-tester`.
3. **`Windows-MCP`** (https://github.com/CursorTouch/Windows-MCP) — **last resort**, Windows only. Use when the scenario truly needs desktop / thick-client / OS UI and the web client is not an option. Install: `/install-windows-mcp`.

Never invent a parallel stack (PowerShell screenshot loops, custom OCR, ad-hoc vision pipelines) while a tool from this list can cover the need.

## Token discipline

- Prefer **structured snapshots** (a11y tree / DOM refs) over images. Vision on full-page screenshots is the expensive path that `agent-browser` exists to avoid.
- Re-snapshot after navigation or DOM-changing actions; do not reuse stale refs.
- Keep MCP tool profiles small (`agent-browser mcp` default `core` profile). Escalate to `--tools all` only when a missing tool blocks the scenario.
- `UI_TESTING=manual` (default) already keeps browser runs opt-in — do not "warm up" the browser outside an allowed run.

## Windows-MCP — when and when not

| Use Windows-MCP | Do not use Windows-MCP |
|---|---|
| Thick / desktop 1C client must be driven | Routine checks of the **web** client at `INFOBASE_PUBLISH_URL` |
| OS dialogs / external Win apps in the scenario | "Because screenshots feel easier" |
| User explicitly requires desktop automation | As a substitute for publishing the web client |

When Windows-MCP is the chosen tool: drive it through its MCP tools; **do not** ask the model to code a screenshotter, template matcher, or OCR layer for the same job.

## Install commands

| Need | Command |
|---|---|
| Web UI testing, token-efficient browser | `/install-agent-browser` |
| Unavoidable Windows desktop automation | `/install-windows-mcp` |

Both commands only install tooling and merge MCP config; they do not flip `UI_TESTING` or set `INFOBASE_PUBLISH_URL`.

## Interaction rules (all web tools)

Unchanged from `1c-tester` / `/deploy-and-test` Step 4:

- Human-like typing with short delays; TAB between fields.
- Wait for elements before interact / assert.
- Screenshot key states for the report (open, filled, saved/posted, errors) — evidence, not the observe loop.
