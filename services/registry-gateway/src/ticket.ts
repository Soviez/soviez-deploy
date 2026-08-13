import {
  createHash,
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  randomBytes,
  sign,
  verify,
} from "node:crypto";

export function base64UrlEncode(buf: Buffer): string {
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function base64UrlDecode(value: string): Buffer {
  const padded =
    value.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (value.length % 4)) % 4);
  return Buffer.from(padded, "base64");
}

export function sha256Hex(data: string | Buffer): string {
  return createHash("sha256").update(data).digest("hex");
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(obj).sort()) {
      out[key] = sortKeys(obj[key]);
    }
    return out;
  }
  return value;
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortKeys(value));
}

export const REGISTRY_TICKET_SIGNING_DOMAIN =
  "soviez.registry-pull-ticket.v1" as const;

export interface RegistryPullTicketClaims {
  typ: "soviez.registry-pull-ticket.v1";
  jti: string;
  session_id: string;
  account_id: string;
  device_id: string;
  operation_id: string;
  repository: string;
  digest: string;
  architecture: string;
  scope: "pull";
  iat: number;
  exp: number;
  signer_key_id: string;
}

function withTicketDomain(canonical: string): Buffer {
  return Buffer.from(
    `${REGISTRY_TICKET_SIGNING_DOMAIN}\n${canonical}`,
    "utf8"
  );
}

export type TicketVerifyResult =
  | { ok: true; claims: RegistryPullTicketClaims }
  | {
      ok: false;
      reason:
        | "malformed"
        | "unknown_key"
        | "signature_invalid"
        | "expired"
        | "not_yet_valid"
        | "scope_denied";
    };

export function verifyRegistryPullTicket(
  token: string,
  publicKeysById: Record<string, string>,
  nowUnix = Math.floor(Date.now() / 1000)
): TicketVerifyResult {
  const parts = token.split(".");
  if (parts.length !== 2) return { ok: false, reason: "malformed" };
  let canonical: string;
  let sig: Buffer;
  try {
    canonical = base64UrlDecode(parts[0]!).toString("utf8");
    sig = base64UrlDecode(parts[1]!);
  } catch {
    return { ok: false, reason: "malformed" };
  }

  let claims: RegistryPullTicketClaims;
  try {
    claims = JSON.parse(canonical) as RegistryPullTicketClaims;
  } catch {
    return { ok: false, reason: "malformed" };
  }

  if (claims.typ !== "soviez.registry-pull-ticket.v1") {
    return { ok: false, reason: "malformed" };
  }
  if (claims.scope !== "pull") {
    return { ok: false, reason: "scope_denied" };
  }
  if (nowUnix > claims.exp) return { ok: false, reason: "expired" };
  if (nowUnix + 30 < claims.iat) return { ok: false, reason: "not_yet_valid" };

  const expectedCanonical = canonicalJson(claims);
  if (expectedCanonical !== canonical) {
    return { ok: false, reason: "signature_invalid" };
  }

  const pubB64 = publicKeysById[claims.signer_key_id];
  if (!pubB64) return { ok: false, reason: "unknown_key" };

  try {
    const raw = base64UrlDecode(pubB64);
    const spkiPrefix = Buffer.from("302a300506032b6570032100", "hex");
    const key = createPublicKey({
      key: Buffer.concat([spkiPrefix, raw]),
      format: "der",
      type: "spki",
    });
    const ok = verify(null, withTicketDomain(expectedCanonical), key, sig);
    if (!ok) return { ok: false, reason: "signature_invalid" };
  } catch {
    return { ok: false, reason: "signature_invalid" };
  }

  return { ok: true, claims };
}

/** Test helper — sign a pull ticket. */
export function issueRegistryPullTicket(
  input: Omit<RegistryPullTicketClaims, "typ" | "jti" | "scope" | "signer_key_id">,
  privateKeyPem: string,
  signerKeyId: string
): { claims: RegistryPullTicketClaims; token: string } {
  const jti = base64UrlEncode(randomBytes(16));
  const claims: RegistryPullTicketClaims = {
    typ: "soviez.registry-pull-ticket.v1",
    jti,
    session_id: input.session_id,
    account_id: input.account_id,
    device_id: input.device_id,
    operation_id: input.operation_id,
    repository: input.repository,
    digest: input.digest,
    architecture: input.architecture,
    scope: "pull",
    iat: input.iat,
    exp: input.exp,
    signer_key_id: signerKeyId,
  };
  const canonical = canonicalJson(claims);
  const key = createPrivateKey(privateKeyPem);
  const signature = sign(null, withTicketDomain(canonical), key);
  const token = `${base64UrlEncode(Buffer.from(canonical, "utf8"))}.${base64UrlEncode(signature)}`;
  return { claims, token };
}

export function generateRegistryTicketKeyPair(): {
  privateKeyPem: string;
  publicKeyRawB64url: string;
  keyId: string;
} {
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  const spki = publicKey.export({ type: "spki", format: "der" }) as Buffer;
  const raw = spki.subarray(spki.length - 32);
  return {
    privateKeyPem: privateKey.export({ type: "pkcs8", format: "pem" }) as string,
    publicKeyRawB64url: base64UrlEncode(raw),
    keyId: `rtk_${sha256Hex(raw).slice(0, 16)}`,
  };
}
