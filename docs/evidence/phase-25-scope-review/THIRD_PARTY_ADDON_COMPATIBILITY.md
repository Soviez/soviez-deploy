# Third-party Odoo 18 addon compatibility

Soviez ERP is independent from Odoo upstream. Criterion is **addon surface stability**, not upstream rebase.

Must preserve for certified features:
- model names, field names, XML IDs
- public Python signatures used by addons
- reflection-sensitive semantics

Verification: static contract tests + at least one real-runtime smoke with a representative third-party-style addon fixture (disposable). Upstream Odoo upgrade compatibility is **out of scope**.
