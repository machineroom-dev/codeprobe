---
type: regex
target: trace
pattern: '\bUserManager\b(?!\.)(?:(?!\\n)[^\n]){0,600}?Also flagged by'
---

Planted defect #10, the `UserManager` god class, survives Section 7A dedup as a primary finding that carries an "Also flagged by" cross-reference to the dropped duplicates.

The god class is a Major, so it lives in the saved report's Major table, which reaches the trace as JSON-escaped `Write` input. There a newline is the two characters `\n`, so `(?:(?!\\n)[^\n]){0,600}?` keeps the window inside one table row, and `(?!\.)` skips method references such as `UserManager.login`. The companion grader `god-class-once` checks that there is only one such row.
