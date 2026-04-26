---
description: Per-task MCP tool playbooks (writing code, review, refactoring, error fixing, performance, forms, integrations, documentation)
alwaysApply: false
category: tooling
---

# Tool Usage by Task — Playbooks

The overall server priority (`graph → code-metadata → Grep`) and the tool descriptors live in `AGENTS.md → Tooling`.

## Writing New Code

1. **templatesearch** — find similar implementations.
2. **get_object_dossier** — full passport of the target metadata object (structure, forms, dependencies, code, roles) in a single call.
3. **search_code** → **codesearch** — review existing patterns in the configuration.
4. **search_function** — find an existing procedure/function by name for reuse.
5. **get_module_structure** — overview of the module you intend to edit.
6. **metadatasearch** / **get_metadata_details** — verify metadata structure and attribute types.
7. **bsl_scope_members** — discover available methods/properties of a context.
8. **docinfo** — verify built-in functions by exact name; **docsearch** — search by description.
9. **ssl_search** — find reusable БСП functions.
10. **syntaxcheck** — verify syntax after writing.
11. **check_1c_code** — find logic and performance defects.
12. **review_1c_code** — verify style and ITS standards compliance.

## Code Review

1. **search_code** → **codesearch** — verify pattern compliance.
2. **trace_impact** → **graph_dependencies** — impact analysis of the change.
3. **trace_call_chain** → **get_method_call_hierarchy** — BSL call chains, callers/callees.
4. **metadatasearch** / **get_metadata_details** — correct metadata usage.
5. **docinfo** — verify method/property existence; **docsearch** — search by description.
6. **review_1c_code** — style and ITS compliance.
7. **check_1c_code** — bugs and performance issues.
8. **its_help** → **fetch_its** — cross-check against ITS standards.

## Architecture Design

1. **get_object_dossier** — passport of key metadata objects.
2. **metadatasearch** / **get_metadata_details** — existing metadata structure.
3. **trace_impact** → **graph_dependencies** — dependency map across USED_IN, DO_MOVEMENTS_IN, CALLS.
4. **find_objects_using_object** — find all objects referencing the given one.
5. **search_code** → **codesearch** — existing architectural patterns.
6. **trace_call_chain** → **get_method_call_hierarchy** — code coupling and call chains.
7. **templatesearch** — architectural templates.
8. **ask_1c_ai** — architectural questions to 1С:Напарник (treat as a hint, not authority).
9. **config_help** — pattern realization in specific configurations.

## Error Fixing

1. **syntaxcheck** — syntax errors.
2. **check_1c_code** — logic and performance issues.
3. **search_function** — locate the failing procedure/function.
4. **search_code** → **codesearch** — related patterns (`detail_level="L0"` for the full body of a specific routine).
5. **get_module_structure** — module context around the error.
6. **trace_call_chain** → **get_method_call_hierarchy** — how the error propagates through the call chain.
7. **docinfo** — verify function/method names; **docsearch** — fallback by description.
8. **metadatasearch** / **get_metadata_details** — verify metadata names and attributes.
9. **modify_1c_code** — targeted AI fix (treat output as a draft, re-validate).

## Performance Optimization

1. **search_code** → **codesearch** — locate slow patterns (`semantic` mode: "медленный запрос", "цикл по выборке").
2. **trace_call_chain** → **get_method_call_hierarchy** — identify hot call chains.
3. **trace_impact** → **graph_dependencies** — objects that cause cascading issues (`relationship_types=["CALLS"]` for pure code paths).
4. **metadatasearch** / **get_metadata_details** — verify indexes and metadata structure.
5. **check_1c_code** — bottleneck analysis.
6. **rewrite_1c_code** — AI optimization (`goal: optimize`); re-validate with `check_1c_code` and `syntaxcheck`.
7. **templatesearch** — optimized templates.
8. **its_help** → **fetch_its** — ITS performance standards.

## Refactoring

1. **get_object_dossier** — passport of the object being refactored.
2. **trace_impact** → **graph_dependencies** (`direction="downstream"`) — what breaks on change.
3. **trace_call_chain** → **get_method_call_hierarchy** (`direction="callers"`) — all callers.
4. **find_objects_using_object** / **find_usages_of_object** — every type reference before renaming/removing.
5. **search_code** → **codesearch** — every code pattern related to the object.
6. **search_code** (`detail_level="L3"`, high `top_k`) → **codesearch** — post-refactor verification that no old references remain.
7. **check_1c_code** + **review_1c_code** — validate the result.

## Generating / Modifying Metadata XML

1. **metadatasearch** (`names_only=true`) — similar objects as examples.
2. **get_xsd_schema** — XSD schema for the target metadata type.
3. Write/modify XML against the schema and examples.
4. **verify_xml** — validate against XSD; fix errors.
5. Use the **1c-metadata-manage** skill for compilation and deployment.

## Form Analysis and Generation

1. **search_forms** — similar existing forms in the configuration.
2. **inspect_form_layout** — structure of the found form (elements, bindings, commands, events).
3. **metadatasearch** (`names_only=true`) — metadata objects for XML references.
4. **get_xsd_schema** (`"Форма"`) — XSD schema of `Form.xml`.
5. Generate `Form.xml` based on examples and schema.
6. **verify_xml** — validate `Form.xml` against XSD.
7. **1c-metadata-manage** skill (form-manage) — compilation and validation.

## Integrations

Use this playbook when writing HTTP services / clients, REST integrations, file or message-queue exchanges, webhooks. Domain rules — `integrations-add.md`.

1. **ssl_search** — check for ready-made БСП subsystems ("Интернет-поддержка пользователей", "Обмен данными", "Получение файлов из Интернета", "Цифровая подпись").
2. **templatesearch** — integration templates (HTTP request, JSON parsing, signed payloads, retry policy).
3. **search_code** → **codesearch** (`semantic` mode) — existing integrations in the configuration ("HTTP запрос", "отправка JSON", "парсинг ответа").
4. **docinfo** — verify platform types by exact name (`HTTPСоединение`, `HTTPЗапрос`, `ЧтениеJSON`, `ЗаписьJSON`, `ЗаписьXML`, `ЧтениеXML`).
5. **docsearch** — fallback when the exact platform-API name is unknown.
6. **get_xsd_schema** + **verify_xml** — when the contract is XML with a known XSD.
7. **its_help** → **fetch_its** — ITS articles on long-running operations, secure password storage, asynchronous external components.
8. **search_function** + **get_module_structure** — locate or extend the integration common module (typically `*HTTPClient`, `*Integration`, `*Exchange`).
9. After implementation: **syntaxcheck** → **check_1c_code** → **review_1c_code**.

## Documentation

1. **codesearch** — find code to document.
2. **metadatasearch** / **get_metadata_details** — metadata structure.
3. **get_module_structure** — list of procedures/functions.
4. **docinfo** — documentation by exact name; **docsearch** — search by description.
5. **helpsearch** — existing help articles.
6. **its_help** → **fetch_its** — methodological ITS articles.
7. **search_1c_documentation** — version-specific platform documentation.

## Comparing Platform Versions

1. **diff_1c_documentation_versions** — what changed between versions.
2. **search_1c_documentation** — documentation for a specific version.
