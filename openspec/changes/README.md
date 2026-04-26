# Changes — active proposals

This folder contains in-flight change proposals. Each change is isolated in
its own sub-folder.

## Layout of a single change

```
changes/<change-name>/
├── proposal.md   # why this change exists, scope, approach
├── design.md     # technical decisions and architecture (optional)
├── tasks.md      # implementation checklist with checkboxes
└── specs/        # delta specs, mirroring the layout of ../specs/
    └── <domain>/
        └── spec.md
```

## Delta spec format

Delta specs use three top-level sections to describe changes relative to the
current state of `../specs/<domain>/spec.md`:

```markdown
# Delta for <domain>

## ADDED Requirements

### Requirement: <name>
...

## MODIFIED Requirements

### Requirement: <name>
... (replaces existing requirement of the same name)

## REMOVED Requirements

### Requirement: <name>
(why it is being removed)
```

When the change is archived (`/opsx:archive` or `openspec archive`):

- ADDED requirements are appended to the main spec.
- MODIFIED requirements replace the existing version.
- REMOVED requirements are deleted from the main spec.

The change folder is then moved to `archive/<YYYY-MM-DD>-<change-name>/`.

## Standard artifacts

| File | Purpose |
|------|---------|
| `proposal.md` | The "why" and "what" — captures intent, scope, and approach. |
| `specs/` | Delta specs (ADDED / MODIFIED / REMOVED requirements). |
| `design.md` | The "how" — technical approach and architecture decisions. Optional but recommended for non-trivial changes. |
| `tasks.md` | Implementation checklist with `- [ ]` checkboxes. |

See the [parent `README.md`](../README.md) for the full workflow and the
recommended slash commands.
