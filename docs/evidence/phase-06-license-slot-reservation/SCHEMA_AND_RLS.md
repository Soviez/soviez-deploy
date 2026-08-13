# Schema and RLS

Migration `082_license_slot_reservation_foundation.sql`

Hold statuses withhold capacity; soft-commit at key_issued via `generate_secure_license_for_purchase`.

RLS: anon deny; authenticated SELECT own reservations only; mutations service-role; events/idempotency deny clients; events immutable trigger.
