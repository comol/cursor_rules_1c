# 1c-ssl-mcp — tool catalog

Search over the 1C Standard Subsystems Library (БСП/SSL) documentation and runtime observability.

> Load this file only if `1c-ssl-mcp` is actually exposed in the current session. The expanded surface below is published in beta; stable tags retain the older `ssl_search(query)` contract. `tools/list` is authoritative.

## Search

| Tool | Parameters | Purpose |
|---|---|---|
| **ssl_search** | `query`, `limit=5`, `min_score`, `database`, `detail="compact"`, `cursor`, `doc_id` | Exact/hybrid search, bounded pagination, or direct fetch of one result |

### Retrieval rules

1. Use one identifier (optionally dotted or with a parameter list) for exact lookup. Ordinary prose uses hybrid semantic + BM25 retrieval.
2. `limit` is 1–20. `min_score` filters cosine similarity; larger is more relevant. `database` restricts the selected SSL database.
3. Start with `detail="compact"`. A compact hit remains resolvable through its `doc_id`; call `ssl_search(query=<same query>, doc_id=<id>, detail="full")` when the full record is needed.
4. A bounded response ends with `total`, `returned`, `truncated` and possibly an opaque `cursor`. Continue with the same query/filter arguments. A cursor is process-local, expires, and is bound to the index/plugin generation; `stale_cursor` means restart the search.
5. `ambiguous_name` returns candidates rather than choosing an overload. Refine by signature or fetch the desired `doc_id`.
6. `not_found` is a completed negative result. Do not repeat the same call as if it were a transport failure.

## Observability and plugins

| Tool | Purpose |
|---|---|
| **plugin_state** | Loaded plugins, hooks/tables, errors, epoch and derived-index fingerprint |
| **plugin_reload** | Atomically reload plugin files in the running process |
| **embedding_state** | Embedding provider, dimension and `input_type` capability |
| **vector_store_state** | zvec runtime, serving generation, manifest and migration status |
| **session_state** | HTTP session bounds and counters |

`plugin_reload` mutates the live server behavior and invalidates generation-bound cursors. Call it only on an explicit operator request, never as part of routine search or troubleshooting. If derived-state hooks changed, a new index generation may be required before results are current.

## Recommended workflow

1. `ssl_search(query=<exact symbol or Russian description>, detail="compact")`.
2. If one hit is the needed answer, fetch it by `doc_id` only when compact evidence is insufficient.
3. Follow `cursor` only when the task requires exhaustive results.
4. Use `embedding_state` / `vector_store_state` when retrieval is degraded; use `session_state` only for transport/session diagnosis.
5. When `1c-ssl-mcp` is absent, fall back to code search (`1c-code-metadata-mcp`) and then repository search. Never invent a BSP API from memory.
