# shellcheck shell=bash
# Security Gate S4 — cron neutralization (runtime; reversible).

soviez_q_odoo_quarantine_conf_snippet() {
  cat <<'EOF'
# Soviez S4 quarantine — runtime containment (reversible on promotion)
max_cron_threads = 0
workers = 0
list_db = False
proxy_mode = True
EOF
}

soviez_q_cron_marker_seed_sql() {
  cat <<'SQL'
CREATE TABLE IF NOT EXISTS soviez_q_cron_marker (id serial PRIMARY KEY, fired_at timestamptz);
CREATE TABLE IF NOT EXISTS ir_cron (
  id serial PRIMARY KEY,
  cron_name text,
  code text,
  active boolean DEFAULT true,
  interval_number int DEFAULT 1,
  interval_type text DEFAULT 'minutes',
  numbercall int DEFAULT -1,
  doall boolean DEFAULT false,
  nextcall timestamp without time zone DEFAULT now()
);
INSERT INTO ir_cron(cron_name, code, active)
SELECT 'soviez_q_probe', 'INSERT INTO soviez_q_cron_marker(fired_at) VALUES (now())', true
WHERE NOT EXISTS (SELECT 1 FROM ir_cron WHERE cron_name='soviez_q_probe');
SQL
}

soviez_q_assert_cron_not_fired() {
  local ctn="$1" user="$2" pass="$3" db="$4"
  local n
  n="$(docker exec -e PGPASSWORD="$pass" "$ctn" psql -U "$user" -d "$db" -At -c \
    "SELECT count(*) FROM soviez_q_cron_marker;" 2>/dev/null || echo 0)"
  if [[ "${n:-0}" != "0" ]]; then
    echo "[error] security:SEC_CRIT_CRON_ACTIVE_IN_QUARANTINE: marker count=$n" >&2
    return 1
  fi
  return 0
}
