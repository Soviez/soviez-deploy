import type { GatewayConfig } from "./auth.js";
import type { UpstreamConfig } from "./proxy.js";

export interface ServerEnvConfig {
  port: number;
  publicKeysById: Record<string, string>;
  upstream: UpstreamConfig;
  serviceName?: string;
  rateLimitPerMinute?: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): ServerEnvConfig {
  const port = parseInt(env.PORT ?? "8087", 10);
  if (Number.isNaN(port)) {
    throw new Error("Invalid PORT");
  }

  let publicKeysById: Record<string, string> = {};
  const keysJson = env.SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON;
  if (keysJson) {
    try {
      publicKeysById = JSON.parse(keysJson) as Record<string, string>;
    } catch {
      throw new Error("SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON is invalid JSON");
    }
  }

  if (
    Object.keys(publicKeysById).length === 0 &&
    env.SOVIEZ_REGISTRY_GATEWAY_ALLOW_EMPTY_KEYS !== "1"
  ) {
    // Production should set keys; tests may set ALLOW_EMPTY or inject via options.
    if (env.NODE_ENV === "production") {
      throw new Error("SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON is required in production");
    }
  }

  const upstream: UpstreamConfig = {
    baseUrl: env.SOVIEZ_UPSTREAM_BASE_URL || undefined,
    host: env.SOVIEZ_UPSTREAM_REGISTRY_HOST ?? "registry-1.docker.io",
    user: env.SOVIEZ_UPSTREAM_REGISTRY_USER,
    token: env.SOVIEZ_UPSTREAM_REGISTRY_TOKEN,
  };

  return {
    port,
    publicKeysById,
    upstream,
    serviceName: env.SOVIEZ_REGISTRY_SERVICE_NAME ?? "soviez-registry",
    rateLimitPerMinute: parseInt(env.SOVIEZ_REGISTRY_RATE_LIMIT_PER_MINUTE ?? "120", 10),
  };
}

export function toGatewayConfig(config: ServerEnvConfig): GatewayConfig {
  return {
    publicKeysById: config.publicKeysById,
    serviceName: config.serviceName,
    rateLimitPerMinute: config.rateLimitPerMinute,
  };
}
