# Self-update architecture

mutating command → detect version → fetch signed manifest → download candidate → SHA256 + signature → validate → lock → install current/previous rotate → re-exec argv with SOVIEZ_SKIP_PLATFORM_UPDATE=1

Support expiry does NOT block platform update. ERP product update remains entitlement-gated.
