---
type: regex
target: trace
pattern: 'Major Issues(?:(?!\\n#{1,3} )[^\n])*?PERF-\d{3}(?:(?!\\n)[^\n])*?order_summaries'
---

Planted defect #8, the N+1 query in `order_summaries()` (`fixture/orders.py`), is listed as a Performance finding in the saved report's "Major Issues" table. Majors are not streamed to the terminal, so this reads the trace, where the report appears as the `Write` tool's JSON-escaped input (quotes become `\"`, newlines `\n`).

The window opens at the `Major Issues` heading and stops at the next level 1-3 heading (`\\n#{1,3} `), as the bait graders' windows do, so the Conflicting Recommendations, Downgraded by Verification, Rejected by Verification and Minor & Suggestion Counts sections never count: a verifier that downgraded the N+1 to Minor, with `order_summaries` in its Downgraded-table note, fails this grader. The window has no length cap (the T8 report had about 35 Major rows) and stays inside one trace event (`[^\n]`, since events are separated by real newlines). Inside it, a `PERF-NNN` ID and `order_summaries` must share one table row (`(?!\\n)` stops at the escaped row break). A Major TEST row that only calls `order_summaries([1])` does not count.
