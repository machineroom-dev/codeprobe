---
type: regex
target: trace
weight: 0.25
pattern: 'Major Issues(?:(?!\\n#{1,3} )[^\n])*?\\n\|\s*(?:\*\*)?ARCH-\d{3}\b(?=(?:(?!\\n)[^\n])*?\bmodels\b)(?=(?:(?!\\n)[^\n])*?\bservices\b)(?:\*\*)?\s*\|(?:(?!\\n)[^|\n])*\|(?:(?!\\n)[^|\n])*?(?:[Cc]ircular|[Cc]ycl|[Bb]idirectional|[Mm]utual|[Tt]wo-way)'
---

Informational: planted defect #9, the direct circular import between `fixture/models.py` and `fixture/services.py` (`evals/expected-findings.md`), survives verification as an Architecture finding in the saved report's "Major Issues" table. Passes if that table has a row that starts with an `ARCH-NNN` ID, names both `models` and `services` anywhere in the row, and calls the dependency circular, cyclic, bidirectional, mutual or two-way in its Problem cell (the third cell of `| ID | File | Problem | Fix Prompt |`, `templates/full-audit-report.md`). Requiring the word in the Problem cell keeps another ARCH row, such as an anemic-model finding whose fix prompt mentions the cycle, from counting.

Low weight (0.25) on purpose: this is a recall check added right before the validation run, so it informs without threatening the 0.8 threshold, and it stays out of the CI plants-survive gate. A verifier that rejects or downgrades the cycle, or a dedup that keeps it under another category's ID, fails it.

Like `n1-is-major`, the window opens at "Major Issues" and stops at the next level 1-3 heading (`\\n#{1,3} `), so a Downgraded or Rejected by Verification row never counts. `(?!\\n)` keeps every check inside one table row and `[^\n]` keeps the window inside one trace event (the report's own newlines are JSON-escaped as `\n`).
