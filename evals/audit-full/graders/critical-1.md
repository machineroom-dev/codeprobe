---
type: regex
target: last_message
pattern: '(?:^|\n)#{1,6} (?![^\n]*/100)[^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion|Fix(?:es)?)\b)[\s\S])*?(?:\bsearch_reports\b|(?<![\w/])/reports\b)|\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|[^\n]*(?:\bsearch_reports\b|(?<![\w/])/reports\b)|(?:\bsearch_reports\b|(?<![\w/])/reports\b)[^\n]*\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|'
---

Planted defect #1: SQL injection in `search_reports()` (`fixture/app.py`, route `/reports`) reported at Critical.

Case-sensitive, so "critical" in prose does not count. It matches in three ways:
(a) after a heading containing "Critical" and before the next heading that names Major, Minor, Suggestion or Fix/Fixes (in the audit terminal layout, "### Critical Issues — Full Detail" opens the window and "### Prioritized Fix Order" closes it). Other headings, such as the `#### ERR-001 | \`file:lines\`` finding headings, stay inside the window. The window is lazy and has no length cap. A heading that carries a `/100` score (for example "## Overall Health: 31/100 Critical") does not open the window, because there "Critical" is a health status label, not a severity bucket, and the Executive Summary below it names every plant.
(b) a table or pipe row with a `| Critical |` cell before the identifier, for severity-first layouts and "**ERR-001 | Critical | ...**" lines.
(c) a table row with the identifier before a `| Critical |` cell.

This is one of the six plants-survive graders. CI gates on every grader whose name starts with `critical-`.
