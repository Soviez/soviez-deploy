# Migration / restore quarantine gap

Current: restore can progress toward normal boot without mandatory:
quarantine → static DB scan → technical review → blocked egress → neutralize cron/mail/webhooks → validation → explicit acceptance → live.

Stage neutralization exists partially; Production restore path lacks full security quarantine gate.

**Gap class:** HIGH (design required; implement in Gate S4).
