---
type: regex
target: trace
weight: 0.25
pattern: '#{2,4} Rejected by Verification(?:(?!\\n#{1,3} )[^\n])*?(?:\b(?:admin_delete_order|list_orders_sorted|WAREHOUSE_API_KEY|fetch_rates|order_totals)\b|fulfillment\.py)'
---

Informational: the verification pass visibly did work on the precision baits. Passes if the saved report's `### Rejected by Verification` section (`templates/full-audit-report.md`, rendered only when at least one finding was rejected) names one of the five baits (`admin_delete_order`, `list_orders_sorted`, `WAREHOUSE_API_KEY`, `fetch_rates`, `order_totals`) or a `fulfillment.py` location. A rejected row carries `file:lines` and the verifier's note but not always the function name, and nothing in `fulfillment.py` is a planted defect, so a rejected `fulfillment.py` finding is a rejected bait.

Low weight (0.25) on purpose: a bait that no sub-skill raised in the first place is also a correct outcome, so this grader is expected to fail often. The `bait-1` to `bait-5` graders are the precision gate.

The window opens at the heading and stops at the next level 1-3 heading (`\\n#{1,3} `), inside one trace event (`[^\n]`, since the report's own newlines are JSON-escaped as `\n`).
