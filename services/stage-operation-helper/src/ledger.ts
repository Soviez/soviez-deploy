/**
 * Local one-use consumption ledger for offline Stage authorization.
 * Root can theoretically rewrite this file — residual risk (documented).
 */
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { sha256Hex } from "./ticket.js";

export interface LocalConsumptionEntry {
  package_or_ticket_hash: string;
  operation_id: string;
  stage_id: string;
  consumed_at: string;
}

export function loadLedger(path: string): LocalConsumptionEntry[] {
  if (!existsSync(path)) return [];
  const raw = readFileSync(path, "utf8").trim();
  if (!raw) return [];
  return raw
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as LocalConsumptionEntry);
}

export function consumeOnce(
  ledgerPath: string,
  entry: LocalConsumptionEntry
): { ok: true } | { ok: false; denial_code: string } {
  const ledger = loadLedger(ledgerPath);
  if (ledger.some((e) => e.package_or_ticket_hash === entry.package_or_ticket_hash)) {
    return { ok: false, denial_code: "OFFLINE_PACKAGE_ALREADY_USED" };
  }
  if (
    ledger.some(
      (e) => e.operation_id === entry.operation_id && e.stage_id === entry.stage_id
    )
  ) {
    return { ok: false, denial_code: "OFFLINE_PACKAGE_ALREADY_USED" };
  }
  mkdirSync(dirname(ledgerPath), { recursive: true });
  appendFileSync(ledgerPath, `${JSON.stringify(entry)}\n`, { mode: 0o600 });
  return { ok: true };
}

export function ticketHash(token: string): string {
  return sha256Hex(token);
}

/** Write Stage-origin certificate file (local evidence only; no phone-home). */
export function writeOriginCertificateFile(
  path: string,
  certificate: Record<string, unknown>
): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(certificate, null, 2), { mode: 0o600 });
}
