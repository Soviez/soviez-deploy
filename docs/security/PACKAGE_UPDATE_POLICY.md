# Package Update Policy (S5)

- Do not force-kill APT/dpkg/unattended-upgrade holders.
- Wait for locks; defer/abort installer if locked (`PKG_LOCK_TIMEOUT`).
- Unattended-upgrades may supply security patches; disruptive service restarts gated by S5 restart matrix.
- Canonical wait: `src/security/update_safety/apt_lock.sh` → `soviez_s5_apt_wait_for_lock`.
- Src healer scan must report **SAFE**.

## S5 Corrective Closure (corr1) — `0.24.5.1-security-s5-corr1`
- Dual Production wizard (Case A: ERP ↔ soviez-deploy) `heal_apt_locks` replaced with **wait-or-fail** (name retained).
- No `killall -9 apt/dpkg/unattended-upgrade`; no blind apt/dpkg lock `rm`.
- Evidence: `docs/evidence/security-s5-apt-lock-correction/`.
- Prior note that legacy killall “exists only in soviez-deploy” is **superseded** — deploy remediated in corr1.
