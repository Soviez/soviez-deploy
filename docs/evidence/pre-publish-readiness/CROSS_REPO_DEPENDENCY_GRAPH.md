# CROSS_REPO_DEPENDENCY_GRAPH

```text
soviez-saas (producer: entitlements, device auth, slots, registry tickets,
             stage ops, migration auth, offline bundles, schema 078–090)
        │
        │ HTTPS APIs / JWT tickets / capability results
        ▼
soviez-sh (consumer: installer/runtime; producer: dist/soviez.sh)
        │
        │ generates host config / invokes dual wizard patterns;
        │ expects workers=0, proxy_mode=True, /websocket→8069
        ▼
Soviez ERP/soviez.sh  ≡  soviez-deploy/soviez.sh
        (byte-identical dual Production/Stage wizard)
```

| Producer | Consumer | Contract | Compat | Publish order | Simultaneous? | Rollback |
|----------|----------|----------|--------|---------------|---------------|----------|
| saas schema 078–090 + APIs | soviez-sh | installer-auth, entitlements, registry pull, stage, migration, offline | New installer needs new SaaS for Stage/migration/offline paths | **SaaS first** | Prefer coordinated window | Restore prior SaaS deploy; keep old installer |
| soviez-sh dist | operators / VPS | CLI contracts `--migration-*`, no `--merge-in` | Old wizard + new modular may diverge on Stage proxy_mode | After SaaS | With wizards | Pin prior dist SHA |
| ERP `soviez.sh` | deploy must match | byte identity | Mixed wizards unsafe for Stage | With deploy | **Atomic pair** | Revert both to prior identical pair |
| deploy `soviez.sh` | ERP must match | byte identity | same | With ERP | **Atomic pair** | same |

### Cross-version
- **new soviez-sh + old SaaS**: UNSAFE for Stage/migration/offline/registry ticket flows requiring 078–090.
- **old soviez-sh + new SaaS**: generally SAFE if APIs remain backward compatible (additive migrations); verify no breaking removals.
- **new soviez-sh + old ERP main wizard**: UNSAFE for Stage `proxy_mode` / WS longpoll parity (post-cert fixes live in wizard).
- **old soviez-sh + new wizard**: mostly SAFE for Production bootstrap; Stage still improved on wizard side only.
