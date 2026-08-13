# Reattach Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Reattachment Operations

The reattach matrix maps modern unified invocations to legacy reattach points:

| Operation Type | Unified Invocations | Legacy CLI Action | Checkpoint Resume Strategy |
|---|---|---|---|
| `new` | `soviez --operation-reattach <id>` | `soviez_cmd_reattach_run` | Resumes licensing machine after auth validations. |
| `stage_create` | `soviez --operation-reattach <id>` | `soviez_cmd_stage_create_run` | Skips completed checkpoints (`soviez_stage_sm_should_run`). |
| `ssl_renewal` | `soviez --operation-reattach <id>` | `soviez_cmd_ssl_reattach` | Continues DNS poll or reload challenge loop. |
| `ssl_repair` | `soviez --operation-reattach <id>` | `soviez_cmd_ssl_reattach` | Retries current broken file symlinks. |
| `retention_delete`| `soviez --operation-reattach <id>` | `soviez_cmd_stage_retention_reattach` | Resumes retention checkpoint deletion. |

No double-execution of heavy destructive or setup operations occurs.
