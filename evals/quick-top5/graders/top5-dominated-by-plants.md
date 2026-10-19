---
type: llm
---

The fixture has five planted Critical defects that should dominate the "Top 5 Issues" table:

1. SQL injection in `search_reports()` (`fixture/app.py`, route `/reports`): SQL built with an f-string from the `name` request parameter.
2. Hardcoded secret `STRIPE_SECRET_KEY` (`fixture/app.py`).
3. Unauthenticated data-mutating endpoint `delete_order()` (`fixture/app.py`, route `/orders/<order_id>`). The `admin_delete_order()` endpoint in `fixture/fulfillment.py` is a different, safe function and does not count.
4. Password written to logs in `login()` (`fixture/app.py`).
5. Four sequential writes (order, items, payment, inventory) with no transaction in `create_order()` (`fixture/orders.py`).

A row refers to a planted defect when its file, lines, function name, route or issue description identifies that defect, even if the function name is not spelled out. Each planted defect counts once.

PASS if at least 3 rows refer to them. FAIL otherwise.
