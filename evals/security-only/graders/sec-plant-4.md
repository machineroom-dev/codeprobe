---
type: regex
target: last_message
flags: i
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion)\b)[\s\S]){0,4000}(?:password[^\n]{0,120}\blog|\blog[^\n]{0,120}password)|\blogin\b[^\n]{0,200}\bCritical\b'
---

Planted defect #4: password written to logs in `login()` reported at Critical. Matches password-and-log on one line inside the Critical section (the finding may cite the line number or the `logger.info` call rather than the function name), or `login` on the same line as "Critical".
