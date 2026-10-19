# codeprobe v2.3.0 — Evals, Plugin Manifest, Verification Pass: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make codeprobe's regression evals runnable under `claude plugin eval`, package the repo as a Claude Code plugin, and add a verification pass that re-checks every Critical/Major finding before it is reported — shipped as v2.3.0.

**Architecture:** The repo stays a skills directory (`skills/<name>/SKILL.md`) and gains a one-file plugin manifest. Evals move from `evals/evals.json` to one directory per case (`prompt.md` + `case.yaml` + `scaffold.sh` + `graders/*.md`) that copy the shared `evals/fixture/` into the runner's sandbox. The verification pass is a new orchestrator section that spawns one verifier agent per category after the sub-skills return and before dedup; verifiers follow a rubric file inlined into their prompt the same way `shared-preamble.md` is today. All "code" here is Markdown prompts plus a bash fixture script, a Python bait file, and a CI workflow; the evals are the tests.

**Tech Stack:** Claude Code ≥ 2.1.269 (`claude plugin eval`, `claude plugin validate`), Bash, Python 3 (fixture only), GitHub Actions, `jq`.

**Spec:** `docs/superpowers/specs/2026-10-19-evals-and-verification-design.md`

## Global Constraints

- READ-ONLY: no sub-skill, verifier, script, or eval may modify files in the audited tree; the only permitted write is `./codeprobe-reports/<project>-<cmd>-<timestamp>.md` (spec §3).
- No new hard runtime dependency. Python 3.8+ remains optional (spec §2 anti-goals).
- Do not add Claude Code-only frontmatter fields to any `SKILL.md` beyond the ones already present (`user-invocable`, `argument-hint`) (spec §3).
- Repo layout unchanged: `skills/` at root; `npx skills add nishilbhave/codeprobe` must keep installing ten skills (spec §5).
- `plugin.json.version` is canonical; `skills/codeprobe/SKILL.md` `metadata.version` must match; CI checks it (spec §4.1).
- Eval sandbox: empty workspace per run; fixture arrives via `scaffold_script` (runs only with `--scaffold`); `Bash`/`Write` granted only via `--allow-tools`; `max_turns` and `timeout_seconds` must be set explicitly (defaults 10 / 300 are far too low) (spec §3).
- Baseline arm not used: every eval run passes `--ablation none` (spec §5).
- Verifier may never raise severity, never add findings, never downgrade more than one bucket (spec §4.4).
- Verification default on; `"verify": false` in `.codeprobe-config.json` disables it (spec §4.4).
- Ship version: `2.3.0` in both `.claude-plugin/plugin.json` and `skills/codeprobe/SKILL.md` frontmatter (spec §4.5).
- Fixture header convention: every fixture file begins with the two-line "codeprobe eval fixture — intentionally flawed code" comment (see `evals/fixture/app.py:1-2`).

## Review Focus

1. **A verifier agent that times out or returns malformed output** — the category's findings must pass through unverified and the dashboard line must say so; the report must still render. Pinned in Task 7 (Step 4 rubric wording) and exercised by the `rejection-line` grader accepting `(N categories unverified)`.
2. **A codebase with zero Critical/Major findings** — no verifier is spawned, the dashboard line reads `Rejected by verification: 0`, and `quick` renders fewer than 5 rows with its one-line note. Pinned in Task 7 Step 4 and Task 8's `quick-top5` `at-most-five` grader.
3. **`verify: false` in config** — no verifier spawned, no dashboard line, no rejected section; report otherwise identical. Pinned in Task 7 Step 4; manual check in Task 10.
4. **A bait that is raised at Minor** — must be tolerated, not scored as a precision failure. Pinned in Task 8 bait graders (scoped to Critical/Major sections only).
5. **Fork pull request** — the CI job must skip, not fail, when secrets are absent. Pinned in Task 9 `if:` guard and a manual dry-check of the expression.

---

## File Structure

| Path | Responsibility | Task |
|---|---|---|
| `.claude-plugin/plugin.json` | plugin manifest, canonical version | 1 |
| `.claude-plugin/marketplace.json` | self-hosted marketplace entry (only if a root source validates) | 1 |
| `scripts/check_version_sync.sh` | exit 1 if manifest and SKILL.md versions differ | 1 |
| `evals/fixture/safe.py` | five baits B1–B5 | 2 |
| `evals/expected-findings.md` | defect map + "Must NOT be reported" table | 2 |
| `evals/_shared/scaffold.sh` | copies `../fixture` into the workspace; each case's `scaffold.sh` is a one-line `exec` of it | 3 |
| `evals/security-only/{prompt.md,case.yaml,scaffold.sh,graders/}` | cheapest case; proves the harness | 3 |
| `evals/quick-top5/…` | quick mode case | 4 |
| `evals/audit-full/…` | full fan-out case; plants, dedup, dashboard graders | 5 |
| `evals/README.md` | how to run locally, grant list, cost note | 5 |
| `skills/codeprobe/verification-rubric.md` | verifier instructions, inlined by orchestrator | 6 |
| `skills/codeprobe/shared-preamble.md` | output contract gains `verification`, `verification_note` | 6 |
| `skills/codeprobe/SKILL.md` | §3 config `verify`; new §4B Verification; §5 fields; §7A/§8 handling; §10 flow | 7 |
| `skills/codeprobe/templates/*.md` | dashboard line, rejected section, downgrade note | 7 |
| `evals/audit-full/graders/bait-*.md`, `rejected-lists-bait.md` | precision graders | 8 |
| `.github/workflows/evals.yml` | CI run, fork guard, plants-survive gate | 9 |
| `README.md`, `docs/superpowers/plans/2026-03-30-token-optimization.md` | docs; version bump | 10 |

---

### Task 1: Plugin manifest and version sync

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json` (conditional, see Step 5)
- Create: `scripts/check_version_sync.sh`

**Interfaces:**
- Produces: `scripts/check_version_sync.sh` — no args, exit 0 when `.claude-plugin/plugin.json` `.version` equals the `version:` under `metadata:` in `skills/codeprobe/SKILL.md`, else exit 1 and print both values. Task 9 calls it.

- [ ] **Step 1: Write `.claude-plugin/plugin.json`** with exactly the object in spec §4.1 but `"version": "2.2.0"` (the bump happens in Task 10). No `skills` or `agents` arrays.

- [ ] **Step 2: Validate**

Run: `claude plugin validate . --strict`
Expected: last line `✔ Validation passed`. If `--strict` warns about an unrecognized manifest field, remove that field (the spec's extra fields are informational).

- [ ] **Step 3: Write `scripts/check_version_sync.sh`** (bash, `set -euo pipefail`). Read the manifest version with `python3 -c` or `jq` if present, else `grep -o`; read SKILL.md's version with `grep -A2 '^metadata:' | grep version`. Must work with only POSIX tools + bash (no hard dep on `jq`).

- [ ] **Step 4: Prove the check works both ways**

Run: `bash scripts/check_version_sync.sh; echo "exit=$?"`
Expected: `exit=0`.
Run: `sed -i '' 's/"2.2.0"/"9.9.9"/' .claude-plugin/plugin.json && bash scripts/check_version_sync.sh; echo "exit=$?"; git checkout .claude-plugin/plugin.json`
Expected: `exit=1` and both versions printed. (`git checkout` fails before the first commit; if so, restore the value with `sed` instead.)

- [ ] **Step 5: Try a root-source marketplace.** Write `.claude-plugin/marketplace.json`:
```json
{ "name": "codeprobe", "owner": { "name": "Nishil" },
  "plugins": [ { "name": "codeprobe", "source": "./", "description": "Senior-engineer code audit, read-only" } ] }
```
Run: `claude plugin validate . --strict && claude plugin marketplace add ./ && claude plugin install codeprobe@codeprobe && claude plugin details codeprobe`
Expected: `Component inventory` lists `Skills (10)`. **If any step rejects the root source**, delete `marketplace.json`, record the exact error in the commit message, and do not restructure the repo (spec §4.1 fallback). Either way, afterwards run `claude plugin marketplace remove codeprobe` so the local machine is left as it was.

- [ ] **Step 6: Commit**
```bash
git add .claude-plugin scripts/check_version_sync.sh
git commit -m "feat: add Claude Code plugin manifest and version sync check"
```

---

### Task 2: Fixture baits

**Files:**
- Create: `evals/fixture/safe.py`
- Modify: `evals/expected-findings.md` (append section after "Structural assertions")

**Interfaces:**
- Produces: five bait locations that Task 8's graders reference by function name: `B1 admin_delete_order`, `B2 list_orders_sorted`, `B3 WAREHOUSE_API_KEY`, `B4 fetch_rates`, `B5 order_totals`.

- [ ] **Step 1: Write `evals/fixture/safe.py`** with the fixture header comment, importing `db` from `database` (as `orders.py` does) and `request`/`session` from `flask`. One function per bait, each preceded by a one-line `# BAIT Bn — <why safe>` comment, implementing spec §4.3 exactly:
  - B1: `require_auth` decorator (checks `session.get("user_id")`, returns `("", 401)` otherwise) applied to `admin_delete_order(order_id)` on `@app.route("/admin/orders/<order_id>", methods=["DELETE"])`.
  - B2: `SORT_COLUMNS = {"date": "created_at", "total": "total"}`; `list_orders_sorted(user_id, key)` builds `f"SELECT * FROM orders WHERE user_id = ? ORDER BY {SORT_COLUMNS[key]}"` with `(user_id,)` parameterized.
  - B3: `WAREHOUSE_API_KEY = os.environ.get("WAREHOUSE_API_KEY", "dev-placeholder-not-a-secret")`.
  - B4: `fetch_rates()` wraps `urllib.request.urlopen(..., timeout=5)` in `except Exception: logger.exception("rate fetch failed"); raise`.
  - B5: `order_totals(order_ids)` runs one `WHERE id IN (...)` query before the loop and indexes a dict inside it.
  `app` is imported from `app` (`from app import app`) — this is intentional; it must **not** create a new cycle.

- [ ] **Step 2: Prove it compiles and the deterministic scripts still agree with the defect map**

Run: `python3 -m py_compile evals/fixture/safe.py && python3 skills/codeprobe/scripts/dependency_mapper.py evals/fixture | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['circular_dependencies']))"`
Expected: compiles; prints `1` (only the planted `models ↔ services` cycle).

- [ ] **Step 3: Append to `evals/expected-findings.md`** a `## Must NOT be reported (precision baits)` table with columns `# | Location | Looks like | Why safe | Failure if reported at`, five rows from spec §4.3, and the grading rule sentence from spec §4.3 verbatim ("a bait reported at **Minor or Suggestion** is tolerated …").

- [ ] **Step 4: Commit**
```bash
git add evals/fixture/safe.py evals/expected-findings.md
git commit -m "test: add five precision baits to the eval fixture"
```

---

### Task 3: First eval case — `security-only` — and the shared scaffold

This task proves the harness: scaffold path resolution, tool grants, and that the plugin loads in the sandbox. Do it before the expensive cases.

**Files:**
- Create: `evals/_shared/scaffold.sh`
- Create: `evals/security-only/prompt.md`, `case.yaml`, `scaffold.sh`, `graders/skill-fired.md`, `graders/read-only.md`, `graders/sec-plant-1.md` … `sec-plant-4.md`, `graders/rationale-present.md`, `graders/single-category.md`
- Modify: `.gitignore` (add `evals/results/`)

**Interfaces:**
- Produces: `evals/_shared/scaffold.sh` — copies `"$(dirname "$0")/../fixture"` to `./fixture` in the cwd; each case's `scaffold.sh` is `exec "$(dirname "$0")/../_shared/scaffold.sh"`. Tasks 4, 5 reuse it.
- Produces: the **grant list** `EVAL_GRANTS` recorded in `evals/README.md` (Task 5) and `.github/workflows/evals.yml` (Task 9).

- [ ] **Step 1: Write the scaffold pair.** `_shared/scaffold.sh` is the 3-line script in spec §4.2 with `set -euo pipefail` and `../fixture` relative to `$0`'s directory's parent. `security-only/scaffold.sh` execs it. `chmod +x` both. `evals/_shared/` must contain no `prompt.md`/`case.yaml` so it is not a case.

- [ ] **Step 2: Write `prompt.md`**
```markdown
---
name: security-only
description: Security sub-skill alone on the planted-defect fixture
tags: [security, regression]
runs: 3
max_turns: 120
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

/codeprobe:codeprobe security ./fixture
```
and `case.yaml`:
```yaml
schema_version: "1.1"
name: security-only
context:
  scaffold_script: scaffold.sh
```

- [ ] **Step 3: Write the graders.** `skill-fired.md`: `type: tool_used`, `tool: Skill`, `input_match: '"skill"\s*:\s*"(?:[\w-]+:)?codeprobe"'`. `read-only.md`: `type: file_exists`, `path: "fixture/**"`, `exists: false`. `sec-plant-1..4.md`: `type: regex`, `target: last_message`, `flags: i`, patterns anchored on the function/constant name and the word Critical within the same finding block — e.g. for #1 `search_reports[\s\S]{0,400}Critical|Critical[\s\S]{0,400}search_reports`; #2 `STRIPE_SECRET_KEY`; #3 `delete_order`; #4 `login[\s\S]{0,400}(password|log)`. `rationale-present.md`: `type: llm`, body `PASS if every finding block in the response contains a line beginning "**Severity rationale:**" with a one-sentence justification. FAIL if any finding lacks one.` `single-category.md`: `type: regex`, `target: last_message`, `pattern: '\b(SRP|OCP|LSP|ISP|DIP|SMELL|ARCH|PERF|ERR|TEST|PATTERN|FWK)-\d{3}\b'`, `match: not_contains`.

- [ ] **Step 4: Run once, single arm, keep the sandbox**

Run: `claude plugin eval . --case security-only --runs 1 --ablation none --scaffold --trust-plugin --keep-temp --allow-tools Write "Bash(python3 *)" "Bash(mkdir *)" "Bash(wc *)" --no-publish`
Expected: the case loads (no `invalid case.yaml`), the progress output shows **no** `not granted` tool, and `skill-fired` passes. If `not granted` lists a command, add the narrowest `Bash(<cmd> *)` pattern and re-run; if `scaffold failed`, inspect the kept temp dir and switch to the `add_dirs` fallback in spec §4.2. Record the final grant list as `EVAL_GRANTS` in your task notes for Tasks 5 and 9.

- [ ] **Step 5: Run at `runs: 3`** with the same command minus `--runs 1 --keep-temp`.
Expected: `SCORE` ≥ 0.8. If a `sec-plant-*` regex fails while the finding is visibly present, loosen only that regex's window (`{0,400}` → `{0,800}`); do not touch the skill.

- [ ] **Step 6: Commit**
```bash
git add .gitignore evals/_shared evals/security-only
git commit -m "test: add security-only eval case runnable with claude plugin eval"
```

---

### Task 4: Eval case — `quick-top5`

**Files:**
- Create: `evals/quick-top5/prompt.md`, `case.yaml`, `scaffold.sh`, `graders/skill-fired.md`, `graders/read-only.md`, `graders/at-most-five.md`, `graders/three-to-five.md`, `graders/top5-dominated-by-plants.md`

- [ ] **Step 1: Write the case** like Task 3 with `name: quick-top5`, `tags: [quick, regression]`, `runs: 3`, `max_turns: 200`, `timeout_seconds: 1800`, body `/codeprobe:codeprobe quick ./fixture`.

- [ ] **Step 2: Write the graders.** Copy `skill-fired.md`, `read-only.md`. `at-most-five.md`: `type: regex`, `target: last_message`, `pattern: '^\|\s*6\s*\|'`, `flags: m`, `match: not_contains`. `three-to-five.md`: `type: llm`, `PASS if the "Top 5 Issues" table has between 3 and 5 numbered rows inclusive. FAIL if fewer than 3 or more than 5.` `top5-dominated-by-plants.md`: `type: llm`, body naming the five planted Criticals from `expected-findings.md` #1–#4 and #6 by function name and `PASS if at least 3 rows refer to them. FAIL otherwise.`

- [ ] **Step 3: Run**

Run: `claude plugin eval . --case quick-top5 --runs 3 --ablation none --scaffold --trust-plugin --no-publish --allow-tools <EVAL_GRANTS>`
Expected: `SCORE` ≥ 0.8.

- [ ] **Step 4: Commit**
```bash
git add evals/quick-top5
git commit -m "test: add quick-top5 eval case"
```

---

### Task 5: Eval case — `audit-full`, retire `evals.json`

**Files:**
- Create: `evals/audit-full/prompt.md`, `case.yaml`, `scaffold.sh`, `graders/skill-fired.md`, `read-only.md`, `report-written.md`, `critical-1.md` … `critical-6.md`, `dashboard-present.md`, `n1-is-major.md`, `god-class-once.md`, `no-false-criticals.md`
- Create: `evals/README.md`
- Delete: `evals/evals.json`

**Interfaces:**
- Produces: grader names `critical-1` … `critical-6` — Task 9's jq gate matches `^critical-`.

- [ ] **Step 1: Write the case** with `name: audit-full`, `tags: [audit, regression]`, `runs: 2`, `max_turns: 200`, `timeout_seconds: 1800`, body `/codeprobe:codeprobe audit ./fixture`.

- [ ] **Step 2: Write the terminal graders.** `report-written.md`: `type: file_exists`, `path: "codeprobe-reports/*.md"`. `critical-1..6.md`: regex on `last_message` as in Task 3 for #1 `search_reports`, #2 `STRIPE_SECRET_KEY`, #3 `delete_order`, #4 `login`+password, #6 `create_order`, #16 `merge_duplicate_accounts`. `dashboard-present.md`: `type: regex`, `target: last_message`, `pattern: '\|\s*Error Handling\s*\|\s*\d+/100[\s\S]*Report saved to \./codeprobe-reports/'`.

- [ ] **Step 3: Write the trace graders.** `n1-is-major.md`: `type: regex`, `target: trace`, `pattern: 'Major Issues[\s\S]{0,20000}order_summaries'` plus a second file `n1-not-critical.md` with `pattern: 'Critical Issues[\s\S]{0,8000}order_summaries'`, `match: not_contains`. `god-class-once.md`: `type: regex`, `target: trace`, `pattern: 'UserManager[\s\S]{0,600}Also flagged by'`, `match: "count:1"`. (Remember quotes in `trace` are `\"`; these patterns avoid quotes.)

- [ ] **Step 4: Write `no-false-criticals.md`** (`type: llm`, `focus: last_message`): `PASS if (a) no finding under "Critical" has an ID prefix TEST-, SMELL-, PATTERN-, or FWK-, and (b) the response does not claim to have modified, written, or edited any file under ./fixture. FAIL if either is violated.`

- [ ] **Step 5: Run once with `--runs 1`** (same flags as Task 3 Step 4 without `--keep-temp`).
Expected: all graders load; `critical-*` and `dashboard-present` pass. If a trace regex fails, run again with `--keep-temp`, open the run's transcript JSONL, and adjust only the window size or escaping. Note the `COST` column for `evals/README.md`.

- [ ] **Step 6: Delete `evals/evals.json`** and write `evals/README.md`: layout tree, the exact local run command with `<EVAL_GRANTS>` filled in, the per-case cost observed, and the sentence that the suite does not use the baseline arm and why (spec §4.2).

- [ ] **Step 7: Run at default runs** (`--runs 2` from the file) and confirm `SCORE` ≥ 0.8.

- [ ] **Step 8: Commit**
```bash
git add evals/audit-full evals/README.md
git rm evals/evals.json
git commit -m "test: add audit-full eval case; retire legacy evals.json"
```

---

### Task 6: Verifier rubric and output-contract fields

**Files:**
- Create: `skills/codeprobe/verification-rubric.md`
- Modify: `skills/codeprobe/shared-preamble.md` (Output Contract table, after `refactored_sketch`)
- Modify: `skills/codeprobe/SKILL.md` §5 table (same two rows)

**Interfaces:**
- Produces: `verification-rubric.md` with the headings `## Role`, `## Inputs you receive`, `## Procedure` (the five numbered rules from spec §4.4), `## Output` (the JSON shape below). Task 7 inlines it between `=== VERIFICATION RUBRIC ===` / `=== END VERIFICATION RUBRIC ===` markers.
- Produces: output contract fields `verification` (`confirmed | downgraded | rejected`, optional, set only by the orchestrator's verifiers) and `verification_note` (required when `verification` is `downgraded` or `rejected`).
- Verifier return shape:
```json
{ "category": "codeprobe-security",
  "findings": [ { "id": "SEC-001", "verification": "confirmed", "verification_note": "", "severity": "critical" } ],
  "summary": { "confirmed": 0, "downgraded": 0, "rejected": 0 } }
```
  `severity` is echoed (possibly lowered by exactly one bucket when `downgraded`).

- [ ] **Step 1: Write `verification-rubric.md`.** The `## Procedure` section is spec §4.4's five rules, reworded as imperatives to a single agent. Add under rule 1: evidence window is ±5 lines; under rule 4: the ordered bucket list `critical > major > minor > suggestion` and "lower by exactly one". Add a `## Hard limits` section: READ-ONLY (copy the preamble's one-liner), never raise, never add, never read the sub-skill detection tables even if present in the file manifest.

- [ ] **Step 2: Add the two rows** to both contract tables with the `Required` column reading `Orchestrator only` and `If downgraded/rejected` respectively. Add to the Rendered Finding Format in the preamble an optional line `**Verification:** downgraded from {old severity} — {verification_note}` directly after the severity-rationale line.

- [ ] **Step 3: Verify nothing else references the field count**

Run: `grep -rn "refactored_sketch" skills/ | wc -l`
Expected: the same count as before plus 0 (the rows were added, not renamed). Run `claude plugin validate . --strict` → `✔ Validation passed`.

- [ ] **Step 4: Commit**
```bash
git add skills/codeprobe/verification-rubric.md skills/codeprobe/shared-preamble.md skills/codeprobe/SKILL.md
git commit -m "feat: add verification rubric and verification fields to the output contract"
```

---

### Task 7: Orchestrator verification pass

**Files:**
- Modify: `skills/codeprobe/SKILL.md` — §3 Config Schema/Behavior; new §4B after §4A; §7A opening sentence; §8 audit flow A/B/C, quick, diff; §10 flow summary
- Modify: `skills/codeprobe/templates/full-audit-report.md`, `quick-review-summary.md`, `pr-review-comment.md`
- Test: `evals/audit-full/graders/rejection-line.md` (new), and re-run of `audit-full`, `quick-top5`

- [ ] **Step 1: Write the failing grader** `evals/audit-full/graders/rejection-line.md`: `type: regex`, `target: last_message`, `pattern: '\*\*Rejected by verification:\*\* \d+( \(\d+ categor(y|ies) unverified\))?'`.

- [ ] **Step 2: Run it to see it fail**

Run: `claude plugin eval . --case audit-full --runs 1 --ablation none --scaffold --trust-plugin --no-publish --allow-tools <EVAL_GRANTS>`
Expected: `rejection-line` FAIL (line not yet emitted); everything else unchanged.

- [ ] **Step 3: Config.** In §3 add `"verify": true` to the schema JSON and a Config Behavior bullet: `verify`: when `false`, skip §4B entirely, omit the "Rejected by verification" line and section.

- [ ] **Step 4: Write §4B "Verification Pass"** immediately after §4A, implementing spec §4.4 as orchestrator instructions. It must state, in this order: when it runs (after all sub-skill agents return, before §7A; for `audit`, `diff`, single-category commands, and `quick` after ranking); what is verified (Critical and Major only; for `quick`, the provisional top 8); fan-out (one agent per category with ≥1 such finding, all spawned in one message; `quick` spawns exactly one); the prompt composition (preamble READ-ONLY block, `=== VERIFICATION RUBRIC ===` inlined from `verification-rubric.md` resolved relative to this SKILL.md, the category's findings with all fields, the file manifest, reference paths, target path — and explicitly **not** the sub-skill SKILL.md); the handling table (`confirmed` unchanged; `downgraded` → apply echoed severity, keep id, set note; `rejected` → remove before §7A and scoring, keep `{id, location, verification_note}` in a `rejected[]` list for the report); failure handling (agent error/timeout/unparseable → all of that category's findings pass through unverified, increment `unverified_categories`); and the `quick` rendering rule (top 5 survivors re-ranked; if fewer than 5, render what survived and add one line `Fewer than 5 findings survived verification.`). Zero Critical/Major → spawn nothing, `rejected_count = 0`.

- [ ] **Step 5: Wire §7A, §8, §10.** §7A opening: "Before computing scores — and after the verification pass (§4B) has removed rejected findings — deduplicate …". §8 audit flow A3 bundle gains `rejected[]`, `rejected_count`, `unverified_categories`; B1 dashboard gains the line `**Rejected by verification:** {rejected_count}` (append ` ({n} categories unverified)` when n>0) directly after "Duplicates removed"; B3 critical detail renders the optional Verification line; C1 saved file includes the new collapsed section. `/codeprobe quick` and `/codeprobe diff` subsections each get one sentence pointing at §4B. §10 flow summary: insert step `8a. **Verify findings**: run §4B on Critical/Major findings; drop rejected, apply downgrades.` between Collect and Deduplicate.

- [ ] **Step 6: Templates.** `full-audit-report.md`: add the dashboard line after "Duplicates removed"; add after "Conflicting Recommendations" a section `### Rejected by Verification` wrapped in `<details><summary>{rejected_count} findings rejected</summary>` with a `| ID | Location | Reason |` table and the comment `<!-- Omit when rejected_count is 0 -->`; add the optional Verification line to the Critical detail block. `pr-review-comment.md`: add row `| Rejected by verification | {rejected_count} |` to the summary table. `quick-review-summary.md`: add line `**Rejected by verification:** {rejected_count}` under Summary Counts.

- [ ] **Step 7: Run `audit-full` once**

Run: same as Step 2.
Expected: `rejection-line` PASS; all six `critical-*` PASS (plants survive); `report-written` PASS.

- [ ] **Step 8: Run `quick-top5` once** with `--case quick-top5 --runs 1`.
Expected: `at-most-five`, `three-to-five` PASS.

- [ ] **Step 9: Commit**
```bash
git add skills/codeprobe/SKILL.md skills/codeprobe/templates evals/audit-full/graders/rejection-line.md
git commit -m "feat: verification pass — adversarial re-check of Critical/Major findings before reporting"
```

---

### Task 8: Precision graders

**Files:**
- Create: `evals/audit-full/graders/bait-1.md` … `bait-5.md`, `graders/rejected-lists-bait.md`

- [ ] **Step 1: Write `bait-n.md`** (`type: regex`, `target: trace`, `match: not_contains`), one per bait, each pattern scoped to the Critical or Major sections of the saved report: `(Critical Issues|Major Issues)[\s\S]{0,30000}?<name>` where `<name>` is `admin_delete_order`, `list_orders_sorted`, `WAREHOUSE_API_KEY`, `fetch_rates`, `order_totals`. Note the non-greedy `{0,30000}?` so a bait mentioned only in the Minor counts or the rejected section does not match.

- [ ] **Step 2: Write `rejected-lists-bait.md`**: `type: regex`, `target: trace`, `weight: 0.25`, `pattern: 'Rejected by Verification[\s\S]{0,6000}(admin_delete_order|list_orders_sorted|WAREHOUSE_API_KEY|fetch_rates|order_totals)'`.

- [ ] **Step 3: Run `audit-full` at default runs**

Run: `claude plugin eval . --case audit-full --ablation none --scaffold --trust-plugin --no-publish --allow-tools <EVAL_GRANTS>`
Expected: every `bait-n` PASS in every run; `critical-*` PASS in every run; `SCORE` ≥ 0.8. If a bait is reported at Major/Critical, read the verifier's note in the transcript (`--keep-temp`) and tighten the corresponding rule in `verification-rubric.md` — never the bait itself, and never the sub-skill tables.

- [ ] **Step 4: Commit**
```bash
git add evals/audit-full/graders
git commit -m "test: precision graders — baits must not reach Major/Critical"
```

---

### Task 9: CI workflow

**Files:**
- Create: `.github/workflows/evals.yml`

- [ ] **Step 1: Obtain a real `results.json`**

Run: `claude plugin eval . --case security-only --runs 1 --ablation none --scaffold --trust-plugin --no-publish --json /tmp/results.json --allow-tools <EVAL_GRANTS>` (use the session scratchpad path instead of `/tmp` when one is provided) and note the exact JSON path to a per-run grader result (name + pass/fail) under `cases[].arms.with[]`.

- [ ] **Step 2: Write the jq gate** as a step script: for the case named `audit-full`, across all `arms.with[]` runs, select graders whose name starts with `critical-` and fail (`exit 1`, printing the grader and run index) if any did not pass. Use the path discovered in Step 1.

- [ ] **Step 3: Write the workflow.** `on: pull_request` with `paths: [skills/**, evals/**, .claude-plugin/**]` and `workflow_dispatch`. Job `evals` on `ubuntu-latest` with the `if:` expression from spec §4.2 verbatim. Steps: checkout; `sudo apt-get install -y bubblewrap socat jq`; install Claude Code (`curl -fsSL https://claude.ai/install.sh | bash` and add to PATH); `bash scripts/check_version_sync.sh`; `claude plugin validate . --strict`; the eval command with `--json results.json --threshold 0.8 --ablation none --no-publish --trust-plugin --scaffold --max-cost-usd 25 --model claude-opus-5-5 --judge-model claude-sonnet-5-5 --allow-tools <EVAL_GRANTS>`; the jq gate; `actions/upload-artifact` of `evals/results/**/report.html` with `if: always()`. Auth: `env: ANTHROPIC_API_KEY: ${{ secrets.CODEPROBE_EVAL_API_KEY }}` on the eval step; add a comment that an OAuth token can be substituted per the Claude Code CI docs.

- [ ] **Step 4: Validate the YAML and the guard**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/evals.yml'))" 2>/dev/null || ruby -ryaml -e "YAML.load_file('.github/workflows/evals.yml')"` → no error. Then `grep -n "head.repo.full_name == github.repository" .github/workflows/evals.yml` → one match on the job's `if:` line. Then run the jq gate script against the Step 1 file with the case name temporarily swapped to `security-only` and a `sec-plant-` prefix → exit 0; edit one `passed` to `false` in a copy → exit 1.

- [ ] **Step 5: Commit**
```bash
git add .github/workflows/evals.yml
git commit -m "ci: run plugin evals on PRs with a plants-survive gate"
```

---

### Task 10: Docs, version bump, release

**Files:**
- Modify: `README.md` (Install, Commands note, How It Works, Scoring, regression-evals bullet)
- Modify: `docs/superpowers/plans/2026-03-30-token-optimization.md` (one-line note at top that evals moved; no other change)
- Modify: `.claude-plugin/plugin.json`, `skills/codeprobe/SKILL.md` (version → `2.3.0`)

- [ ] **Step 1: README.** Under Install add `### Install as a Claude Code plugin` with either the marketplace commands (if Task 1 Step 5 succeeded) or `claude --plugin-dir <path-to-clone>`, and the sentence that plugin installs invoke `/codeprobe:codeprobe …` while skills.sh installs keep `/codeprobe …`. Under How It Works add item 5 **Verification** (two sentences from spec §4.4: what is verified, what happens to rejected findings) and renumber the evals bullet to 6 with the run command from `evals/README.md`. Under Scoring add: "Findings rejected by verification are removed before scoring." Under Configuration add `"verify": true` to the JSON and one line explaining it.

- [ ] **Step 2: Bump both versions to `2.3.0`** and run `bash scripts/check_version_sync.sh && claude plugin validate . --strict`. Expected: exit 0, `✔ Validation passed`.

- [ ] **Step 3: Manual end-to-end in a normal session**, from the repo root: `/codeprobe audit evals/fixture`. Expected: terminal shows the dashboard with the `Rejected by verification` line, six Criticals, the save line; the saved report has the collapsed rejected section. Then write `evals/fixture/.codeprobe-config.json` containing `{"verify": false}`, re-run, confirm the line is absent, and **delete that config file** (do not commit it). Delete `./codeprobe-reports/` afterwards (it is gitignored, but keep the tree clean).

- [ ] **Step 4: Full suite at default runs**

Run: `claude plugin eval . --ablation none --scaffold --trust-plugin --no-publish --json results.json --threshold 0.8 --max-cost-usd 25 --allow-tools <EVAL_GRANTS>`
Expected: exit 0; every `critical-*` grader passed in every `audit-full` run (check with the Task 9 jq script). Delete `results.json`.

- [ ] **Step 5: Commit and tag**
```bash
git add README.md docs/superpowers/plans/2026-03-30-token-optimization.md .claude-plugin/plugin.json skills/codeprobe/SKILL.md
git commit -m "feat: ship v2.3.0 — runnable evals, plugin manifest, verification pass"
git tag v2.3.0
```
Do not push; the owner pushes and runs `npx skills update` on their machines (the installed copy under `~/.agents/skills` is a stale-install gotcha).
