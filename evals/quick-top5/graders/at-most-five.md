---
type: regex
target: last_message
pattern: '^\|\s*6\s*\|'
flags: m
match: not_contains
---

The "Top 5 Issues" table has no sixth row. Rows in `templates/quick-review-summary.md` start with `| 1 |` through `| 5 |`, so a line starting `| 6 |` means the table overflowed.
