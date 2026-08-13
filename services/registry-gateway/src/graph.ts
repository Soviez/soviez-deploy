import type { RegistryPullTicketClaims } from "./ticket.js";

export interface ManifestDescriptor {
  mediaType?: string;
  size?: number;
  digest: string;
}

export interface OciManifestV2 {
  schemaVersion?: number;
  mediaType?: string;
  config: ManifestDescriptor;
  layers: ManifestDescriptor[];
}

/** Per-session authorized digest graph (manifest + config + layers). */
export class SessionGraphCache {
  private readonly graphs = new Map<string, Set<string>>();

  /** Register the ticket-authorized manifest digest for a session. */
  seedSession(sessionId: string, manifestDigest: string): void {
    const set = this.graphs.get(sessionId) ?? new Set<string>();
    set.add(normalizeDigest(manifestDigest));
    this.graphs.set(sessionId, set);
  }

  /** Parse manifest body and add config + layer digests to session graph. */
  ingestManifest(sessionId: string, body: Buffer | string): void {
    let manifest: OciManifestV2;
    try {
      manifest = JSON.parse(
        typeof body === "string" ? body : body.toString("utf8")
      ) as OciManifestV2;
    } catch {
      return;
    }
    const set = this.graphs.get(sessionId) ?? new Set<string>();
    if (manifest.config?.digest) {
      set.add(normalizeDigest(manifest.config.digest));
    }
    for (const layer of manifest.layers ?? []) {
      if (layer.digest) set.add(normalizeDigest(layer.digest));
    }
    this.graphs.set(sessionId, set);
  }

  isManifestAuthorized(
    claims: RegistryPullTicketClaims,
    reference: string
  ): boolean {
    const ref = normalizeDigest(reference);
    const authorized = normalizeDigest(claims.digest);
    return ref === authorized;
  }

  isBlobAuthorized(
    claims: RegistryPullTicketClaims,
    digest: string
  ): boolean {
    const normalized = normalizeDigest(digest);
    const set = this.graphs.get(claims.session_id);
    if (!set) {
      // Allow manifest digest itself (some clients re-fetch)
      return normalized === normalizeDigest(claims.digest);
    }
    return set.has(normalized);
  }

  clearSession(sessionId: string): void {
    this.graphs.delete(sessionId);
  }
}

export function normalizeDigest(digest: string): string {
  const trimmed = digest.trim();
  if (trimmed.startsWith("sha256:")) return trimmed;
  if (/^[a-f0-9]{64}$/i.test(trimmed)) return `sha256:${trimmed.toLowerCase()}`;
  return trimmed;
}

export function normalizeRepository(name: string): string {
  return name.replace(/^\/+/, "").replace(/\/+$/, "");
}

export function repositoryMatches(
  claims: RegistryPullTicketClaims,
  requestedRepo: string
): boolean {
  return (
    normalizeRepository(claims.repository) ===
    normalizeRepository(requestedRepo)
  );
}
