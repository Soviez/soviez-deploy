# CLEANUP_AND_DROP_SAFETY

| Rule | Proven |
|------|--------|
| Drop requires confirmation | ✅ |
| Drop stagec only | ✅ integration; a/b remain |
| Production untouched | ✅ messaging + no prod paths removed |
| No global docker prune | ✅ coded remove_owned only |

