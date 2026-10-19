# codeprobe v2.3.0 — Runnable Evals, Plugin Packaging, and a Verification Pass

**Date:** 2026-10-19
**Status:** Builder check done (5 questions, all settled below as author's calls) — pending owner approval
**Baseline:** codeprobe v2.2.0 (commit `65e4f59`), Claude Code 2.1.303
**Supersedes:** nothing. Follow-on work is listed under Non-goals.

---

## 1. Intent

codeprobe shipped "regression evals" in v2.2.0, but they are a hand-written JSON checklist that no tool executes. Every change to a sub-skill prompt, the severity guardrails, or the dedup logic is currently un-measurable. Meanwhile Claude Code has shipped an official eval runner (`claude plugin eval`) that reads a different layout, a plugin manifest format, and a sandboxed way to run a plugin against fixtures in CI.

This release does three things, in dependency order:

1. **Make the evals runnable** under `claude plugin eval`, with the existing planted-defect fixture, so recall (planted defects found in the right severity bucket) and precision (baits not reported) are measured numbers.
2. **Package the repo as a Claude Code plugin** (one manifest file), which is the prerequisite for (1) and lets Claude Code users install it natively. The existing `npx skills add nishilbhave/codeprobe` path must keep working unchanged.
3. **Add a verification pass** to the orchestrator: an adversarial second look at every Critical and Major finding before it reaches the report. This is the biggest quality gap versus Qodo PR-Agent and Claude Code's own `/code-review`, both of which try to disprove findings before reporting them. (1) exists so that (3) can be proven not to drop planted defects.

### Why now

- The eval format we ship is explicitly not read by the official runner (docs: "neither tool reads the other's case files").
- Follow-on work the owner wants (per-category model tiers, a learnings file, a graphify pre-step, reference-guide refresh) all change findings. None of it is safe without a regression gate.
- The skill has ~1.1K installs on skills.sh. A false-positive-heavy audit is the most common reason a user stops trusting a reviewer; the verification pass addresses that directly.

### What success looks like

- `claude plugin eval . --scaffold --allow-tools ...` runs from the repo root, exits 0, and the report shows every planted Critical found and every bait unreported, at the default 3 runs.
- A CI job runs the suite on pull requests with a pinned model, a cost ceiling, and a pass threshold.
- A `/codeprobe audit evals/fixture` run with verification on reports **zero** rejected planted Criticals, and **none** of the baits added in this release appear at Major or Critical in the final report. Whether a bait was never raised or was raised and rejected is reported, not scored (see 4.2, `rejected-lists-bait`).
- `npx skills add nishilbhave/codeprobe` and `claude plugin install` both work from the same tree.

---

## 2. Goals, non-goals, anti-goals

### Goals

- G1. Evals in the official `evals/<case>/prompt.md` + `graders/*.md` layout, runnable locally and in CI.
- G2. A fixture with both planted defects (recall) and planted baits (precision), with a single defect map that grades both.
- G3. `.claude-plugin/plugin.json` at the repo root; `claude plugin validate .` passes.
- G4. A verification pass in the orchestrator, on by default for `audit`, `diff`, and `quick`, configurable off.
- G5. Findings that fail verification are dropped and counted; findings downgraded by verification carry a note. Neither silently disappears.
- G6. Ship as v2.3.0 with the version in one canonical place and a check that the other copy matches.

### Non-goals (explicitly deferred, in the owner's intended order)

- Per-category model tiers (`model: haiku` for cheaper sub-agents). The verification pass is designed so the model for verifiers and sub-agents can be set later without restructuring.
- A per-repo learnings file (persisted feedback so rejected findings are not re-reported).
- Graphify as an optional pre-step feeding architecture, SOLID, and patterns.
- Reference-guide refresh and new guides for Go, Java, Rust.
- Intent/spec review and the cross-sub-skill disagreement policy (`docs/feedback-gaps.md` Gaps 2 and 3).
- A Workflow-tool (ultracode) rewrite of the orchestrator.
- An MCP server.
- Submitting to Anthropic's plugin directory or hosting a separate marketplace repo.

### Anti-goals (would make this a failure even if it technically works)

- Breaking the `npx skills add` install path or changing the skill name users invoke today (`/codeprobe`).
- Any new **hard** runtime dependency. Python 3.8+ stays optional; nothing else is added.
- A verification pass that drops planted Criticals. Precision must not be bought with recall. The eval gates this.
- Evals that are so expensive nobody runs them. A full suite run must have a cost ceiling and a cheap single-arm mode for iteration.
- Violating the READ-ONLY constraint anywhere, including inside eval sandboxes (the only permitted write remains `./codeprobe-reports/`).

---

## 3. Constraints

- **Read-only constraint** in `skills/codeprobe/SKILL.md` is unchanged and applies to verifier agents too.
- **Agent Skills spec compatibility.** Outside Claude Code only `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` are spec fields. The orchestrator already uses Claude Code-only fields (`user-invocable`, `argument-hint`) and that has not broken `npx skills add`; do not add more Claude Code-only frontmatter fields to any SKILL.md in this release.
- **Eval sandbox facts** (from the Claude Code docs, 2026-10): each run starts in an empty workspace with a temporary HOME; nothing personal or project-level loads; fixture files reach the workspace only via a `scaffold_script` (runs only with `--scaffold`) or read-only `add_dirs`; `Bash`, `Write`, `Edit` must be granted on the command line with `--allow-tools`; Bash then runs under the OS sandbox with writes confined to the workspace; default `max_turns` is 10 and default `timeout_seconds` is 300; there are no custom-code graders, only `regex`, `tool_used`, `tool_order`, `file_exists`, `llm`, `baseline`.
- **Plugin skill naming.** Installed as a plugin, the skill is invoked as `/codeprobe:codeprobe audit …`. Installed via skills.sh it stays `/codeprobe audit …`. Both must work; docs show both.
- **Marketplace root-source is unverified.** Docs only show `"source": "./plugins/<name>"`. Whether `"./"` is accepted for a plugin that *is* the repo root is not documented.
- Claude Code ≥ 2.1.269 for `plugin eval`; git ≥ 2.31.

---

## 4. Design

### 4.1 Plugin packaging

**Files added**

```
.claude-plugin/plugin.json
```

```json
{
  "name": "codeprobe",
  "version": "2.3.0",
  "description": "Senior-engineer code audit: 9 parallel review agents, scored health dashboard, severity-rated findings with fix prompts. Read-only.",
  "author": { "name": "Nishil" },
  "license": "MIT",
  "repository": "https://github.com/nishilbhave/codeprobe"
}
```

Only `name` is required; the rest is informational. `skills/<name>/SKILL.md` is a default scan location, so no `skills` array is declared. Nothing else goes in `.claude-plugin/`.

**Version canonicality (my call).** `plugin.json.version` is canonical. `skills/codeprobe/SKILL.md` keeps `metadata.version` because the three templates fill `{version}` from it. A tiny script `scripts/check_version_sync.sh` (grep both, exit 1 on mismatch) runs in CI. Bumping means editing two lines.

**Marketplace (builder verifies).** Add `.claude-plugin/marketplace.json` with `name: codeprobe`, `owner`, and one entry `{ "name": "codeprobe", "source": "./" }`. Run `claude plugin validate .` and then `claude plugin marketplace add ./ && claude plugin install codeprobe@codeprobe` locally. If a root-relative source is rejected, **drop marketplace.json from this release** and document the two install paths that are known to work: `npx skills add nishilbhave/codeprobe` and `claude --plugin-dir <clone>`. Do not restructure the repo into `plugins/codeprobe/` to satisfy the marketplace; that would break skills.sh.

**README** gains a short "Install as a Claude Code plugin" subsection under Install, and the Commands table notes the `/codeprobe:codeprobe` form.

### 4.2 Evals

**Layout** (replaces `evals/evals.json`; the old file is deleted, its assertions migrate into graders):

```
evals/
├── fixture/                     # shared planted-defect project (unchanged location)
│   ├── app.py, orders.py, manager.py, models.py, services.py, database.py, utils.js
│   ├── tests/test_orders.py
│   └── (new bait files, see 4.3)
├── expected-findings.md         # defect map, now with a "Must NOT be reported" table
├── audit-full/
│   ├── prompt.md
│   ├── case.yaml                # context.scaffold_script: scaffold.sh
│   ├── scaffold.sh              # copies ../fixture into the workspace as ./fixture
│   └── graders/
├── quick-top5/
│   └── (same shape)
├── security-only/
│   └── (same shape)
└── results/                     # gitignored
```

`evals/fixture/` holds no `prompt.md` or `case.yaml`, so the runner does not treat it as a case.

**Scaffold script.** Each case's `scaffold.sh` copies the shared fixture into the empty workspace. The script is invoked by path, so it locates the fixture relative to itself:

```bash
#!/usr/bin/env bash
set -euo pipefail
cp -R "$(dirname "$0")/../fixture" ./fixture
```

Builder verifies that `$0` resolves to the case directory under the runner; if it does not, fall back to `add_dirs: [fixture]` with a per-case symlink and adjust the prompt path. Scaffold has a 120-second limit, which copying ~10 files will not approach.

**prompt.md for `audit-full`** (representative; the others differ in command and limits):

```markdown
---
name: audit-full
description: Full 9-category audit of the planted-defect fixture
tags: [audit, regression]
runs: 2
max_turns: 200
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

/codeprobe:codeprobe audit ./fixture
```

The slash-command form is used rather than natural language so the case measures the skill, not trigger-phrase matching. `runs: 2` for the full-fan-out case (`audit-full`) and `runs: 3` for the cheaper ones is my call to keep a full-suite run affordable; `--runs` overrides it.

**Tool grants.** The orchestrator needs `Bash` (for `python3 scripts/*.py`, `mkdir -p ./codeprobe-reports`, and read-only git in `diff`) and `Write` (for the report). These are not grantable from `prompt.md`, so the documented run command is:

```bash
claude plugin eval . --scaffold --trust-plugin \
  --allow-tools Write "Bash(python3 *)" "Bash(mkdir *)" "Bash(wc *)" \
  --max-cost-usd 25
```

Builder confirms the minimal Bash grant set by running once with `--keep-temp` and reading the `not granted` list.

**Baseline arm.** Without the plugin, `/codeprobe:codeprobe` does not exist, so the without-arm is noise. Every case sets graders that are inherently with-only (`tool_used: Skill`) and the CI command passes `--ablation none`. The Δ feature is not used in this release.

**Graders per case.** Each case gets one cheap grader on *process* and several on *result*, following the docs' guidance. Exact regexes are the builder's; the required checks are:

**Where graders look.** The terminal contract (SKILL.md Section 8B) deliberately keeps Major findings, minor counts, and the rejected section out of `last_message`; only Criticals, the dashboard, and the top-5 fix order appear there. That contract does not change. Anything that lives only in the saved report is graded on the `trace` target instead: the orchestrator writes the report with the `Write` tool, so the full report text is present in the transcript as that tool call's JSON-escaped input. A grader's `{ source: file, path }` cannot be used because the report filename carries a timestamp. Regexes over `trace` must therefore avoid literal double quotes (they appear as `\"`) and match on IDs, file names, and section headings.

| Case | Grader | Type | Target | Checks |
|---|---|---|---|---|
| all | `skill-fired` | `tool_used` on `Skill`, `input_match` on `codeprobe` | — | the skill ran |
| all | `read-only` | `file_exists` with `exists: false` for `fixture/**` | — | no fixture file was created (creation is the only thing `file_exists` sees; modification is covered by the `llm` rubric below) |
| audit-full | `report-written` | `file_exists` `codeprobe-reports/*.md` | — | report artifact exists |
| audit-full | `critical-<n>` ×6 | `regex`, one grader per planted Critical (#1, #2, #3, #4, #6, #16) | `last_message` | each Critical appears in the terminal's Critical section. These six are the **plants-survive** set referenced by CI (4.2 CI) |
| audit-full | `dashboard-present` | `regex` for the 9-row category table and the save line | `last_message` | terminal contract honored |
| audit-full | `rejection-line` | `regex` for `Rejected by verification: \d+` | `last_message` | the count is reported (0 is acceptable) |
| audit-full | `n1-is-major` | `regex` | `trace` | `order_summaries` appears in the Major table, not under Critical |
| audit-full | `god-class-once` | `regex` `match: "count:1"` on the `UserManager` primary + `Also flagged by` | `trace` | dedup kept exactly one primary with cross-reference |
| audit-full | `no-false-criticals` | `llm` | `last_message` | zero Criticals from Test Quality, Code Smells, Patterns, Framework; no fixture file modified |
| audit-full | `bait-<n>-absent` ×5 | `regex` `match: not_contains` per bait location, scoped to the Critical and Major sections | `trace` | each bait absent at Major/Critical (Minor/Suggestion tolerated) |
| audit-full | `rejected-lists-bait` | `regex` for any bait location inside the "Rejected by verification" section, `weight: 0.25` | `trace` | informational: verification visibly did work. Low weight because a bait the sub-skills never raised is also a correct outcome |
| quick-top5 | `at-most-five` | `regex` `match: "count:N"` is not usable for a range, so: one grader `not_contains` for a 6th row, one `llm` check that 3–5 rows exist | `last_message` | between three and five findings (see 4.4 quick handling) |
| quick-top5 | `top5-dominated-by-plants` | `llm` | `last_message` | ≥3 of the rows are planted Criticals |
| security-only | `sec-plant-<n>` ×4 | `regex` per SEC plant | `last_message` | #1–#4 found |
| security-only | `rationale-present` | `regex` on "Severity rationale" with `match: "count:N"` equal to the finding count, or an `llm` check if counts vary | `last_message` | every finding has a rationale |
| security-only | `single-category` | `regex` `match: not_contains` for `SRP-`, `SMELL-`, `ARCH-`, `PERF-` IDs | `last_message` | no cross-category leakage |

`llm` graders are kept short and written as explicit PASS/FAIL conditions. `--judge-model` is pinned in CI.

**CI.** `.github/workflows/evals.yml`, triggered on `pull_request` touching `skills/**` or `evals/**` and on `workflow_dispatch`. Steps: install Claude Code, run the command above with `--json results.json --threshold 0.8 --ablation none --no-publish --model <pinned> --judge-model <pinned>`, upload `evals/results/**/report.html` as an artifact. Secrets: whichever auth the owner uses for Claude Code in CI (API key or OAuth token); the workflow reads it from a repo secret named in the file. Linux runners need `bubblewrap` and `socat` for the Bash sandbox. The threshold is 0.8 initially (not the 1.0 default) because `llm` graders are noisy; raise it once the suite has a history.

*Fork pull requests (my call).* Secrets are not available to `pull_request` runs from forks, and `pull_request_target` would run untrusted code with `--trust-plugin` and credentials. The job therefore carries `if: github.event.pull_request.head.repo.full_name == github.repository || github.event_name == 'workflow_dispatch'`, so fork PRs skip it and a maintainer runs the suite on a fork branch by hand with `workflow_dispatch` after reading the diff. The repo has no external contributors today; revisit if that changes.

*Plants-survive hard gate (my call).* The suite threshold is one number, but dropping a planted Critical is the anti-goal and must block regardless of the aggregate. After the eval step, a small step parses `results.json` with `jq` and fails the job if any `critical-<n>` grader in `audit-full` failed in **any** run. This is a second gate on the same run, not a second run.

**Migration of `evals/evals.json`:** its three cases map 1:1 to `audit-full`, `quick-top5`, `security-only`. The precision checks (baits) fold into `audit-full` rather than a fourth case, because a separate case would be a second full fan-out over the same fixture measuring nothing the first run does not already show. Every assertion string becomes a grader or part of an `llm` rubric. `docs/superpowers/plans/` and the README's "Regression evals" bullet are updated to describe the new layout and the run command.

### 4.3 Fixture baits (precision)

The fixture gains code that *looks* like a defect to a pattern-matching reviewer but is safe on inspection. Each bait targets one sub-skill's most common false positive. All live in a new `evals/fixture/safe.py`, each with a one-line comment stating it is a deliberate bait, consistent with the existing fixture header convention.

| # | Bait | Looks like | Why it is safe | Must not appear as |
|---|---|---|---|---|
| B1 | `@require_auth`-decorated `DELETE /admin/orders/<id>` where the decorator is defined in the same file and checks a session | missing auth on mutating endpoint (#3) | auth is enforced by the decorator | Critical/Major SEC |
| B2 | f-string SQL where the interpolated value is a module-level constant chosen from a fixed allowlist (`ORDER BY {SORT_COLUMNS[key]}`) and the row filter is parameterized | SQL injection (#1) | no user input reaches the string | Critical SEC |
| B3 | `WAREHOUSE_API_KEY = os.environ.get("WAREHOUSE_API_KEY", "dev-placeholder-not-a-secret")` in `safe.py` | hardcoded secret (#2) | the literal is a non-secret dev default; the real value comes from the environment. (An `.env.example` or `conftest.py` placeholder was considered and dropped: the security table already excludes those paths by rule, so they would never reach the verifier and would test nothing.) | Critical SEC |
| B4 | `except Exception as e: logger.exception(...); raise` on an external call | swallowed exception (#7) | logged and re-raised | Major ERR |
| B5 | A loop over `order_ids` that issues one `WHERE id IN (...)` query before the loop and indexes a dict inside it | N+1 (#8) | single batched query | Major PERF |

Five is deliberate: enough to measure, few enough that a human can confirm each verdict by reading the file. `expected-findings.md` gains a "Must NOT be reported" table with these rows and the grading rule: a bait reported at **Minor or Suggestion** is tolerated (not scored); at **Major or Critical** it is a precision failure.

### 4.4 Verification pass

**Where it sits.** New orchestrator step between "Collect findings" and "Deduplicate" (Section 4 → new Section 4B in `SKILL.md`; Section 11 flow summary gains a step). Runs for `audit`, `diff`, and `quick`. Single-category commands (`/codeprobe security` etc.) also run it — one verifier, same rules — because single-category output is what users paste into tickets.

**What is verified.** Every finding at `critical` or `major`. `minor` and `suggestion` pass through unverified; they only contribute counts and the cost of verifying them is not worth it.

**Fan-out.** One verifier agent per category that has at least one Critical or Major finding, spawned in parallel in a single message (≤ 9 agents). For `quick`: rank the pooled scan-mode candidates first (Section 4, Execution Order), then spawn **one** verifier for the provisional top **8**. Render the top 5 among those that come back `confirmed` or `downgraded`, re-ranked after any downgrade. This is one round, no loop: if fewer than 5 survive, render what survived (minimum 3 is the eval's expectation on the fixture; a clean codebase may legitimately show fewer) and say so in one line. Candidates ranked 9+ are never verified and never rendered. The verifier receives: the shared preamble's READ-ONLY block, the list of findings for its category (all output-contract fields), the file manifest, the reference-guide paths, and the verification rubric below. It does **not** receive the sub-skill's detection tables, so it cannot simply re-run the same pattern match.

**Verifier rubric** (new file `skills/codeprobe/verification-rubric.md`, read once by the orchestrator and inlined, same mechanism as the preamble). For each finding the verifier must:

1. Open the file at the stated location and confirm the quoted `evidence` exists within ±5 lines of the stated range. If it does not, the finding is `rejected: evidence not found`.
2. Trace the claim, not the pattern. For input-flow claims (injection, XSS, mass assignment, IDOR), identify the actual source of the tainted value. For auth claims, look for enforcement at any layer: decorator, router-level middleware, framework config, a guard called in the function body. For "missing X" claims (transaction, timeout, validation), check whether X is provided by a caller, a wrapper, or the framework. For performance claims, confirm the loop actually issues the query per iteration.
3. Check the exclusion lists. Test fixtures, `.env.example`, generated code, and vendored directories are already excluded by the sub-skills' "What It Does NOT Flag" rules; the verifier re-applies them.
4. Return one verdict per finding:
   - `confirmed` — evidence holds and the severity rationale's boundary claim is true.
   - `downgraded` — the issue is real but the boundary claim is false (e.g., "exploitable as-is" but the endpoint is behind auth). Verifier sets the new severity (one bucket lower, never two; never above the original) and a one-sentence `verification_note`.
   - `rejected` — not an issue, with a one-sentence reason quoting the mitigating code.
5. Never raise severity. Never add new findings. Never modify files (READ-ONLY).

Output: the same findings list with two new fields per finding, `verification: confirmed|downgraded|rejected` and `verification_note` (required for downgraded/rejected), plus a summary `{ "confirmed": n, "downgraded": n, "rejected": n }`.

**Orchestrator handling.**

- `rejected` findings are removed before dedup and before scoring. Their count appears on a new dashboard line, `**Rejected by verification:** N`, next to "Duplicates removed". In the saved report, a collapsed "Rejected by verification" section lists `id | location | reason` so the user can disagree. In the terminal, only the count is shown.
- `downgraded` findings keep their ID and move buckets; the rendered finding shows `**Verification:** downgraded from Major — {note}` under the severity rationale.
- `confirmed` renders unchanged.
- If a verifier agent fails or times out, its category's findings pass through unverified and the dashboard line reads `Rejected by verification: N (1 category unverified)`. Verification failure never blocks the report.

**Configuration.** `.codeprobe-config.json` gains `"verify": true` (default). `false` skips the pass entirely and omits the dashboard line. No per-command flag; commands take only a path.

**Cost.** Verification adds at most 9 agents, each reading only the files named in its findings. Expected overhead on a typical repo: 20–40% of the sub-skill phase, less on clean codebases (few Critical/Major → few verifiers). This is the number the `audit-full` eval's cost column will show, and it is the input to the later model-tier decision (verifiers are a natural candidate for a cheaper model, but **not in this release**).

**Output contract changes.** `shared-preamble.md` and SKILL.md Section 5 add the two optional fields. Sub-skills do not set them. The three templates gain the dashboard line and the collapsed section (audit template only; `pr-review-comment.md` adds the count line to its summary table; `quick-review-summary.md` adds a one-line count).

### 4.5 Documentation and version

- `README.md`: plugin install subsection; `/codeprobe:codeprobe` note; "Regression evals" bullet rewritten with the run command; a new "Verification" paragraph under How It Works; the scoring section notes rejected findings do not count.
- `docs/feedback-gaps.md`: no change (Gaps 2 and 3 remain open; verification is not a disagreement policy).
- `CHANGELOG.md` is **not** added; the repo has never had one and the git log plus the version bump commit serve that role. (Owner may override.)
- Version 2.3.0 in `plugin.json` and `SKILL.md`.

---

## 5. Decisions already made (do not revisit)

| Decision | Choice | Why |
|---|---|---|
| Eval runner | `claude plugin eval`, not skill-creator's `evals.json` | official, CI-capable, sandboxed; the old file is unrunnable |
| Fixture delivery to the sandbox | `scaffold_script` copying the shared fixture | `add_dirs` is read-only and codeprobe must be able to `mkdir ./codeprobe-reports` in the workspace; the fixture itself is never written to |
| Baseline arm | not used (`--ablation none`) | the without-arm cannot invoke a slash command that does not exist |
| What gets verified | Critical and Major only | they drive scores and terminal output; verifying Minor/Suggestion is cost without benefit |
| Verifier fan-out | per category, parallel | matches the existing sub-skill shape; bounded at 9 |
| Verifier may not upgrade | hard rule | prevents the pass from becoming a second finder; keeps the severity ceilings in Section 6 authoritative |
| Rejected findings | dropped from scores, listed in the saved report | the user can audit the auditor without the terminal getting noisier |
| Verification default | on | the whole point is fewer false positives by default; `verify: false` exists for cost-sensitive runs |
| Version source of truth | `plugin.json`, mirrored in SKILL.md with a CI check | templates need the frontmatter copy; CI prevents drift |
| Repo layout | unchanged (`skills/` at root) | preserves `npx skills add` |
| Precision case | folded into `audit-full`, no separate case | a second full fan-out over the same fixture measures nothing new |
| Grading saved-report content | `trace` target (the `Write` call carries the report) | terminal contract stays as is; `{source: file}` cannot target a timestamped filename |
| `quick` verification | provisional top 8, one verifier, one round | bounded cost, no loop, 5 survivors in the common case |
| Fork PRs in CI | skipped on `pull_request`; maintainer runs `workflow_dispatch` | no secrets to forks, no `pull_request_target` with `--trust-plugin` |
| Plants-survive | hard gate via `results.json` parse, in addition to the 0.8 threshold | dropping a plant is the anti-goal; one aggregate number cannot express it |

## 6. Left to the builder

- Exact regex patterns and `llm` rubric wording for every grader (the table in 4.2 states what each must check).
- The minimal `--allow-tools` Bash grant list, discovered with `--keep-temp`.
- Whether `scaffold.sh` can locate the fixture via `$0`; the fallback is specified.
- Whether marketplace.json with a root source validates; the fallback is specified.
- Exact wording of the verifier rubric and the new SKILL.md Section 4B, within the rules in 4.4.
- CI auth secret name and the pinned model IDs (use the current Claude 5 family; pin full IDs, not aliases).
- The precise bait code in `safe.py`, within the table in 4.3.

## 7. Verification of this design (how we'll know it worked)

1. `claude plugin validate .` → `✔ Validation passed`.
2. `claude plugin eval . --scaffold --trust-plugin --allow-tools … --ablation none --runs 1` → all three cases load, `skill-fired` passes, no `not granted` tools.
3. Full run at default runs: every case ≥ 0.8, and every `critical-<n>` grader in `audit-full` passes in every run (the plants-survive gate, enforced separately from the threshold).
4. Manual: `/codeprobe audit evals/fixture` in a normal session shows the new dashboard line and the collapsed rejected section in the saved report.
5. `npx skills add nishilbhave/codeprobe` from a clean machine still installs ten skills and `/codeprobe audit .` works.
