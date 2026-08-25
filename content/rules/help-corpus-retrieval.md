---
description: How to retrieve the detailed 1C development standards from the `1c-standards` collection of the Help MCP server (`1C-docs-mcp`) — the `standards` tool, name resolution, paging, and what to do when the server is not exposed. Load when following a "Where this standard lives" pointer from a routed rule.
alwaysApply: false
category: tooling
---

# Retrieving the routed standards from the Help MCP corpus

Fourteen of the detailed domain standards in `content/rules/` carry headings without bodies. Their normative text is one document each in the **`1c-standards`** collection of the Help MCP server (`1C-docs-mcp`), and this file is the single description of how to get it. The routed files point here instead of repeating the contract.

## The tool is `standards`, not `docsearch`

`1C-docs-mcp` holds four kinds of content and reaches them with four tools. The standards collection is **read whole rather than sampled**, so it has its own tool:

```
standards()                          → the catalogue: every standard, its name and declared description
standards(name="anti-patterns")      → that standard, entire
standards(query="именование ролей")  → search inside the standards only
```

Optional on all three forms: `max_chars`, `max_items`, `detail_level` (`detailed` | `compact`), `cursor`.

**`docsearch` and `docinfo` cannot reach the standards.** They serve the platform syntax reference and the platform prose; their `scope` parameter (`syntax` | `docs` | `all`) does not select this collection, and there is **no `corpus` parameter on any tool of this server**. A call like `docsearch(query=..., corpus="...")` is an unknown-argument error, and it is exactly the guessed-parameter defect `AGENTS.md → MCP Tool Calling → C.5` forbids.

The sibling collection `formatspec` works identically over the 1C file-format specifications (form / role / DCS / MXL / extension on-disk XML) — useful next to `metadata-xml-workarounds.md` and the `1c-metadata-manage` skill.

## Naming a standard

`name` accepts three spellings, case-insensitively:

- the **short name** — the file stem of the rule, which is what the routed files quote: `coding-standards`, `dev-standards-architecture`, `anti-patterns`;
- the **`doc_id`** a previous answer returned (`1c-standards/content/rules/anti-patterns.md`);
- the document's own **title**.

A name the collection does not hold answers `not_found` **and lists every standard it does hold** — so a misspelling costs one call, not a guessing loop. When you do not know which rule governs the work, `standards()` (the catalogue) is cheaper than guessing at names.

## Prefer whole documents; mind the paging

- **Know which rule governs → `standards(name=…)`.** These rules are written to be loaded before the work starts; one call gets the whole rule. Do **not** issue one `standards(query=…)` per section — that is more calls for less text, and it returns matched passages rather than the rule.
- **Do not know which rule → `standards(query=…)` once**, then fetch the rule it points at by name.
- **A document larger than `max_chars` is paged, not cut.** The response carries `collection.parts` and `next_cursor`; continue until you have the parts you need. A first page is not the rule — treat a truncated retrieval the same way you would treat half a file.
- **Retrieved text stays in context.** Re-requesting the same standard against unchanged state is forbidden by `AGENTS.md → MCP Tool Calling → C.2` like any other repeat.

## Retrieve before you apply

Every routed file reproduces its headings so that existing `<file>.md §N` and `→ "Title"` references still resolve. A heading is a **retrieval target, not a summary**: acting on a section title without reading the text behind it is inventing the rule, not following it. Reconstructing a standard from its heading — or from training-data memory of "how 1C is usually written" — is a defect.

## When the server is not exposed

`1C-docs-mcp` is an optional server (`content/mcp-servers.json`: `required: false`), and the ruleset must stay operational without it (`content/rules/mcp-first-search.md → When Grep / Glob / Read are legitimately the right tool`; `AGENTS.md → MCP Tool Calling → A.1`: MCP calls are mandatory **when a relevant server is exposed**). An outage degrades the evidence; it does not brick the work and it does not fail a gate by itself:

1. **State it once**, in one line, the first time a routed standard is needed.
2. **Work from what is still inlined** — the always-on rules, the un-routed rules (`module-structure.md`, `dev-standards-change-markers.md`, `forms-add.md`, `metadata-xml-workarounds.md`, `coding-standards.md`, `form-module.md`, `integrations-add.md`, `getconfigfiles.md`), and the pinned text on GitHub if the session can reach it.
3. **Record it under Risks** in the delivery summary, as the graceful-degradation lines of `verification-gates.md` are recorded: *"Standard `<name>` not retrieved — `1C-docs-mcp` not exposed in this session."*
4. **Do not claim standards compliance you did not verify.** The hard gates of `verification-gates.md` run as written; their own availability rules apply unchanged.
5. **On a promotion-trigger path** (`verification-policy.md → Triage details`) where the unretrievable standard is genuinely decisive for the change — raise `CONFUSION` and let the user choose between proceeding without it and deferring to a session that has the server. This is the one case where an outage stops the work, and it stops it by asking rather than by silently failing a gate.

## Where the corpus comes from

The collection ships **inside the `1C-docs-mcp` image** — nothing is mounted or indexed per project. If `standards` is absent from the session's tool schema while `docsearch` is present, the image predates the collection tools; `/checkmcp` reports that case.

Its content is built from **`content/standards/`** in the `1c-rules` source repository — the authoring home of the fourteen routed bodies and the only place they are edited (`content/standards/README.md` there; the directory is deliberately not installed into projects, so in an installed project it exists upstream only). The routers in `content/rules/` are pointers, not text: editing one changes nothing an agent reads.

Two consequences worth knowing while working:

- **An edit is live when the corpus is re-indexed, not when it is merged.** Until then, retrieval returns the previous text.
- **The pin is no longer load-bearing.** The collection was first built from `content/rules` at commit `410951e74fd3`, the last commit whose rule files still had bodies — which made any re-sync from a later commit index the routers and empty the corpus. Building from `content/standards/` removes that trap: this directory holds bodies at every commit. The routers still link the pinned text as a direct-read fallback, and that link stays valid, but it is a convenience now rather than the only surviving copy.

## Success criteria

- ✅ Standards fetched with `standards`, never with `docsearch` / `docinfo` and never with a `corpus` argument.
- ✅ The governing rule fetched whole by name; `query` used to *find* a rule, not to read one section at a time.
- ✅ Paged documents followed to the parts actually needed.
- ✅ No section applied from its heading alone.
- ✅ An unavailable server stated once, recorded under **Risks**, and never silently passed off as compliance.
