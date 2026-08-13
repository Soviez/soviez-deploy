# Migration Authorization

## What this step does

After your data has been transferred and staging validated (Phase 19), Phase 20 **authorizes** the license move: one Migration Token is consumed, the license binding moves to the destination, and both sides enter pre-cutover states.

**This does not switch public traffic.** Your production domain stays on the source until a later cutover phase.

## Before you start

- Phase 19 transfer shows `ready_for_20` = PASS or WARNING (not BLOCKED).
- You have at least one available Migration Token on the license.
- Source write freeze is released.
- You understand this consumes the token **immediately** on commit — there is no long reservation.

## Steps

### 1. Plan (optional)

Review eligibility and prerequisites:

```bash
./soviez.sh migration authorization plan --pair-id <pair-id>
```

### 2. Commit authorization

Requires explicit confirmation:

```bash
./soviez.sh migration authorization commit --pair-id <pair-id> --confirm
```

On success you receive an **authorization receipt** with an `authorization_id`. The token is consumed atomically with the binding transition.

### 3. Activate destination (pre-cutover)

```bash
./soviez.sh migration destination activate --pair-id <pair-id> --authorization-id <auth-id>
```

Destination becomes **licensed internally** but is **not publicly reachable** on your production domain.

### 4. Check Phase 21 readiness (informational)

```bash
./soviez.sh migration phase21-readiness --authorization-id <auth-id>
```

A PASS report means pre-cutover checks passed. It does **not** start cutover.

## What changes

| Location | State after Phase 20 |
|----------|---------------------|
| Source | Still serves traffic; enters migration grace (some operations restricted) |
| Destination | Licensed pre-cutover; internal health only |
| Migration Token | Consumed (one per successful authorization) |
| DNS / domain | Unchanged |

## Important

- Phase 21 cutover is **not** part of this release.
- If commit outcome is uncertain, use recovery — see [Migration Authorization Recovery](MIGRATION_AUTHORIZATION_RECOVERY.md).
