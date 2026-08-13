# AI_ASSISTED_ATTACK_ANALYSIS — Phase 10.5

Likely AI-assisted attempts and responses:

| Attack pattern | Expected denial / control |
|----------------|---------------------------|
| Forge ticket without private key | `TICKET_SIGNATURE_INVALID` |
| Cross-domain signature reuse | Wrong domain / type fail |
| Binding field swap (license/stage/domain) | `TICKET_BINDING_MISMATCH` / specific codes |
| Replay consumed jti | `TICKET_ALREADY_CONSUMED` / offline already used |
| Clock skew past `exp` | `TICKET_EXPIRED` (START only) |
| Tooling digest substitution | `TOOLING_NOT_APPROVED` |
| Fake neutralization all-true without controls | Complete path rejects if controls fail |
| Instruct Bash to skip helper | Future Phase 11 must refuse uncertified Stages |

Honest limit: AI can still guide a Root operator to replace the helper.

**Tests:** _(parent fills)_
