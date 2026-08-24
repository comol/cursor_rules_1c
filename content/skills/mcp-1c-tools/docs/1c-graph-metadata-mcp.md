# 1c-graph-metadata-mcp — tool catalog

Graph metadata server: scoped Neo4j graph, BSL call graph, forms, evidence, impact and project lifecycle. Structural/template tools are deterministic; `answer_metadata_question` and natural-language `search_metadata` require an LLM unless the deployment is in graph-only mode.

> Load this file only if `1c-graph-metadata-mcp` is actually exposed in the current session. The published surface varies with `MCP_TOOL_PROFILE` and feature gates; `list_graph_capabilities` / `get_graph_tool_schema` are authoritative.

## Contract and scope — read before calling

1. Current source responses use the slim `contract_version: "2.0"` envelope. Always-present fields are `contract_version`, `context`, `total`, `returned`; optional empty/false/null fields are omitted. Payload is in `items`, `text`, `nodes`/`edges`, or `data` depending on the tool.
2. Every tool accepts contract paging controls `cursor` and `max_items`. Project-data tools also accept `project_id` and optional `generation`. Get a valid project through `list_graph_projects`; do not invent it.
3. `project_id` is the security/data scope. A legacy domain argument named `project_name` on some search functions is only an in-graph filter and must never be used as a substitute for scope.
4. If `truncated` is true, read `truncation_reason` / `limits` and continue with the opaque cursor using exactly the same project, generation and query. A cursor is bound to the tool, query, generation and plugin epoch.
5. Errors are typed (`project_not_registered`, `stale_generation`, `invalid_argument`, `invalid_cursor`, `timeout`, etc.). Do not retry with guessed argument names.
6. `execute_metadata_cypher` has been removed. Never ask for or attempt arbitrary client Cypher. Use `run_graph_cypher_template(template_id, arguments)` with an allow-listed read-only template, or a typed graph tool.
7. Resolve an ambiguous entity once with `resolve_graph_entity`, then pass its returned stable reference to path/evidence/domain tools. Do not reconstruct `node_id`, keys or edge refs by hand.

### Tools not automatically project-scoped

Discovery/health/contract tools (`get_metadata_prompt`, `get_indexing_status`, `health_graph`, `get_graph_capabilities`, `list_graph_capabilities`, `get_graph_tool_schema`, `metadata_report`), project lifecycle tools, plugin reload, and ordinary-form file tools receive only universal paging controls from the wrapper. A `project_id` shown in their own schema is a normal domain argument.

## Recommended workflow

1. `health_graph(project_id=...)` when availability is uncertain; it separates process liveness, Neo4j, providers and exact/fulltext/vector/hybrid/traversal lanes.
2. `list_graph_projects` → choose `project_id`; `get_graph_project_status` if ingestion/generation readiness matters.
3. `resolve_graph_entity(reference=...)` for a named/path/code reference.
4. Use the narrow typed tool (`get_object_dossier`, domain relation, path, impact, comparison) rather than broad search.
5. Use `explain_graph_evidence` / `explain_path` when a decision depends on provenance. A structural answer without evidence is not automatically a release proof.
6. Page until complete when the answer claims exhaustiveness. `truncated`, `exhaustive=false`, `degraded=true`, or unknown readiness forbids a “nothing else exists” conclusion.

## Search and object navigation

| Tool | Primary domain arguments | Use |
|---|---|---|
| `search_metadata` | `query`, optional legacy `project_name` | JSON template in the **value** of `query` (preferred) or NL→Cypher when LLM is available |
| `search_metadata_by_description` | `query`, `top_k=10`, `filter_type`, `use_fuzzy=false`, `alpha=0.5` | Name/synonym/comment/help fulltext + vector search |
| `business_search` | `query`, `top_k=10`, `filter_type`, `include_structure=true` | Business-semantic search; can degrade to structural/fulltext lanes |
| `search_code` | `query`, `search_type="hybrid"`, `top_k=3`, `filter_type`, `detail_level="L1"` | BSL routine search. Use fulltext for identifiers, semantic for intent; request full code only when needed |
| `answer_metadata_question` | `question`, `max_tokens=4000`, `include_code=true` | LLM/RAG synthesis; non-deterministic hint, verify sources |
| `get_object_dossier` | `object_name`, optional `sections` | First call for a known qualified object; bounded multi-section passport |
| `resolve_qualified_name` | `qualified_name` | Resolve a 1C dotted qualified name |
| `find_by_guid` | `guid` | Find metadata by GUID |
| `resolve_graph_entity` | `reference`, optional `kinds`, `max_candidates` | Convert name/path/code reference to stable graph identity |
| `explain_graph_entity` | `reference`, optional relation filter/direction/group limit | Compact entity card and grouped relations |
| `fetch_graph_nodes` | `node_ids` | Expand compact node IDs returned by graph/path tools |

**Argument naming:** search inputs are `query`; Q&A uses `question`; dossier/object-relationship tools use `object_name`; call traversal uses `routine_name`; movement lookup uses `register_name`. Do not invent `q`, `text`, `prompt`, `full_name`, `object_full_name`, or `query_template`.

## Relationships and classic impact

| Tool | Primary domain arguments | Use |
|---|---|---|
| `find_objects_using_object` | `object_name` | Objects that use a type reference |
| `find_usages_of_object` | `object_name` | Exact attributes/dimensions/resources that reference it |
| `find_register_movement_docs` | `register_name` | Documents making movements into a register |
| `trace_impact` | `object_name`, `depth=3`, `direction="downstream"`, optional `relationship_types` | Legacy recursive impact by graph relations |
| `trace_call_chain` | `routine_name`, optional `object_name`, `direction="callees"`, `depth=3` | BSL callers/callees |
| `find_test_artifacts` | `references`, optional `test_kinds` | Locate indexed tests covering named graph entities; does not execute tests |

## Evidence-first path, release impact and comparison

These tools take structured refs returned by `resolve_graph_entity`, not guessed strings.

| Tool | Primary domain arguments | Use |
|---|---|---|
| `find_graph_path` | `from_ref`, `to_ref`, `direction="undirected"`, optional `edge_types`, `max_depth`, `max_paths` | K shortest grounded paths; inspect `exhaustive` and per-edge evidence |
| `explain_path` | `steps` from a path result | Explain each path step without re-encoding it |
| `affected_subgraph` | `roots`, optional `node_kinds`, `depth`, `direction`, `edge_types`, `stop_kinds` | Release-oriented transitive impact with related tests and bounded frontier |
| `explain_graph_evidence` | exactly one of `node_ref` or `edge_ref` | Provenance for one graph fact |
| `compare_graph_scope` | structured `base`, `target`, optional `node_kinds` | Compare projects/generations/layers; do not interpret an incomparable/truncated kind as deleted |
| `compare_base_and_extension` | `object_name`, `extension_name` | Object-oriented base/extension diff |
| `resolve_effective_entity` | `object_ref`, optional `extension_name` | Effective entity after extension layers |

## 1C domain relations

| Tool | Primary domain arguments | Use |
|---|---|---|
| `get_access_rights` | `object_ref`, optional `right`, `role`, `field` | Role rights on object/field |
| `get_event_subscriptions` | `source_ref`, optional `event`, `handler` | Source → subscription → handler chain |
| `find_predefined_values` | `object_ref`, optional `parent_ref`, `name` | Predefined hierarchy |
| `get_register_writers` | `ref`, `direction="both"` | Register writers in either direction |
| `get_data_links` | `ref`, `direction="both"`, optional `link_kind` | Data-reference paths |
| `get_report_dcs_lineage` | `report_ref` | Report → DCS → datasets/queries/fields lineage |

## Forms

| Tool | Primary domain arguments | Use |
|---|---|---|
| `search_forms` | `query=""`, `form_kind="all"`, optional `owner_ref` | Search managed/ordinary forms |
| `get_form_structure` | `form_ref`, optional `include`, `max_depth` | Elements, attributes, commands, events |
| `find_form_links` | `form_ref`, `direction="both"`, optional `link_kinds` | Handlers, bindings, owner/module links |
| `unpack_ordinary_form` | `form_path`, `workspace_path`, `overwrite=false`, `include="summary"`, `max_chars=4000` | Admin-profile file operation: unpack `Form.bin` |
| `build_ordinary_form` | `workspace_path`, `output_path`, `overwrite=false`, `verify=true` | Admin-profile file operation: rebuild and logically verify `Form.bin` |

An ordinary `Form.bin` is a binary container, not XML. Do not edit it directly. A rebuilt binary may differ in bytes because of timestamps; `verification.status == "match"` is the round-trip criterion.

## Observability, contract and safe templates

| Tool | Purpose |
|---|---|
| `health_graph` | Process, Neo4j, provider and per-lane readiness; pass `project_id` for exact lane state |
| `get_indexing_status` | Background task status/restart-loop protection |
| `get_graph_schema` | Node and edge kinds in the selected project |
| `get_graph_stats` | Graph/evidence counters; optional label filter |
| `list_graph_indexes` | Neo4j index state/population |
| `get_graph_capabilities` | Local analysis vs delegated capabilities and graph-only degradation |
| `list_graph_capabilities` | Published tools, contract version/profile/feature gates/limits |
| `get_graph_tool_schema` | Exact JSON Schema, annotations and example for one tool — use before any uncertain call |
| `get_metadata_prompt` | Graph schema and template catalogue; does **not** authorize raw Cypher |
| `run_graph_cypher_template` | Execute one allow-listed read-only `template_id`; values travel separately in `arguments`, and project-scope names are forbidden there |
| `list_plugins` | Loaded plugins, hooks/tables/presets, failures and plugin epoch |
| `metadata_report` | Tombstone explaining replacements for the removed monolithic report |

In graph-only mode, structural graph/template/fulltext functions continue while LLM/vector-dependent lanes report explicit degradation. Do not call missing providers a total outage; inspect `health_graph` and capabilities.

## Project lifecycle and profiles

| Tool | Primary arguments | Use |
|---|---|---|
| `list_graph_projects` | none | Registered projects in this namespace |
| `get_graph_project_status` | `project_id`, optional `operation_id` | Active/staging generations, readiness and operation progress |
| `register_graph_project` | `project_id`, `source_descriptor`, `operation_id` | Register a source; idempotent operation ID |
| `refresh_graph_project` | `project_id`, `operation_id` | Build staging generation, validate, then promote |
| `delete_graph_project` | `project_id`, `operation_id` | Destructive scoped deletion |
| `reload_plugins` | `operation_id` | Atomic plugin reload; derived-state hooks affect the next build and invalidate old cursors |

`MCP_TOOL_PROFILE=admin` publishes lifecycle, plugin reload and ordinary-form write tools. `read-only` omits them from `tools/list`; do not attempt to call hidden tools. Plugins are enabled by default in current source. Call-scoped hooks affect the next call; derived-state hooks change the build fingerprint and require a new generation.

## Source preparation

- A Designer XML export in `CODE_EXPORT_PATH` is sufficient: with `METADATA_SOURCE=auto`, the server prefers a supplied text report and otherwise synthesizes/caches one from XML in the background. `METADATA_SOURCE=xml` deliberately ignores a stale report; `report` requires one.
- Report synthesis does not support 1C:EDT. For EDT, use the source-format adapter plus a supplied text report for the metadata-report lane.
- HTTP probes in every server mode: `/health` or `/healthz` for liveness, `/ready` or `/readyz` for Neo4j + published tool readiness.
