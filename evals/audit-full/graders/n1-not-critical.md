---
type: regex
target: trace
pattern: 'Critical Issues(?:(?!Major Issues|Minor & Suggestion|\\n#{1,3} )[^\n])*?order_summaries'
match: not_contains
---

Planted defect #8, the N+1 query in `order_summaries()`, is not escalated to Critical (the v2.2.0 severity demotion). Fails if `order_summaries` appears after a "Critical Issues" heading and before the next severity heading or level 1-3 heading.

The saved report reaches the trace as JSON-escaped `Write` input. Its sections are `### Critical Issues — Full Detail`, `### Major Issues — Summary Table`, then `### Minor & Suggestion Counts` (`templates/full-audit-report.md`). The terminal summary (also in the trace, as the final assistant message) follows `### Critical Issues` with `### Prioritized Fix Order (top 5)` and no Major heading. So the window stops at "Major Issues", "Minor & Suggestion", or the next level 1-3 heading (`\\n#{1,3} `), and has no length cap: an `order_summaries` mention in the terminal's fix order or score notes does not count. Critical findings are `#### ` blocks, so they stay inside the window. Trace events are separated by real newlines and the report's own newlines are escaped as `\n`, so `[^\n]` keeps the window inside one event (one copy of the report). A "Critical Issues" heading in one event cannot reach an `order_summaries` mention in a later sub-agent result.
