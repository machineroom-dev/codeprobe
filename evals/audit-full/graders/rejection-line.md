---
type: regex
target: last_message
pattern: '\*\*Rejected by verification:\*\* \d+( \(\d+ categor(y|ies) unverified\))?'
---

The terminal dashboard carries the verification-pass count line `**Rejected by verification:** N`, optionally suffixed with `(N categories unverified)` when a verifier agent failed or timed out. Zero is a valid count. The line is emitted whenever config `verify` is on (the default), so its absence means the verification pass (SKILL.md Section 4B) did not run or the dashboard contract was not honored.
