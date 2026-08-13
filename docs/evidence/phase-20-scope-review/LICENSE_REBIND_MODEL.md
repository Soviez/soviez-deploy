# LICENSE_REBIND_MODEL.md

## Distinctions

| Concept | Role |
|---------|------|
| License record | One sellable License |
| Production slot | One permanent slot |
| Source device/environment binding | Current traffic-serving bind |
| Destination device/environment binding | Future Production bind |
| Temporary staging identity | Phase 19; non-slot |
| Stage identities | Child of Production; rebound exactly |
| Entitlements | Support/update/Stage grants follow License |

## Model (recommended)

```text
one License
+ one Production slot
+ binding transition source → destination
```

**Must not** create a second independent sellable Production License or second permanent slot.

Source moves to **`migration_origin_grace`** (same License; not a second slot).

Destination becomes **`production_licensed_pre_cutover`** (licensed future owner; not traffic owner until Phase 21).
