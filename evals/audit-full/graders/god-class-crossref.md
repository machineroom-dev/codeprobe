---
type: regex
target: trace
pattern: '(?:\bUserManager\b(?!\.)(?:(?!\\n)[^\n]){0,600}?[Gg]od[ -][Cc]lass|[Gg]od[ -][Cc]lass(?:(?!\\n)[^\n]){0,600}?\bUserManager\b(?!\.))(?:(?!\\n)[^\n]){0,600}?Also flagged by'
---

Planted defect #10: the `UserManager` god class is reported once as a cross-referenced primary. Some copy of the saved report holds a row (one report line, i.e. no escaped `\n` inside the match) that names `UserManager`, calls it a god class (either order), and carries an "Also flagged by" cross-reference. Anchoring on the words "god class" keeps unrelated rows that merely mention `UserManager` (e.g. a dependency-injection finding) from counting.
