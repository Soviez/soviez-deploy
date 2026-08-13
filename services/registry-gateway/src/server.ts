import {
  createServer,
  type IncomingMessage,
  type Server,
  type ServerResponse,
} from "node:http";
import {
  authenticateRequest,
  buildTokenExchange,
  buildWwwAuthenticate,
  denyUnsafeAuthScope,
  denialHttpStatus,
  isDenialBody,
  RateLimiter,
  type GatewayConfig,
} from "./auth.js";
import { REGISTRY_DENIAL_CODES, denialResponse } from "./denial.js";
import {
  SessionGraphCache,
  normalizeDigest,
  normalizeRepository,
  repositoryMatches,
} from "./graph.js";
import { fetchUpstreamBody, proxyUpstream, type UpstreamConfig } from "./proxy.js";
import { safeError, safeLog } from "./redact.js";

export interface RegistryGatewayOptions {
  port: number;
  host?: string;
  gatewayConfig: GatewayConfig;
  upstream: UpstreamConfig;
  graphCache?: SessionGraphCache;
  /** Require public keys configured before /ready succeeds. */
  requireKeysForReady?: boolean;
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function sendDenial(
  res: ServerResponse,
  status: number,
  code: string,
  message: string
): void {
  sendJson(res, status, { code, message });
}

function requestBaseUrl(req: IncomingMessage): string {
  const host = req.headers.host ?? "localhost";
  const proto = req.headers["x-forwarded-proto"] ?? "http";
  return `${proto}://${host}`;
}

export function createRegistryGateway(
  options: RegistryGatewayOptions
): Server {
  const graphCache = options.graphCache ?? new SessionGraphCache();
  const serviceName = options.gatewayConfig.serviceName ?? "soviez-registry";
  const rateLimiter = new RateLimiter(
    options.gatewayConfig.rateLimitPerMinute ?? 120
  );

  const server = createServer(async (req, res) => {
    try {
      await handleRequest(req, res);
    } catch (err) {
      safeError("request handler error", err);
      if (!res.headersSent) {
        sendDenial(
          res,
          500,
          REGISTRY_DENIAL_CODES.INTERNAL_ERROR,
          "Internal server error"
        );
      }
    }
  });

  async function handleRequest(
    req: IncomingMessage,
    res: ServerResponse
  ): Promise<void> {
    const method = req.method ?? "GET";
    const url = new URL(req.url ?? "/", "http://gateway.local");
    const path = url.pathname;
    const baseUrl = requestBaseUrl(req);
    const clientKey =
      (req.headers["x-forwarded-for"] as string | undefined)?.split(",")[0]?.trim() ||
      req.socket.remoteAddress ||
      "unknown";

    // /live = process liveness (no dependency check)
    if (method === "GET" && (path === "/live" || path === "/health")) {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
      return;
    }

    // /ready = keys configured; never leaks secrets or upstream status details
    if (method === "GET" && path === "/ready") {
      const keyCount = Object.keys(options.gatewayConfig.publicKeysById).length;
      const requireKeys = options.requireKeysForReady !== false;
      if (requireKeys && keyCount === 0) {
        sendJson(res, 503, { status: "not_ready", reason: "keys_unconfigured" });
        return;
      }
      sendJson(res, 200, { status: "ok", keys_configured: keyCount > 0 });
      return;
    }

    if (!rateLimiter.allow(clientKey)) {
      sendDenial(
        res,
        429,
        REGISTRY_DENIAL_CODES.RATE_LIMITED,
        "Rate limit exceeded"
      );
      return;
    }

    if (method === "GET" && path === "/auth/token") {
      const service = url.searchParams.get("service");
      if (service && service !== serviceName) {
        sendDenial(
          res,
          403,
          REGISTRY_DENIAL_CODES.AUDIENCE_DENIED,
          "Wrong token service/audience"
        );
        return;
      }
      const scopeDeny = denyUnsafeAuthScope(url.searchParams.get("scope"));
      if (scopeDeny) {
        sendDenial(res, 403, scopeDeny.code, scopeDeny.message);
        return;
      }
      const auth = authenticateRequest(req, options.gatewayConfig);
      if (isDenialBody(auth)) {
        sendDenial(res, denialHttpStatus(auth), auth.code, auth.message);
        return;
      }
      // Never include upstream credentials in token response
      const exchange = buildTokenExchange(auth);
      graphCache.seedSession(auth.claims.session_id, auth.claims.digest);
      safeLog("token_exchange", {
        request_id: auth.claims.jti.slice(0, 12),
        session_id_prefix: auth.claims.session_id.slice(0, 8),
        repository: auth.claims.repository,
        result: "ok",
      });
      sendJson(res, 200, exchange);
      return;
    }

    if (path === "/v2/" && method === "GET") {
      const auth = authenticateRequest(req, options.gatewayConfig);
      if (isDenialBody(auth)) {
        res.writeHead(401, {
          "www-authenticate": buildWwwAuthenticate(baseUrl, serviceName),
          "docker-distribution-api-version": "registry/2.0",
          "content-type": "application/json",
        });
        res.end(
          JSON.stringify({
            errors: [{ code: "UNAUTHORIZED", message: "authentication required" }],
          })
        );
        return;
      }
      graphCache.seedSession(auth.claims.session_id, auth.claims.digest);
      res.writeHead(200, {
        "docker-distribution-api-version": "registry/2.0",
      });
      res.end();
      return;
    }

    if (method === "GET" && path === "/v2/_catalog") {
      sendDenial(
        res,
        403,
        REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED,
        "Catalog access denied"
      );
      return;
    }

    if (method === "GET" && /\/v2\/.+\/tags\/list$/.test(path)) {
      sendDenial(
        res,
        403,
        REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED,
        "Tag listing denied"
      );
      return;
    }

    if (["PUT", "POST", "PATCH", "DELETE"].includes(method)) {
      sendDenial(
        res,
        405,
        REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED,
        "Write operations denied"
      );
      return;
    }

    const manifestMatch = /^\/v2\/(.+)\/manifests\/(.+)$/.exec(path);
    if (manifestMatch && (method === "GET" || method === "HEAD")) {
      const auth = authenticateRequest(req, options.gatewayConfig);
      if (isDenialBody(auth)) {
        sendDenial(res, denialHttpStatus(auth), auth.code, auth.message);
        return;
      }

      const repo = normalizeRepository(decodeURIComponent(manifestMatch[1]!));
      const reference = decodeURIComponent(manifestMatch[2]!);

      if (!repositoryMatches(auth.claims, repo)) {
        sendDenial(
          res,
          403,
          REGISTRY_DENIAL_CODES.REPOSITORY_SCOPE_DENIED,
          "Repository not authorized"
        );
        return;
      }

      graphCache.seedSession(auth.claims.session_id, auth.claims.digest);

      if (!graphCache.isManifestAuthorized(auth.claims, reference)) {
        sendDenial(
          res,
          403,
          REGISTRY_DENIAL_CODES.BLOB_SCOPE_DENIED,
          "Manifest digest not authorized"
        );
        return;
      }

      const upstreamPath = `/v2/${repo}/manifests/${reference}`;

      if (method === "GET") {
        const fetched = await fetchUpstreamBody(options.upstream, upstreamPath);
        if (fetched.status < 200 || fetched.status >= 300) {
          sendDenial(
            res,
            fetched.status === 404 ? 404 : 502,
            REGISTRY_DENIAL_CODES.UPSTREAM_UNAVAILABLE,
            "Upstream manifest unavailable"
          );
          return;
        }
        graphCache.ingestManifest(auth.claims.session_id, fetched.body);
        const headers: Record<string, string> = {};
        for (const [key, value] of Object.entries(fetched.headers)) {
          if (!value) continue;
          headers[key] = Array.isArray(value) ? value.join(", ") : value;
        }
        res.writeHead(200, headers);
        res.end(fetched.body);
        return;
      }

      await proxyUpstream(
        options.upstream,
        method,
        upstreamPath,
        req,
        res
      );
      return;
    }

    const blobMatch = /^\/v2\/(.+)\/blobs\/(.+)$/.exec(path);
    if (blobMatch && (method === "GET" || method === "HEAD")) {
      const auth = authenticateRequest(req, options.gatewayConfig);
      if (isDenialBody(auth)) {
        sendDenial(res, denialHttpStatus(auth), auth.code, auth.message);
        return;
      }

      const repo = normalizeRepository(decodeURIComponent(blobMatch[1]!));
      const digest = normalizeDigest(decodeURIComponent(blobMatch[2]!));

      if (!repositoryMatches(auth.claims, repo)) {
        sendDenial(
          res,
          403,
          REGISTRY_DENIAL_CODES.REPOSITORY_SCOPE_DENIED,
          "Repository not authorized"
        );
        return;
      }

      graphCache.seedSession(auth.claims.session_id, auth.claims.digest);

      if (!graphCache.isBlobAuthorized(auth.claims, digest)) {
        sendDenial(
          res,
          403,
          REGISTRY_DENIAL_CODES.BLOB_SCOPE_DENIED,
          "Blob digest not authorized"
        );
        return;
      }

      const upstreamPath = `/v2/${repo}/blobs/${digest}`;
      await proxyUpstream(options.upstream, method, upstreamPath, req, res);
      return;
    }

    sendDenial(
      res,
      404,
      REGISTRY_DENIAL_CODES.INVALID_REQUEST,
      "Not found"
    );
  }

  return server;
}

export function startRegistryGateway(
  options: RegistryGatewayOptions
): Promise<{ server: Server; port: number }> {
  const server = createRegistryGateway(options);
  const host = options.host ?? "0.0.0.0";
  return new Promise((resolve, reject) => {
    server.listen(options.port, host, () => {
      const addr = server.address();
      if (!addr || typeof addr === "string") {
        reject(new Error("Failed to bind gateway"));
        return;
      }
      safeLog(`registry-gateway listening on ${host}:${addr.port}`);
      resolve({ server, port: addr.port });
    });
    server.on("error", reject);
  });
}

export function stopRegistryGateway(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((err) => (err ? reject(err) : resolve()));
  });
}
