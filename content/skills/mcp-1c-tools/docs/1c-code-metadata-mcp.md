# 1c-code-metadata-mcp — tool catalog

Metadata and BSL code search, module navigation, forms, XSD schemas, XML validation. Fallback for `1c-graph-metadata-mcp` when the latter is unavailable.

> Load this file only if the `1c-code-metadata-mcp` server is actually available in the current session.

## Source layout

- Published beta deployments index metadata and code directly from `CODE_PATH`. The default is `METADATA_SOURCE=xml`; `SOURCE_FORMAT=auto` detects a Designer XML export (`Configuration.xml`) or a 1C:EDT project. A separate `METADATA_PATH` report is legacy and required only with `METADATA_SOURCE=report`. Stable tags still use the older report-dependent contract.
- On a beta deployment, do not tell the operator to create a text configuration report for a normal installation. Prefer one Designer XML export or EDT project. For EDT, force `SOURCE_FORMAT=edt` only when auto-detection evidence is missing. Always trust the connected tool schema and image channel over this default.
- With `INCREMENTAL_INDEXING=true`, ordinary source updates are SHA-256 incremental and publish a checked generation atomically. Do not recommend `reindex(force=true)` or `RESET_DATABASE=true` for every update; reserve a full reset for an explicit repair or format/fingerprint migration.

> **Argument naming — do not invent.** Object-scoped tools on this server take **`object_name`** (the same shape as on `1c-graph-metadata-mcp` — a 1C dotted qualified name like `Справочник.Контрагенты`, `Документ.РеализацияТоваровУслуг`, `РегистрНакопления.ТоварыНаСкладах`, `ОбщийМодуль.РаботаСКонтрагентамиКлиентСервер`): `get_metadata_details`, `graph_dependencies`, `inspect_form_layout` (plus `form_name=""`). Forbidden hallucinations on these tools: `object_full_name`, `full_name`, `qualified_name`, `name`, `fullName`, `objectFullName`. Other tools use **different** parameter names — do not generalise `object_name` to all of them: `search_function` takes **`name`** (the routine name, not a qualified object), `get_module_structure` takes **`module_path`**, `get_method_call_hierarchy` takes **`method_name`**, `bsl_scope_members` takes **`context`**, `get_xsd_schema` and `verify_xml` take **`object_type`** (+ `xml_content` for `verify_xml`). Search inputs on `metadatasearch`, `codesearch`, `search_forms`, `helpsearch` go into **`query`** — not `q`, `text`, `prompt`, or `search_query`. If a Pydantic / schema validator rejects the call as `Missing required argument` or `Unexpected keyword argument`, re-read this file before retrying — do not paraphrase the parameter.

## `grep=true` retry rule

Use `grep=true` as a targeted substring retry **only after** indexed / semantic / exact search did not find enough and the query is likely to benefit from literal matching: exact identifier, query fragment, metadata path, event handler name, error text, or string literal.

Applies only to tools that expose a `grep` parameter: `codesearch`, `metadatasearch`, `search_function`, `helpsearch`, `search_forms`. If the query is conceptual or the first result is already sufficient, do not spend an extra call on `grep=true`.

## Metadata search

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **metadatasearch** | `query`, `limit=5`, `object_type=""`, `names_only=false`, `grep=false` | Semantic / FTS search over metadata XML files. `object_type` filters by category (`Справочники`, `Документы`, etc.). `names_only=true` returns a compact list (`full_path`, `object_type`, `synonym`) instead of raw chunks. Prefer `names_only` to find objects, then use `get_metadata_details` for details | Metadata search, existence check, relationships. Use exact configuration names (`'Справочники.Контрагенты.Реквизиты'`) |
| **get_metadata_details** | `object_name` | Full structure: attributes with types, tabular parts, synonyms, properties | When the object name is known (`'Справочник.Номенклатура'`, `'Документ.РеализацияТоваровУслуг'`) |

## Code search & navigation

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **codesearch** | `query`, `limit=5`, `grep=false` | Hybrid search over BSL object modules and common modules | Find patterns, check usages, verify implementations. `query` — code, function name, or comment |
| **search_function** | `name`, `exact=true`, `limit=10`, `grep=false` | Find BSL procedures/functions through a structural FTS index. `exact=true` — case-insensitive with auto-fallback to fuzzy | Find a specific procedure / function (`'ОбработкаПроведения'`, `'ПриСозданииНаСервере'`) |
| **get_module_structure** | `module_path` | Full module structure: procedures, functions, regions, statistics | Understand a module before editing, overview of contents |
| **get_method_call_hierarchy** | `method_name`, `direction="both"`, `depth=3` | Call graph: who calls (`callers`), what it calls (`callees`), or `both` | Call chains, impact analysis, hot paths |
| **graph_dependencies** | `object_name`, `direction="both"`, `limit=50` | Dependency graph: `forward` (what it uses), `reverse` (who uses it), `both` | Impact analysis before refactoring, relationships between objects |
| **bsl_scope_members** | `context`, `member_type="all"` | Available methods / properties / events for a BSL context. `member_type`: `all`, `methods`, `properties`, `events` | Discover an object's API (`'Справочник.Номенклатура'`, `'Глобальный'`) |

## Help search

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **helpsearch** | `query`, `limit=5`, `grep=false` | Search over HTML help and user documentation | Help topics, purpose of metadata objects, functional descriptions |

## Compact API

Use the compact tools for navigation under a strict response budget. They page with opaque cursors; repeat the same query and pass the returned cursor.

| Tool | Parameters | Purpose |
|---|---|---|
| **compact_search** | `query`, `kinds=""`, `cursor=""`, `max_items=0`, `max_bytes=0`, `max_candidates=0` | Bounded symbol/metadata search |
| **compact_symbol** | `name=""`, `module_path=""`, `item_id=""`, `include_body=false`, paging bounds | Exact BSL symbol locations; include a body only when needed |
| **compact_call** | `symbol=""` or `item_id`, `direction="callees"`, `depth=1`, optional `module_path`, graph/time bounds | Bounded call-graph walk |
| **compact_metadata** | `query=""`, `object_type=""`, `item_id=""`, paging/member bounds | Compact metadata object and member cards |

## Forms

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **search_forms** | `query`, `limit=10`, `grep=false` | Search across all configuration forms (elements, attributes, commands) | Find existing forms as examples before generating new ones (`'Номенклатура'`, `'ФормаЭлемента'`) |
| **inspect_form_layout** | `object_name`, `form_name=""` | Full element tree: hierarchy, attributes, commands, event handlers, bindings, visibility, accessibility | Study the layout before modification or as a reference for a new form |

## Ordinary forms — `Form.bin`

An ordinary form (обычная форма) of a Designer export is `Forms/<Имя>/Ext/Form.bin`,
a 1C **binary container**, not XML — `search_forms` / `inspect_form_layout` and every
XML route see nothing for it. These two tools are the route to one, and the *same
pair with the same arguments and the same result payload* is published by
`1c-graph-metadata-mcp`. Contract, workspace layout, error codes and the warnings
that matter: **`content/skills/v8unpack-cf/SKILL.md → Ordinary forms`** — read it
before the first call.

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **unpack_ordinary_form** | `form_path`, `workspace_path`, `overwrite=false`, `include="summary"`, `max_chars=4000` | Read one `Form.bin` into an editable workspace: `payload/` (container entries verbatim — the source of truth) and `decoded/` (`form.json`, the layout as JSON-compatible data; `module.bsl`, the form module). `include` embeds a bounded preview: `summary` / `structure` / `module` / `all` | Any task touching an ordinary form: read the module, inspect the layout, prepare an edit |
| **build_ordinary_form** | `workspace_path`, `output_path`, `overwrite=false`, `verify=true` | Write the workspace back to a `Form.bin` and verify it by re-reading it and comparing the logical payload (entry names, sizes, SHA-256) | After editing `payload/`. Check `verification.status == "match"` |

**Do not judge the round trip by the final SHA-256** — a rebuilt `Form.bin` always
differs byte for byte (write timestamps). `binary_identical: false` with
`verification.status: "match"` is the correct outcome. **Never edit `Form.bin`
directly and never read it as XML.** A standalone `Form.bin` names no element: its
brace tree is positional, so do not invent element names or types from it.

## XSD schemas & validation

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **get_xsd_schema** | `object_type` | Generated XSD for a metadata type (`Справочник`, `Документ`, `РегистрСведений`, `РегистрНакопления`, `Роль`) or sub-type (`Форма`, `СКД`, `Макет`). English aliases accepted | Get XML structure rules before generating / modifying metadata XML |
| **verify_xml** | `xml_content`, `object_type` | Validate XML against XSD. Returns `status` (`valid` / `invalid` / `error` / `not_found`) and `errors` list | Validate generated / modified XML before committing |

## Configuration artifacts

| Tool | Primary parameters | Purpose |
|---|---|---|
| **get_form_artifact** | `object_name`, `form_name` or `artifact_id`, `include_ranges=true` | Read a form artifact with provenance |
| **get_role_artifact** | `role_name` or `artifact_id`; optional `object_name` | Read role rights or roles granting access to an object |
| **get_report_artifact** | `report_name` or `artifact_id` | Read report forms, layouts and DCS structure |
| **list_artifact_links** | `artifact_id`; optional result URI/digest filters | List immutable external run/test links attached to an artifact |
| **register_external_result_link** | `artifact_id`, `result_uri`, `result_digest`, `producer` | Register a link to an immutable external result; do not invent mutable or unhashed links |

## Administration

| Tool | Parameters | Purpose | When to use |
|---|---|---|---|
| **reindex** | `force=false` | Background reindexation. `force=true` wipes and rebuilds all indexes from scratch | After configuration changes, when search results seem stale |
| **stats** | *(none)* | Index statistics: document counts per collection, embedding provider, last indexation time, reindex schedule | Diagnostics, verify indexing status |
| **plugin_state** | *(none)* | Loaded plugin files, hooks, tables, errors, epoch and contribution to the generation fingerprint | Diagnose plugin state |
| **plugin_reload** | *(none)* | Atomically reload plugins | After changing call-scoped plugins; derived-state changes still require a new generation |
