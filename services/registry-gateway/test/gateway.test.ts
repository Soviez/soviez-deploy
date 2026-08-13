import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";
import {
  MOCK_LAYER_ONE,
  MOCK_LAYER_ONE_DIGEST,
  MOCK_MANIFEST_DIGEST,
  MOCK_REPOSITORY,
  startMockUpstream,
  stopMockUpstream,
} from "../src/mock-upstream.js";
import {
  startRegistryGateway,
  stopRegistryGateway,
} from "../src/server.js";
import {
  generateRegistryTicketKeyPair,
  issueRegistryPullTicket,
} from "../src/ticket.js";

const UPSTREAM_SECRET = "super-secret-hub-token-xyz";

function captureConsole(): {
  logs: string[];
  restore: () => void;
} {
  const logs: string[] = [];
  const origLog = console.log;
  const origError = console.error;
  console.log = (...args: unknown[]) => {
    logs.push(args.map(String).join(" "));
  };
  console.error = (...args: unknown[]) => {
    logs.push(args.map(String).join(" "));
  };
  return {
    logs,
    restore: () => {
      console.log = origLog;
      console.error = origError;
    },
  };
}

async function httpRequest(
  baseUrl: string,
  path: string,
  opts: {
    method?: string;
    headers?: Record<string, string>;
  } = {}
): Promise<{ status: number; headers: Record<string, string>; body: Buffer }> {
  const res = await fetch(`${baseUrl}${path}`, {
    method: opts.method ?? "GET",
    headers: opts.headers,
  });
  const body = Buffer.from(await res.arrayBuffer());
  const headers: Record<string, string> = {};
  res.headers.forEach((value, key) => {
    headers[key.toLowerCase()] = value;
  });
  return { status: res.status, headers, body };
}

describe("registry-gateway", () => {
  let mock: Awaited<ReturnType<typeof startMockUpstream>>;
  let gateway: Awaited<ReturnType<typeof startRegistryGateway>>;
  let gatewayUrl: string;
  let validToken: string;
  let keyPair: ReturnType<typeof generateRegistryTicketKeyPair>;

  before(async () => {
    keyPair = generateRegistryTicketKeyPair();
    const now = Math.floor(Date.now() / 1000);
    validToken = issueRegistryPullTicket(
      {
        session_id: "sess_test_001",
        account_id: "acct_001",
        device_id: "dev_001",
        operation_id: "op_001",
        repository: MOCK_REPOSITORY,
        digest: MOCK_MANIFEST_DIGEST,
        architecture: "amd64",
        iat: now,
        exp: now + 900,
      },
      keyPair.privateKeyPem,
      keyPair.keyId
    ).token;

    mock = await startMockUpstream();

    process.env.SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON = JSON.stringify({
      [keyPair.keyId]: keyPair.publicKeyRawB64url,
    });
    process.env.SOVIEZ_UPSTREAM_BASE_URL = mock.baseUrl;
    process.env.SOVIEZ_UPSTREAM_REGISTRY_USER = "pull-user";
    process.env.SOVIEZ_UPSTREAM_REGISTRY_TOKEN = UPSTREAM_SECRET;

    gateway = await startRegistryGateway({
      port: 0,
      host: "127.0.0.1",
      gatewayConfig: {
        publicKeysById: { [keyPair.keyId]: keyPair.publicKeyRawB64url },
      },
      upstream: {
        baseUrl: mock.baseUrl,
        host: "registry-1.docker.io",
        user: "pull-user",
        token: UPSTREAM_SECRET,
      },
    });
    gatewayUrl = `http://127.0.0.1:${gateway.port}`;
  });

  after(async () => {
    await stopRegistryGateway(gateway.server);
    await stopMockUpstream(mock.server);
  });

  it("live, ready, and health alias return ok", async () => {
    for (const path of ["/live", "/ready", "/health"]) {
      const res = await httpRequest(gatewayUrl, path);
      assert.equal(res.status, 200);
      assert.equal(JSON.parse(res.body.toString()).status, "ok");
    }
  });

  it("REG basic auth token exchange (docker login path)", async () => {
    const basic = Buffer.from(`sess_test_001:${validToken}`).toString("base64");
    const res = await httpRequest(
      gatewayUrl,
      "/auth/token?service=soviez-registry&scope=repository:soviez/soviez-erp:pull",
      { headers: { Authorization: `Basic ${basic}` } }
    );
    assert.equal(res.status, 200);
    const body = JSON.parse(res.body.toString());
    assert.equal(body.token, validToken);
    assert.ok(!JSON.stringify(body).includes(UPSTREAM_SECRET));
  });

  it("REG push scope denied at token endpoint", async () => {
    const res = await httpRequest(
      gatewayUrl,
      "/auth/token?service=soviez-registry&scope=repository:soviez/soviez-erp:push",
      { headers: { Authorization: `Bearer ${validToken}` } }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "METHOD_NOT_ALLOWED");
  });

  it("REG wrong audience/service denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      "/auth/token?service=other-registry",
      { headers: { Authorization: `Bearer ${validToken}` } }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "AUDIENCE_DENIED");
  });

  it("REG wrong license binding denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
      {
        headers: {
          Authorization: `Bearer ${validToken}`,
          "X-Soviez-Account-Id": "wrong-account",
        },
      }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "LICENSE_BINDING_DENIED");
  });

  it("REG wrong device binding denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
      {
        headers: {
          Authorization: `Bearer ${validToken}`,
          "X-Soviez-Device-Id": "wrong-device",
        },
      }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "DEVICE_BINDING_DENIED");
  });

  it("REG rate limit eventually trips on /v2/", async () => {
    const limited = await startRegistryGateway({
      port: 0,
      host: "127.0.0.1",
      gatewayConfig: {
        publicKeysById: { [keyPair.keyId]: keyPair.publicKeyRawB64url },
        rateLimitPerMinute: 3,
      },
      upstream: {
        baseUrl: mock.baseUrl,
        host: "registry-1.docker.io",
        user: "pull-user",
        token: UPSTREAM_SECRET,
      },
    });
    const url = `http://127.0.0.1:${limited.port}`;
    try {
      let last = 200;
      for (let i = 0; i < 6; i++) {
        const res = await httpRequest(url, "/v2/");
        last = res.status;
      }
      assert.equal(last, 429);
    } finally {
      await stopRegistryGateway(limited.server);
    }
  });

  it("unauthorized manifest denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`
    );
    assert.equal(res.status, 401);
  });

  it("GET /v2/ without auth returns 401 with WWW-Authenticate", async () => {
    const res = await httpRequest(gatewayUrl, "/v2/");
    assert.equal(res.status, 401);
    assert.match(
      res.headers["www-authenticate"] ?? "",
      /Bearer realm=.*\/auth\/token.*service="soviez-registry"/
    );
  });

  it("valid ticket allows manifest and blobs", async () => {
    const auth = { Authorization: `Bearer ${validToken}` };

    const manifest = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
      { headers: auth }
    );
    assert.equal(manifest.status, 200);
    const parsed = JSON.parse(manifest.body.toString());
    assert.equal(parsed.schemaVersion, 2);
    assert.ok(parsed.layers.length >= 2);

    const configDigest = parsed.config.digest;
    const layerDigest = parsed.layers[0].digest;

    const configBlob = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/blobs/${configDigest}`,
      { headers: auth }
    );
    assert.equal(configBlob.status, 200);
    assert.ok(configBlob.body.length > 0);

    const layerBlob = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/blobs/${layerDigest}`,
      { headers: auth }
    );
    assert.equal(layerBlob.status, 200);
    assert.equal(layerBlob.body.toString(), MOCK_LAYER_ONE.toString());
  });

  it("auth token exchange returns bearer metadata", async () => {
    const res = await httpRequest(gatewayUrl, "/auth/token", {
      headers: { Authorization: `Bearer ${validToken}` },
    });
    assert.equal(res.status, 200);
    const body = JSON.parse(res.body.toString());
    assert.equal(body.token, validToken);
    assert.ok(body.expires_in > 0);
    assert.ok(body.issued_at);
  });

  it("wrong repo denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/other/repo/manifests/${MOCK_MANIFEST_DIGEST}`,
      { headers: { Authorization: `Bearer ${validToken}` } }
    );
    assert.equal(res.status, 403);
    assert.equal(
      JSON.parse(res.body.toString()).code,
      "REPOSITORY_SCOPE_DENIED"
    );
  });

  it("wrong digest denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/sha256:0000000000000000000000000000000000000000000000000000000000000000`,
      { headers: { Authorization: `Bearer ${validToken}` } }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "BLOB_SCOPE_DENIED");
  });

  it("unauthorized blob digest denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/blobs/sha256:deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef`,
      { headers: { Authorization: `Bearer ${validToken}` } }
    );
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "BLOB_SCOPE_DENIED");
  });

  it("catalog denied", async () => {
    const res = await httpRequest(gatewayUrl, "/v2/_catalog", {
      headers: { Authorization: `Bearer ${validToken}` },
    });
    assert.equal(res.status, 403);
    assert.equal(JSON.parse(res.body.toString()).code, "METHOD_NOT_ALLOWED");
  });

  it("tags list denied", async () => {
    const res = await httpRequest(gatewayUrl, `/v2/${MOCK_REPOSITORY}/tags/list`, {
      headers: { Authorization: `Bearer ${validToken}` },
    });
    assert.equal(res.status, 403);
  });

  it("push denied", async () => {
    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/latest`,
      {
        method: "PUT",
        headers: { Authorization: `Bearer ${validToken}` },
      }
    );
    assert.equal(res.status, 405);
    assert.equal(JSON.parse(res.body.toString()).code, "METHOD_NOT_ALLOWED");
  });

  it("expired ticket denied", async () => {
    const now = Math.floor(Date.now() / 1000);
    const expired = issueRegistryPullTicket(
      {
        session_id: "sess_expired",
        account_id: "acct_001",
        device_id: "dev_001",
        operation_id: "op_expired",
        repository: MOCK_REPOSITORY,
        digest: MOCK_MANIFEST_DIGEST,
        architecture: "amd64",
        iat: now - 3600,
        exp: now - 60,
      },
      keyPair.privateKeyPem,
      keyPair.keyId
    ).token;

    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
      { headers: { Authorization: `Bearer ${expired}` } }
    );
    assert.equal(res.status, 401);
    assert.equal(
      JSON.parse(res.body.toString()).code,
      "PULL_SESSION_EXPIRED"
    );
  });

  it("range request works on layer blob", async () => {
    const auth = { Authorization: `Bearer ${validToken}` };

    // Ensure graph is populated
    await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
      { headers: auth }
    );

    const res = await httpRequest(
      gatewayUrl,
      `/v2/${MOCK_REPOSITORY}/blobs/${MOCK_LAYER_ONE_DIGEST}`,
      {
        headers: {
          ...auth,
          Range: "bytes=0-4",
        },
      }
    );
    assert.equal(res.status, 206);
    assert.match(res.headers["content-range"] ?? "", /^bytes 0-4\//);
    assert.equal(res.body.length, 5);
    assert.equal(
      res.body.toString(),
      MOCK_LAYER_ONE.subarray(0, 5).toString()
    );
  });

  it("secrets absent from logs", async () => {
    const capture = captureConsole();
    try {
      await httpRequest(
        gatewayUrl,
        `/v2/${MOCK_REPOSITORY}/manifests/${MOCK_MANIFEST_DIGEST}`,
        { headers: { Authorization: `Bearer ${validToken}` } }
      );
      await httpRequest(
        gatewayUrl,
        `/v2/${MOCK_REPOSITORY}/blobs/${MOCK_LAYER_ONE_DIGEST}`,
        { headers: { Authorization: `Bearer ${validToken}` } }
      );

      const combined = capture.logs.join("\n");
      assert.doesNotMatch(combined, new RegExp(UPSTREAM_SECRET));
      assert.doesNotMatch(combined, new RegExp(validToken));
    } finally {
      capture.restore();
    }
  });
});
