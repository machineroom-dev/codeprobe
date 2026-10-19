# codeprobe evals

Regression suite for the codeprobe skill, run with `claude plugin eval`. Each case
runs the real `/codeprobe:codeprobe` slash command against a planted-defect
fixture and grades the terminal output, the trace and the workspace.

## Layout

```
evals/
├── _shared/scaffold.sh      # copies ../fixture into the run's workspace as ./fixture
├── fixture/                 # planted-defect project (no prompt.md, so not a case)
├── expected-findings.md     # defect map: planted defects, structural checks, baits
├── audit-full/              # /codeprobe:codeprobe audit ./fixture   (main regression gate)
├── quick-top5/              # /codeprobe:codeprobe quick ./fixture
├── security-only/           # /codeprobe:codeprobe security ./fixture
└── results/                 # run output, gitignored
```

Each case directory holds `prompt.md` (frontmatter: runs, `max_turns`,
`timeout_seconds`, tools; body: the slash command), `case.yaml` (points at
`scaffold.sh`), a one-line `scaffold.sh` that calls `_shared/scaffold.sh`, and
`graders/*.md`.

## Running locally

From the repo root:

```bash
claude plugin eval . --ablation none --scaffold --trust-plugin --no-publish \
  --max-cost-usd 25 \
  --allow-tools Write "Bash(python3 *)" "Bash(mkdir *)" "Bash(wc *)"
```

Add `--case audit-full` (or another case name) to run one case, `--runs N` to
override the per-case run count, and `--keep-temp` to keep the sandboxes for
reading the transcript. `Write` saves the report; the Bash grants cover the
skill's `python3 scripts/*.py`, `mkdir -p ./codeprobe-reports` and `wc` calls.
A denied Bash command is not listed as `not granted`; look for
`permission_denied` events in the trace.

## Cost

Observed with the default model, per run:

| Case | Runs per invocation | Cost per run | Cost per invocation |
|---|---|---|---|
| audit-full | 2 | ≈ $5.30 | ≈ $11 |
| quick-top5 | 3 | ≈ $3.90 | ≈ $11.70 |
| security-only | 3 | ≈ $2.20 | ≈ $6.60 |

## How the graders work

- **The skill ran.** Slash commands expand inline, so the trace has no `Skill`
  tool call. `skill-fired` instead looks for an `Agent` dispatch carrying the
  `=== SUB-SKILL: codeprobe-<name> ===` marker, which only the orchestrator's
  Invocation Protocol (SKILL.md Section 4) produces.
- **Terminal vs trace.** Criticals, the dashboard and the top-5 fix order are in
  `last_message`. Majors live only in the saved report, so those graders read
  the `trace`, where the report is the `Write` call's JSON-escaped input. Trace
  patterns avoid literal quotes and `^`/`$` anchors.
- **Plants survive.** `audit-full/graders/critical-1` … `critical-6` check that
  each planted Critical is in the terminal's Critical section. CI gates on every
  grader whose name starts with `critical-`.

## No baseline arm

The suite does not use the baseline (without-plugin) arm: without the plugin the
`/codeprobe:codeprobe` command does not exist, so the without-arm is noise. Every
run passes `--ablation none`.
