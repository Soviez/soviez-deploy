#!/usr/bin/env python3
"""S3 read-only technical-record classifier. Never executes record content."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def redact_snippet(text: str, start: int, end: int, window: int = 80) -> str:
    a = max(0, start - window)
    b = min(len(text), end + window)
    snip = text[a:b]
    # Redact long tokens that look like secrets
    snip = re.sub(r"(?i)(password|passwd|secret|token|api[_-]?key)\s*[:=]\s*\S+", r"\1=***REDACTED***", snip)
    snip = re.sub(r"[A-Za-z0-9+/_-]{40,}", "***REDACTED***", snip)
    return snip.replace("\n", "\\n")


def fingerprint(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def long_base64_blob(text: str) -> bool:
    # Obfuscation heuristic: long base64-like contiguous blob
    return bool(re.search(r"(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{200,}={0,2}(?![A-Za-z0-9+/])", text))


def classify_record(rec: dict, rules: list, iocs: list) -> list:
    findings = []
    content = rec.get("content") or ""
    model = rec.get("model") or ""
    for rule in rules:
        models = rule.get("models") or []
        if models and model not in models and model.replace("_", ".") not in models:
            # allow ir_act_server vs ir.actions.server mapping via alias
            aliases = {
                "ir_act_server": "ir.actions.server",
                "ir_config_parameter": "ir.config_parameter",
                "ir_ui_view": "ir.ui.view",
                "ir_cron": "ir.cron",
                "base_automation": "base.automation",
                "res_users": "res.users",
                "res_groups": "res.groups",
                "ir_module_module": "ir.module.module",
            }
            mapped = aliases.get(model, model)
            if mapped not in models:
                continue
        pat = rule.get("pattern") or ""
        try:
            m = re.search(pat, content, re.DOTALL)
        except re.error:
            continue
        if not m:
            continue
        sev = rule.get("severity", "MEDIUM")
        # Soften bare eval/exec unless other CRITICAL/HIGH also present later
        findings.append(
            {
                "rule_id": rule["id"],
                "category": rule.get("category"),
                "severity": sev,
                "confidence": rule.get("confidence"),
                "rationale": rule.get("rationale"),
                "remediation": rule.get("remediation"),
                "model": model,
                "record_id": rec.get("id"),
                "xml_id": rec.get("xml_id"),
                "name": rec.get("name"),
                "active": rec.get("active"),
                "field": rec.get("field"),
                "content_fingerprint": fingerprint(content),
                "snippet": redact_snippet(content, m.start(), m.end()),
                "executable": bool(rec.get("executable", True)),
                "module_hint": rec.get("module_hint"),
            }
        )
    # Obfuscation heuristic
    if long_base64_blob(content):
        findings.append(
            {
                "rule_id": "SDB009_OBFUSCATED_PAYLOAD",
                "category": "obfuscation",
                "severity": "HIGH",
                "confidence": "medium",
                "rationale": "Long base64-like blob in technical content",
                "remediation": "HIGH — review encoded payload",
                "model": model,
                "record_id": rec.get("id"),
                "xml_id": rec.get("xml_id"),
                "name": rec.get("name"),
                "active": rec.get("active"),
                "field": rec.get("field"),
                "content_fingerprint": fingerprint(content),
                "snippet": "[long-base64-blob redacted]",
                "executable": bool(rec.get("executable", True)),
                "module_hint": rec.get("module_hint"),
            }
        )
    # IOC matching against content
    low = content.lower()
    for ioc in iocs:
        val = (ioc.get("value") or "").lower()
        if not val:
            continue
        if val in low:
            findings.append(
                {
                    "rule_id": "SDB_IOC_" + ioc.get("type", "unknown").upper(),
                    "category": "known_ioc",
                    "severity": ioc.get("severity", "HIGH"),
                    "confidence": "high",
                    "rationale": f"Known IOC match ({ioc.get('type')})",
                    "remediation": "CRITICAL/HIGH — known IOC",
                    "model": model,
                    "record_id": rec.get("id"),
                    "name": rec.get("name"),
                    "field": rec.get("field"),
                    "content_fingerprint": fingerprint(content),
                    "snippet": redact_snippet(content, max(0, low.find(val) - 20), low.find(val) + len(val) + 20),
                    "ioc_value": ioc.get("value"),
                    "ioc_tags": ioc.get("tags"),
                }
            )
    return findings


def severity_rank(s: str) -> int:
    return {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "INFO": 0}.get((s or "").upper(), 0)


def overall_status(findings: list) -> str:
    if not findings:
        return "PASS"
    worst = max(severity_rank(f.get("severity")) for f in findings)
    if worst >= 4:
        return "FAIL"
    if worst >= 3:
        return "FAIL"
    if worst >= 2:
        return "PASS_WITH_REVIEW"
    return "PASS_WITH_REVIEW"


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: classify_records.py <rules.json> <iocs.json> <records.json>", file=sys.stderr)
        return 2
    rules = load_json(Path(sys.argv[1])).get("rules") or []
    iocs = load_json(Path(sys.argv[2])).get("iocs") or []
    records = load_json(Path(sys.argv[3]))
    if isinstance(records, dict):
        records = records.get("records") or []
    all_findings = []
    for rec in records:
        all_findings.extend(classify_record(rec, rules, iocs))
    # Deduplicate identical rule+record+field
    seen = set()
    deduped = []
    for f in all_findings:
        key = (f.get("rule_id"), f.get("model"), f.get("record_id"), f.get("field"), f.get("content_fingerprint"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(f)
    out = {
        "status": overall_status(deduped),
        "finding_count": len(deduped),
        "findings": deduped,
        "mutation_count": 0,
        "executed_payloads": 0,
    }
    print(json.dumps(out, indent=2, sort_keys=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
