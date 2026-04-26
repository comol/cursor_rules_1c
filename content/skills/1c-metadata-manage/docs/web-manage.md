# 1C Web Manage — Web Publishing for 1C Information Bases

Publish and operate a 1C information base over HTTP via Apache (or IIS) for thin web clients, OData, HTTP services and SOAP.

Five operations: **info / publish / unpublish / stop / test**. They form a stable workflow:

```
web-info → web-publish → web-test → web-unpublish  (or web-stop to keep the publication, just halt Apache)
```

---

## Connection parameters

All operations resolve the target infobase from `.v8-project.json` in the project root (the same file used by `db-manage`):

1. If the user passed an explicit infobase path/server — use it directly.
2. If the user passed an alias — resolve via `databases[].id|alias|name`.
3. Otherwise — match the current git branch against `databases[].branches`.
4. Fallback — the entry marked `default: true`.

**Always pass through:**

- `v8path` → `-V8Path` (so we don't accidentally publish via the wrong platform version).
- `user` / `password` → `-UserName` / `-Password` (when stored).
- `webPath` → `-ApachePath` (when the project bundles its own Apache).

If `.v8-project.json` is missing — stop and ask the user to register the base via `db-list`.

---

## 1. Web info — current state

Reports whether Apache is running, which infobases are published and the last error from `error.log`.

```powershell
powershell.exe -NoProfile -File tools/1c-web-ops/scripts/web-info.ps1 [-ApachePath <path>]
```

Default `-ApachePath` is `tools/apache24` relative to the project root.

Output should answer three questions:

- Is the HTTP server process alive (PID, uptime, port)?
- What publications exist (URL, infobase reference, application name)?
- Last 5 lines of `error.log` if any errors are present.

---

## 2. Web publish — register the infobase

Generates `default.vrd`, patches `httpd.conf`, downloads a portable Apache if needed, and starts the service.

```powershell
powershell.exe -NoProfile -File tools/1c-web-ops/scripts/web-publish.ps1 `
    [-V8Path <path>] `
    [-InfoBasePath <path> | -InfoBaseServer <name> -InfoBaseRef <name>] `
    [-UserName <name>] [-Password <secret>] `
    [-AppName <publication>] [-ApachePath <path>] [-Port <port>] `
    [-Manual]
```

| Parameter | Required | Description |
|---|:--:|---|
| `-V8Path` | no | Platform `bin/` directory (used to locate `wsap24.dll`/`wsisapi.dll`). |
| `-InfoBasePath` | * | Path to a file infobase. |
| `-InfoBaseServer` | * | 1C cluster name (server-mode infobase). |
| `-InfoBaseRef` | * | Infobase reference on the cluster. |
| `-UserName` / `-Password` | no | Credentials embedded into `default.vrd`. |
| `-AppName` | no | Publication name; defaults to the base directory name. |
| `-ApachePath` | no | Apache root, default `tools/apache24`. |
| `-Port` | no | HTTP port, default `8081`. |
| `-Manual` | no | Verify configuration only, do not download/start anything. |

`*` — provide either `-InfoBasePath` **or** the pair `-InfoBaseServer` + `-InfoBaseRef`.

**Idempotency.** Repeated invocation with the same `-AppName` replaces the publication. Use this to:

- switch the embedded user (same `-AppName`, new `-UserName`);
- restart Apache after `web-stop` (same parameters).

**Parallel publication for the same base under different users** (e.g. testing role-based access) — give each one a distinct `-AppName`:

- `-AppName bpdemo-ivanov` (rights of `Иванов`);
- `-AppName bpdemo-admin` (admin).

After success, report:

- Web client URL: `http://localhost:<Port>/<AppName>`.
- OData: `http://localhost:<Port>/<AppName>/odata/standard.odata`.
- HTTP services: `http://localhost:<Port>/<AppName>/hs/<RootUrl>/...`.
- Web services: `http://localhost:<Port>/<AppName>/ws/<Name>?wsdl`.

---

## 3. Web stop — halt without removing the publication

Stops Apache but keeps the publication entries in `httpd.conf` and the generated `default.vrd` files. The next `web-publish` call (or `web-stop -Start`) brings it back up unchanged.

```powershell
powershell.exe -NoProfile -File tools/1c-web-ops/scripts/web-stop.ps1 [-ApachePath <path>] [-Force]
```

Use this when:

- finishing the working day on a developer machine;
- temporarily releasing the port for another service;
- before backing up infobase files to avoid platform locks.

---

## 4. Web unpublish — remove the publication

Stops Apache, removes the publication block from `httpd.conf`, deletes the corresponding `default.vrd`. The infobase itself is **not** touched.

```powershell
powershell.exe -NoProfile -File tools/1c-web-ops/scripts/web-unpublish.ps1 `
    -AppName <publication> `
    [-ApachePath <path>] [-KeepApacheRunning]
```

Pass `-KeepApacheRunning` if other publications must keep serving — by default the script restarts Apache after editing the config.

---

## 5. Web test — smoke test through the web client

Runs an end-to-end check against the published web client via Playwright (browser automation). Two flavours:

- **Smoke** — opens the URL, waits for the start page to render, asserts no platform error banner, captures a screenshot. Used as a 30-second sanity check after `web-publish`.
- **Scripted** — feeds an action script (Russian-language section / command names) to the runner; suitable for short reproducible scenarios in CI or manual UAT.

Reference runner (Node + Playwright) lives at `tools/1c-web-ops/scripts/run.mjs`. Minimum environment:

```powershell
cd tools/1c-web-ops/scripts
npm install
npx playwright install chromium
```

Smoke command:

```powershell
node tools/1c-web-ops/scripts/run.mjs smoke http://localhost:8081/bpdemo
```

Scripted command:

```powershell
node tools/1c-web-ops/scripts/run.mjs run http://localhost:8081/bpdemo scripts/scenario.js
```

A scripted scenario is a small JS file exposing helpers like `navigateSection`, `openCommand`, `fillFields`, `clickElement`, `waitForCommand`, `captureScreenshot`. Keep scenarios deterministic — no timing-based waits, only platform-event waits.

---

## When to delegate to `metadata-manager`

- Multiple operations chained (`publish → test → unpublish`).
- Configuration changes that require platform restart in between.
- Custom Apache layout or non-default port mapping.

For a single read-only `web-info` or a one-shot smoke test, run the script directly — delegation overhead is not worth it.
