/**
 * Stage operation helper CLI.
 *
 * Future Phase 11 contract:
 *   Bash → obtain ticket + private tooling → run this helper →
 *   helper verifies/consumes/neutralizes/writes origin cert →
 *   Bash does infrastructure orchestration only.
 *
 * Bash cannot produce a certified Stage by flipping a local Boolean.
 *
 * Residual risk: Root can replace this binary. That is deterred/detectable,
 * not cryptographically prevented. Soviez does not claim unbreakable DRM.
 */
import { readFileSync } from "node:fs";
import {
  assertBindings,
  verifyStageOperationTicket,
  type StageOperationTicketClaims,
} from "./ticket.js";
import { certifyNeutralization } from "./neutralization.js";
import { consumeOnce, ticketHash, writeOriginCertificateFile } from "./ledger.js";

export interface HelperVerifyInput {
  ticketToken: string;
  publicKeysById: Record<string, string>;
  expected: Record<string, string>;
  ledgerPath?: string;
  nowUnix?: number;
}

export type HelperVerifyOutput =
  | {
      ok: true;
      claims: StageOperationTicketClaims;
      denial_code: null;
    }
  | { ok: false; denial_code: string; reason?: string };

export function runVerify(input: HelperVerifyInput): HelperVerifyOutput {
  const verified = verifyStageOperationTicket(
    input.ticketToken,
    input.publicKeysById,
    input.nowUnix
  );
  if (!verified.ok) {
    return { ok: false, denial_code: verified.denial_code, reason: verified.reason };
  }
  const bound = assertBindings(verified.claims, input.expected);
  if (!bound.ok) return { ok: false, denial_code: bound.denial_code };

  if (input.ledgerPath) {
    const c = consumeOnce(input.ledgerPath, {
      package_or_ticket_hash: ticketHash(input.ticketToken),
      operation_id: verified.claims.operation_id,
      stage_id: verified.claims.stage_id,
      consumed_at: new Date().toISOString(),
    });
    if (!c.ok) return { ok: false, denial_code: c.denial_code };
  }

  return { ok: true, claims: verified.claims, denial_code: null };
}

export function runNeutralizeAndCertify(input: {
  claims: StageOperationTicketClaims;
  controls: Record<string, boolean>;
  certificateOutPath?: string;
  authorizationId?: string;
}): {
  ok: boolean;
  denial_code: string | null;
  neutralization: ReturnType<typeof certifyNeutralization>;
  origin_certificate: Record<string, unknown> | null;
} {
  const neutralization = certifyNeutralization({
    stageId: input.claims.stage_id,
    operationId: input.claims.operation_id,
    controls: input.controls,
  });
  if (!neutralization.passed) {
    return {
      ok: false,
      denial_code: "NEUTRALIZATION_FAILED",
      neutralization,
      origin_certificate: null,
    };
  }

  const origin_certificate = {
    typ: "soviez.stage-origin-certificate.v1",
    stage_id: input.claims.stage_id,
    license_id: input.claims.license_id,
    production_fingerprint: input.claims.production_fingerprint,
    database_uuid: input.claims.database_uuid,
    stage_domain: input.claims.stage_domain,
    operation_type: input.claims.operation_type,
    created_at: new Date().toISOString(),
    release_digest: input.claims.release_digest,
    tooling_digest: input.claims.tooling_digest,
    authorization_id: input.authorizationId ?? null,
    ticket_jti: input.claims.jti,
    neutralization_digest: neutralization.digest,
    delivery_trace_id: input.claims.delivery_trace_id,
    retention_created_at: null,
    retention_expires_at: null,
    note: "Local evidence only. Does not phone home. Does not expire with Stage License.",
  };

  if (input.certificateOutPath) {
    writeOriginCertificateFile(input.certificateOutPath, origin_certificate);
  }

  return {
    ok: true,
    denial_code: null,
    neutralization,
    origin_certificate,
  };
}

function main(argv: string[]): number {
  const cmd = argv[2] || "help";
  if (cmd === "help" || cmd === "--help") {
    process.stdout.write(
      [
        "soviez-stage-helper verify --ticket <file> --keys <json> --expect <json> [--ledger <path>]",
        "soviez-stage-helper neutralize --claims <json> --controls <json> [--cert-out <path>]",
        "",
        "Residual Root risk: replacing this helper bypasses local checks.",
        "Soviez does not claim unbreakable DRM.",
        "",
      ].join("\n")
    );
    return 0;
  }

  if (cmd === "verify") {
    const ticketPath = argValue(argv, "--ticket");
    const keysPath = argValue(argv, "--keys");
    const expectPath = argValue(argv, "--expect");
    const ledger = argValue(argv, "--ledger");
    if (!ticketPath || !keysPath || !expectPath) {
      process.stderr.write("missing --ticket/--keys/--expect\n");
      return 2;
    }
    const result = runVerify({
      ticketToken: readFileSync(ticketPath, "utf8").trim(),
      publicKeysById: JSON.parse(readFileSync(keysPath, "utf8")) as Record<
        string,
        string
      >,
      expected: JSON.parse(readFileSync(expectPath, "utf8")) as Record<string, string>,
      ledgerPath: ledger,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return result.ok ? 0 : 1;
  }

  if (cmd === "neutralize") {
    const claims = JSON.parse(
      readFileSync(argValue(argv, "--claims")!, "utf8")
    ) as StageOperationTicketClaims;
    const controls = JSON.parse(
      readFileSync(argValue(argv, "--controls")!, "utf8")
    ) as Record<string, boolean>;
    const certOut = argValue(argv, "--cert-out");
    const result = runNeutralizeAndCertify({
      claims,
      controls,
      certificateOutPath: certOut,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return result.ok ? 0 : 1;
  }

  process.stderr.write(`unknown command: ${cmd}\n`);
  return 2;
}

function argValue(argv: string[], flag: string): string | undefined {
  const i = argv.indexOf(flag);
  if (i < 0) return undefined;
  return argv[i + 1];
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith("cli.ts") || process.argv[1]?.endsWith("cli.js")) {
  process.exitCode = main(process.argv);
}

export { main };
