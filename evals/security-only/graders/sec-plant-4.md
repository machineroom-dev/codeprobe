---
type: regex
target: last_message
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion|Fix(?:es)?)\b)[\s\S])*?(?:\b[Pp]assword[^\n]{0,120}\b[Ll]og(?:s|ged|ging|ger)?\b|\b[Ll]og(?:s|ged|ging|ger)?\b[^\n]{0,120}\b[Pp]assword)|\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|[^\n]*(?:\b[Pp]assword[^\n]{0,120}\b[Ll]og(?:s|ged|ging|ger)?\b|\b[Ll]og(?:s|ged|ging|ger)?\b[^\n]{0,120}\b[Pp]assword)|(?:\b[Pp]assword[^\n]{0,120}\b[Ll]og(?:s|ged|ging|ger)?\b|\b[Ll]og(?:s|ged|ging|ger)?\b[^\n]{0,120}\b[Pp]assword)[^\n]*\|\s*(?:\*\*)?Critical(?:\*\*)?\s*\|'
---

Planted defect #4: password written to logs in `login()` reported at Critical. The identifier is "password" and a logging token (`log`, `logs`, `logged`, `logging`, `logger`, whole words only, so "login" does not count) on one line. The function name is not required, because findings often cite only `app.py:40` or the `logger.info` call.

Case-sensitive, so "critical" in prose does not count. It matches in three ways:
(a) after a heading containing "Critical" and before the next heading that names Major, Minor, Suggestion or Fix/Fixes (for example "## Fix prompts" or "### Fix order"). Other headings, such as ID-less finding sub-headings like "### 1. SQL injection", stay inside the window. The window is lazy and has no length cap.
(b) a table or pipe row with a `| Critical |` cell before the identifier, for severity-first layouts and "**SEC-001 | Critical | ...**" lines.
(c) a table row with the identifier before a `| Critical |` cell.
