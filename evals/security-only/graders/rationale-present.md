---
type: llm
---

PASS if every finding block in the response (each `### SEC-NNN | …` heading) contains a line beginning "**Severity rationale:**" whose text says why this severity bucket was chosen rather than a neighbouring one (for example "Critical, not Major, because …"). One or two sentences are both acceptable. FAIL if any finding block lacks that line, or the line is empty, or it merely restates the problem without naming the bucket boundary.
