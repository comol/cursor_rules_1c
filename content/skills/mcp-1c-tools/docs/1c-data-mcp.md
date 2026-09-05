# 1c-data-mcp — tool catalog

Execution of BSL code, queries and event-log inspection **inside the project's live infobase** via the HTTP service `hs/mcp` published on that infobase (tools from [comol/mcp_designer_tools](https://github.com/comol/mcp_designer_tools), loaded into the *Конструктор MCP серверов для 1С* on the IB side).

> Load this file only if the `1c-data-mcp` server is actually available in the current session (its tools are visible in the agent tool schema). Mere presence in `mcp-servers.json` or in `.cursor/mcp.json` does not count as availability — the HTTP endpoint `{INFOBASE_PUBLISH_URL}/hs/mcp` must respond and must be reachable **without** authentication. Setup and troubleshooting — `content/commands/checkmcp.md` (section about `1c-data-mcp`).

## Tool catalog

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **vcexecutecode** | `bslcode` — BSL code as a string | Executes arbitrary BSL inside the connected infobase via `Выполнить()`. Returns `"ошибок нет"` if execution finished without exception, otherwise the text of `ОписаниеОшибки()`. The code may assign to the predefined variable `Результат` (initial value `"ошибок нет"`) to return a value back. | Verify that a fragment actually runs in the **current** IB — wrong type, missing metadata, missing extension method, runtime error in a built-in — when static checks (`syntaxcheck` / `check_1c_code`) cannot answer the question. Probe platform-version-specific behaviour against the real platform of the IB. |
| **vcexecutequery** | `querytext` — text of a 1C query | Executes a query against the live IB and returns the result as a plain text table (headers + rows separated by ` \| `). All parameters must be embedded directly in the text (no separate parameter map). Multi-line text is allowed; line continuation via `\|` follows standard 1C rules. | Sanity-check a generated query against **real data** in this IB: row counts, sample values, presence of references with the expected attributes, behaviour of a virtual table on the actual register state. Cheap read-only diagnostics during a bug hunt. |
| **validatequery** | `querytext` — text of a 1C query | Parses the query and calls `НайтиПараметры()` inside `Попытка / Исключение`. Returns `"нет ошибок"` or the text of `ОписаниеОшибки()`. Does **not** execute the query, does **not** verify that tables / fields actually exist in the metadata, does **not** evaluate RLS. | Cheap pre-flight check for a freshly generated / hand-edited query text before calling `vcexecutequery` or before saving the text into a module / DCS scheme. Useful right after `rewrite_1c_code` / `modify_1c_code` (non-deterministic) when the output is a query string. |
| **vcloggetlasterror** | — (no parameters) | Reads the most recent event-log entry with `УровеньЖурналаРегистрации.Ошибка` from the last 24 hours via `ВыгрузитьЖурналРегистрации` (limit 1). Returns formatted lines: `Дата`, `Событие`, `Метаданные`, `Данные`, `Описание`. Returns `"ошибок не найдено"` when the window is clean. | First step of Phase 1 (Reproduce) in `standards(name="systematic-debugging")` — get the exact error text, the affected metadata object and the timestamp without leaving the agent. Confirm that an attempted repro actually produced an error in the IB, and on what object. |

## When to use `1c-data-mcp`

Use these tools **only** when the answer must come from the live infobase — i.e. the verification cannot be done by reading the configuration dump, by static MCP analyzers, or by platform / БСП docs:

- "Does this BSL fragment actually run in this IB right now?" → `vcexecutecode`.
- "Does this query parse?" — quick smoke test → `validatequery`.
- "Does this query return what I think it returns against current data?" → `vcexecutequery`.
- "What error did the IB log for that failing scenario I just reproduced?" → `vcloggetlasterror`.

For everything that can be answered from the configuration dump (object structure, attributes, module text, call graph, impact analysis, БСП API names, ITS standards, code templates) — use the read-only / index-based servers first (`1c-graph-metadata-mcp`, `1c-code-metadata-mcp`, `1C-docs-mcp`, `1c-ssl-mcp`, `1c-code-check-mcp`, `1c-templates-mcp`) and only escalate to `1c-data-mcp` when the question is specifically "what does this **running** IB do".

Do **not** use `1c-data-mcp` as a replacement for `syntaxcheck` / `check_1c_code` / `review_1c_code` — those tools cover style, logic and standards offline; `vcexecutecode` only confirms that the code did not throw on one execution.

## Safety and discipline

`vcexecutecode` and `vcexecutequery` run arbitrary code and queries against the **connected infobase** with whatever rights the technical IB user from `default.vrd` has. Treat every call as a write-capable action and obey the following:

- **Read-only first.** Default to `validatequery` → `vcexecutequery` for queries; default to a non-mutating fragment for `vcexecutecode` (`ЗначениеЗаполнено`, `ПолучитьФункциональнуюОпцию`, `НайтиПоНаименованию`, `Метаданные.НайтиПоПолномуИмени`, type checks, format checks). Confirm read-only intent explicitly in the prompt to the tool.
- **No mutations without explicit user consent.** Before any `Записать()` / `Удалить()` / `НачатьТранзакцию` / `Выполнить("УДАЛИТЬ ...")` / direct register movement via `vcexecutecode` — ask the user, name the affected object, and have a rollback plan (transaction wrap with explicit `ОтменитьТранзакцию`, or a IB copy). On production IBs — refuse and request a copy IB.
- **No secrets in arguments.** `bslcode` and `querytext` are sent over HTTP and may end up in logs. Do not embed passwords, tokens, personal data, or production user credentials in the code / query text — load them inside the IB via `ЗначениеХранилища` / БСП secret storage instead.
- **Do not pipe AI output blindly.** Output of `rewrite_1c_code`, `modify_1c_code`, `ask_1c_ai` is non-deterministic. Validate query strings with `validatequery` first; validate BSL fragments with `syntaxcheck` first; only then consider `vcexecutequery` / `vcexecutecode` against the live IB.
- **`vcloggetlasterror` window is fixed.** It always looks 24 hours back and returns only level `Ошибка`, only the single most recent record. For older errors, narrower filters (by user / metadata / event), or higher levels (`Предупреждение`, `Информация`) — fall back to the Configurator's `ОтчетПоЖурналуРегистрации` or to a custom `ВыгрузитьЖурналРегистрации` call wrapped in `vcexecutecode`.

## Notes on `vcexecutecode` return value

The implementation runs `Выполнить(bslcode)` inside a procedure where the variable `Результат` is initialised to `"ошибок нет"`. Two consequences:

- Code that does not raise and does not touch `Результат` always returns `"ошибок нет"` — you only know it ran, not what it produced.
- To get a value back, the code must assign to `Результат` as its last meaningful statement, e.g. `Результат = Строка(ТекущаяДатаСеанса());` or `Результат = Метаданные.Справочники.Контрагенты.Реквизиты.ИНН.Тип.КвалификаторыСтроки.Длина;`.

## Availability check

If the server is offline (web publication down, `mcp` HTTP service not published, or publication requires Basic auth and the MCP client gets `401`/`403`), the tools simply do not appear in the agent's tool schema. Do **not** synthesize their behaviour from memory and do **not** invent fake "execution" output — fall back to the verification path that does not need the live IB (static MCP analyzers + reading code in the dump + asking the user to run the snippet in the Configurator). Setup / fix steps — `content/commands/checkmcp.md`.
