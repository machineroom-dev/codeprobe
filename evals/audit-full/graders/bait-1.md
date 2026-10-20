---
type: regex
target: trace
pattern: '#{2,4} Critical Issues(?:(?!\\n#{1,3} )[^\n])*?\\n#### (?:\*\*)?SEC-\d{3}\b(?:(?!\\n)[^\n])*?fulfillment\.py(?:(?!\\n#{1,6} )[^\n])*?\badmin_delete_order\b|#{2,4} Major Issues(?:(?!\\n#{1,3} )[^\n])*?\\n\|\s*(?:\*\*)?SEC-\d{3}\b(?:\*\*)?\s*\|(?:(?!\\n)[^|\n])*?fulfillment\.py(?:(?!\\n)[^\n])*?\badmin_delete_order\b'
match: not_contains
---

Precision bait B1 (`evals/expected-findings.md`, "Must NOT be reported"): `admin_delete_order()` in `fixture/fulfillment.py` is protected by the `require_auth` decorator defined in the same file, which checks for a logged-in user (401) and for the `admin` role (403). Fails if the saved report lists it as a Security finding at Critical or Major. Minor or Suggestion is tolerated.

In the Critical section (`#### ID | `file:lines`` blocks, see `templates/full-audit-report.md`) it needs a block whose heading carries a `SEC-NNN` ID and a `fulfillment.py` location, with `admin_delete_order` anywhere in that block (up to the next heading). In the Major section (one `| ID | `file:lines` | problem | fix prompt |` row per finding) it needs a row that starts with a `SEC-NNN` ID, has `fulfillment.py` in the File cell, and names `admin_delete_order` in the same row (`(?!\\n)` stops at the escaped row break). Requiring the `fulfillment.py` location keeps a finding elsewhere that only cites the bait as the safe example to copy (for instance a fix prompt saying "do it the way `admin_delete_order` does") from counting.

The saved report reaches the trace as JSON-escaped `Write` input (and again in the tool-result echo), so a newline inside the report is the two characters `\n`, and `[^\n]` keeps every window inside one trace event, that is one copy of the report. A section window opens at the `Critical Issues` or `Major Issues` heading and stops at the next level 1-3 heading (`\\n#{1,3} `), so the Conflicting Recommendations, Downgraded by Verification, Rejected by Verification and Minor & Suggestion Counts sections never count. Only the assembled report (and the terminal summary, which repeats its Critical section) carries these headings, so a sub-skill finding that the verifier rejected or downgraded below the forbidden bucket does not count.
