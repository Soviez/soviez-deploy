# SELF_UPDATE_LIVE_POSITIVE

- captured_utc: 2026-08-16T16:20:38Z
- host: soviez-u2404
- channel: staging
- SELFUP-LIVE-01 (published staging manifest + candidate, VERSION file 0.24.6.0 → 0.24.6.1):
  - Status: **BLOCKED / FAIL apply**
  - Observation: no Ed25519 reject on published manifest; install path then fails with  from platform install ( bug)
  - Payload SHA preserved: dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b
  - VERSION file not advanced (remained 0.24.6.0) though embedded  still reports 0.24.6.1 from payload content
- Connected curl download of cert-branch manifest → not required for local fixture path; published artifact URL available on GitHub raw
