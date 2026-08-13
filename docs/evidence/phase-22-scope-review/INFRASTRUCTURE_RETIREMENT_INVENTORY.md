# Infrastructure Retirement Inventory

Phase 22 produces a **retirement plan**, not broad deletion.

Inventory each:

host · VM · container · volumes · disks · snapshots · databases · filestore paths · Nginx sites · certificates · DNS records · firewall · SSH keys · service users · systemd · cron · backup jobs · provider resources · monitoring · log retention · Stage resources

Per resource fields:

exact ID · owner · source/destination · active/inactive · archive dependency · recovery dependency · retention requirement · deletion authority · purge eligibility · current action · future action · blocker

Unknown/orphaned resources → WARNING/BLOCKED on retirement readiness, not silent ignore.
