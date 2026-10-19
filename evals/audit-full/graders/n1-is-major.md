---
type: regex
target: trace
pattern: 'Major Issues(?:(?!Minor & Suggestion)[^\n]){0,20000}?PERF-\d{3}(?:(?!\\n)[^\n]){0,600}?order_summaries'
---

Planted defect #8, the N+1 query in `order_summaries()` (`fixture/orders.py`), is listed as a Performance finding in the saved report's "Major Issues" table. Majors are not streamed to the terminal, so this reads the trace, where the report appears as the `Write` tool's JSON-escaped input (quotes become `\"`, newlines `\n`).

The window runs from the "Major Issues" heading to the "Minor & Suggestion" heading, inside one trace event (`[^\n]`, since events are separated by real newlines). Inside it, a `PERF-NNN` ID and `order_summaries` must share one table row (`(?!\\n)` stops at the escaped row break). A Major TEST row that only calls `order_summaries([1])` does not count.
