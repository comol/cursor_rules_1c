---
name: mcp-1c-tools
description: "Catalog of MCP servers for 1C development — search, code navigation, metadata, code review, docs, ITS, templates, live-IB execution — with the exact parameter names of every routinely called tool. Use whenever a 1C task requires calling tools from any 1c-*-mcp / 1C-*-mcp server. Each server has a detail file under `docs/` for rare modes and response formats."
---

# MCP tools for 1C — dispatcher

Single source of truth for the server catalog, task → server routing and parameter names. Open `docs/<server>.md` only when the tables below do not cover the call: rare modes and response formats, a schema validation error (`Missing required argument` / `Unexpected keyword argument`), or reformulating a missed search (search modes, `detail_level`, filters). A server counts as available only when its tools are exposed in the current session's tool schema; an entry in `mcp-servers.json` proves nothing.

## What is mandatory vs. conditional

- **Mandatory for risk-bearing 1C work** when a relevant server is exposed — the scope list in `AGENTS.md → MCP Tool Calling → A.1` (BSL / metadata edits or review, metadata XML, forms, integrations, refactoring, performance, runtime errors, platform API checks, impact analysis, validation, project memory, OpenSpec artifacts that state 1C facts).
- **Conditional for external knowledge** — platform docs, БСП / SSL and ITS tools when the task depends on versioned platform behaviour, reusable БСП APIs or standards compliance; never for prose cleanup.
- **Not required for Markdown / rules / documentation-only work** — validate structure, links, paths and consistency instead.

## Server catalog

| Server (id) | Purpose | Details |
|---|---|---|
| **1c-graph-metadata-mcp** | Graph metadata (Neo4j / Cypher): structural object passport, impact analysis, call graph, usage search, business semantic search | [`docs/1c-graph-metadata-mcp.md`](docs/1c-graph-metadata-mcp.md) |
| **1c-code-metadata-mcp** | Metadata and BSL code search, navigation (modules, procedures, functions, call hierarchy), forms, XSD schemas, validation | [`docs/1c-code-metadata-mcp.md`](docs/1c-code-metadata-mcp.md) |
| **1c-templates-mcp** | Code template library + project vector memory (`remember` / `recall`) | [`docs/1c-templates-mcp.md`](docs/1c-templates-mcp.md) |
| **1c-ssl-mcp** | Standard Subsystems Library (БСП / SSL) search | [`docs/1c-ssl-mcp.md`](docs/1c-ssl-mcp.md) |
| **1C-docs-mcp** | 1C platform documentation (by description / by exact name), the platform-capability check, and the `1c-standards` corpus (`standards` tool) | [`docs/1C-docs-mcp.md`](docs/1C-docs-mcp.md) |
| **1c-code-check-mcp** | 1С:Напарник — code review, technical check, AI rewrite / modify, ITS documentation | [`docs/1c-code-check-mcp.md`](docs/1c-code-check-mcp.md) |
| **1c-syntax-checker-mcp** | BSL syntax and style via BSL Language Server: `syntaxcheck_file` (**default** — a file on disk by path, optionally line-filtered) and `syntaxcheck` (fallback — code as text for a fragment that has no file yet) | [`docs/1c-syntax-checker-mcp.md`](docs/1c-syntax-checker-mcp.md) |
| **1c-data-mcp** | Live-IB execution: BSL fragment (`vcexecutecode`), query (`vcexecutequery`), query parse-check (`validatequery`), last event-log error (`vcloggetlasterror`). Read-only by default; ask before any mutation | [`docs/1c-data-mcp.md`](docs/1c-data-mcp.md) |
| **edt-mcp** *(conditional)* | Live 1C:EDT workspace: validation markers, native navigation / references, MDO-format metadata and modules, form snapshots, DB update. Only in EDT projects (`USE_EDT=true`); never replaces the bundle — routing in `content/rules/edt-workflow.md` | [`docs/edt-mcp.md`](docs/edt-mcp.md) |

## Parameter names — exact, never guessed

Use the names below (they match the live schema); never substitute a natural-sounding alias. On a schema rejection re-read `docs/<server>.md` — do not retry with another guess.

| Server | Tools | Input parameter |
|---|---|---|
| graph | `get_object_dossier`, `find_objects_using_object`, `find_usages_of_object`, `trace_impact`, `compare_base_and_extension` (+ `extension_name`) | **`object_name`** — not `object_full_name`, `full_name`, `fullName`, `qualified_name`, `name` |
| graph | `trace_call_chain` | **`routine_name`** (+ optional `object_name`) |
| graph | `find_register_movement_docs` / `find_by_guid` / `resolve_qualified_name` | `register_name` / `guid` / `qualified_name` |
| graph | `search_metadata` (JSON template as the value), `search_metadata_by_description`, `execute_metadata_cypher`, `search_code`, `business_search` | **`query`** — not `query_template`, `template`, `json_query`, `q`, `text`, `search_query`, `prompt` |
| graph | `answer_metadata_question` | **`question`** |
| code-metadata | `get_metadata_details`, `graph_dependencies`, `inspect_form_layout` (+ optional `form_name`) | **`object_name`** — same shape and bans as above |
| code-metadata | `search_function` / `get_module_structure` / `get_method_call_hierarchy` / `bsl_scope_members` | `name` / `module_path` / `method_name` / `context` |
| code-metadata | `get_xsd_schema`, `verify_xml` (+ `xml_content`) | **`object_type`** |
| code-metadata | `metadatasearch`, `codesearch`, `search_forms`, `helpsearch` | **`query`** — not `q`, `text`, `prompt`, `search_query` |

`object_name` on both servers is a dotted qualified name with the type prefix — `Справочник.Контрагенты`, `Документ.РеализацияТоваровУслуг`, `РегистрНакопления.ТоварыНаСкладах`, `ОбщийМодуль.РаботаСКонтрагентамиКлиентСервер` — never a separate "full name" parameter.

### Parameter-rich tools — tune before calling

Defaults are usually suboptimal; set the parameters to the task, and on a miss reformulate (mode, `detail_level`, `exact`, `top_k`, filters) before switching tools:

- `1c-graph-metadata-mcp`: `search_code` (`search_type`, `detail_level`), `search_metadata` (JSON templates), `search_metadata_by_description` (`alpha`, `use_fuzzy`), `trace_impact` (`direction`, `depth`, `relationship_types`), `trace_call_chain` (`direction`, `depth`), `get_object_dossier` (`sections`), `business_search` (`include_structure`, `filter_type`).
- `1c-code-metadata-mcp`: `metadatasearch` (`object_type`, `names_only`), `get_method_call_hierarchy` (`direction`, `depth`), `graph_dependencies` (`direction`), `bsl_scope_members` (`member_type`).

If `docs/<server>.md` conflicts with the descriptor exposed by the current environment, the environment descriptor wins.

## Fallback chain

**Project-source search** (code, metadata, usages, call chains, structure, forms, file locations): `1c-graph-metadata-mcp` → `1c-code-metadata-mcp` → `1c-code-metadata-mcp` with `grep=true` → only then native discovery tools (`Grep` / `Glob` / `Read`-scanning) with a one-line "what was tried" note. The discipline, its boundaries (bounded priority, not a ban; freshness evidence for a negative result; fragment-level retrieval before full-module `Read`), the quick first-pick table and the multi-extension scope rule are owned by `content/rules/mcp-first-search.md`.

**External knowledge** — no `Grep` equivalent; call only when the knowledge is needed:

1. `1c-templates-mcp` — templates (`templatesearch`: task text verbatim, reuse the hit — `docs/1c-templates-mcp.md`) and project memory (`recall` / `remember` — `content/rules/project-memory.md`).
2. `1c-ssl-mcp` — БСП / SSL reusable APIs and patterns.
3. `1C-docs-mcp` — versioned platform documentation; the mandatory platform-capability check before hand-rolling a specialized mechanism (`docs/1C-docs-mcp.md → Platform capability discovery`); the routed project standards (`standards(name=…)`, `content/rules/help-corpus-retrieval.md`).
4. `1c-code-check-mcp` — 1С:Напарник checks, ITS standards (`its_help` → `fetch_its` for every document used), AI drafts (non-deterministic — re-validate).
5. `1c-syntax-checker-mcp` — BSL validation after edits; `syntaxcheck_file` by path is the default, `syntaxcheck` with text only when the file tool is not exposed or the code has no file yet.
6. `1c-data-mcp` — the live infobase (run a fragment or a query, parse-check a query, last event-log error); read-only fragments by default, ask before any mutation (`docs/1c-data-mcp.md → Safety`).

Per-task tool sequences (writing code, review, architecture, error fixing, performance, refactoring, metadata XML, forms, integrations, documentation, platform-version comparison) — `content/rules/tooling-playbooks.md`.
