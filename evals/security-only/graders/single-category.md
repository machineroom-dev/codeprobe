---
type: regex
target: last_message
pattern: '\b(SRP|OCP|LSP|ISP|DIP|SMELL|ARCH|PERF|ERR|TEST|PATTERN|FWK)-\d{3}\b'
match: not_contains
---

No finding IDs from categories other than Security leak into a security-only run.
