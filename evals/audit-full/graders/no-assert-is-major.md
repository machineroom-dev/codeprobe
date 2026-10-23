---
type: regex
target: trace
weight: 0.25
pattern: 'Major Issues(?:(?!\\n#{1,3} )[^\n])*?\\n\|\s*(?:\*\*)?TEST-\d{3}\b(?=(?:(?!\\n)[^\n])*?\btest_orders\b)(?:\*\*)?\s*\|(?:(?!\\n)[^|\n])*\|(?:(?!\\n)[^|\n])*?[Aa]ssert'
---

Informational: planted defect #22, the two tests in `fixture/tests/test_orders.py` that contain zero assertions (`evals/expected-findings.md`), survives verification as a Test Quality finding in the saved report's "Major Issues" table. Passes if that table has a row that starts with a `TEST-NNN` ID, names `test_orders` anywhere in the row, and mentions assertions (`assert`, `assertion`, `asserts`) in its Problem cell (the third cell of `| ID | File | Problem | Fix Prompt |`, `templates/full-audit-report.md`). Requiring the word in the Problem cell keeps another TEST row in that file, whose fix prompt merely says to add assertions, from counting.

Low weight (0.25) on purpose: this is a recall check added right before the validation run, so it informs without threatening the 0.8 threshold, and it stays out of the CI plants-survive gate. A verifier that rejects the finding because it sits in test code (verification-rubric.md rule 3 forbids that) fails it.

Like `n1-is-major`, the window opens at "Major Issues" and stops at the next level 1-3 heading (`\\n#{1,3} `), so a Downgraded or Rejected by Verification row never counts. `(?!\\n)` keeps every check inside one table row and `[^\n]` keeps the window inside one trace event (the report's own newlines are JSON-escaped as `\n`).
