---
description: Model profile for Claude Opus 5 (AGENT_MODEL=opus5) — verbosity and report shape, narration cadence, no self-invented extra verification, damped subagent spawning, correction narration, effort and thinking settings
alwaysApply: false
category: workflow
---

# Model profile — Claude Opus 5

**When to load this file:** `AGENT_MODEL=opus5` in `.dev.env`, or you know you are running as Claude Opus 5. Load once per session, before the first non-trivial task. Routing, precedence and the invariants this file may not touch — `content/rules/model-adaptation.md`. Everything below tunes **initiative and communication only**; every hard gate of `AGENTS.md` stays exactly as written.

Baseline: Claude Opus 5 runs this ruleset well without tuning. The items below are the documented behaviours that most often need it.

## 1. Verbosity and the delivery report

Opus 5's default user-facing answers run **longer** than prior Opus models', and lowering `effort` reduces thinking rather than visible output — length has to be asked for.

- Keep the mandatory report of `AGENTS.md → Development Procedure → 5` (what changed, file list, risks) — and keep it tight: **lead with the outcome** in the first sentence, then the file list, then risks. No restating the task, no recap of the process, no "как я это делал".
- Caveats, trade-offs and disclaimers: short. One line each, not a paragraph.
- When the user asks a question, answer at summary depth and stop; expand only when they ask for depth.
- **Written artefacts follow the same calibration.** Files you author — OpenSpec `proposal.md` / `design.md` / `tasks.md`, `content/skills/handoff` output, `1c-doc-writer` deliverables, review reports — tend to come out longer than needed on this model. Cover the substance; drop filler sections, redundant summaries and boilerplate. Length is not evidence of thoroughness.

## 2. Narration during work

Opus 5 narrates readily and announces what it is about to do; per-message output during agentic work is longer than on prior models.

- One sentence before the first tool call of a task ("смотрю модуль и шаблоны, потом правлю"). After that, an update only when you **find something material** or **change direction**.
- Do not narrate each MCP call, and do not re-summarise between calls. The evidence one-liners the ruleset requires (`Template:`, `Memory:`, `Metadata tooling:`, `IB tooling:`, validator results) are the report, not narration — keep them, keep them one line each.
- Under `CAVEMAN=on` this profile and the skill agree: terse working messages, complete sentences in the final answer.

## 3. Scope and no self-invented verification

Opus 5 verifies its own work without being told to, and instructions to double-check compound into wasted passes.

- **Do not add verification the ruleset did not ask for**: no extra "review my own diff" pass, no second read of a file you already read unchanged, no re-running a validator on unchanged content (already forbidden by `AGENTS.md → MCP Tool Calling → C.2`), and **never** a subagent spawned to check your own work.
- **The mandated chain is not self-verification.** `syntaxcheck → check_1c_code → review_1c_code` within the `B.1` budget, `verify_xml` for metadata XML, and the gates in `content/rules/verification-gates.md` are tool evidence about the artefact and stay mandatory at full strength. The spec-compliance stage of `content/rules/subagent-pipeline.md` also stays — when that pipeline is actually in use. What this section removes is the *self-invented* layer on top.
- **Scope discipline.** Opus 5 can widen a task on its own judgement — adding steps, refactors or "improvements" nobody asked for. `AGENTS.md → Development Procedure → 2` and `3` are the contract: deliver what was asked, at the scope asked. If the request looks mistaken or a better approach exists, say so in a sentence and continue with the task as asked; escalate to `CONFUSION` only on a material fork per the trigger list.

## 4. Delegation to subagents

Opus 5 delegates more readily than prior models, and delegation multiplies cost when the task is small.

- The threshold in `content/rules/subagents.md` stands, and on this model it leans toward **direct execution**: anything you can finish in a handful of tool calls, a single-module edit, or a task where you need the context in your own head — do it yourself.
- Never delegate verification of your own output (§3). If one subagent can do the work, use one, not several; keep spawn counts low and prefer a single wide brief over fan-out.
- With `ORCHESTRATION=economy` the mode's routing wins — the parent still delegates execution per `content/rules/orchestrator-economy.md` — but the low-spawn-count preference stays: one subagent per tier task, no fan-out for one module.

## 5. Correction narration

Opus 5 narrates corrections to its own earlier statements more than prior models.

- Correct an earlier statement only when the error would change the user's code, conclusions or decisions. State it plainly in a sentence and continue.
- For slips that change nothing (a mistyped file path you already fixed, a number you restated correctly) — make the fix and move on. No tally of your own mistakes, no apology paragraph. This does not weaken the reporting obligations: a validator that failed, a skipped step, or an unverified artefact is always reported (`AGENTS.md → MCP Tool Calling → B.1`).

## 6. Review tasks

Opus 5 reviews code with high precision **and** follows a stated bar literally — a brief that says "only critical issues" produces fewer findings, not a better filter.

- When you review BSL yourself or brief `1c-code-reviewer` / `1c-arch-reviewer`: ask for **coverage** — report every finding with severity and confidence — and filter afterwards. Do not put "only high-severity", "be conservative" or "не придирайся" in the brief.
- Filtering happens in the report you give the user (blocking defects first, style nits collapsed), not in the finding step. This does not change what `check_1c_code` / `review_1c_code` severities mean for the gate: `critical` / `error` still block per `B.1`.

## 7. Effort, thinking and context (client-side settings)

You often cannot set these yourself; state the recommendation once when it matters and apply the prompt-level equivalent otherwise.

- **Effort:** `high` is the default and fits most 1C work. Use `xhigh` for full-cycle multi-module changes, architecture, metadata surgery and hard debugging; `low` / `medium` are genuinely strong on this model — use them for docs-fix, triage, quick-fix and routine lookups.
- **Keep thinking enabled.** On Opus 5 thinking is on by default and can be disabled only at `high` effort or below; with it disabled the model can emit a tool call as plain text (the call never runs, and in an agentic loop the leaked text pollutes the rest of the session) or leak internal XML tags into the answer. Both are fatal for a ruleset whose entire discipline is MCP tool calls. If cost is the concern, lower `effort` — do not disable thinking.
- Never add "do not think", "do not reason", "skip the reasoning" style instructions to a prompt, a subagent brief or a skill — on this model such rules increase tag leakage.
- **1M-token context** is available and instruction following holds across it. Practical consequence: prefer keeping evidence you already fetched in context over re-querying for it (which `C.2` forbids anyway). It is **not** a licence to bulk-read modules or glob source trees — `content/rules/mcp-first-search.md` is unchanged.
