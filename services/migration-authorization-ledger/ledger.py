#!/usr/bin/env python3
"""Phase 20 disposable/authoritative migration-authorization ledger (SQLite).

Provides atomic commit semantics for certification fixtures and TEST_MODE:
token consume IFF destination binding + source grace + authorization committed.
Also usable as a local mirror when SaaS RPC is unavailable.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import time
import uuid
from typing import Any


SCHEMA = """
CREATE TABLE IF NOT EXISTS grants (
  grant_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  license_id TEXT NOT NULL,
  capability_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  quantity_consumed INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  provider TEXT NOT NULL DEFAULT 'fixture'
);
CREATE TABLE IF NOT EXISTS wallet (
  license_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  credits INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS licenses (
  license_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  slot_count INTEGER NOT NULL DEFAULT 1,
  binding_fp TEXT,
  binding_db_uuid TEXT,
  binding_digest TEXT,
  status TEXT NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS idempotency (
  account_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  authorization_id TEXT NOT NULL,
  PRIMARY KEY (account_id, idempotency_key)
);
CREATE TABLE IF NOT EXISTS authorizations (
  authorization_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  license_id TEXT NOT NULL,
  pair_id TEXT NOT NULL,
  readiness_id TEXT,
  staging_id TEXT,
  grant_id TEXT,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  body_json TEXT NOT NULL,
  status TEXT NOT NULL,
  committed_at REAL,
  UNIQUE(account_id, idempotency_key)
);
CREATE TABLE IF NOT EXISTS bindings (
  authorization_id TEXT PRIMARY KEY,
  license_id TEXT NOT NULL,
  source_fp TEXT NOT NULL,
  dest_fp TEXT NOT NULL,
  source_db_uuid TEXT,
  dest_db_uuid TEXT,
  slot_count INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS source_grace (
  authorization_id TEXT PRIMARY KEY,
  license_id TEXT NOT NULL,
  source_fp TEXT NOT NULL,
  traffic_owner TEXT NOT NULL DEFAULT 'source',
  state TEXT NOT NULL DEFAULT 'migration_origin_grace'
);
CREATE TABLE IF NOT EXISTS stage_rebinds (
  authorization_id TEXT NOT NULL,
  stage_id TEXT NOT NULL,
  mandatory INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  retention_deadline TEXT,
  PRIMARY KEY (authorization_id, stage_id)
);
CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  authorization_id TEXT,
  event TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS offline_replay (
  package_id TEXT PRIMARY KEY,
  authorization_id TEXT NOT NULL,
  used_at REAL NOT NULL
);
"""


def db_path() -> str:
    p = os.environ.get("SOVIEZ_MIG_P20_LEDGER_PATH")
    if not p:
        root = os.environ.get("SOVIEZ_ROOT") or os.environ.get("TMPDIR") or "/tmp"
        p = os.path.join(root, "migration", "p20_ledger.sqlite")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(db_path(), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(SCHEMA)
    return conn


def jdump(obj: Any) -> str:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True)


def request_hash(payload: dict) -> str:
    raw = jdump(payload).encode()
    return hashlib.sha256(raw).hexdigest()


def seed(args: argparse.Namespace) -> None:
    conn = connect()
    with conn:
        conn.execute(
            "INSERT OR REPLACE INTO licenses(license_id,account_id,slot_count,binding_fp,binding_db_uuid,binding_digest,status) VALUES(?,?,?,?,?,?,?)",
            (args.license_id, args.account_id, 1, args.source_fp, args.source_db_uuid, args.source_digest, "active"),
        )
        conn.execute(
            "INSERT OR REPLACE INTO wallet(license_id,account_id,credits) VALUES(?,?,?)",
            (args.license_id, args.account_id, args.credits),
        )
        conn.execute(
            "INSERT OR REPLACE INTO grants(grant_id,account_id,license_id,capability_code,quantity,quantity_consumed,status,provider) VALUES(?,?,?,?,?,?,?,?)",
            (
                args.grant_id,
                args.account_id,
                args.license_id,
                "migration_token",
                args.credits,
                0,
                "active",
                args.provider,
            ),
        )
    print(jdump({"ok": True, "ledger": db_path(), "grant_id": args.grant_id, "credits": args.credits}))


def eligibility(args: argparse.Namespace) -> None:
    conn = connect()
    g = conn.execute(
        "SELECT * FROM grants WHERE account_id=? AND license_id=? AND capability_code='migration_token' AND status='active'",
        (args.account_id, args.license_id),
    ).fetchone()
    w = conn.execute("SELECT credits FROM wallet WHERE license_id=?", (args.license_id,)).fetchone()
    if not g:
        print(jdump({"status": "unavailable", "available_quantity": 0, "code": "MIGRATION_TOKEN_NOT_ELIGIBLE"}))
        return
    rem = int(g["quantity"]) - int(g["quantity_consumed"])
    wallet = int(w["credits"]) if w else 0
    consistent = rem == wallet
    status = "eligible" if rem >= 1 and wallet >= 1 and consistent else "unavailable"
    code = "MIGRATION_TOKEN_LEDGER_INCONSISTENT" if not consistent else ("OK" if status == "eligible" else "MIGRATION_TOKEN_QUANTITY_INSUFFICIENT")
    print(
        jdump(
            {
                "status": status,
                "available_quantity": rem,
                "wallet_credits": wallet,
                "grant_id": g["grant_id"],
                "provider": g["provider"],
                "ledger_consistent": consistent,
                "code": code,
                "consumed": False,
                "reserved": False,
            }
        )
    )


def commit(args: argparse.Namespace) -> None:
    payload = json.loads(args.payload_json)
    rh = payload.get("request_hash") or request_hash({k: v for k, v in payload.items() if k != "request_hash"})
    payload["request_hash"] = rh
    conn = connect()
    try:
        with conn:
            # Serialize per license
            conn.execute("BEGIN IMMEDIATE")
            existing = conn.execute(
                "SELECT * FROM idempotency WHERE account_id=? AND idempotency_key=?",
                (payload["account_id"], payload["idempotency_key"]),
            ).fetchone()
            if existing:
                if existing["request_hash"] != rh:
                    raise RuntimeError("MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT")
                auth = conn.execute(
                    "SELECT body_json FROM authorizations WHERE authorization_id=?",
                    (existing["authorization_id"],),
                ).fetchone()
                print(auth["body_json"])
                return

            lic = conn.execute(
                "SELECT * FROM licenses WHERE license_id=? AND account_id=?",
                (payload["license_id"], payload["account_id"]),
            ).fetchone()
            if not lic:
                raise RuntimeError("MIGRATION_LICENSE_BINDING_MISMATCH")
            if lic["binding_fp"] and lic["binding_fp"] != payload["source_fp"]:
                raise RuntimeError("MIGRATION_SOURCE_BINDING_INVALID")

            # Conflict: another committed auth for same license
            other = conn.execute(
                "SELECT authorization_id FROM authorizations WHERE license_id=? AND status='committed' LIMIT 1",
                (payload["license_id"],),
            ).fetchone()
            if other:
                raise RuntimeError("MIGRATION_ACTIVE_OPERATION_CONFLICT")

            g = conn.execute(
                "SELECT * FROM grants WHERE grant_id=? AND account_id=? AND license_id=? AND capability_code='migration_token'",
                (payload["grant_id"], payload["account_id"], payload["license_id"]),
            ).fetchone()
            if not g or g["status"] != "active":
                raise RuntimeError("MIGRATION_TOKEN_NOT_ELIGIBLE")
            rem = int(g["quantity"]) - int(g["quantity_consumed"])
            w = conn.execute("SELECT credits FROM wallet WHERE license_id=?", (payload["license_id"],)).fetchone()
            wallet = int(w["credits"]) if w else 0
            if rem < 1 or wallet < 1:
                raise RuntimeError("MIGRATION_TOKEN_QUANTITY_INSUFFICIENT")
            if rem != wallet:
                raise RuntimeError("MIGRATION_TOKEN_LEDGER_INCONSISTENT")

            auth_id = payload.get("authorization_id") or f"mauth-{uuid.uuid4().hex[:16]}"
            qty_before = rem
            qty_after = rem - 1
            new_consumed = int(g["quantity_consumed"]) + 1
            gstatus = "exhausted" if new_consumed >= int(g["quantity"]) else "active"
            conn.execute(
                "UPDATE grants SET quantity_consumed=?, status=? WHERE grant_id=?",
                (new_consumed, gstatus, payload["grant_id"]),
            )
            conn.execute(
                "UPDATE wallet SET credits=? WHERE license_id=?",
                (wallet - 1, payload["license_id"]),
            )
            # Destination binding replaces source binding on license record (logical move; slot_count unchanged)
            slot_before = int(lic["slot_count"])
            conn.execute(
                "UPDATE licenses SET binding_fp=?, binding_db_uuid=?, binding_digest=? WHERE license_id=?",
                (payload["dest_fp"], payload["dest_db_uuid"], payload["dest_digest"], payload["license_id"]),
            )
            body = {
                "schema": "soviez.migration_authorization.v1",
                "authorization_id": auth_id,
                "operation_id": payload.get("operation_id"),
                "idempotency_key": payload["idempotency_key"],
                "request_hash": rh,
                "account_id": payload["account_id"],
                "license_id": payload["license_id"],
                "production_slot_id": payload.get("slot_id") or f"slot-{payload['license_id']}",
                "source_production_id": payload.get("source_production_id"),
                "source_environment_id": payload.get("source_environment_id"),
                "source_device_fingerprint": payload["source_fp"],
                "source_database_uuid": payload.get("source_db_uuid"),
                "source_image_digest": payload.get("source_digest"),
                "destination_environment_id": payload.get("dest_environment_id"),
                "destination_device_fingerprint": payload["dest_fp"],
                "destination_database_uuid": payload.get("dest_db_uuid"),
                "destination_image_digest": payload.get("dest_digest"),
                "migration_pair_id": payload["pair_id"],
                "routing_plan_id": payload.get("routing_plan_id"),
                "transfer_manifest_id": payload.get("manifest_id"),
                "staging_id": payload.get("staging_id"),
                "readiness_id": payload.get("readiness_id"),
                "token_entitlement_id": payload["grant_id"],
                "token_source_type": g["provider"],
                "token_quantity_before": qty_before,
                "token_quantity_after": qty_after,
                "token_consumed_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "source_binding_before": {"fingerprint": payload["source_fp"], "db_uuid": payload.get("source_db_uuid")},
                "destination_binding_after": {"fingerprint": payload["dest_fp"], "db_uuid": payload.get("dest_db_uuid")},
                "source_grace_id": f"grace-{auth_id}",
                "source_grace_state": "migration_origin_grace",
                "destination_status": "production_licensed_pre_cutover",
                "selected_stage_ids": payload.get("stage_ids") or [],
                "stage_rebind_results": [],
                "transaction_status": "committed",
                "commit_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "slot_count_before": slot_before,
                "slot_count_after": slot_before,
                "phase21_allowed": False,
                "production_dns_changed": False,
                "traffic_cutover_started": False,
                "traffic_owner": "source",
                "licensed_future_owner": "destination",
                "signer": "soviez-p20-fixture-ledger",
                "public_signature": hashlib.sha256((auth_id + rh).encode()).hexdigest(),
            }
            stages = payload.get("stage_ids") or []
            mandatory = set(payload.get("mandatory_stage_ids") or [])
            results = []
            for sid in stages:
                # expired stage denial
                if sid.startswith("expired-"):
                    status = "denied_expired"
                    code = "MIGRATION_STAGE_EXPIRED"
                elif sid.startswith("wrong-parent-"):
                    status = "denied_parent"
                    code = "MIGRATION_STAGE_REBIND_FAILED"
                else:
                    status = "rebound"
                    code = "OK"
                results.append({"stage_id": sid, "status": status, "code": code, "mandatory": sid in mandatory, "retention_deadline_unchanged": True})
                conn.execute(
                    "INSERT INTO stage_rebinds(authorization_id,stage_id,mandatory,status,retention_deadline) VALUES(?,?,?,?,?)",
                    (auth_id, sid, 1 if sid in mandatory else 0, status, payload.get("retention_deadline") or "unchanged"),
                )
            body["stage_rebind_results"] = results

            conn.execute(
                "INSERT INTO authorizations(authorization_id,account_id,license_id,pair_id,readiness_id,staging_id,grant_id,idempotency_key,request_hash,body_json,status,committed_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    auth_id,
                    payload["account_id"],
                    payload["license_id"],
                    payload["pair_id"],
                    payload.get("readiness_id"),
                    payload.get("staging_id"),
                    payload["grant_id"],
                    payload["idempotency_key"],
                    rh,
                    jdump(body),
                    "committed",
                    time.time(),
                ),
            )
            conn.execute(
                "INSERT INTO idempotency(account_id,idempotency_key,request_hash,authorization_id) VALUES(?,?,?,?)",
                (payload["account_id"], payload["idempotency_key"], rh, auth_id),
            )
            conn.execute(
                "INSERT INTO bindings(authorization_id,license_id,source_fp,dest_fp,source_db_uuid,dest_db_uuid,slot_count) VALUES(?,?,?,?,?,?,?)",
                (
                    auth_id,
                    payload["license_id"],
                    payload["source_fp"],
                    payload["dest_fp"],
                    payload.get("source_db_uuid"),
                    payload.get("dest_db_uuid"),
                    slot_before,
                ),
            )
            conn.execute(
                "INSERT INTO source_grace(authorization_id,license_id,source_fp,traffic_owner,state) VALUES(?,?,?,?,?)",
                (auth_id, payload["license_id"], payload["source_fp"], "source", "migration_origin_grace"),
            )
            conn.execute(
                "INSERT INTO audit(authorization_id,event,payload,created_at) VALUES(?,?,?,?)",
                (auth_id, "committed", jdump({"token_quantity_after": qty_after, "slot_count": slot_before}), time.time()),
            )
            print(jdump(body))
    except RuntimeError as e:
        print(jdump({"ok": False, "code": str(e), "message": str(e)}), file=sys.stderr)
        sys.exit(25)
    except Exception as e:
        print(jdump({"ok": False, "code": "MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN", "message": str(e)}), file=sys.stderr)
        sys.exit(25)


def get_by_idempotency(args: argparse.Namespace) -> None:
    conn = connect()
    row = conn.execute(
        "SELECT a.body_json FROM idempotency i JOIN authorizations a ON a.authorization_id=i.authorization_id WHERE i.account_id=? AND i.idempotency_key=?",
        (args.account_id, args.idempotency_key),
    ).fetchone()
    if not row:
        print(jdump({"ok": False, "code": "MIGRATION_AUTHORIZATION_REQUIRED"}))
        sys.exit(25)
    print(row["body_json"])


def register_offline(args: argparse.Namespace) -> None:
    conn = connect()
    try:
        with conn:
            exists = conn.execute("SELECT 1 FROM offline_replay WHERE package_id=?", (args.package_id,)).fetchone()
            if exists:
                raise RuntimeError("MIGRATION_AUTHORIZATION_REPLAY_DENIED")
            conn.execute(
                "INSERT INTO offline_replay(package_id,authorization_id,used_at) VALUES(?,?,?)",
                (args.package_id, args.authorization_id, time.time()),
            )
        print(jdump({"ok": True, "package_id": args.package_id}))
    except RuntimeError as e:
        print(jdump({"ok": False, "code": str(e)}), file=sys.stderr)
        sys.exit(25)


def snapshot(args: argparse.Namespace) -> None:
    conn = connect()
    g = conn.execute(
        "SELECT quantity, quantity_consumed, status FROM grants WHERE license_id=? AND capability_code='migration_token'",
        (args.license_id,),
    ).fetchone()
    w = conn.execute("SELECT credits FROM wallet WHERE license_id=?", (args.license_id,)).fetchone()
    lic = conn.execute("SELECT slot_count, binding_fp FROM licenses WHERE license_id=?", (args.license_id,)).fetchone()
    n_auth = conn.execute(
        "SELECT count(*) AS c FROM authorizations WHERE license_id=? AND status='committed'",
        (args.license_id,),
    ).fetchone()["c"]
    print(
        jdump(
            {
                "grant_remaining": (int(g["quantity"]) - int(g["quantity_consumed"])) if g else 0,
                "wallet_credits": int(w["credits"]) if w else 0,
                "slot_count": int(lic["slot_count"]) if lic else 0,
                "binding_fp": lic["binding_fp"] if lic else None,
                "committed_authorizations": n_auth,
            }
        )
    )


def main() -> None:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("seed")
    s.add_argument("--account-id", required=True)
    s.add_argument("--license-id", required=True)
    s.add_argument("--grant-id", required=True)
    s.add_argument("--credits", type=int, default=1)
    s.add_argument("--provider", default="fixture")
    s.add_argument("--source-fp", required=True)
    s.add_argument("--source-db-uuid", required=True)
    s.add_argument("--source-digest", required=True)

    e = sub.add_parser("eligibility")
    e.add_argument("--account-id", required=True)
    e.add_argument("--license-id", required=True)

    c = sub.add_parser("commit")
    c.add_argument("--payload-json", required=True)

    g = sub.add_parser("get")
    g.add_argument("--account-id", required=True)
    g.add_argument("--idempotency-key", required=True)

    o = sub.add_parser("offline-register")
    o.add_argument("--package-id", required=True)
    o.add_argument("--authorization-id", required=True)

    sn = sub.add_parser("snapshot")
    sn.add_argument("--license-id", required=True)

    args = p.parse_args()
    {"seed": seed, "eligibility": eligibility, "commit": commit, "get": get_by_idempotency, "offline-register": register_offline, "snapshot": snapshot}[
        args.cmd
    ](args)


if __name__ == "__main__":
    main()
