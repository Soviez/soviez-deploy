import type { IncomingMessage } from "node:http";
import {
  REGISTRY_DENIAL_CODES,
  denialResponse,
  type DenialBody,
} from "./denial.js";
import {
  verifyRegistryPullTicket,
  type RegistryPullTicketClaims,
} from "./ticket.js";

export interface AuthContext {
  token: string;
  claims: RegistryPullTicketClaims;
}

export interface GatewayConfig {
  publicKeysById: Record<string, string>;
  /** Optional expected Docker registry service/audience (WWW-Authenticate). */
  serviceName?: string;
  /** Max auth attempts per IP per window (0 = disabled). */
  rateLimitPerMinute?: number;
}

export function parseBearerToken(
  header: string | undefined
): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match?.[1]?.trim() ?? null;
}

/** Docker login stores username=session_id, password=pull_ticket. */
export function parseBasicCredential(
  header: string | undefined
): { username: string; password: string } | null {
  if (!header) return null;
  const match = /^Basic\s+(.+)$/i.exec(header.trim());
  if (!match?.[1]) return null;
  try {
    const decoded = Buffer.from(match[1], "base64").toString("utf8");
    const idx = decoded.indexOf(":");
    if (idx < 0) return null;
    return {
      username: decoded.slice(0, idx),
      password: decoded.slice(idx + 1),
    };
  } catch {
    return null;
  }
}

function headerValue(
  req: IncomingMessage,
  name: string
): string | undefined {
  const raw = req.headers[name.toLowerCase()];
  if (Array.isArray(raw)) return raw[0];
  return raw;
}

function verifyClaimBindings(
  req: IncomingMessage,
  claims: RegistryPullTicketClaims,
  basicUsername: string | null
): DenialBody | null {
  if (basicUsername && basicUsername !== claims.session_id) {
    return denialResponse(
      REGISTRY_DENIAL_CODES.INVALID_REQUEST,
      "Session username does not match ticket",
      401
    ).body;
  }

  const expectedAccount = headerValue(req, "x-soviez-account-id");
  if (expectedAccount && expectedAccount !== claims.account_id) {
    return denialResponse(
      REGISTRY_DENIAL_CODES.LICENSE_BINDING_DENIED,
      "License/account binding mismatch",
      403
    ).body;
  }

  const expectedDevice = headerValue(req, "x-soviez-device-id");
  if (expectedDevice && expectedDevice !== claims.device_id) {
    return denialResponse(
      REGISTRY_DENIAL_CODES.DEVICE_BINDING_DENIED,
      "Device binding mismatch",
      403
    ).body;
  }

  return null;
}

export function authenticateRequest(
  req: IncomingMessage,
  config: GatewayConfig
): AuthContext | DenialBody {
  const bearer = parseBearerToken(req.headers.authorization);
  const basic = parseBasicCredential(req.headers.authorization);

  const token = bearer ?? basic?.password ?? null;
  if (!token) {
    return denialResponse(
      REGISTRY_DENIAL_CODES.INVALID_REQUEST,
      "Authorization required",
      401
    ).body;
  }

  const result = verifyRegistryPullTicket(token, config.publicKeysById);
  if (!result.ok) {
    const code =
      result.reason === "expired"
        ? REGISTRY_DENIAL_CODES.PULL_SESSION_EXPIRED
        : result.reason === "scope_denied"
          ? REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED
          : result.reason === "signature_invalid" ||
              result.reason === "unknown_key" ||
              result.reason === "malformed"
            ? REGISTRY_DENIAL_CODES.SIGNATURE_INVALID
            : REGISTRY_DENIAL_CODES.INVALID_REQUEST;
    return denialResponse(code, `Ticket verification failed: ${result.reason}`, 401)
      .body;
  }

  const binding = verifyClaimBindings(
    req,
    result.claims,
    basic?.username ?? null
  );
  if (binding) return binding;

  return { token, claims: result.claims };
}

export function isDenialBody(value: unknown): value is DenialBody {
  return (
    typeof value === "object" &&
    value !== null &&
    "code" in value &&
    "message" in value
  );
}

export function denialHttpStatus(body: DenialBody): number {
  switch (body.code) {
    case REGISTRY_DENIAL_CODES.LICENSE_BINDING_DENIED:
    case REGISTRY_DENIAL_CODES.DEVICE_BINDING_DENIED:
    case REGISTRY_DENIAL_CODES.AUDIENCE_DENIED:
    case REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED:
    case REGISTRY_DENIAL_CODES.REPOSITORY_SCOPE_DENIED:
    case REGISTRY_DENIAL_CODES.BLOB_SCOPE_DENIED:
      return 403;
    case REGISTRY_DENIAL_CODES.RATE_LIMITED:
      return 429;
    case REGISTRY_DENIAL_CODES.PULL_SESSION_EXPIRED:
    case REGISTRY_DENIAL_CODES.SIGNATURE_INVALID:
    case REGISTRY_DENIAL_CODES.INVALID_REQUEST:
      return 401;
    default:
      return 401;
  }
}

export interface TokenExchangeResponse {
  token: string;
  access_token: string;
  expires_in: number;
  issued_at: string;
}

export function buildTokenExchange(
  auth: AuthContext
): TokenExchangeResponse {
  const now = Math.floor(Date.now() / 1000);
  return {
    token: auth.token,
    access_token: auth.token,
    expires_in: Math.max(0, auth.claims.exp - now),
    issued_at: new Date(auth.claims.iat * 1000).toISOString(),
  };
}

export function buildWwwAuthenticate(
  baseUrl: string,
  serviceName = "soviez-registry"
): string {
  const realm = `${baseUrl.replace(/\/$/, "")}/auth/token`;
  return `Bearer realm="${realm}",service="${serviceName}"`;
}

/** Deny push scopes requested at the token endpoint. */
export function denyUnsafeAuthScope(scopeParam: string | null): DenialBody | null {
  if (!scopeParam) return null;
  const scopes = scopeParam.split(/\s+/).filter(Boolean);
  for (const scope of scopes) {
    // repository:name:actions
    const parts = scope.split(":");
    const actions = (parts[parts.length - 1] ?? "").split(",");
    for (const action of actions) {
      const a = action.trim().toLowerCase();
      if (a && a !== "pull") {
        return denialResponse(
          REGISTRY_DENIAL_CODES.METHOD_NOT_ALLOWED,
          `Action '${a}' denied — pull only`,
          403
        ).body;
      }
    }
  }
  return null;
}

/** Simple in-memory rate limiter (per key). */
export class RateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly limit: number,
    private readonly windowMs = 60_000
  ) {}

  allow(key: string, now = Date.now()): boolean {
    if (this.limit <= 0) return true;
    const cutoff = now - this.windowMs;
    const prev = (this.hits.get(key) ?? []).filter((t) => t >= cutoff);
    if (prev.length >= this.limit) {
      this.hits.set(key, prev);
      return false;
    }
    prev.push(now);
    this.hits.set(key, prev);
    return true;
  }
}
