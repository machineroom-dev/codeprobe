---
type: regex
target: last_message
flags: i
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion)\b)[\s\S]){0,4000}(?:\bdelete_order\b|(?<!/admin)/orders/<order_id>)|(?:\bdelete_order\b|(?<!/admin)/orders/<order_id>)[^\n]{0,200}\bCritical\b'
---

Planted defect #3: unauthenticated `delete_order()` endpoint reported at Critical. Also accepts the route `/orders/<order_id>`, since some runs cite the route and line range without the function name. `\b` and the `(?<!/admin)` lookbehind keep the `admin_delete_order` bait in safe.py (`/admin/orders/<order_id>`) from matching. Same Critical-section window as sec-plant-1.
