# Shared Sub-Skill Preamble

## READ-ONLY CONSTRAINT

**This sub-skill is strictly read-only. Never modify, write, edit, or delete any file in the user's codebase. Report findings only.**

---

## Output Contract

Every finding MUST include ALL of the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | `{PREFIX}-{NNN}` — use the ID prefix specified by your sub-skill |
| `severity` | Yes | One of: `critical`, `major`, `minor`, `suggestion` |
| `severity_rationale` | Yes | One sentence explaining why this severity bucket and not the one below. See "How to write `severity_rationale`" below. |
| `location` | Yes | File path + line range (e.g., `src/UserService.php:45-67`) |
| `problem` | Yes | One sentence describing the issue |
| `evidence` | Yes | Concrete proof from the code — quote the relevant lines |
| `suggestion` | Yes | What to do to fix it |
| `fix_prompt` | Yes | A copy-pasteable prompt the user can give to Claude Code to apply the fix. Must reference specific file names, line ranges, method names, and the exact change to make. |
| `refactored_sketch` | No | Optional code snippet showing the improved version |

### Rendered Finding Format

```
### {ID} | {Severity} | `{file}:{lines}`

**Problem:** {problem description}

**Severity rationale:** {one sentence: why this bucket, not the one below}

**Evidence:**
> {quoted code patterns, specific variable names, line references}

**Suggestion:** {what to do to fix it}

**Fix prompt:**
> {copy-pasteable prompt for Claude Code}

**Refactored sketch:** (optional)
```

### How to write `severity_rationale`

A one-sentence justification of *why this severity, not the one below*. The format forces the reviewer to commit to a boundary call rather than picking a bucket by gut feel — this is the primary mechanism for keeping severity scoring stable across runs.

Rules:
- One sentence. No hedging ("could be either Major or Critical" is not allowed).
- Reference the specific signal that crossed the boundary (input source, blast radius, exploitability, scope of breakage), not a generic restatement of the problem.
- For Critical: state why Critical and not Major. Usually: confirmed exploit path, data loss path, or production crash on a core flow.
- For Suggestion (lowest level): state why Suggestion and not Minor. Usually: no real risk, purely a style/preference improvement.

Examples:
- **Critical:** "Critical (not Major) because user input flows directly into the SQL string with no parameterization — exploitable as-is via the public `POST /reports` endpoint."
- **Major:** "Major (not Minor) because the endpoint requires no auth and enables credential-stuffing; not Critical because rate-limiting at the load balancer partially mitigates."
- **Minor:** "Minor (not Major) because the magic number appears in a single internal helper with no callers depending on its specific value."
- **Suggestion:** "Suggestion (not Minor) because the pattern works fine today; the abstraction would only pay off if a second consumer appears."

---

## Execution Modes

### `full` Mode
Analyze the target path thoroughly. Produce detailed findings for every detected issue with all required fields. Include refactored_sketch for critical and major findings where it adds clarity.

### `scan` Mode
Quick count of issues by severity. Identify the worst offenders. Skip `evidence` and `fix_prompt` fields. Return counts per category, counts by severity, and top 3 worst-offending files.

---

## Summary Output

At the end of every execution (regardless of mode), provide a summary:

```json
{
  "skill": "{skill-name}",
  "summary": { "critical": 0, "major": 0, "minor": 0, "suggestion": 0 }
}
```

Replace the zeros with actual counts from the analysis.

---

## Source Files & References

The orchestrator has pre-loaded all source files and reference guides. They are provided below — do NOT use Read, Glob, or Grep to re-read them. Analyze the provided content directly.

If you need to check something not covered in the provided files (e.g., .gitignore existence, specific config files not in the source listing), you may use Read/Grep/Glob for those targeted lookups only.
