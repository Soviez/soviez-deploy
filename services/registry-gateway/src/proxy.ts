import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import type { IncomingHttpHeaders, IncomingMessage, ServerResponse } from "node:http";
import { pipeline } from "node:stream/promises";
import { safeError } from "./redact.js";

export interface UpstreamConfig {
  /** Full base URL override (tests), e.g. http://127.0.0.1:9999 */
  baseUrl?: string;
  host: string;
  user?: string;
  token?: string;
}

const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailers",
  "transfer-encoding",
  "upgrade",
]);

const FORWARD_REQUEST_HEADERS = [
  "accept",
  "accept-encoding",
  "if-none-match",
  "range",
  "user-agent",
];

const FORWARD_RESPONSE_HEADERS = [
  "content-type",
  "content-length",
  "content-range",
  "accept-ranges",
  "docker-content-digest",
  "docker-distribution-api-version",
  "etag",
  "last-modified",
  "cache-control",
];

function pickHeaders(
  source: IncomingHttpHeaders,
  allowlist: string[]
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const name of allowlist) {
    const value = source[name];
    if (value !== undefined) {
      out[name] = Array.isArray(value) ? value.join(", ") : value;
    }
  }
  return out;
}

function buildUpstreamUrl(
  config: UpstreamConfig,
  path: string
): { url: URL; isHttps: boolean } {
  if (config.baseUrl) {
    const url = new URL(path, config.baseUrl);
    return { url, isHttps: url.protocol === "https:" };
  }
  const url = new URL(`https://${config.host}${path}`);
  return { url, isHttps: true };
}

function upstreamAuthHeader(config: UpstreamConfig): string | undefined {
  if (!config.user || !config.token) return undefined;
  const creds = Buffer.from(`${config.user}:${config.token}`).toString("base64");
  return `Basic ${creds}`;
}

export async function proxyUpstream(
  config: UpstreamConfig,
  method: string,
  path: string,
  clientReq: IncomingMessage,
  clientRes: ServerResponse
): Promise<void> {
  const { url, isHttps } = buildUpstreamUrl(config, path);
  const reqFn = isHttps ? httpsRequest : httpRequest;

  const headers: Record<string, string> = {
    ...pickHeaders(clientReq.headers, FORWARD_REQUEST_HEADERS),
  };

  const auth = upstreamAuthHeader(config);
  if (auth) headers.authorization = auth;

  await new Promise<void>((resolve, reject) => {
    const upstreamReq = reqFn(
      url,
      { method, headers },
      (upstreamRes) => {
        const responseHeaders: Record<string, string | string[]> = {};
        for (const [key, value] of Object.entries(upstreamRes.headers)) {
          if (!value || HOP_BY_HOP.has(key.toLowerCase())) continue;
          if (
            FORWARD_RESPONSE_HEADERS.includes(key.toLowerCase()) ||
            key.toLowerCase().startsWith("x-")
          ) {
            responseHeaders[key] = value;
          }
        }

        clientRes.writeHead(upstreamRes.statusCode ?? 502, responseHeaders);

        pipeline(upstreamRes, clientRes)
          .then(() => resolve())
          .catch((err) => {
            safeError("upstream pipeline error", err);
            reject(err);
          });
      }
    );

    upstreamReq.on("error", (err) => {
      safeError("upstream request error", err);
      if (!clientRes.headersSent) {
        clientRes.writeHead(502, { "content-type": "application/json" });
        clientRes.end(
          JSON.stringify({
            code: "UPSTREAM_UNAVAILABLE",
            message: "Upstream registry unavailable",
          })
        );
      } else {
        clientRes.destroy();
      }
      reject(err);
    });

    upstreamReq.end();
  });
}

/** Collect upstream body for manifest graph ingestion (small payloads only). */
export async function fetchUpstreamBody(
  config: UpstreamConfig,
  path: string
): Promise<{ status: number; headers: IncomingHttpHeaders; body: Buffer }> {
  const { url, isHttps } = buildUpstreamUrl(config, path);
  const reqFn = isHttps ? httpsRequest : httpRequest;

  const headers: Record<string, string> = {
    accept: "application/vnd.docker.distribution.manifest.v2+json",
  };
  const auth = upstreamAuthHeader(config);
  if (auth) headers.authorization = auth;

  return new Promise((resolve, reject) => {
    const req = reqFn(url, { method: "GET", headers }, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => {
        resolve({
          status: res.statusCode ?? 502,
          headers: res.headers,
          body: Buffer.concat(chunks),
        });
      });
      res.on("error", reject);
    });
    req.on("error", reject);
    req.end();
  });
}
