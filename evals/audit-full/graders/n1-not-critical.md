---
type: regex
target: trace
pattern: 'Critical Issues(?:(?!Major Issues|Minor & Suggestion)[^\n])*?order_summaries'
match: not_contains
---

Planted defect #8, the N+1 query in `order_summaries()`, is not escalated to Critical (the v2.2.0 severity demotion). Fails if `order_summaries` appears after a "Critical Issues" heading and before the next severity heading.

The saved report reaches the trace as JSON-escaped `Write` input. Its sections are `### Critical Issues — Full Detail`, `### Major Issues — Summary Table`, then `### Minor & Suggestion Counts` (`templates/full-audit-report.md`), so the window stops at "Major Issues" or "Minor & Suggestion" and has no length cap. Trace events are separated by real newlines and the report's own newlines are escaped as `\n`, so `[^\n]` keeps the window inside one event (one copy of the report). A "Critical Issues" heading in one event cannot reach an `order_summaries` mention in a later sub-agent result.
