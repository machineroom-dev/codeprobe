---
name: codeprobe
description: >
  Whole-codebase code quality audit system with 9 specialized sub-skills covering
  security, SOLID principles, architecture, error handling, performance, test
  quality, code smells, design patterns, and framework best practices. Produces a
  scored health dashboard (0-100 per category), severity-rated findings (P0-P3)
  with severity rationales, and copy-pasteable fix prompts; also does PR-style
  diff review vs a base branch. Strictly read-only — never modifies user code.
  Use when the user says "codeprobe", "audit", "full code review", "code health",
  "check my code", "security scan", "code smells", "SOLID check", or asks how
  healthy, risky, or maintainable a codebase is. (For reviewing just the working
  diff, the built-in /code-review may be more appropriate unless the user asks
  for codeprobe.)
user-invocable: true
argument-hint: "[audit|diff|solid|security|smells|architecture|patterns|performance|errors|tests|framework|quick] <path-or-base>"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Write
metadata:
  author: Nishil
  version: "2.2.0"
---

# Code Review Orchestrator

## READ-ONLY CONSTRAINT

**THIS SKILL IS STRICTLY READ-ONLY WITH RESPECT TO THE CODEBASE BEING REVIEWED.** NEVER modify, write, edit, or delete any file in the user's source tree. NEVER run commands with side effects on the reviewed project (no `npm install`, no `pip install`, no git commits, no database mutations). If a fix is needed, generate a copy-pasteable fix prompt that the user can run separately.

**One documented exception — report artifact:** after `/codeprobe audit` finishes, the orchestrator writes a single markdown report to `./codeprobe-reports/<project>-<cmd>-<timestamp>.md` in the current working directory (e.g. `./codeprobe-reports/growth-engine-audit-2026-04-23-221047.md`). This is the skill's own output, not modification of reviewed code. No other writes are permitted anywhere.

**Git is read-only too:** `/codeprobe diff` may run read-only git commands (`git diff`, `git merge-base`, `git ls-files`, `git rev-parse`, `git status`). It must NEVER run git commands that mutate the repository or working tree — no commit, checkout, stash, reset, fetch, or pull.

Violations of this constraint are NEVER acceptable, regardless of user request.

---

## 1. Command Routing

Parse the user's input to extract a subcommand and target path. The input format is:

```
/codeprobe [subcommand] [path]
```

### Routing Table

| Command | Behavior | Sub-skills Invoked |
|---------|----------|-------------------|
| `/codeprobe audit <path>` | Full audit — visual health dashboard (category scores, codebase stats, hot spots) followed by detailed P0-P3 findings with fix prompts | All available sub-skills + `file_stats.py` |
| `/codeprobe solid <path>` | SOLID principles analysis only | `codeprobe-solid` |
| `/codeprobe security <path>` | Security audit only | `codeprobe-security` |
| `/codeprobe smells <path>` | Code smells detection only | `codeprobe-code-smells` |
| `/codeprobe architecture <path>` | Architecture analysis only | `codeprobe-architecture` |
| `/codeprobe patterns <path>` | Design patterns analysis only | `codeprobe-patterns` |
| `/codeprobe performance <path>` | Performance audit only | `codeprobe-performance` |
| `/codeprobe errors <path>` | Error handling audit only | `codeprobe-error-handling` |
| `/codeprobe tests <path>` | Test quality audit only | `codeprobe-testing` |
| `/codeprobe framework <path>` | Framework best practices only | `codeprobe-framework` |
| `/codeprobe quick <path>` | Top 5 issues — run all sub-skills in scan mode, then generate full detail for top 5 | All available |
| `/codeprobe diff [base]` | PR-style review of changed files vs a base branch (default: `main`, fallback `master`) — see Section 4A | All 9 sub-skills, scoped to changed files |

### Default Behaviors

- **No subcommand given**: Ask the user what they want. Present the available commands.
- **No path given**: Use the current working directory.
- **Unknown subcommand**: Say it is not a codeprobe command and list the routing table above.

---

## 2. Stack Auto-Detection

Before routing to any sub-skill, detect the technology stack at the target path. This informs which reference guides to load and pass to sub-skills.

### Detection Procedure

1. Use Glob to scan file extensions at the target path (recursive, reasonable depth).
2. Apply the following detection rules — multiple stacks can match simultaneously:

| Signal | Stack Detected | Reference to Load |
|--------|---------------|-------------------|
| `.php` files | PHP / Laravel | `references/php-laravel.md` |
| `.js`, `.ts`, `.jsx`, `.tsx` files | JavaScript / TypeScript | `references/javascript-typescript.md` |
| `.py` files | Python | `references/python.md` |
| `.jsx`, `.tsx` files + `next.config.*` present | React / Next.js | `references/react-nextjs.md` |
| `.sql` files or `migrations/` directory | SQL / Database | `references/sql-database.md` |
| `routes/` directory or API route patterns | API Design | `references/api-design.md` |

3. For each detected stack, confirm the corresponding reference file exists. If it does not exist, skip silently.
4. Collect the **absolute paths** of all applicable reference files to pass to sub-skills. Do NOT read reference contents into the orchestrator's own context — sub-agents read the references relevant to their domain directly, which keeps every context window lean.

### Reference Resolution

References live in the `references/` directory within this skill's own directory. Resolve paths relative to this SKILL.md file's location, NOT the user's project, and convert them to absolute paths before passing them to sub-agents (whose working directory is the user's project):
```
{this-skill's-directory}/references/{reference-file}.md
```

If a reference file does not exist, continue without it. Never fail the review because a reference is missing.

---

## 3. Config Loading

Check for a `.codeprobe-config.json` file in the project root (the target path or its ancestor directories).

### Config Schema

```json
{
  "severity_overrides": {
    "long_method_loc": 50,
    "large_class_loc": 500,
    "deep_nesting_max": 4,
    "max_constructor_deps": 6
  },
  "skip_categories": ["codeprobe-testing"],
  "skip_rules": ["SPEC-GEN-001"],
  "framework": "laravel",
  "extra_references": [],
  "report_format": "markdown",
  "verify": true
}
```

### Config Behavior

- **If absent**: All defaults apply. No error.
- **`severity_overrides`**: Pass to sub-skills so they adjust thresholds accordingly.
- **`skip_categories`**: Do not invoke the listed sub-skills, even in `audit` or `quick` mode.
- **`skip_rules`**: Pass to sub-skills so they suppress findings with matching IDs.
- **`framework`**: If set, skip auto-detection for that framework and force-load the corresponding reference. Other auto-detection still proceeds.
- **`extra_references`**: Additional reference file paths to load and pass to sub-skills.
- **`report_format`**: Output format preference (default: `markdown`).
- **`verify`**: Default `true`. When `false`, skip the verification pass (Section 4B) entirely and omit the "Rejected by verification" dashboard line and report section.

---

## 4. Sub-Skill Execution

### Context Preparation (runs once before any sub-skill)

Before invoking any sub-skill, the orchestrator prepares the shared context. The orchestrator does NOT read source file contents itself — each sub-agent reads the files its domain needs. This keeps the orchestrator's context lean and avoids duplicating the codebase into every agent prompt.

1. **Read the shared preamble** from `shared-preamble.md` (in this skill's directory). This contains the output contract, execution modes, and constraints shared by all sub-skills.

2. **Build a file manifest** for the target path:
   - Preferred: run `python3 scripts/file_stats.py <target_path>` once (resolve the script path relative to this SKILL.md) and derive the manifest from its per-file output.
   - Fallback (Python 3 unavailable): use Glob for source files (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.php`, `.vue`, `.sql`, `.css`, `.scss` and config files like `next.config.*`, `package.json`, `composer.json`, `requirements.txt`, `.env.example`) and get line counts via `wc -l`.
   - **Exclusions (both paths):** skip `node_modules`, `vendor`, `.git`, `__pycache__`, `.next`, `dist`, `build`, `.venv`, `venv`, `env`, and `codeprobe-reports/` — matching the SKIP_DIRS in the bundled scripts.
   - The manifest is a listing of `{filepath} ({LOC} lines)`, one per line, plus the detected stacks.

3. **Collect reference file paths** (already resolved during stack detection in Section 2). Paths only, not content.

4. **Resolve each sub-skill's SKILL.md path.** Sub-skills live in sibling directories: resolve `../codeprobe-{name}/SKILL.md` relative to this SKILL.md's location and record the **absolute** path. Do not read the sub-skill files yourself and do not inline their content: each sub-agent reads its own file (Invocation Protocol step 2). Passing the path inside the `=== SUB-SKILL: … ===` marker block is mandatory in every mode, including `scan`/`quick` — never rely on the sub-agent resolving the sub-skill by name, because the agent may not have the skill registered.

**Bash discipline.** Every Bash invocation is exactly one command: one `python3 …`, one `mkdir -p …`, one `wc -l …`, one `date …`. Never chain commands with `&&`, `;`, or pipes into loops, never set shell variables, and never use Bash to read files (`cat`, `head`, `for … cat`) — use the Read tool. Restricted environments grant Bash patterns one command at a time, so a chained command is denied as a whole, and a denial must never change what the sub-agents receive.

### Invocation Protocol

For each sub-skill to run, spawn an Agent with a prompt that includes:

1. **The shared preamble path** — the absolute path of `shared-preamble.md`, with: "Read this file first with the Read tool. It is your output contract, execution modes, and READ-ONLY constraint." Also copy the preamble's READ-ONLY CONSTRAINT sentence into the prompt verbatim, so the constraint holds even before the Read.
2. **The sub-skill marker block**, naming the sub-skill and the absolute path of its SKILL.md:
   ```
   === SUB-SKILL: codeprobe-{name} ===
   Read the file at {absolute path of ../codeprobe-{name}/SKILL.md} with the Read tool before doing anything else. It is the sub-skill you are executing: its detection tables are the product, and every rule in it applies. Ignore its Standalone Mode section — the orchestrator has already provided everything it would load. If the Read fails, stop and reply with exactly `SUB-SKILL UNREADABLE: {path}` and nothing else.
   === END SUB-SKILL ===
   ```
   Never summarize, condense, or paraphrase a sub-skill into the prompt in place of the path — a paraphrase silently drops rules. If an agent replies `SUB-SKILL UNREADABLE`, read that one file yourself and re-spawn that agent once with the file content inlined verbatim (frontmatter stripped) between the same markers; this is the only case in which content is inlined.
3. **The mode** — one of `full` or `scan`.
4. **The file manifest** — paths + line counts + detected stacks. Instruct the agent: "Use Read/Grep/Glob to inspect the files relevant to your detection tables. Do not read every file blindly — target what your domain needs."
5. **Reference file paths** — absolute paths of applicable reference guides, with: "Read the reference(s) relevant to your findings before finalizing severity and fix prompts."
6. **Config overrides** — severity overrides and skip rules from `.codeprobe-config.json`.
7. **Target path** — so the sub-skill knows the project root for any targeted lookups.
8. **Sub-skill-specific pre-computed script output (when applicable)**:
   - For `codeprobe-architecture`: before spawning the agent, run `python3 scripts/dependency_mapper.py <target_path>` via Bash and capture the JSON output. Pass it as an additional context block labeled `=== DEPENDENCY_GRAPH === ... === END DEPENDENCY_GRAPH ===`. The sub-skill uses this as the ground truth for cycle detection. If Python 3 is unavailable or the script fails, omit the block — the sub-skill falls back to LLM-based import tracing.
   - For `codeprobe-performance`: if `scripts/complexity_scorer.py` output is available (optional), pass it as `=== COMPLEXITY_SCORES === ... === END COMPLEXITY_SCORES ===`.
9. **Bash discipline**, one line: "Every Bash call is exactly one command — never `&&`, `;`, loops, or shell variables; use Read to read files."

The sub-skill's own SKILL.md contains only its domain-specific detection logic. All other shared context (output format, modes, file manifest, reference paths, pre-computed script data) comes from the orchestrator's prompt; the sub-agent reads source files itself.

**Collect findings** returned by each sub-skill in the standard output contract format (Section 5).

### Execution Modes

| Mode | Used By | Behavior |
|------|---------|----------|
| `full` | `/codeprobe audit`, `/codeprobe diff`, `/codeprobe solid`, etc. | Run complete analysis, return all findings |
| `scan` | `/codeprobe quick` | Run the same complete analysis, but return only severity counts per category + the top 5 candidate findings with ALL output-contract fields (the analysis cost is the same either way — scan mode trims the *output*, so the orchestrator can rank candidates across categories without a second pass) |

### Execution Order

- **Parallelism:** Sub-skill agents are independent — deduplication and scoring happen only after all of them return. Spawn ALL applicable sub-skill agents **in a single message (parallel)**; do not run them one at a time. The fixed category order below is for report presentation only, not execution. (Exception: Claude.ai degraded mode, Section 9, runs sequentially because no sub-agents are available.)
- **Before spawning:** pre-compute the dependency graph via `scripts/dependency_mapper.py` (for `codeprobe-architecture`, Invocation Protocol step 8) and run `scripts/file_stats.py` for the manifest and codebase stats (skip gracefully if Python 3 unavailable).
- **`/codeprobe audit`**: Spawn all 9 sub-skills in `full` mode. Presentation order: `codeprobe-security`, `codeprobe-error-handling`, `codeprobe-solid`, `codeprobe-architecture`, `codeprobe-patterns`, `codeprobe-performance`, `codeprobe-code-smells`, `codeprobe-testing`, `codeprobe-framework`. Collect all findings. Run the verification pass (Section 4B). Apply deduplication (Section 7A). Derive category scores from severity counts. Compute hot spots by aggregating findings per file and ranking by distinct-categories-flagged.
- **`/codeprobe quick`**: Spawn all 9 sub-skills in `scan` mode (parallel). Collect each sub-skill's top-5 candidates (already carrying full output-contract detail). Rank all candidates by severity (critical > major > minor > suggestion), breaking ties by category weight (Section 7). Send the provisional top 8 through the verification pass (Section 4B), then render the top 5 survivors. This is a single pass — no re-runs.

### Available Sub-Skills

1. `codeprobe-security` — Security vulnerability detection
2. `codeprobe-error-handling` — Error handling & resilience
3. `codeprobe-solid` — SOLID principles analysis
4. `codeprobe-architecture` — Architecture analysis
5. `codeprobe-patterns` — Design patterns advisor
6. `codeprobe-performance` — Performance & scalability
7. `codeprobe-code-smells` — Code smell detection
8. `codeprobe-testing` — Test quality & coverage
9. `codeprobe-framework` — Framework-specific best practices

---

## 4A. Diff Review (`/codeprobe diff [base]`)

PR-style review: analyze only what changed relative to a base branch, so review effort concentrates on the code someone is about to merge.

### Preconditions

- Requires a git repository: check with `git rev-parse --is-inside-work-tree`. If not in one, tell the user diff review needs git and suggest `/codeprobe audit` instead.
- Git usage is strictly read-only (see the READ-ONLY CONSTRAINT above).

### Base Resolution

1. If the user passed a base ref, use it (verify with `git rev-parse --verify <base>`).
2. Otherwise try `main`, then `master`.
3. If none resolve, ask the user which base to compare against.

### Changed-File Collection

1. Compute the merge base: run `git merge-base <base> HEAD` as its own Bash call and substitute the printed SHA (written `<MB>` below) into the later commands — no shell variables (Bash discipline, Section 4). Comparing against the merge base — not the base tip — reviews only this branch's changes, matching what a PR diff shows even when the base has moved on.
2. Changed files: `git diff --name-status <MB>` (this includes uncommitted working-tree changes, which is intended — review what would ship). Drop deleted files (status `D`).
3. Untracked files: `git ls-files --others --exclude-standard`.
4. Filter both lists to the source/config extensions used for the manifest (Section 4) and apply the same directory exclusions.
5. Changed line ranges per file: parse the `@@` hunk headers (new-file side) from `git diff -U0 <MB> -- <file>`. Untracked files count as fully changed.
6. If the resulting list is empty, report "No reviewable changes vs `<base>`" and stop — do not fall back to a full audit unasked.

### Execution

Run the standard flow (Sections 2-4) with these adjustments:

- The file manifest contains ONLY the changed/untracked files, each annotated with its changed line ranges.
- Spawn all 9 sub-skills in parallel, `full` mode. Add to each agent prompt: "This is a diff review. Anchor every finding in one of the manifest files, prioritizing the annotated changed lines. You may Read surrounding or related files for context, but do not report findings in unchanged files."
- The dependency graph (`dependency_mapper.py`) still runs project-wide — a changed import can create a cycle through unchanged files.
- Deduplication (Section 7A) and scoring (Section 7) apply as usual, computed over the diff findings only. Skip the hot-spots computation and codebase stats — they describe whole-codebase health, not a diff.

### Rendering

See Section 8 (`/codeprobe diff` subsection) — diff output uses `templates/pr-review-comment.md`. The verification pass (Section 4B) runs on the diff findings before deduplication; the rejected count fills the summary table's "Rejected by verification" row.

---

## 4B. Verification Pass

After every sub-skill agent has returned — and before deduplication (Section 7A) — re-check every Critical and Major finding with an independent verifier agent. The verifier's job is adversarial: find the reason the finding is wrong, not restate it. The whole section is skipped when `.codeprobe-config.json` sets `"verify": false`.

### When it runs

- `/codeprobe audit`, `/codeprobe diff`, and every single-category command (`security`, `solid`, …): once all sub-skill agents have returned.
- `/codeprobe quick`: after ranking the pooled scan-mode candidates (Section 4, Execution Order). Only the **Critical and Major findings among the provisional top 8** are verified; Minor and Suggestion candidates in the top 8 pass through as survivors. If none of the top 8 is Critical or Major, spawn nothing.

### What is verified

- Every finding whose `severity` is `critical` or `major`. `minor` and `suggestion` findings pass through untouched; they are never sent to a verifier.
- If there are zero Critical or Major findings, spawn nothing and set `rejected_count = 0`.

### Fan-out

- One verifier agent per category that has at least one Critical or Major finding. Spawn all verifiers **in a single message (parallel)**, never one at a time. Maximum 9.
- `/codeprobe quick` spawns exactly **one** verifier, for the Critical/Major findings among the provisional top 8, across all categories.

### Verifier prompt composition

Each verifier prompt contains, in this order:

1. The **READ-ONLY CONSTRAINT** block from `shared-preamble.md`.
2. The **verification rubric** by path, between markers:
   ```
   === VERIFICATION RUBRIC ===
   Read the file at {absolute path of verification-rubric.md, resolved relative to this SKILL.md} with the Read tool before doing anything else. It defines your role, procedure, hard limits, and output shape. If the Read fails, stop and reply with exactly `RUBRIC UNREADABLE: {path}` and nothing else.
   === END VERIFICATION RUBRIC ===
   ```
   Do not inline the rubric. If a verifier replies `RUBRIC UNREADABLE`, read the file yourself and re-spawn that verifier once with the content inlined verbatim between the same markers.
3. The **findings to verify** — the category's Critical/Major findings (for `quick`, the Critical/Major findings among the top 8, which may span categories) with every output-contract field from Section 5.
4. The **file manifest** (Section 4, Context Preparation step 2).
5. The **reference guide paths** (paths only).
6. The **target path**.
7. One line of **Bash discipline**: "Every Bash call is exactly one command — never `&&`, `;`, loops, or shell variables; use Read to read files." (The same sentence goes into every sub-skill agent prompt, Invocation Protocol step 9.)

Absolute paths for the rubric, preamble, and sub-skill files come from this SKILL.md's own location (the skill base directory); never run `realpath`, `pwd`, or `cd` to derive them.

Do **not** include the sub-skill's SKILL.md, its detection tables, or the shared preamble beyond the READ-ONLY block. A verifier that sees the detection pattern will re-run the pattern instead of tracing the claim.

### Handling verdicts

The verifier returns the shape defined in `verification-rubric.md` (`findings[]` with `verification` and `verification_note`, plus a `summary`). Apply each verdict:

| `verification` | Orchestrator action |
|---|---|
| `confirmed` | Keep the finding unchanged. |
| `downgraded` | Keep the `id`; record the original severity as `old_severity`, then set `severity` to the echoed value (it must be exactly one bucket below the original — if it is not, treat the verdict as `confirmed`); store `verification_note` on the finding. Append `{id, location, old_severity, severity, verification_note}` to `downgraded[]`. |
| `rejected` | Remove the finding before Section 7A and before scoring. Append `{id, location, verification_note}` to `rejected[]`. |

Then set `rejected_count = len(rejected[])` and `downgraded_count = len(downgraded[])`. Ignore any returned entry whose `id` was not in the input, any verdict that raises severity, and any new finding — verifiers cannot add or escalate. An input finding that receives no verdict passes through unverified and unchanged.

### Failure handling

If a verifier agent errors, times out, or returns output that cannot be mapped onto the rubric's shape, every finding of that category passes through **unverified and unchanged**, and `unverified_categories` is incremented by one. Verification never blocks or delays the report; a missing verifier result is reported on the dashboard line (Section 8), not retried. The one exception is the `RUBRIC UNREADABLE` reply, which gets the single inlined re-spawn described under Verifier prompt composition; if that re-spawn also fails, this rule applies. For `/codeprobe quick`, whose single verifier spans categories, a failure sets `unverified_categories` to the number of categories represented in its input.

### Reporting rule (all surfaces)

Every surface that shows a verification count renders exactly `**Rejected by verification:** {rejected_count}` (the PR comment uses its table row instead). Append ` ({n} categories unverified)` when `unverified_categories` > 0, using `category` when n is 1. Omit the line, the row, and the Rejected/Downgraded sections entirely when config `verify` is `false`. Placement differs by surface on purpose — last dashboard line in the terminal, after "Duplicates removed" in the saved file's Score Breakdown — and each template fixes its own position.

### `/codeprobe quick` rendering rule

After the single verifier returns: drop `rejected` candidates, apply downgrades, re-rank the survivors (severity, then category weight), and render the top 5. If fewer than 5 survived, render those that did and add the line `Fewer than 5 findings survived verification.` directly under the table. Candidates ranked 9 or lower are never verified and never rendered.

---

## 5. Output Contract

Every finding from every sub-skill MUST include every field marked `Yes`. The two verification fields are set only by the orchestrator's verifiers (Section 4B), never by sub-skills:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier in format `{PREFIX}-{NNN}` (e.g., `SRP-001`, `SEC-003`) |
| `severity` | Yes | One of: `critical`, `major`, `minor`, `suggestion` |
| `severity_rationale` | Yes | One sentence explaining why this severity bucket and not the one below. |
| `location` | Yes | File path + line range (e.g., `src/UserService.php:45-67`) |
| `problem` | Yes | One sentence describing the issue |
| `evidence` | Yes | Concrete proof from the code — quote the relevant lines |
| `suggestion` | Yes | What to do to fix it |
| `fix_prompt` | Yes | A copy-pasteable prompt the user can give to Claude Code to apply the fix |
| `refactored_sketch` | No | Optional code snippet showing the improved version |
| `verification` | Orchestrator only | One of: `confirmed`, `downgraded`, `rejected`. Set only by the orchestrator's verifiers on Critical/Major findings; sub-skills never set it. |
| `verification_note` | If downgraded/rejected | One sentence: for `downgraded`, which part of the severity rationale's boundary claim is false; for `rejected`, the reason, quoting the mitigating code. Empty for `confirmed`. |

### Finding Format Example

```
### SRP-001 | Major | `src/UserService.php:45-67`

**Problem:** UserService violates Single Responsibility — handles authentication, email sending, and database queries in one class.

**Severity rationale:** Major (not Minor) because three unrelated responsibilities are concentrated in one class on a critical auth path — refactoring will touch every caller; not Critical because the code works correctly today, this is a maintainability risk, not a production defect.

**Evidence:**
> Lines 45-50: `public function authenticate($credentials) { ... }`
> Lines 52-60: `public function sendWelcomeEmail($user) { ... }`
> Lines 62-67: `public function findByUsername($name) { ... }`

**Suggestion:** Extract email logic into a dedicated `UserMailer` service and database queries into a `UserRepository`.

**Fix prompt:**
> Refactor `src/UserService.php` to follow Single Responsibility Principle: extract `sendWelcomeEmail()` into a new `UserMailer` class and `findByUsername()` into a `UserRepository` class. Keep `authenticate()` in `UserService` and inject the new dependencies.
```

---

## 6. Severity Levels

| Level | Priority | Meaning | Examples |
|-------|----------|---------|----------|
| Critical | P0 | **Confirmed bugs, exploitable security vulnerabilities, or data loss/corruption risks** that would cause harm in production | SQL injection with user input, missing auth on data-mutating endpoint, race condition causing data corruption, unhandled crash on a core path, missing DB transaction on multi-step writes |
| Major | P1 | Significant maintainability, reliability, or scalability problem that increases risk but is not an immediate production defect | Missing tests for critical business logic, large classes, code duplication, missing error handling on external calls, N+1 queries, missing input validation |
| Minor | P2 | Code smell, low risk, worth addressing for long-term health | Magic numbers, deep nesting, poor naming, missing edge case tests, verbose error details |
| Suggestion | P3 | Improvement idea, nice to have, no real risk if ignored | Pattern opportunities, style improvements, speculative generality |

### Severity Guardrails

**The following are NEVER Critical — classify as Major at most:**
- Missing tests (even for critical business logic)
- Code duplication or large classes/files
- Code smells of any kind
- Framework convention violations
- Missing documentation, comments, or type annotations

**Critical is reserved exclusively for:**
- Confirmed bugs (code that produces wrong results or crashes)
- Exploitable security vulnerabilities (injection, auth bypass, IDOR with proof)
- Data loss or corruption risks (missing transactions, race conditions on writes)
- Sensitive data exposure (secrets in code, credentials in logs)

**Sub-skills: do NOT escalate findings beyond the severity specified in your detection table.** If your table says "Major," report it as Major even if the specific instance seems severe. The orchestrator's scoring formula accounts for finding counts at each level.

---

## 7. Scoring

After collecting all findings, compute scores per category and an overall score.

### Category Score Formula

Each penalty component is capped to prevent a single severity level from dominating the score:

```
crit_penalty  = min(50, critical_count * 15)
major_penalty = min(30, major_count * 6)
minor_penalty = min(10, minor_count * 2)

category_score = max(0, 100 - crit_penalty - major_penalty - minor_penalty)
```

Suggestions do not affect the score.

**Rationale:** Diminishing returns prevent a single severity from flooring the score. A category with 4 criticals scores 50 (not 0), reflecting problems exist but the code is not completely broken. The maximum total penalty from all three levels combined is 90, so a score of 0 requires extreme findings across all severities.

### Category Weights

| Category | Weight |
|----------|--------|
| Security | 20% |
| SOLID | 15% |
| Architecture | 15% |
| Error Handling | 12% |
| Performance | 12% |
| Test Quality | 10% |
| Code Smells | 8% |
| Design Patterns | 4% |
| Framework | 4% |

All 9 categories are active. Weights sum to 100%.

### Overall Score

```
overall = sum(category_score_i * weight_i for each active category)
```

If `skip_categories` in `.codeprobe-config.json` excludes some categories, normalize by dividing by the sum of active weights:

```
overall = sum(category_score_i * weight_i for each active category) / sum(weight_i for each active category)
```

Clamp the result to the range [0, 100].

### Score Interpretation

| Range | Status |
|-------|--------|
| 80-100 | Healthy |
| 60-79 | Needs Attention |
| 0-59 | Critical |

---

## 7A. Cross-Category Deduplication

Before computing scores — and after the verification pass (Section 4B) has removed rejected findings and applied downgrades — deduplicate findings that flag the same issue from multiple categories.

### Deduplication Procedure

1. **Group findings by location.** Normalize each finding's `location` to `{file}:{start_line}`. Two findings overlap if they share the same file AND their line ranges overlap (i.e., start_line_A <= end_line_B AND start_line_B <= end_line_A).

2. **Check for genuine disagreement first.** Dedup is for "same issue, different lens" — NOT for opposing recommendations. If two overlapping findings pull in opposite directions (e.g., SOLID recommends extracting an abstraction while Performance flags that abstraction as overhead; Architecture recommends decoupling while Performance recommends locality), do NOT deduplicate them. Keep both findings at full severity and route the pair to the report's **Conflicting Recommendations** section with a one-line note naming the tradeoff. The operator must see the tension and decide — silently picking a winner hides exactly the call that needs human judgment.

3. **For each remaining group of overlapping findings from different categories:**
   a. **Select a primary finding.** Use this priority order:
      - Security findings (SEC) take priority for anything involving auth, injection, or data exposure
      - Error Handling findings (ERR) take priority for exception/validation issues
      - Performance findings (PERF) take priority for query/caching issues
      - SOLID findings (SRP/OCP/LSP/ISP/DIP) take priority for structural violations
      - Architecture findings (ARCH) take priority for layer/boundary violations
      - If still ambiguous, the category with the higher weight (Section 7) wins
   b. **Drop the duplicates.** Remove each non-primary finding in the group from the findings list entirely — it appears in neither the report body nor its category's severity counts. (Demoting duplicates to `suggestion`, as earlier versions did, just inflated suggestion counts with noise.)
   c. **Cross-reference the primary.** Append to the primary finding's `suggestion` field: `Also flagged by: {list of duplicate category:id pairs}` — this preserves the multi-category signal (it also feeds hot-spot ranking) without duplicate entries.
   d. **Count the drops.** Track the total number of dropped duplicates and report it in the dashboard's "Duplicates removed" line.

4. **Recount severity totals per category** after deduplication, then proceed to scoring.

### Examples

- "Refresh bypasses quota" found as SEC-007, ERR-011, FW-001 at same location: keep SEC-007 (cross-ref "Also flagged by: ERR-011, FW-001"), drop ERR-011 and FW-001.
- "God component" found as SRP-001, SMELL-001, ARCH-005 at same file: keep SRP-001 (SOLID priority for structural), drop the others.
- SRP-002 says "extract `PricingCalculator` from `OrderService`" while PERF-004 at the same lines says "this hot path should stay inlined — the indirection costs allocations per request": genuine conflict — keep both, render under Conflicting Recommendations.

---

## 8. Report Rendering

Render the final output based on the command used.

### `/codeprobe audit` — Full Audit Report

Use the template at `templates/full-audit-report.md` (loaded via Read) to assemble the markdown for the saved report file. The terminal output is a summary — **the user MUST see a visual summary in the terminal, not only the "Report saved" line**.

**Terminal vs saved-file split (MANDATORY):**

| Surface | What it shows | How it's produced |
|---------|---------------|-------------------|
| **Terminal** | Dashboard + executive summary + critical findings (full detail) + prioritized fix order (top 5) + "Report saved" line | Streamed markdown sections in the assistant response |
| **Saved file** (`./codeprobe-reports/<project>-<cmd>-<ts>.md`) | Everything: dashboard, exec summary, all critical/major findings, minor/suggestion counts, full prioritized fix order, Downgraded/Rejected by Verification sections | Plain markdown written via `Write` tool |

The terminal must never be empty or reduced to just a save confirmation. If Claude only emitted the save line in a past run, that was a bug in how these instructions were followed — fix it by executing the flow below in order.

#### Step-by-step flow

**A. Compute data** (shared by both surfaces)
  1. Run sub-skills per Section 4, collect findings, verify Critical/Major findings per Section 4B, deduplicate per Section 7A.
  2. Derive category scores, overall score, hot spots, codebase stats.
  3. Assemble an in-memory "report bundle": `{dashboard_data, exec_summary, critical[], major[], minor_counts[], suggestion_counts[], fix_order[], rejected[], rejected_count, downgraded[], downgraded_count, unverified_categories}`.

**B. Render to terminal** (user-facing — emit these **directly as markdown in the assistant response**, in order)

  Do NOT pipe the dashboard through the Bash tool. The Bash tool collapses its output by default in Claude Code's UI (`+N lines (ctrl+r to expand)`), which hides the dashboard behind a fold. Emit the dashboard as ordinary assistant-response markdown so the user sees it immediately. Modern terminals (Ghostty, iTerm2, etc.) will apply their own markdown styling — bold, inline-code highlighting, emphasis — which is the only coloring available on this path. If no coloring shows, plain text is fine; do not try to force ANSI escapes into the response.

  (`scripts/render_dashboard.py` exists for users running the audit directly from their own shell outside Claude Code, where its stdout is a real TTY. Do NOT invoke it from within the `/codeprobe audit` flow.)

  1. **Dashboard (markdown)** — emit the dashboard block inline. Include: title line (`## Code Health Report — {project}`), `**Overall Health:** {score}/100 [{status_label}]`, the 9-row **Category Scores markdown table** with columns `Category | Score | Bar | Status` (bar wrapped in backticks, 20-char Unicode `█`/`░` proportional to score), codebase stats block (files, LOC, backend/frontend split, largest file, test ratio, comment ratio), a hot-spots list (up to 3 entries), and — last, on its own line — `**Rejected by verification:** {rejected_count}` (append ` ({n} categories unverified)` when `unverified_categories` > 0, using `category` when n is 1; omit the whole line only when config `verify` is `false`). Status labels plain text in the Status column, no emoji, no brackets inside the table.
  2. **Executive Summary** — 2-3 sentences covering the most important findings.
  3. **Critical findings — full detail** — for each critical finding: ID, location, problem, severity rationale, evidence, suggestion, fix prompt. (A finding that is still Critical was never downgraded, so no `**Verification:**` line appears here; downgrades are listed in the saved file's "Downgraded by Verification" table.) This is the highest-signal section; always show in the terminal.
  4. **Prioritized Fix Order (top 5)** — the first 5 entries from the full prioritized fix order. Reference the saved file for the complete list.
  5. **Save confirmation line** — `--> Report saved to ./codeprobe-reports/{project}-{cmd}-{YYYY-MM-DD-HHMMSS}.md` (no emoji; ASCII arrow). This is the LAST line in the terminal output.

  Do NOT also stream the major-findings table, minor/suggestion counts, or the full fix order to the terminal — those would duplicate content that the saved file already carries and bloat the terminal output. The user can open the saved file for the complete picture.

**C. Write saved-file markdown**

  1. Build the full markdown using `templates/full-audit-report.md` placeholders — this includes sections that are NOT streamed to the terminal (major findings table, minor/suggestion counts, full prioritized fix order, the "Downgraded by Verification" table — omitted when `downgraded_count` is 0 — and the collapsed "Rejected by Verification" section — omitted when `rejected_count` is 0).
  2. Derive the filename as `{project}-{cmd}-{YYYY-MM-DD-HHMMSS}.md`:
     - `{project}` — resolve the target path to an absolute path (use the current working directory if the user passed no path); take its basename; if that basename points to a file, strip the extension; slugify it (lowercase; replace any run of `[^a-z0-9]+` with a single `-`; trim leading/trailing `-`); fall back to `unknown` if the slug ends up empty.
     - `{cmd}` — the subcommand routed in Section 1 (`audit`, `quick`, `diff`, `security`, `solid`, `architecture`, `performance`, `errors`, `tests`, `smells`, `patterns`, `framework`), lowercased.
     - `{YYYY-MM-DD-HHMMSS}` — current local time, obtained with one Bash call: `date +%Y-%m-%d-%H%M%S`. If Bash is unavailable or denied, use the most recent timestamp visible in any tool output, else `0000-00-00-000000`; never leave the placeholder unfilled.
  3. Ensure `./codeprobe-reports/` exists (`mkdir -p ./codeprobe-reports` via Bash if missing).
  4. Write to `./codeprobe-reports/{project}-{cmd}-{YYYY-MM-DD-HHMMSS}.md` using the `Write` tool.
  5. If the write fails (read-only filesystem, permission denied, etc.), surface a short inline note in the terminal but do not re-emit the summary.

**D. Terminal-output contract (hard requirements)**

- The terminal MUST include (in this order): dashboard → exec summary → critical findings → top 5 fix order → "Report saved" line.
- When config `verify` is on (the default), the dashboard MUST end with the `**Rejected by verification:**` line — `0` is a valid count.
- If there are zero critical findings, show the dashboard, exec summary, a one-line "No critical issues found" note, top 5 fix order (will be major-only), and save confirmation — still non-empty.
- If the report save fails, still emit the full terminal summary — do not block the summary on the file write.
- If the template file is missing, render inline following the same section ordering; the save step (C) still applies.

Status thresholds (applied to overall health and each category score):
- 80-100 = "Healthy"
- 60-79 = "Needs Attention"
- 0-59 = "Critical"

**Token budget guidance:** For a codebase with ~100 findings, the tiered findings layout (major as table, minor/suggestion as counts only — all in the saved file) targets ~8,000-12,000 tokens on disk (vs ~40,000 with full detail for all findings). The terminal summary is much tighter because only the dashboard, exec summary, critical findings, and top 5 fix order are streamed there. The user can drill into specific categories with `/codeprobe security .` etc. for full detail on any one category.

### `/codeprobe quick` — Quick Review Summary

Use the template at `templates/quick-review-summary.md` (loaded via Read). Before rendering, run the single-verifier pass described in Section 4B (`/codeprobe quick` rendering rule) on the provisional top 8; the table shows the top 5 survivors, with the one-line note when fewer than 5 survived. If the template does not exist yet, render inline:

1. **Header**: Project name, "Quick Review — Top 5 Issues".
2. **Top 5 Findings**: Full detail for the 5 most impactful issues, each with fix prompt.
3. **Summary Counts**: Total issues found by severity across all categories, then `**Estimated Score:**`, then `**Rejected by verification:** {rejected_count}` (Section 4B reporting rule).
4. **Next Step**: Suggest running `/codeprobe audit` for the complete picture.

### `/codeprobe diff` — PR-Style Review

Use the template at `templates/pr-review-comment.md` (loaded via Read). Fill `{branch}` with the current branch (`git rev-parse --abbrev-ref HEAD`), `{base_branch}` with the resolved base, `{changed_files}` with the reviewed-file count, and `{overall_score}` with the standard formula (Section 7) applied to the diff findings. Fill `{version}` from this file's frontmatter `metadata.version`.

- **Terminal**: emit the filled template directly as assistant-response markdown (it is compact enough to stream whole), then the save-confirmation line (same format as Section 8B step 5).
- **Saved file**: the same markdown, written to `./codeprobe-reports/{project}-diff-{YYYY-MM-DD-HHMMSS}.md` following the Section 8C filename and write rules.
- The rendered markdown is deliberately paste-ready as a GitHub PR comment — keep it self-contained (no references to "the saved file" inside the body).
- Verification (Section 4B) applies to the diff findings; `{rejected_count}` fills the "Rejected by verification" row of the summary table.

### `/codeprobe <category>` — Single-Category Report

Used by `security`, `solid`, `architecture`, `performance`, `errors`, `tests`, `smells`, `patterns`, and `framework`. One sub-skill runs in `full` mode, then one verifier (Section 4B). A single category is bounded, and full detail is the reason users drill into one category — do not collapse Minor or Suggestion findings into counts here.

**Terminal** (emit directly as assistant-response markdown, in this order):

1. **Header**: `## {Category} Review — {project}` and one line of counts: `{n} critical · {n} major · {n} minor · {n} suggestions`.
2. **Every finding, full detail**, grouped under `### Critical Issues`, `### Major Issues`, `### Minor Issues`, `### Suggestions` (omit empty groups), each rendered in the Rendered Finding Format from `shared-preamble.md` — including the `**Severity rationale:**` line and, when the finding was downgraded, the `**Verification:**` line.
3. `**Rejected by verification:** {rejected_count}` per the Section 4B reporting rule.
4. **Save confirmation line** — same format as Section 8B step 5.

**Saved file**: the same markdown, plus the collapsed "Rejected by Verification" section (`<details>` with an `ID | Location | Reason` table; omit when `rejected_count` is 0), written to `./codeprobe-reports/{project}-{cmd}-{YYYY-MM-DD-HHMMSS}.md` following the Section 8C filename and write rules.

## 9. Claude.ai Degraded Mode

Detect whether filesystem access is available. If the user has pasted or uploaded code rather than providing a file path, or if Read/Glob/Grep tools are unavailable:

1. **Switch to degraded mode**: Analyze only the in-context code provided.
2. **Execute sub-skills sequentially** on the pasted code (no parallel agents).
3. **Skip** `file_stats.py`, `dependency_mapper.py`, and all script-dependent steps (sub-skills fall back to LLM-only analysis — architecture loses deterministic cycle detection).
4. **Skip** `/codeprobe diff`, the Codebase Stats row of the audit dashboard, and the report-save step (no filesystem write). Still render scores, hot spots, and findings to the terminal.
5. **Inform the user**: "Running in Claude.ai mode — some features like codebase statistics, diff review, and multi-file analysis are unavailable. Analyzing the provided code directly."
6. Still produce findings in the standard output contract format.
7. Still compute scores based on findings from available sub-skills.

---

## 10. Execution Flow Summary

When `/codeprobe` is invoked, execute this sequence:

1. **Parse command**: Extract subcommand and target path from user input.
2. **Validate command**: Check the routing table. If the subcommand is unknown, say so and list the available commands.
3. **Resolve target path**: Use provided path or default to current working directory. For `diff`: resolve the base ref and collect changed files + line ranges per Section 4A instead — the manifest is restricted to those files.
4. **Load config**: Check for `.codeprobe-config.json` at project root. Apply defaults if absent.
5. **Auto-detect stack**: Scan target path for technology signals. Load matching references.
6. **Apply config overrides**: If `framework` is set in config, adjust detection. Apply `skip_categories` and `skip_rules`.
7. **Execute sub-skills**: Prepare shared context (Section 4), then spawn all applicable sub-skill agents in parallel with the appropriate mode.
8. **Collect findings**: Aggregate all findings in the output contract format.
8a. **Verify findings**: run Section 4B on Critical/Major findings (one verifier per category, spawned in parallel; `quick` verifies the Critical/Major findings among its provisional top 8 with one verifier); drop rejected findings, apply downgrades, record `rejected_count`, `downgraded_count` and `unverified_categories`. Skipped when config `verify` is `false`.
9. **Deduplicate findings**: Apply the cross-category deduplication procedure (Section 7A) — route genuine conflicts to the Conflicting Recommendations section, drop true duplicates, recount severity totals per category.
10. **Compute scores**: Calculate per-category and overall scores using the post-deduplication severity counts and the formulas in Section 7.
11. **Render report**: Format output using the appropriate template or inline format. Use the tiered output format for `/codeprobe audit`.
12. **Present to user**: Display the final report.

**Remember: This entire process is READ-ONLY. At no point do we modify any user files.**
