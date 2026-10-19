---
type: regex
target: trace
pattern: 'Critical Issues[\s\S]{0,8000}order_summaries'
match: not_contains
---

Planted defect #8, the N+1 query in `order_summaries()`, is not escalated to Critical (the v2.2.0 severity demotion). Fails if `order_summaries` appears within 8000 characters after a "Critical Issues" heading anywhere in the trace.
