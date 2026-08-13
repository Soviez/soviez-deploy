#!/usr/bin/env node
/**
 * Disposable Stage Operation Ticket issuer for isolated tests only.
 * Domain: soviez.stage-operation.v1 — never uses production keys.
 */
import {
  createPrivateKey,
  generateKeyPairSync,
  randomBytes,
  sign,
  createHash,
} from "node:crypto";
import { writeFileSync } from "node:fs";

function b64url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === "object") {
    const out = {};
    for (const k of Object.keys(value).sort()) out[k] = sortKeys(value[k]);
    return out;
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(sortKeys(value));
}

const claimsIn = JSON.parse(process.argv[2] || "{}");
const outDir = process.argv[3] || ".";

const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const spki = publicKey.export({ type: "spki", format: "der" });
const raw = spki.subarray(spki.length - 32);
const keyId = "sok_test_" + createHash("sha256").update(raw).digest("hex").slice(0, 8);
const now = Math.floor(Date.now() / 1000);

const claims = {
  typ: "soviez.stage-operation.v1",
  protocol_version: "stage-operation/v1",
  jti: b64url(randomBytes(12)),
  operation_id: claimsIn.operation_id || "op-test",
  operation_type: claimsIn.operation_type || "stage_create",
  subject_pseudonym: "sub_test",
  account_id: claimsIn.account_id || "11111111-1111-1111-1111-111111111111",
  license_id: claimsIn.license_id,
  device_id: claimsIn.device_id || "dddddddd-dddd-dddd-dddd-dddddddddddd",
  device_pubkey_fingerprint: claimsIn.device_pubkey_fingerprint || "fp_device",
  host_pubkey_fingerprint: claimsIn.host_pubkey_fingerprint || "fp_host_fixture",
  production_fingerprint: claimsIn.production_fingerprint,
  database_uuid: claimsIn.database_uuid,
  stage_id: claimsIn.stage_id,
  stage_domain: claimsIn.stage_domain,
  release_id: claimsIn.release_id || "cccccccc-cccc-cccc-cccc-cccccccccccc",
  release_digest: claimsIn.release_digest,
  tooling_artifact_id: "stage-tooling-fixture-v1",
  tooling_digest: claimsIn.tooling_digest,
  architecture: claimsIn.architecture || "linux/amd64",
  entitlement_decision_ref: "ent:test",
  delivery_trace_id: "del_test",
  iat: now,
  exp: now + 3600,
  nonce: b64url(randomBytes(8)),
  signer_key_id: keyId,
};

const canonical = canonicalJson(claims);
const sig = sign(
  null,
  Buffer.from(`soviez.stage-operation.v1\n${canonical}`, "utf8"),
  createPrivateKey(privateKey.export({ type: "pkcs8", format: "pem" }))
);
const token = `${b64url(Buffer.from(canonical, "utf8"))}.${b64url(sig)}`;
const keys = { [keyId]: b64url(raw) };

writeFileSync(`${outDir}/ticket.token`, token);
writeFileSync(`${outDir}/keys.json`, JSON.stringify(keys));
writeFileSync(`${outDir}/claims.json`, JSON.stringify(claims, null, 2));
console.log(JSON.stringify({ token, keyId, keys }));
