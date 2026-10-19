---
type: regex
target: trace
pattern: 'Major Issues[\s\S]{0,20000}order_summaries'
---

Planted defect #8, the N+1 query in `order_summaries()` (`fixture/orders.py`), is listed in the saved report's "Major Issues" table. Majors are not streamed to the terminal, so this reads the trace, where the report appears as the `Write` tool's input. That input is JSON-escaped (quotes become `\"`, newlines `\n`), so the pattern uses only the heading and the function name.
