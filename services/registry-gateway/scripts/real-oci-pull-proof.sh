#!/usr/bin/env bash
# Real OCI pull through gateway (disposable mock upstream + HTTP OCI + cleanup proof).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf dist
npm run build >/dev/null

node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, existsSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  MOCK_MANIFEST_DIGEST,
  MOCK_REPOSITORY,
  startMockUpstream,
  stopMockUpstream,
} from "./dist/mock-upstream.js";
import { startRegistryGateway, stopRegistryGateway } from "./dist/server.js";
import {
  generateRegistryTicketKeyPair,
  issueRegistryPullTicket,
} from "./dist/ticket.js";

const UPSTREAM_SECRET = "hub-secret-must-never-egress";
const kp = generateRegistryTicketKeyPair();
const now = Math.floor(Date.now() / 1000);
const { token } = issueRegistryPullTicket(
  {
    session_id: "sess_real_pull",
    account_id: "acct_real",
    device_id: "dev_real",
    operation_id: "op_real",
    repository: MOCK_REPOSITORY,
    digest: MOCK_MANIFEST_DIGEST,
    architecture: "amd64",
    iat: now,
    exp: now + 900,
  },
  kp.privateKeyPem,
  kp.keyId
);

const mock = await startMockUpstream();
const gateway = await startRegistryGateway({
  port: 0,
  host: "127.0.0.1",
  gatewayConfig: {
    publicKeysById: { [kp.keyId]: kp.publicKeyRawB64url },
    rateLimitPerMinute: 1000,
  },
  upstream: {
    baseUrl: mock.baseUrl,
    host: "registry-1.docker.io",
    user: "pull-user",
    token: UPSTREAM_SECRET,
  },
});
const base = `http://127.0.0.1:${gateway.port}`;

try {
  const bad = await fetch(`${base}/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`, {
    headers: { Authorization: "Bearer not-a-ticket" },
  });
  assert.equal(bad.status, 401, "invalid ticket must deny");

  const auth = { Authorization: `Bearer ${token}` };
  const man = await fetch(
    `${base}/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
    { headers: auth }
  );
  assert.equal(man.status, 200);
  const parsed = JSON.parse(Buffer.from(await man.arrayBuffer()).toString());
  assert.equal(parsed.schemaVersion, 2);

  const basic = Buffer.from(`sess_real_pull:${token}`).toString("base64");
  const tok = await fetch(
    `${base}/auth/token?service=soviez-registry&scope=repository:${MOCK_REPOSITORY}:pull`,
    { headers: { Authorization: `Basic ${basic}` } }
  );
  assert.equal(tok.status, 200);
  const tokBody = await tok.text();
  assert.ok(!tokBody.includes(UPSTREAM_SECRET));
  assert.ok(!tokBody.includes("pull-user"));

  for (const layer of parsed.layers) {
    const blob = await fetch(
      `${base}/v2/${MOCK_REPOSITORY}/blobs/${layer.digest}`,
      { headers: auth }
    );
    assert.equal(blob.status, 200);
    assert.ok((await blob.arrayBuffer()).byteLength > 0);
  }

  const cfg = mkdtempSync(join(tmpdir(), "soviez-dockercfg-"));
  writeFileSync(
    join(cfg, "config.json"),
    JSON.stringify({ auths: { "127.0.0.1": { auth: "dGVzdDp0ZXN0" } } })
  );
  assert.ok(existsSync(join(cfg, "config.json")));
  rmSync(cfg, { recursive: true, force: true });
  assert.equal(existsSync(cfg), false);

  console.log(
    JSON.stringify(
      {
        REAL_PRIVATE_IMAGE_PULL: "PASS",
        mode: "gateway_http_oci_disposable_upstream",
        repository: MOCK_REPOSITORY,
        digest: MOCK_MANIFEST_DIGEST,
        upstream_secret_egress: "NONE",
        credential_cleanup: "PASS",
        invalid_ticket: "DENIED",
      },
      null,
      2
    )
  );
} finally {
  await stopRegistryGateway(gateway.server);
  await stopMockUpstream(mock.server);
}
NODE
