# Engineering vs release boundary

| State | Meaning | Set by |
|-------|---------|--------|
| ENGINEERING CERTIFIED | Phase 25 engineering PASS; matrix+docs+checklist+evidence | Phase 25 implementation + eng owner sign-off |
| READY TO RELEASE | Checklist complete; known limitations accepted; no release blockers | Checklist evaluation |
| AUTHORIZED TO RELEASE | Explicit owner release authorization | Separate owner act |
| RELEASED | Artifact published / customers can obtain | Separate publish act |

**Rule:** Phase 25 PASS ⇒ ENGINEERING CERTIFIED only. It does **not** set AUTHORIZED TO RELEASE or RELEASED unless master plan required that (it does not; explicit note forbids automatic publish/rollout).
