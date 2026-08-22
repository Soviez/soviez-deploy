import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";
import {
  createPrivateKey,
  generateKeyPairSync,
  sign,
} from "node:crypto";
import {
  assertBindings,
  base64UrlEncode,
  canonicalJson,
  STAGE_OPERATION_SIGNING_DOMAIN,
  STAGE_OPERATION_TICKET_TYPE,
  STAGE_OPERATION_PROTOCOL_VERSION,
  verifyStageOperationTicket,
  type StageOperationTicketClaims,
} from "../src/ticket.js";
import { certifyNeutralization, NEUTRALIZATION_CONTROLS } from "../src/neutralization.js";
import { consumeOnce, ticketHash } from "../src/ledger.js";
import { runNeutralizeAndCertify, runVerify } from "../src/cli.js";

function issueTestTicket(
  overrides: Partial<StageOperationTicketClaims> = {}
): { token: string; claims: StageOperationTicketClaims; pub: string; keyId: string } {
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  const spki = publicKey.export({ type: "spki", format: "der" }) as Buffer;
  const raw = spki.subarray(spki.length - 32);
  const keyId = "sok_test";
  const now = Math.floor(Date.now() / 1000);
  const claims: StageOperationTicketClaims = {
    typ: STAGE_OPERATION_TICKET_TYPE,
    protocol_version: STAGE_OPERATION_PROTOCOL_VERSION,
    jti: "jti_test_1",
    operation_id: "op-test-001",
    operation_type: "stage_create",
    subject_pseudonym: "sub_abc",
    account_id: "11111111-1111-1111-1111-111111111111",
    license_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    device_id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
    device_pubkey_fingerprint: "fp_device",
    host_pubkey_fingerprint: "fp_host",
    production_fingerprint: "prod_fp_1",
    database_uuid: "db-uuid-1",
    stage_id: "stage01",
    stage_domain: "stage01.example.com",
    release_id: "rrrrrrrr-rrrr-rrrr-rrrr-rrrrrrrrrrrr",
    release_digest:
      "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    tooling_artifact_id: "stage-tooling-fixture-v1",
    tooling_digest:
      "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    architecture: "linux/amd64",
    entitlement_decision_ref: "ent:test",
    delivery_trace_id: "del_test",
    iat: now,
    exp: now + 900,
    nonce: "nonce1",
    signer_key_id: keyId,
    ...overrides,
  };
  const canonical = canonicalJson(claims);
  const signature = sign(
    null,
    Buffer.from(`${STAGE_OPERATION_SIGNING_DOMAIN}\n${canonical}`, "utf8"),
    createPrivateKey(privateKey.export({ type: "pkcs8", format: "pem" }) as string)
  );
  const token = `${base64UrlEncode(Buffer.from(canonical, "utf8"))}.${base64UrlEncode(signature)}`;
  return { token, claims, pub: base64UrlEncode(raw), keyId };
}

describe("stage-operation-helper verifier", () => {
  it("verifies valid ticket and rejects tampering", () => {
    const t = issueTestTicket();
    const ok = verifyStageOperationTicket(t.token, { [t.keyId]: t.pub });
    assert.equal(ok.ok, true);

    const parts = t.token.split(".");
    const claims = JSON.parse(
      Buffer.from(parts[0]!.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString()
    ) as StageOperationTicketClaims;
    claims.license_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
    const bad =
      base64UrlEncode(Buffer.from(canonicalJson(claims), "utf8")) + "." + parts[1];
    const fail = verifyStageOperationTicket(bad, { [t.keyId]: t.pub });
    assert.equal(fail.ok, false);
    if (!fail.ok) assert.equal(fail.denial_code, "TICKET_SIGNATURE_INVALID");
  });

  it("rejects wrong host / license bindings", () => {
    const t = issueTestTicket();
    const v = verifyStageOperationTicket(t.token, { [t.keyId]: t.pub });
    assert.equal(v.ok, true);
    if (!v.ok) return;
    const badHost = assertBindings(v.claims, {
      ...Object.fromEntries(
        Object.entries(v.claims).map(([k, val]) => [k, String(val)])
      ),
      host_pubkey_fingerprint: "other_host",
    });
    assert.equal(badHost.ok, false);
  });

  it("rejects expired tickets", () => {
    const t = issueTestTicket({
      iat: 1,
      exp: 2,
    });
    const fail = verifyStageOperationTicket(t.token, { [t.keyId]: t.pub }, 100);
    assert.equal(fail.ok, false);
    if (!fail.ok) assert.equal(fail.denial_code, "TICKET_EXPIRED");
  });

  it("local ledger detects offline replay", () => {
    const dir = mkdtempSync(join(tmpdir(), "stage-ledger-"));
    const path = join(dir, "ledger.jsonl");
    const entry = {
      package_or_ticket_hash: "hash1",
      operation_id: "op1",
      stage_id: "stage01",
      consumed_at: new Date().toISOString(),
    };
    assert.equal(consumeOnce(path, entry).ok, true);
    assert.equal(consumeOnce(path, entry).ok, false);
  });

  it("neutralization must pass all controls for origin cert", () => {
    const t = issueTestTicket();
    const partial: Record<string, boolean> = {};
    for (const k of NEUTRALIZATION_CONTROLS) partial[k] = true;
    partial.webhooks_disabled = false;
    const fail = runNeutralizeAndCertify({
      claims: t.claims,
      controls: partial,
    });
    assert.equal(fail.ok, false);
    assert.equal(fail.denial_code, "NEUTRALIZATION_FAILED");
    assert.equal(fail.origin_certificate, null);

    for (const k of NEUTRALIZATION_CONTROLS) partial[k] = true;
    const ok = runNeutralizeAndCertify({
      claims: t.claims,
      controls: partial,
      certificateOutPath: join(mkdtempSync(join(tmpdir(), "soc-")), "origin.json"),
    });
    assert.equal(ok.ok, true);
    assert.ok(ok.origin_certificate);
    assert.equal(
      (ok.origin_certificate as { note: string }).note.includes("phone home"),
      true
    );
  });

  it("runVerify integrates signature + bindings + ledger", () => {
    const t = issueTestTicket();
    const dir = mkdtempSync(join(tmpdir(), "v-"));
    const expected = {
      license_id: t.claims.license_id,
      device_id: t.claims.device_id,
      host_pubkey_fingerprint: t.claims.host_pubkey_fingerprint,
      production_fingerprint: t.claims.production_fingerprint,
      database_uuid: t.claims.database_uuid,
      stage_id: t.claims.stage_id,
      stage_domain: t.claims.stage_domain,
      operation_type: t.claims.operation_type,
      release_digest: t.claims.release_digest,
      tooling_digest: t.claims.tooling_digest,
      architecture: t.claims.architecture,
    };
    const first = runVerify({
      ticketToken: t.token,
      publicKeysById: { [t.keyId]: t.pub },
      expected,
      ledgerPath: join(dir, "ledger.jsonl"),
    });
    assert.equal(first.ok, true);
    const second = runVerify({
      ticketToken: t.token,
      publicKeysById: { [t.keyId]: t.pub },
      expected,
      ledgerPath: join(dir, "ledger.jsonl"),
    });
    assert.equal(second.ok, false);
    assert.ok(ticketHash(t.token).length === 64);
  });

  it("documents that Bash Boolean alone cannot certify", () => {
    const neut = certifyNeutralization({
      stageId: "x",
      operationId: "y",
      controls: {},
    });
    assert.equal(neut.passed, false);
    assert.ok(neut.failed_controls.length > 0);
  });
});
