# SECURITY_ADVERSARY_MATRIX

| Adversary | Attempt | Outcome |
|-----------|---------|---------|
| DNS spoof | Wrong TXT | Verify fail |
| Replay | Reuse verified challenge | Deny |
| Cutover smuggler | Set cutover/transfer flags in modules | Static gate fail / runtime deny |
| Source attacker via installer | Mutate Production nginx/DNS | Guard + static gate |
| Cross-tenant | Read other pair plan/challenge | Isolation deny |
| Token thief | Consume token in Phase 18 | No code path / static gate |
