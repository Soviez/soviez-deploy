import { createHash } from "node:crypto";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

export const MOCK_REPOSITORY = "soviez/soviez-erp";

function digestOf(data: Buffer | string): string {
  return `sha256:${createHash("sha256").update(data).digest("hex")}`;
}

/** Small fixture blobs for in-process mock registry. */
export const MOCK_CONFIG_BLOB = Buffer.from(
  JSON.stringify({
    architecture: "amd64",
    os: "linux",
    config: { Env: ["PATH=/usr/local/bin"] },
  }),
  "utf8"
);

export const MOCK_LAYER_ONE = Buffer.from("soviez-layer-one-fixture-content", "utf8");
export const MOCK_LAYER_TWO = Buffer.from("soviez-layer-two-fixture-content-v2", "utf8");

export const MOCK_CONFIG_DIGEST = digestOf(MOCK_CONFIG_BLOB);
export const MOCK_LAYER_ONE_DIGEST = digestOf(MOCK_LAYER_ONE);
export const MOCK_LAYER_TWO_DIGEST = digestOf(MOCK_LAYER_TWO);

export const MOCK_MANIFEST = {
  schemaVersion: 2,
  mediaType: "application/vnd.docker.distribution.manifest.v2+json",
  config: {
    mediaType: "application/vnd.docker.container.image.v1+json",
    size: MOCK_CONFIG_BLOB.length,
    digest: MOCK_CONFIG_DIGEST,
  },
  layers: [
    {
      mediaType: "application/vnd.docker.container.image.v1.tar+gzip",
      size: MOCK_LAYER_ONE.length,
      digest: MOCK_LAYER_ONE_DIGEST,
    },
    {
      mediaType: "application/vnd.docker.container.image.v1.tar+gzip",
      size: MOCK_LAYER_TWO.length,
      digest: MOCK_LAYER_TWO_DIGEST,
    },
  ],
};

export const MOCK_MANIFEST_BODY = Buffer.from(
  JSON.stringify(MOCK_MANIFEST),
  "utf8"
);

export const MOCK_MANIFEST_DIGEST = digestOf(MOCK_MANIFEST_BODY);

const blobs = new Map<string, Buffer>([
  [MOCK_CONFIG_DIGEST, MOCK_CONFIG_BLOB],
  [MOCK_LAYER_ONE_DIGEST, MOCK_LAYER_ONE],
  [MOCK_LAYER_TWO_DIGEST, MOCK_LAYER_TWO],
]);

function parseRange(
  header: string | undefined,
  size: number
): { start: number; end: number } | null {
  if (!header) return null;
  const match = /^bytes=(\d*)-(\d*)$/i.exec(header.trim());
  if (!match) return null;
  let start = match[1] ? parseInt(match[1], 10) : 0;
  let end = match[2] ? parseInt(match[2], 10) : size - 1;
  if (Number.isNaN(start) || Number.isNaN(end)) return null;
  if (match[1] === "" && match[2] !== "") {
    // suffix range: bytes=-500
    const suffix = parseInt(match[2], 10);
    if (Number.isNaN(suffix)) return null;
    start = Math.max(0, size - suffix);
    end = size - 1;
  }
  if (start < 0 || end >= size || start > end) return null;
  return { start, end };
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function handleRequest(req: IncomingMessage, res: ServerResponse): void {
  const url = new URL(req.url ?? "/", "http://mock.local");
  const path = url.pathname;

  if (req.method === "GET" && (path === "/health" || path === "/v2/")) {
    res.writeHead(200, {
      "docker-distribution-api-version": "registry/2.0",
    });
    res.end();
    return;
  }

  const manifestMatch = /^\/v2\/(.+)\/manifests\/(.+)$/.exec(path);
  if (manifestMatch && (req.method === "GET" || req.method === "HEAD")) {
    const repo = manifestMatch[1]!;
    const reference = decodeURIComponent(manifestMatch[2]!);
    if (repo !== MOCK_REPOSITORY) {
      sendJson(res, 404, { errors: [{ code: "MANIFEST_UNKNOWN" }] });
      return;
    }
    const refDigest =
      reference.startsWith("sha256:") ? reference : `sha256:${reference}`;
    if (refDigest !== MOCK_MANIFEST_DIGEST) {
      sendJson(res, 404, { errors: [{ code: "MANIFEST_UNKNOWN" }] });
      return;
    }
    res.writeHead(200, {
      "content-type": "application/vnd.docker.distribution.manifest.v2+json",
      "docker-content-digest": MOCK_MANIFEST_DIGEST,
      "content-length": String(MOCK_MANIFEST_BODY.length),
    });
    if (req.method === "HEAD") {
      res.end();
    } else {
      res.end(MOCK_MANIFEST_BODY);
    }
    return;
  }

  const blobMatch = /^\/v2\/(.+)\/blobs\/(.+)$/.exec(path);
  if (blobMatch && (req.method === "GET" || req.method === "HEAD")) {
    const repo = blobMatch[1]!;
    const digest = decodeURIComponent(blobMatch[2]!);
    if (repo !== MOCK_REPOSITORY) {
      sendJson(res, 404, { errors: [{ code: "BLOB_UNKNOWN" }] });
      return;
    }
    const blob = blobs.get(digest);
    if (!blob) {
      sendJson(res, 404, { errors: [{ code: "BLOB_UNKNOWN" }] });
      return;
    }

    const range = parseRange(req.headers.range, blob.length);
    if (range) {
      const slice = blob.subarray(range.start, range.end + 1);
      res.writeHead(206, {
        "content-type": "application/octet-stream",
        "accept-ranges": "bytes",
        "content-range": `bytes ${range.start}-${range.end}/${blob.length}`,
        "content-length": String(slice.length),
      });
      if (req.method === "HEAD") {
        res.end();
      } else {
        res.end(slice);
      }
      return;
    }

    res.writeHead(200, {
      "content-type": "application/octet-stream",
      "accept-ranges": "bytes",
      "content-length": String(blob.length),
    });
    if (req.method === "HEAD") {
      res.end();
    } else {
      res.end(blob);
    }
    return;
  }

  if (req.method === "GET" && path === "/v2/_catalog") {
    sendJson(res, 200, { repositories: [MOCK_REPOSITORY] });
    return;
  }

  if (req.method === "GET" && /\/v2\/.+\/tags\/list$/.test(path)) {
    sendJson(res, 200, { name: MOCK_REPOSITORY, tags: ["latest"] });
    return;
  }

  if (["PUT", "POST", "PATCH", "DELETE"].includes(req.method ?? "")) {
    sendJson(res, 405, { errors: [{ code: "METHOD_NOT_ALLOWED" }] });
    return;
  }

  sendJson(res, 404, { errors: [{ code: "NOT_FOUND" }] });
}

export function startMockUpstream(): Promise<{
  server: ReturnType<typeof createServer>;
  port: number;
  baseUrl: string;
}> {
  return new Promise((resolve, reject) => {
    const server = createServer(handleRequest);
    server.listen(0, "127.0.0.1", () => {
      const addr = server.address();
      if (!addr || typeof addr === "string") {
        reject(new Error("Failed to bind mock upstream"));
        return;
      }
      resolve({
        server,
        port: addr.port,
        baseUrl: `http://127.0.0.1:${addr.port}`,
      });
    });
    server.on("error", reject);
  });
}

export function stopMockUpstream(
  server: ReturnType<typeof createServer>
): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((err) => (err ? reject(err) : resolve()));
  });
}
