---
type: regex
target: trace
pattern: '\bUserManager\b(?!\.)(?:(?!\\n)[\s\S]){0,600}?Also flagged by'
match: "count:2"
---

Planted defect #10, the `UserManager` god class, survives Section 7A dedup as exactly one primary finding that carries an "Also flagged by" cross-reference to the dropped duplicates.

The god class is a Major, so it lives in the saved report's Major table, which reaches the trace as JSON-escaped `Write` input. There a newline is the two characters `\n`, so the window `(?:(?!\\n)[\s\S]){0,600}?` stays inside one table row. Without that, a `UserManager.login` mention in one row paired with another row's "Also flagged by". `(?!\.)` skips method references such as `UserManager.login`.

The count is 2, not 1, because the trace carries the saved report twice: once as the `Write` call's input and once as the `content` that the `Write` tool result echoes back. One primary row in one report therefore matches twice. A count of 4 means the god class appears as two cross-referenced rows (or the report was written twice); a count of 0 means the cross-reference is missing.
