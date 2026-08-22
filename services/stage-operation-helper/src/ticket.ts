/**
 * Stage Operation Ticket crypto — mirrors SaaS soviez.stage-operation.v1 domain.
 * Verifier ships ONLY public keys. Private signing keys never ship in this package.
 */
import {
  createHash,
  createPublicKey,
  verify,
} from "node:crypto";

export const STAGE_OPERATION_SIGNING_DOMAIN = "soviez.stage-operation.v1";
export const STAGE_OPERATION_TICKET_TYPE = "soviez.stage-operation.v1";
export const STAGE_OPERATION_PROTOCOL_VERSION = "stage-operation/v1";

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

export interface StageOperationTicketClaims {
  typ: string;
  protocol_version: string;
  jti: string;
  operation_id: string;
  operation_type: string;
  subject_pseudonym: string;
  account_id: string;
  license_id: string;
  device_id: string;
  device_pubkey_fingerprint: string;
  host_pubkey_fingerprint: string;
  production_fingerprint: string;
  database_uuid: string;
  stage_id: string;
  stage_domain: string;
  release_id: string;
  release_digest: string;
  tooling_artifact_id: string;
  tooling_digest: string;
  architecture: string;
  entitlement_decision_ref: string;
  delivery_trace_id: string;
  iat: number;
  exp: number;
  nonce: string;
  signer_key_id: string;
}

export type VerifyResult =
  | { ok: true; claims: StageOperationTicketClaims }
  | { ok: false; reason: string; denial_code: string };

export function verifyStageOperationTicket(
  token: string,
  publicKeysById: Record<string, string>,
  nowUnix = Math.floor(Date.now() / 1000)
): VerifyResult {
  const parts = token.split(".");
  if (parts.length !== 2) {
    return { ok: false, reason: "malformed", denial_code: "TICKET_SIGNATURE_INVALID" };
  }
  let canonical: string;
  let sig: Buffer;
  try {
    canonical = base64UrlDecode(parts[0]!).toString("utf8");
    sig = base64UrlDecode(parts[1]!);
  } catch {
    return { ok: false, reason: "malformed", denial_code: "TICKET_SIGNATURE_INVALID" };
  }

  let claims: StageOperationTicketClaims;
  try {
    claims = JSON.parse(canonical) as StageOperationTicketClaims;
  } catch {
    return { ok: false, reason: "malformed", denial_code: "TICKET_SIGNATURE_INVALID" };
  }

  if (claims.typ !== STAGE_OPERATION_TICKET_TYPE) {
    return { ok: false, reason: "wrong_type", denial_code: "TICKET_SIGNATURE_INVALID" };
  }
  if (claims.protocol_version !== STAGE_OPERATION_PROTOCOL_VERSION) {
    return { ok: false, reason: "wrong_protocol", denial_code: "TICKET_SIGNATURE_INVALID" };
  }

  const pubRaw = publicKeysById[claims.signer_key_id];
  if (!pubRaw) {
    return { ok: false, reason: "unknown_key", denial_code: "TICKET_SIGNATURE_INVALID" };
  }

  try {
    const raw = base64UrlDecode(pubRaw);
    const spkiPrefix = Buffer.from("302a300506032b6570032100", "hex");
    const key = createPublicKey({
      key: Buffer.concat([spkiPrefix, raw]),
      format: "der",
      type: "spki",
    });
    const ok = verify(
      null,
      Buffer.from(`${STAGE_OPERATION_SIGNING_DOMAIN}\n${canonical}`, "utf8"),
      key,
      sig
    );
    if (!ok) {
      return {
        ok: false,
        reason: "signature_invalid",
        denial_code: "TICKET_SIGNATURE_INVALID",
      };
    }
  } catch {
    return { ok: false, reason: "unknown_key", denial_code: "TICKET_SIGNATURE_INVALID" };
  }

  if (claims.exp <= nowUnix) {
    return { ok: false, reason: "expired", denial_code: "TICKET_EXPIRED" };
  }

  return { ok: true, claims };
}

export function assertBindings(
  claims: StageOperationTicketClaims,
  expected: Record<string, string>
): { ok: true } | { ok: false; denial_code: string } {
  const pairs: [string, string, string][] = [
    ["license_id", expected.license_id!, "TICKET_BINDING_MISMATCH"],
    ["device_id", expected.device_id!, "TICKET_BINDING_MISMATCH"],
    ["host_pubkey_fingerprint", expected.host_pubkey_fingerprint!, "TICKET_BINDING_MISMATCH"],
    ["production_fingerprint", expected.production_fingerprint!, "PRODUCTION_FINGERPRINT_MISMATCH"],
    ["database_uuid", expected.database_uuid!, "DATABASE_UUID_MISMATCH"],
    ["stage_id", expected.stage_id!, "TICKET_BINDING_MISMATCH"],
    ["stage_domain", expected.stage_domain!, "STAGE_DOMAIN_CONFLICT"],
    ["operation_type", expected.operation_type!, "OPERATION_NOT_ALLOWED"],
    ["release_digest", expected.release_digest!, "RELEASE_NOT_APPROVED"],
    ["tooling_digest", expected.tooling_digest!, "TOOLING_NOT_APPROVED"],
    ["architecture", expected.architecture!, "ARCHITECTURE_NOT_SUPPORTED"],
  ];
  for (const [field, want, code] of pairs) {
    if (want !== undefined && (claims as unknown as Record<string, unknown>)[field] !== want) {
      return { ok: false, denial_code: code };
    }
  }
  return { ok: true };
}
