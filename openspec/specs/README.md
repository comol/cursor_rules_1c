# Specs — source of truth

This folder contains the authoritative specifications describing how the
system currently behaves. It is owned jointly by humans and AI assistants.

## Conventions

- One sub-folder per capability/domain (e.g. `auth-login/`, `payments/`).
- Each capability folder contains exactly one `spec.md`.
- Requirements use the `### Requirement:` heading and Gherkin-style
  scenarios under `#### Scenario:`.

## Minimal spec template

```markdown
# <capability> Specification

## Purpose
<one paragraph: why this capability exists>

## Requirements

### Requirement: <name>
<normative statement with MUST / SHALL / MAY>

#### Scenario: <name>
- GIVEN <precondition>
- WHEN <action>
- THEN <expected result>
- AND <additional result>
```

## How specs are updated

You normally do **not** edit spec files in this folder by hand. The standard
flow is:

1. Open a change proposal in `../changes/<change-name>/`.
2. Place delta specs under `../changes/<change-name>/specs/<domain>/spec.md`
   using `## ADDED Requirements`, `## MODIFIED Requirements`, and
   `## REMOVED Requirements` sections.
3. Run `/opsx:archive` (or `openspec archive`) — the deltas are merged into
   the corresponding files in this folder automatically.

See the [parent `README.md`](../README.md) for the full workflow.
