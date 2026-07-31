---
description: Active-model adaptation — how AGENT_MODEL in .dev.env selects a model profile (opus5 | sonnet5 | fable5 | gpt56), what a profile may and may not change, and the model-agnostic prompting baseline that always holds
alwaysApply: false
category: workflow
---

# Active model adaptation

**When to load this file:** when you need the routing / precedence contract of the model layer — at the start of a session where `AGENT_MODEL` is set in `.dev.env`, when the user runs `/rulesmodel`, when a profile and a base rule appear to conflict, or when the value in `.dev.env` does not match the model you are actually running. For the concrete behavioural deltas load the profile file itself (`content/rules/model-<slug>.md`); this file is the router, not the content.

## 1. What this layer is

The base ruleset (`AGENTS.md` + every on-demand rule) is written **model-neutral**: it states what must be verified, which tools are mandatory, and what the delivery report must contain — none of which depends on which LLM is executing it. Vendors, however, document behaviours that differ **per model**: default verbosity, how eagerly the model narrates, plans, delegates, re-verifies its own work, or takes unrequested action, and which effort / thinking settings that model actually respects.

A **model profile** is a thin delta that tunes those documented behaviours to the running model. It exists so the same ruleset produces the same outcome on Claude Opus 5, Claude Sonnet 5, Claude Fable 5 and GPT-5.6 without the base rules being rewritten for a particular vendor's quirks.

Sources of the deltas: the Anthropic prompting best-practices set (`platform.claude.com/docs/en/build-with-claude/prompt-engineering/…`, including the per-model pages for Opus 5 / Sonnet 5 / Fable 5) and the OpenAI latest-model guide (`developers.openai.com/api/docs/guides/latest-model` → *Prompting best practices*). Only the **model-specific** parts of those guides are allowed into profiles; everything a guide states for all models belongs to §5 below and is always in force.

## 2. Selecting the profile

| `AGENT_MODEL` | Model | Profile file |
|---|---|---|
| `opus5` | Claude Opus 5 | `content/rules/model-opus5.md` |
| `sonnet5` | Claude Sonnet 5 | `content/rules/model-sonnet5.md` |
| `fable5` | Claude Fable 5 (and Claude Mythos 5) | `content/rules/model-fable5.md` |
| `gpt56` | GPT-5.6 | `content/rules/model-gpt56.md` |
| *empty / missing / unknown* | any other model | *no profile — the base ruleset applies as written* |

- **`AGENT_MODEL` is Defaulted** (`content/rules/dev-standards-env.md → "AGENT_MODEL — active-model profile of the parent agent"`): missing file, missing key, empty or unrecognised value means "no model layer". Never ask for it at task time, never guess it, never treat its absence as a defect — the base ruleset is complete without it. The canonical editor is the `/rulesmodel` command (`content/commands/rulesmodel.md`).
- **Load once per session**, before the first non-trivial task, together with the rest of the always-on layer. A profile is small (≈1–2k tokens); do not re-read it per task and do not load more than one.
- **Self-knowledge wins over a stale value.** `AGENT_MODEL` is a project setting and may have been written for a different client. If you know you are running a model that has a profile, apply **that** profile, state the mismatch in one line, and recommend `/rulesmodel` — do not silently rewrite `.dev.env` mid-task. If the value names a model that has a profile and you cannot tell what you are running, trust the value.
- **No family guessing.** A model without its own profile (Claude Opus 4.8 / 4.6, Sonnet 4.6, GPT-5.5 and earlier, and every non-Anthropic / non-OpenAI model) runs the base ruleset. Applying a neighbouring profile "because it is close" is wrong — profiles encode deltas that are only correct for the named model. The user may still opt in explicitly through `/rulesmodel <slug>`; then honour the choice and say which profile is active.
- **Not the same thing as `SUBAGENT_MODEL_*`.** `AGENT_MODEL` describes the model **you** (the parent agent) run on and tunes your behaviour. `SUBAGENT_MODEL_CODING` / `_ANALYSIS` / `_LIGHT` are the concrete models the **installer** stamps into subagent files per tier (`content/rules/subagents.md → Model-tier routing`, edited by `/economymode models`). Changing one never changes the other. A subagent running a different model applies its own profile only if its client resolves one; the parent does not translate profiles for it.

## 3. Accepted spellings (normalisation)

Users write model names however they like. `/rulesmodel` and any manual `.dev.env` edit resolve free-form input to a slug from §2; the mapping is by **family + major version**, case-insensitive, ignoring spaces, dashes, dots, underscores, vendor prefixes and language:

| Slug | Recognised as |
|---|---|
| `opus5` | `opus5`, `opus 5`, `opus-5`, `claude-opus-5`, `claude opus 5`, `Claude Opus 5.0`, `клод опус 5`, `опус 5` |
| `sonnet5` | `sonnet5`, `sonnet 5`, `claude-sonnet-5`, `Claude Sonnet 5`, `сонет 5`, `соннет 5` |
| `fable5` | `fable5`, `fable 5`, `claude-fable-5`, `Claude Fable 5`, `mythos5`, `claude-mythos-5`, `фейбл 5`, `фабл 5`, `мифос 5` |
| `gpt56` | `gpt56`, `gpt5.6`, `gpt-5.6`, `GPT 5.6`, `openai gpt-5.6`, `гпт 5.6`, `гпт-5.6` |

Rules for the resolution:

- **Ambiguous or unsupported input is never silently coerced.** `gpt-5.5`, `opus 4.8`, `sonnet 4.6`, `haiku`, `gemini`, `glm`, `qwen`, a bare `claude` or a bare `5` resolve to **nothing**: report the supported set and leave / clear the value (base ruleset). Offer the nearest same-family profile only as an explicit choice the user confirms.
- **A version qualifier is not part of the slug.** Client-side variants and effort suffixes (`-thinking`, `-high`, `#xhigh`, `-max`, `-fast`, provider prefixes such as `anthropic/`, `openai/`) are stripped before matching: `anthropic/claude-opus-5#xhigh` → `opus5`.
- The canonical slug written to `.dev.env` is always the dot-free form from §2 (`gpt56`, not `gpt5.6`) — rule file names and the `AGENTS.md` path rewriting both require it.

## 4. Precedence — what a profile may and may not change

A profile tunes **how much the agent does on its own initiative** and **how it communicates**. It never lowers the floor.

**A profile MAY:**

- shape response length, narration cadence, and the wording (not the presence) of the delivery report of `AGENTS.md → Development Procedure → 5`;
- shape how much upfront exploration and planning is proportionate before acting;
- tune delegation eagerness within the bounds of `content/rules/subagents.md` (and `orchestrator-economy.md` when the mode is on);
- forbid **self-invented extra** verification — additional self-review passes, a verifier subagent, or repeated re-reading of your own diff that no rule asked for;
- recommend client-side settings (effort / reasoning effort, verbosity, thinking on/off) and give a prompt-level equivalent for clients where those settings are not exposed to you;
- recommend a level of an existing presentation switch (e.g. the `caveman` skill's level) with a one-line reason;
- emphasise a mechanism the base rules already own (project memory, `recall` / `remember`, handoff) when the model is documented to benefit from it.

**A profile MUST NOT** touch any of these, and any reading of a profile that seems to do so is a misreading:

- the hard gates — `1c-metadata-manage` for metadata mutations and infobase-operation tooling (`AGENTS.md → Skills and Subagents`), MCP-first search (`content/rules/mcp-first-search.md`), the platform-capability check and `templatesearch` / `recall` obligations (`AGENTS.md → MCP Tool Calling → A`), and the memory gates (`AGENTS.md → Project memory`);
- the validator chain and its budget (`syntaxcheck → check_1c_code → review_1c_code`, `AGENTS.md → MCP Tool Calling → B.1`) or the gates in `content/rules/verification-gates.md`. **Mandated validator calls are tool evidence, not self-verification** — a profile that damps "over-verification" damps only the extra passes the agent invents for itself;
- triage (`content/rules/verification-policy.md`), the `CONFUSION` obligation on material forks, the completeness / no-placeholders principle, the source-language policy, or the evidence one-liners (`Template:`, `Memory:`, `Metadata tooling:`, `IB tooling:`);
- the requirement to confirm destructive or hard-to-reverse actions.

**Precedence on conflict:** `USER-RULES.md` and `memory.md` → `LLM-RULES.md` → the active model profile → `AGENTS.md` and the other on-demand rules, for the behaviours the profile explicitly covers. Everything in the MUST NOT list is outside what a profile can cover, so it wins regardless of the order. If a profile and a base rule genuinely collide on a behaviour that is not in the MUST NOT list, follow the profile and note it in one line; if the collision touches the MUST NOT list, follow the base rule and report the profile text as a defect worth fixing upstream.

## 5. Model-agnostic prompting baseline (always in force)

These are the parts of both vendor guides that apply to **every** model. They are not repeated in profiles, are never overridden by a profile, and are already implemented by the base ruleset — the pointers show where:

- **Be explicit and specific; sequence steps when order matters.** State the desired output and its constraints (`AGENTS.md → Development Procedure → 1`, `4`).
- **Give the reason with the instruction.** A rule that carries its "why" is followed more accurately — this is why rules in this set state the consequence of violation, and why task briefs to subagents must carry intent, not only steps (`content/rules/subagents.md → Bounded sidecar task templates`).
- **Structure mixed content with tags and use examples.** Wrap distinct kinds of content (instructions vs. input vs. examples) in named tags in long briefs; keep examples relevant, diverse and few (3–5).
- **Long context: data first, question last.** Put long inputs (module listings, XML dumps, logs) above the instruction, and ground answers in quoted fragments of what you read.
- **Say what to do, not what not to do.** Positive examples of the wanted shape beat prohibitions.
- **Parallel independent tool calls; never guess parameters.** Batch independent MCP / file calls, keep dependent calls sequential, and never invent an argument name or value (`AGENTS.md → MCP Tool Calling → C.1`, `C.3`, `C.5`).
- **Investigate before answering.** Never speculate about code you have not opened; read the file the user named (`AGENTS.md → MCP Tool Calling → A.3`, `content/rules/mcp-first-search.md`).
- **Define success criteria and verify against them.** Turn imperative tasks into verifiable goals (`AGENTS.md → Development Procedure → 4`).
- **Keep instructions non-contradictory.** Conflicting instructions degrade every model; resolve a conflict explicitly (`CONFUSION`, or the precedence chain above) instead of averaging the two readings.
