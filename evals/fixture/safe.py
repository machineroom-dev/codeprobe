# codeprobe eval fixture — intentionally flawed code used to regression-test
# audits. Do NOT copy patterns from this file. Defect map: evals/expected-findings.md
import functools
import os
import urllib.request

from flask import request, session

from app import app, logger
from database import db


def require_auth(view):
    @functools.wraps(view)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            return "", 401
        return view(*args, **kwargs)

    return wrapper


# BAIT B1 — auth is enforced by require_auth (defined above), which checks the session.
@app.route("/admin/orders/<order_id>", methods=["DELETE"])
@require_auth
def admin_delete_order(order_id):
    db.execute("DELETE FROM orders WHERE id = ?", (order_id,))
    return "", 204


SORT_COLUMNS = {"date": "created_at", "total": "total"}


# BAIT B2 — no user input reaches the SQL string: ORDER BY uses a fixed allowlist, user_id is parameterized.
def list_orders_sorted(user_id, key):
    return db.query_all(
        f"SELECT * FROM orders WHERE user_id = ? ORDER BY {SORT_COLUMNS[key]}",
        (user_id,),
    )


# BAIT B3 — the literal is a non-secret dev default; the real value comes from the environment.
WAREHOUSE_API_KEY = os.environ.get("WAREHOUSE_API_KEY", "dev-placeholder-not-a-secret")


# BAIT B4 — the exception is logged and re-raised, not swallowed.
def fetch_rates():
    try:
        with urllib.request.urlopen(
            "https://rates.internal/api/latest", timeout=5
        ) as resp:
            return resp.read()
    except Exception:
        logger.exception("rate fetch failed")
        raise


# BAIT B5 — one batched WHERE id IN (...) query before the loop; the loop only does dict lookups.
def order_totals(order_ids):
    placeholders = ", ".join("?" for _ in order_ids)
    rows = db.query_all(
        f"SELECT id, total FROM orders WHERE id IN ({placeholders})",
        tuple(order_ids),
    )
    total_by_id = {row["id"]: row["total"] for row in rows}
    totals = []
    for order_id in order_ids:
        totals.append(total_by_id.get(order_id, 0))
    return totals
