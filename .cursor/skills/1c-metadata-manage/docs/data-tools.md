# 1C Data Tools — Execute Code, Queries & Diagnostics via MCP

## Prerequisites

Before using any tool below, verify the `user-1c-data-mcp` MCP server is available in the current environment. If the server is not present, inform the user that these tools require the `1c-data-mcp` MCP server to be configured and connected, and stop.

All tools are called via `CallMcpTool` with `server: "user-1c-data-mcp"`.

## Available Tools

### vcexecutequery

Executes a 1C query language statement and returns the result as a text table (headers + rows separated by `|`).

| Parameter | Type | Description |
|---|---|---|
| `querytext` | string | Query text in 1C query language |

**Constraints:**
- The query must be a **single line** — no line breaks allowed
- All query parameters must be **inlined** directly in the query text (no `&Parameter` placeholders)

### vcvalidatequery

Validates a 1C query for syntactic correctness **without executing** it.

| Parameter | Type | Description |
|---|---|---|
| `querytext` | string | Query text in 1C query language to validate |

**Constraints:**
- The query must be a **single line** — no line breaks allowed

Returns `нет ошибок` on success, or a description of the syntax error found.

### vcexecutecode

Executes arbitrary BSL (1C language) code in the database. To return a value, define a variable named `Результат` and assign to it — this value will be the tool output.

| Parameter | Type | Description |
|---|---|---|
| `bslcode` | string | BSL code to execute |

### vcloggetlasterror

Returns the last error from the 1C event log (Журнал регистрации) within the past 24 hours. Takes **no parameters**.

## Agent Guidelines

- Use `vcexecutequery` for data retrieval; use `vcexecutecode` when procedural logic or object manipulation is required.
- For complex or generated queries, consider running `vcvalidatequery` before execution to catch syntax errors early.
- After a failed operation or user-reported issue, call `vcloggetlasterror` to get diagnostics from the event log.
- **Never execute data-modifying code** (writes, deletions, posting documents) without explicit user confirmation.
