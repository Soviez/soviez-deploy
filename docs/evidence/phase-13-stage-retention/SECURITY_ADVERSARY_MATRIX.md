# Security Adversary Matrix
| Threat | Control |
|---|---|
| Tampered max deadline | Recomputed from immutable creation; fail closed |
| Production resource substitution | Exact naming and path/identity checks |
| Symlink/path traversal | Realpath-under-Stage and `..` rejection |
| Concurrent deletion | Per-Stage mkdir lock |
| Global cleanup blast radius | Explicit resource names; no global prune |
| Full Root code replacement | Residual disclosed; not claimed as DRM |
