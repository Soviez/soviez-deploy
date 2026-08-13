# Archive Restore-Test Protocol

```text
encrypted archive → decrypt → checksum → pg_restore (isolated) → schema/counts → destroy restore target only
```

Restore target must not consume a permanent slot or become public.  
Full ERP restore: recommended; Phase 22 may PASS with WARNING if skipped when DB+filestore gates pass.
