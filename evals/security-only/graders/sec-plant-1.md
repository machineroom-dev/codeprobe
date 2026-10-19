---
type: regex
target: last_message
flags: i
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion)\b)[\s\S]){0,4000}(?:\bsearch_reports\b|(?<![\w/])/reports\b)|(?:\bsearch_reports\b|(?<![\w/])/reports\b)[^\n]{0,200}\bCritical\b'
---

Planted defect #1: SQL injection in `search_reports()` reported at Critical. Matches `search_reports` (or its route `/reports`) after a heading line containing "Critical" and before any later heading naming Major/Minor/Suggestion (or on the same line as "Critical", for table layouts).
