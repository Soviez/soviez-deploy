#!/usr/bin/env node
/**
 * Disposable offline Stage authorization package issuer for isolated tests.
 * Never uses production keys. Output: package JSON + tooling bundle dir.
 */
import {
  createPrivateKey,
  generateKeyPairSync,
  randomBytes,
  sign,
  createHash,
} from "node:crypto";
import { mkdirSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

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
mkdirSync(outDir, { recursive: true });

const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const spki = publicKey.export({ type: "spki", format: "der" });
const raw = spki.subarray(spki.length - 32);
const keyId = "sok_offline_" + createHash("sha256").update(raw).digest("hex").slice(0, 8);
const now = Math.floor(Date.now() / 1000);

const toolingDigest =
  claimsIn.tooling_digest ||
  "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const releaseDigest =
  claimsIn.release_digest ||
  "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

const claims = {
  typ: "soviez.stage-operation.v1",
  protocol_version: "stage-operation/v1",
  jti: b64url(randomBytes(12)),
  operation_id: claimsIn.operation_id || "op-offline-1",
  operation_type: claimsIn.operation_type || "stage_create",
  subject_pseudonym: "sub_offline",
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
  release_digest: releaseDigest,
  tooling_artifact_id: "stage-tooling-offline-v1",
  tooling_digest: toolingDigest,
  architecture: claimsIn.architecture || "linux/amd64",
  entitlement_decision_ref: "ent:offline",
  delivery_trace_id: "del_offline",
  iat: now,
  exp: claimsIn.exp || now + 3600,
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

const toolingDir = join(outDir, "tooling");
mkdirSync(toolingDir, { recursive: true });
writeFileSync(join(toolingDir, "ARTIFACT.digest"), toolingDigest);
writeFileSync(
  join(toolingDir, "tooling.meta.json"),
  JSON.stringify(
    {
      digest: toolingDigest,
      signed: true,
      artifact_id: "stage-tooling-offline-v1",
      no_production_secrets: true,
    },
    null,
    2
  )
);
writeFileSync(join(toolingDir, "neutralize.sh"), "#!/bin/sh\necho offline-tooling\n");

const startBefore = new Date((claimsIn.start_before_epoch || now + 3600) * 1000).toISOString();

const pkg = {
  typ: "soviez.stage-offline-auth.v1",
  protocol_version: "stage-operation/v1",
  package_id: "pkg_" + b64url(randomBytes(8)),
  authorization_id: claimsIn.authorization_id || "offline-auth-" + b64url(randomBytes(4)),
  operation_id: claims.operation_id,
  signer_key_id: keyId,
  start_before: startBefore,
  ticket_token: token,
  public_keys: keys,
  bindings: {
    license_id: claims.license_id,
    production_fingerprint: claims.production_fingerprint,
    database_uuid: claims.database_uuid,
    stage_id: claims.stage_id,
    stage_domain: claims.stage_domain,
    host_pubkey_fingerprint: claims.host_pubkey_fingerprint,
    architecture: claims.architecture,
    release_digest: releaseDigest,
    tooling_digest: toolingDigest,
    operation_id: claims.operation_id,
    operation_type: claims.operation_type,
  },
  tooling: {
    digest: toolingDigest,
    bundle_path: "tooling",
    artifact_id: "stage-tooling-offline-v1",
  },
  release: {
    digest: releaseDigest,
    id: claims.release_id,
  },
};

const pkgPath = join(outDir, "offline-package.json");
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
writeFileSync(join(outDir, "keys.json"), JSON.stringify(keys));
writeFileSync(join(outDir, "ticket.token"), token);
// Never write private key into the package directory.
console.log(JSON.stringify({ package: pkgPath, keyId, package_id: pkg.package_id }));
