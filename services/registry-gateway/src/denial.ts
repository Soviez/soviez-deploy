/** Stable denial codes — subset used by the registry gateway. */

export const REGISTRY_DENIAL_CODES = {
  REPOSITORY_SCOPE_DENIED: "REPOSITORY_SCOPE_DENIED",
  BLOB_SCOPE_DENIED: "BLOB_SCOPE_DENIED",
  METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
  UPSTREAM_UNAVAILABLE: "UPSTREAM_UNAVAILABLE",
  SIGNATURE_INVALID: "SIGNATURE_INVALID",
  PULL_SESSION_EXPIRED: "PULL_SESSION_EXPIRED",
  INVALID_REQUEST: "INVALID_REQUEST",
  INTERNAL_ERROR: "INTERNAL_ERROR",
  LICENSE_BINDING_DENIED: "LICENSE_BINDING_DENIED",
  DEVICE_BINDING_DENIED: "DEVICE_BINDING_DENIED",
  RATE_LIMITED: "RATE_LIMITED",
  AUDIENCE_DENIED: "AUDIENCE_DENIED",
} as const;

export type RegistryDenialCode =
  (typeof REGISTRY_DENIAL_CODES)[keyof typeof REGISTRY_DENIAL_CODES];

export interface DenialBody {
  code: RegistryDenialCode;
  message: string;
}

export function denialResponse(
  code: RegistryDenialCode,
  message: string,
  status = 403
): { status: number; body: DenialBody } {
  return { status, body: { code, message } };
}
