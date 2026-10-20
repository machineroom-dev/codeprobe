---
type: regex
target: trace
pattern: '(?:\bUserManager\b(?!\.)(?:(?!\\n)[^\n]){0,600}?[Gg]od[ -][Cc]lass|[Gg]od[ -][Cc]lass(?:(?!\\n)[^\n]){0,600}?\bUserManager\b(?!\.))(?:(?!\\n)[^\n]){0,600}?Also flagged by[^\n]*?(?:\bUserManager\b(?!\.)(?:(?!\\n)[^\n]){0,600}?[Gg]od[ -][Cc]lass|[Gg]od[ -][Cc]lass(?:(?!\\n)[^\n]){0,600}?\bUserManager\b(?!\.))(?:(?!\\n)[^\n]){0,600}?Also flagged by'
match: not_contains
---

Planted defect #10, the `UserManager` god class, appears as exactly one cross-referenced primary: no copy of the saved report holds two rows that each pair `UserManager` with "god class" and "Also flagged by". Together with `god-class-crossref` (at least one such row), this means exactly one.

Trace events are separated by real newlines, and the report's own newlines are escaped as `\n`, so `[^\n]*?` between the two row patterns keeps the search inside one event, i.e. one copy of the report. The check therefore does not depend on how many times the harness stores the report (`Write` input, echoed tool result, a later Read-back or a second Write).
