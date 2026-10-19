---
type: regex
target: last_message
pattern: '(?:^|\n)#{1,6} (?![^\n]*/100)[^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion|Fix(?:es)?)\b)[\s\S])*?(?:\bcreate_order\b)|\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|[^\n]*(?:\bcreate_order\b)|(?:\bcreate_order\b)[^\n]*\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|'
---

Planted defect #6 in `evals/expected-findings.md`: `create_order()` (`fixture/orders.py`) does four sequential writes (order, items, payment, inventory) with no transaction, reported at Critical. `\b` keeps `test_create_order` in the tests from matching.

Case-sensitive, so "critical" in prose does not count. It matches in three ways:
(a) after a heading containing "Critical" and before the next heading that names Major, Minor, Suggestion or Fix/Fixes (in the audit terminal layout, "### Critical Issues — Full Detail" opens the window and "### Prioritized Fix Order" closes it). Other headings, such as the `#### ERR-001 | \`file:lines\`` finding headings, stay inside the window. The window is lazy and has no length cap. A heading that carries a `/100` score (for example "## Overall Health: 31/100 Critical") does not open the window, because there "Critical" is a health status label, not a severity bucket, and the Executive Summary below it names every plant.
(b) a table or pipe row with a `| Critical |` cell before the identifier, for severity-first layouts and "**ERR-001 | Critical | ...**" lines.
(c) a table row with the identifier before a `| Critical |` cell.

This is one of the six plants-survive graders. CI gates on every grader whose name starts with `critical-`.
