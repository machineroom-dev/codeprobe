---
type: regex
target: last_message
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion|Fix(?:es)?)\b)[\s\S])*?\bSTRIPE_SECRET_KEY\b|\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|[^\n]*\bSTRIPE_SECRET_KEY\b|\bSTRIPE_SECRET_KEY\b[^\n]*\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|'
---

Planted defect #2: hardcoded `STRIPE_SECRET_KEY` reported at Critical.

Case-sensitive, so "critical" in prose does not count. It matches in three ways:
(a) after a heading containing "Critical" and before the next heading that names Major, Minor, Suggestion or Fix/Fixes (for example "## Fix prompts" or "### Fix order"). Other headings, such as ID-less finding sub-headings like "### 1. SQL injection", stay inside the window. The window is lazy and has no length cap.
(b) a table or pipe row with a `| Critical |` cell before the identifier, for severity-first layouts and "**SEC-001 | Critical | ...**" lines.
(c) a table row with the identifier before a `| Critical |` cell.
