---
type: regex
target: last_message
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} (?:[^\n]*\b(?:Major|Minor|Suggestion)\b|(?![^\n]*\b(?:Critical|SEC-\d{3})\b)))[\s\S])*?(?:\bsearch_reports\b|(?<![\w/])/reports\b)|\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|[^\n]*(?:\bsearch_reports\b|(?<![\w/])/reports\b)|(?:\bsearch_reports\b|(?<![\w/])/reports\b)[^\n]*\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|'
---

Planted defect #1: SQL injection in `search_reports()` (route `/reports`) reported at Critical.

Case-sensitive, so "critical" in prose does not count. It matches in three ways:
(a) after a heading containing "Critical" and before the next heading that names Major, Minor or Suggestion, or that names neither Critical nor a SEC-NNN ID (for example "## Fix prompts" or "### Fix order"). The window is lazy and has no length cap.
(b) a table or pipe row with a `| Critical |` cell before the identifier, for severity-first layouts and "**SEC-001 | Critical | ...**" lines.
(c) a table row with the identifier before a `| Critical |` cell.
