# Trust Pairing Model — Phase 17

## Goal

Bind **exact** source Production + **exact** destination bootstrap + **exact** License into a short-lived trusted migration pair **without** transferring business payloads.

## Recommended protocol (pending OD-03/04)

**Application-signed certificates / challenges** over an authenticated channel, consistent with existing Device Authorization + request signing (Ed25519) and Phase 7 manifest trust — **not** inventing a second PKI.

| Option | Fit | Notes |
|--------|-----|-------|
| Mutual TLS | Possible later for streaming (19) | Heavier; good for transfer plane |
| SSH certificates / host keys | Useful for transfer plane | Host-key substitution risk; needs owner fingerprint confirm |
| **App-signed challenge/response (recommended for Phase 17 pairing)** | Best fit | Reuses signing primitives; pairs identities without TOFU |

SSH and/or mTLS connectivity **tests** may run with synthetic payloads (OD-16); pairing trust object remains app-signed.

## Protocol requirements

- Source initiates **or** owner explicitly authorizes pairing (OD-04)  
- Destination generates one-time bootstrap identity  
- Signed challenge/response; short-lived nonce  
- Exact source host + destination host + License + migration operation binding  
- Replay protection + expiry (OD-06)  
- No shared permanent password  
- No TOFU without owner fingerprint confirmation (OD-05)  
- No automatic SSH key acceptance  
- Pairing revocable; abort removes temporary trust  
- No business payload during pairing  

## Owner confirmation

Display: source host fingerprint, destination host fingerprint, License ID, Production ID, bootstrap ID. Require interactive confirm (or non-TTY explicit flags).

## Offline pairing package (OD-19)

Optional export/import of signed pairing package analogous to offline Stage packages — **pending owner decision**.

## Ops

`migration_trust_pairing` — states in `OPERATION_ENGINE_MODEL.md`.

## Failure codes

`MIGRATION_PAIR_*`, `MIGRATION_PAIR_REPLAY_DENIED`, `MIGRATION_PAIR_SIGNATURE_INVALID`, `MIGRATION_PAIR_EXPIRED`, `MIGRATION_PAIR_IDENTITY_MISMATCH`.
