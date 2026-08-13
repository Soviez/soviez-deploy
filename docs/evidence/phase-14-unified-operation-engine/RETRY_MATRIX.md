# Retry Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Rescheduling Mechanics

When a retryable state fails (`failed_retryable` or `recovery_required`), the operator triggers retry via `soviez --operation-retry <id>`.

## 2. Retry Steps

1. **Safety Assert:** Validates that the operation current state is either `failed_retryable` or `recovery_required`. Otherwise, throws `OPERATION_RETRY_NOT_ALLOWED`.
2. **Metadata Update:** Increments `retry_count` in the canonical JSON file using an in-place Python parser block.
3. **Transition Flow:** Transitions the operation safely: `failed_retryable` → `retry_scheduled` → `starting` → `running`.
4. **Execution Delegation:** Hands control over to the corresponding adapter to re-execute the background thread from the last valid checkpoint.
