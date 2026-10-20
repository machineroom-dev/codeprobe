---
type: regex
target: trace
pattern: '#{2,4} Critical Issues(?:(?!\\n#{1,3} )[^\n])*?\\n#### (?:\*\*)?PERF-\d{3}\b(?:(?!\\n)[^\n])*?fulfillment\.py(?:(?!\\n#{1,6} )[^\n])*?\border_totals\b|#{2,4} Major Issues(?:(?!\\n#{1,3} )[^\n])*?\\n\|\s*(?:\*\*)?PERF-\d{3}\b(?:\*\*)?\s*\|(?:(?!\\n)[^|\n])*?fulfillment\.py(?:(?!\\n)[^\n])*?\border_totals\b'
match: not_contains
---

Precision bait B5: `order_totals()` in `fixture/fulfillment.py` runs one batched `WHERE id IN (...)` query and then does dict lookups in the loop, so it is not an N+1. Fails if the saved report lists it as a Performance finding at Major or Critical. Minor or Suggestion is tolerated.

In the Critical section (`#### ID | `file:lines`` blocks, see `templates/full-audit-report.md`) it needs a block whose heading carries a `PERF-NNN` ID and a `fulfillment.py` location, with `order_totals` anywhere in that block (up to the next heading). In the Major section (one `| ID | `file:lines` | problem | fix prompt |` row per finding) it needs a row that starts with a `PERF-NNN` ID, has `fulfillment.py` in the File cell, and names `order_totals` in the same row (`(?!\\n)` stops at the escaped row break). Requiring the `fulfillment.py` location keeps a finding elsewhere that only cites the bait as the safe example to copy (for instance a fix prompt saying "do it the way `order_totals` does") from counting.

The saved report reaches the trace as JSON-escaped `Write` input (and again in the tool-result echo), so a newline inside the report is the two characters `\n`, and `[^\n]` keeps every window inside one trace event, that is one copy of the report. A section window opens at the `Critical Issues` or `Major Issues` heading and stops at the next level 1-3 heading (`\\n#{1,3} `), so the Conflicting Recommendations, Downgraded by Verification, Rejected by Verification and Minor & Suggestion Counts sections never count. Only the assembled report (and the terminal summary, which repeats its Critical section) carries these headings, so a sub-skill finding that the verifier rejected or downgraded below the forbidden bucket does not count.
