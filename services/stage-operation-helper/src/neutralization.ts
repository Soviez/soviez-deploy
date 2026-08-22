import { createHash } from "node:crypto";
import { canonicalJson } from "./ticket.js";

export const NEUTRALIZATION_CONTROLS = [
  "outgoing_email_disabled",
  "sms_disabled",
  "payment_providers_disabled",
  "webhooks_disabled",
  "external_cron_isolated",
  "production_url_callbacks_blocked",
  "stage_identity_marker_set",
  "database_is_neutralized_flag",
] as const;

export type NeutralizationControlMap = Record<
  (typeof NEUTRALIZATION_CONTROLS)[number],
  boolean
>;

export interface NeutralizationResult {
  typ: "soviez.stage-neutralization-result.v1";
  stage_id: string;
  operation_id: string;
  controls: NeutralizationControlMap;
  passed: boolean;
  failed_controls: string[];
  issued_at: string;
  digest: string;
}

export function certifyNeutralization(input: {
  stageId: string;
  operationId: string;
  controls: Partial<NeutralizationControlMap>;
}): NeutralizationResult {
  const full = {} as NeutralizationControlMap;
  const failed: string[] = [];
  for (const key of NEUTRALIZATION_CONTROLS) {
    const ok = input.controls[key] === true;
    full[key] = ok;
    if (!ok) failed.push(key);
  }
  const body = {
    typ: "soviez.stage-neutralization-result.v1" as const,
    stage_id: input.stageId,
    operation_id: input.operationId,
    controls: full,
    passed: failed.length === 0,
    failed_controls: failed,
    issued_at: new Date().toISOString(),
  };
  const digest = `sha256:${createHash("sha256").update(canonicalJson(body)).digest("hex")}`;
  return { ...body, digest };
}
