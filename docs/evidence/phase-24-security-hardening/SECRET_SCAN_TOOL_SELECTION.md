# Secret scan tool selection

Chosen: **embedded pattern/entropy scanner** as authoritative local gate; **Gitleaks** preferred when installed.

Why:
1. Repository is local-first / may have no CI SaaS
2. Gitleaks not installed on certification host — cannot hard-require it for PASS
3. Embedded scanner covers required patterns + high-entropy assignments
4. `.gitleaks.toml` ready for CI hosts that install gitleaks
