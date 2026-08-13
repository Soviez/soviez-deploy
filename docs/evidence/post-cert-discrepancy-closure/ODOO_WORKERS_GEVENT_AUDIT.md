# ODOO_WORKERS_GEVENT_AUDIT

Default Production/Stage workers=0.
formworkers previously set workers>0 without gevent — FIXED: Odoo workers forced to 0; formula retained for memory/cgroup sizing only.
gevent_port never set by installer. workers>0 = NOT_SUPPORTED.
