# Warning Schedule
The local warning ledger emits once per Stage at remaining calendar-day thresholds: **30, 14, 7, 3, 1, 0**, plus one overdue marker.

Entries are JSONL and threshold-idempotent. The unit suite calls the 7-day evaluator twice and confirms exactly one warning record.
