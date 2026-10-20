---
type: regex
target: trace
pattern: '#{2,4} Critical Issues(?:(?!\\n#{1,3} )[^\n])*?\\n#### (?:\*\*)?SEC-\d{3}\b(?:(?!\\n)[^\n])*?fulfillment\.py(?:(?!\\n#{1,6} )[^\n])*?\bWAREHOUSE_API_KEY\b'
match: not_contains
---

Precision bait B3: `WAREHOUSE_API_KEY` in `fixture/fulfillment.py` takes its real value from the environment, and the literal fallback is a non-secret dev default. Fails if the saved report lists it as a Security finding at Critical. Per the bait table, a Major is tolerated.

In the Critical section (`#### ID | `file:lines`` blocks, see `templates/full-audit-report.md`) it needs a block whose heading carries a `SEC-NNN` ID and a `fulfillment.py` location, with `WAREHOUSE_API_KEY` anywhere in that block (up to the next heading). Requiring the `fulfillment.py` location keeps a finding elsewhere that only cites the bait as the safe example to copy (for instance a fix prompt saying "do it the way `WAREHOUSE_API_KEY` does") from counting.

The saved report reaches the trace as JSON-escaped `Write` input (and again in the tool-result echo), so a newline inside the report is the two characters `\n`, and `[^\n]` keeps every window inside one trace event, that is one copy of the report. A section window opens at the `Critical Issues` or `Major Issues` heading and stops at the next level 1-3 heading (`\\n#{1,3} `), so the Conflicting Recommendations, Downgraded by Verification, Rejected by Verification and Minor & Suggestion Counts sections never count. Only the assembled report (and the terminal summary, which repeats its Critical section) carries these headings, so a sub-skill finding that the verifier rejected or downgraded below the forbidden bucket does not count.
