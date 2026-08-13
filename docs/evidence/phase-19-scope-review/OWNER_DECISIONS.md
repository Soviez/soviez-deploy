# OWNER_DECISIONS.md

**Date:** 2026-08-02  
**Status:** OPEN — recommendations only; **every OD Requires owner approval**. Not silently binding.

| OD | Decision | Options | Recommendation | Status |
|----|----------|---------|----------------|--------|
| 01 | Migration strategy | A one-shot freeze; **B multi-pass+final freeze**; C WAL/PITR; D archive relay | **Option B**; no WAL/PITR | Requires owner approval |
| 02 | Final write-freeze max target | 5 / **15** / 30 / 60 min | **15 minutes** | Requires owner approval |
| 03 | Freeze hard timeout | Soft warn only; **hard timeout** | **Hard timeout** | Requires owner approval |
| 04 | Auto release freeze on timeout/abort | Manual only; **auto release** | **Auto release** | Requires owner approval |
| 05 | Freeze vs stop semantics | Couple ERP/PG/landing; **keep distinct** | App write freeze ≠ ERP stop ≠ PG stop ≠ maintenance landing | Requires owner approval |
| 06 | Pre-migration Full backup gate | Skip; age 72h; **≤24h VERIFIED exact source Full** | Exact source Full, **VERIFIED**, age **≤24h** at final pass start | Requires owner approval |
| 07 | RESTORE_TESTED requirement | Mandatory; **recommended**; ignore | **Recommended, not mandatory** | Requires owner approval |
| 08 | Backup pin through 19–21 | No pin; **pin backup id** | **Pin through Phases 19–21** | Requires owner approval |
| 09 | Primary transfer protocol | SSH-first; SFTP backup-as-migrate; **app mTLS chunked** | **Application-level mTLS chunked transfer service** | Requires owner approval |
| 10 | SSH role | Primary; forbidden; **admin fallback only** | **Admin fallback only** | Requires owner approval |
| 11 | Plain FTP | Allow; **ban** | **No plain FTP** | Requires owner approval |
| 12 | TOFU for peer identity | Allow; **ban** | **No TOFU** | Requires owner approval |
| 13 | Chunk sizing strategy | Content-defined; **fixed initially** | **Fixed chunks initially** | Requires owner approval |
| 14 | Default chunk size | 16 / **64** / 256 MiB | **64 MiB** | Requires owner approval |
| 15 | Compression | none; gzip; **zstd balanced**; zstd max | **zstd balanced** | Requires owner approval |
| 16 | Bandwidth profile | aggressive; **balanced**; throttle | **Balanced** | Requires owner approval |
| 17 | Addon transfer mode | Binary ship all; **registry-first** | **Registry-first** | Requires owner approval |
| 18 | Third-party business credentials | Auto copy; prompt; **never auto** | **No automatic transfer** | Requires owner approval |
| 19 | Destination identity | Production early; **isolated non-Production staging** | **Isolated non-Production staging** | Requires owner approval |
| 20 | Staging technical validation | Forbid all checks; **allow internal ERP technical validation** | **Allow internal technical validation** | Requires owner approval |
| 21 | Public login on staging | Allow; **deny** | **No public login** | Requires owner approval |
| 22 | License slot on staging | Soft bind; **no slot** | **No slot** | Requires owner approval |
| 23 | Stage selection | Auto all; **explicit select only** | **Explicit select only** | Requires owner approval |
| 24 | Expired Stages | Selectable; **always excluded** | **Always excluded** | Requires owner approval |
| 25 | Optional Stage failure | BLOCKED; **WARNING**; ignore | **WARNING** unless marked mandatory | Requires owner approval |
| 26 | Abort staging disposition | Always delete; **preserve**; ask | **Preserve staging** | Requires owner approval |
| 27 | Exact-delete on abort | Default on; **optional flag** | **Optional** (destructive) | Requires owner approval |
| 28 | Migration Token in Phase 19 | Soft-reserve; consume; **eligibility only** | **Eligibility check only** | Requires owner approval |
| 29 | Token reserved flag | Soft true; **false** | **`reserved=false`** | Requires owner approval |
| 30 | Token consumed flag | Allow burn; **false** | **`consumed=false`** | Requires owner approval |
| 31 | Source state after Phase 19 | Stopped; drained; **ACTIVE** | **Source remains ACTIVE** | Requires owner approval |
| 32 | Ready-for-20 report | Binary only; **PASS/WARNING/BLOCKED** | **PASS / WARNING / BLOCKED** | Requires owner approval |
| 33 | Phase 19 plan weight | Leave none; propose 3/4/**5** | Propose **5** (Very High; like Phase 17) — **do not apply** | Requires owner approval |
| 34 | Credit budget rebalance 20–24 | Ignore; **owner rebalance** (7% left) | **Owner must rebalance 20–24** before crediting 5 | Requires owner approval |
| 35 | WAL/PITR in Phase 19 | Include; **exclude** | **No WAL/PITR** | Requires owner approval |
| 36 | Final DB method | Logical rep; filesystem clone; **Phase 16 `-Fc`** | **Reuse Phase 16 `-Fc` dump** | Requires owner approval |
| 37 | Filestore method | Single tar only; block device; **file-level chunked pre-sync** | **File-level chunked pre-sync** | Requires owner approval |
| 38 | Static gate / `pg_dump` in migration | Keep total ban; **scoped authorized modules** | Introduce authorized transfer modules + **scoped gate updates** | Requires owner approval |
| 39 | ERP/PG stop during freeze | Stop both; stop ERP only; **neither by default** | **Neither** (writes frozen at app layer) | Requires owner approval |
| 40 | SaaS payload relay | Allow emergency relay; **ban** | **Ban SaaS payload relay** | Requires owner approval |

Commercial, destructive (exact-delete), and weight-credit policies remain owner-gated before implementation authorization.
