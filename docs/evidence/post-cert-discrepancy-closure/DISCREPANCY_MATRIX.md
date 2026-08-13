# DISCREPANCY_MATRIX

| ID | Finding | Classification | Action |
|----|---------|----------------|--------|
| D1 | `--merge-in` never implemented; superseded by `--migration-*` (Phase 17 evidence) | **REQUIREMENT_DECISION** → Case B NOT_SUPPORTED | Formalize decision; no alias; static test; docs |
| D2 | Certified edge routes `/websocket`→8069; `formworkers` can set `workers>0` without gevent | **RUNTIME_DEFECT** + decision | Enforce certified topology `workers=0`; classify `workers>0` as NOT_SUPPORTED |
| D3 | `ensure_stage_soviez_conf` omits `proxy_mode` | **RUNTIME_DEFECT** | Add `proxy_mode = True` to Stage conf (ERP≡deploy) |
| D4 | P21 nginx hardcodes `127.0.0.1:8069`, no WS routes | **RUNTIME_DEFECT** | Resolve upstream from host publish / env; add WS locations |
| D5 | Phase-12 `soviez_nginx_render_owned` lacks `/websocket` (SUPPORTED via SSL promote) | **RUNTIME_DEFECT** | Add WS + longpolling (compat) + upgrade headers |

Longpolling: **COMPATIBILITY_ROUTED** (same upstream as HTTP/WS when template includes it); not a separate gevent port.
