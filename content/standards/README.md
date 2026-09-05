# `content/standards/` — bodies of the routed rules

This directory is the **authoring home of the fourteen detailed 1C standards** whose files in `content/rules/` carry headings without bodies. It is the source the `1c-standards` collection of the Help MCP server (`1C-docs-mcp`) is built from, and it is the only place those rules are edited.

Maintainers may read, edit, review, and validate these source files. Applying a routed standard during 1C development requires retrieval through MCP `standards`; this directory and repository URLs are not runtime fallbacks.

## Not installed

`install.ps1` enumerates exactly four content directories — `content/rules`, `content/agents`, `content/commands`, `content/skills`. This one is deliberately not among them: user projects get the thin routers and retrieve the text, which is the whole point of the split. Adding it to the installer would undo the refactor.

## The sync contract

The corpus build uses this authoring source (build configuration, not a runtime retrieval link):

```
url:    https://github.com/comol/ai_rules_1c
prefix: content/standards
```

1. Select a reviewed source commit and record its full revision and the hashes of the indexed body files in the corpus build / release evidence. Index `content/standards`, never the routers under `content/rules`; exclude this README.
2. Validate the router/body heading pairs before indexing. Publish the rebuilt corpus with its image identity and the source revision in release evidence so maintainers can relate a rules release to its corpus build.
3. Retrieve the changed standards by short name from that image through `standards`, follow paging, and compare the returned bodies with the indexed source. Only this verification establishes that the changes are available through MCP; merging or pushing the source files alone does not.
4. If the corpus build is outside the current task or unavailable, report the source change as complete and the corpus publication as pending. Do not claim synchronization with the deployed server without evidence.

Keep the rule file stem as the stable lookup name, for example `standards(name="anti-patterns")`. A returned `doc_id` is opaque: copy it exactly if reused, never derive it from a path. Build metadata is a maintainer contract, not a new MCP API; clients use only version / provenance fields actually exposed by the connected server.

## What belongs here, and what does not

Here: a rule whose `content/rules/` file is a router — the fourteen listed below.

Not here: any rule that is inlined in `content/rules/`. Those are read from context and need no retrieval; a second copy in this directory would be a duplicate to keep in sync, which is exactly the failure this directory exists to end. **One rule, one body, one location.**

| Routed standard | Router |
|---|---|
| `anti-patterns.md` | `content/rules/anti-patterns.md` |
| `async-methods.md` | `content/rules/async-methods.md` |
| `bsp-access-rights.md` | `content/rules/bsp-access-rights.md` |
| `dcs-advanced-composition.md` | `content/rules/dcs-advanced-composition.md` |
| `dcs-design.md` | `content/rules/dcs-design.md` |
| `dev-standards-architecture.md` | `content/rules/dev-standards-architecture.md` |
| `dev-standards-code-style.md` | `content/rules/dev-standards-code-style.md` |
| `extension-patterns.md` | `content/rules/extension-patterns.md` |
| `form-patterns.md` | `content/rules/form-patterns.md` |
| `locks-and-transactions.md` | `content/rules/locks-and-transactions.md` |
| `logging-strategy.md` | `content/rules/logging-strategy.md` |
| `platform-solutions.md` | `content/rules/platform-solutions.md` |
| `registers-design.md` | `content/rules/registers-design.md` |
| `systematic-debugging.md` | `content/rules/systematic-debugging.md` |

## Editing a standard

1. Edit the body **here**. Change its router only when retrieval instructions or headings need to change.
2. Keep every `##` / `###` / `####` heading in sync with its router. The routers reproduce the heading tree so that existing `<file>.md §N → "Title"` references and anchor links still resolve; a heading added here and not there is a reference that will not resolve, and one removed here leaves the router pointing at nothing. `tools/validate-rules.ps1` checks the pair.
3. Rebuild and verify the collection under the sync contract above. Until then, agents may retrieve the previous text.

Retrieval side of the contract — `content/rules/help-corpus-retrieval.md`.
