# Disk cleanup report

Phase 24 / `run_all` used disposable `/tmp` roots and labeled fixtures. Exact dangling volume reclaim ran between suites. Colima `default` profile was stopped/started by reboot suites and left running afterward for host use — **VM not deleted** (holds retained `wab-poc_*` / RC / Phase 17 resources; disposability UNSAFE). No global `docker system prune`. No unrelated resource deletion.
