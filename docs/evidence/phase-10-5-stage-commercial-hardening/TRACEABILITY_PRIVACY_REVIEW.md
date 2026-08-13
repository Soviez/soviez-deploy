# TRACEABILITY_PRIVACY_REVIEW — Phase 10.5

| Field | Allowed? | Contents |
|-------|----------|----------|
| `delivery_trace_id` | Yes | Pseudonymous delivery / leak attribution |
| `subject_pseudonym` | Yes | License hash — not name/email |
| Customer name / email | **No** | Forbidden in ticket / tooling |
| Business records / dumps | **No** | Forbidden |
| Continuous telemetry | **No** | Forbidden |
| Origin cert phone-home | **No** | Local evidence only |

User disclosure: Stage creation requires operation authorization; minimal licensing metadata; no business data; Stage continues offline after creation; expired Stage License does not stop/delete Stages; private tooling may carry a pseudonymous delivery ID; Full Root can bypass local software; no unbreakable DRM claim.

**Tests:** _(parent fills)_
