# shellcheck shell=bash
# Phase 13 — calendar-day retention math (UTC persistence, host-TZ display).

# Override clock for tests: SOVIEZ_RETENTION_NOW_UTC=YYYY-MM-DDTHH:MM:SSZ
soviez_retention_now_utc() {
  if [[ -n "${SOVIEZ_RETENTION_NOW_UTC:-}" ]]; then
    printf '%s' "$SOVIEZ_RETENTION_NOW_UTC"
    return 0
  fi
  date -u +%Y-%m-%dT%H:%M:%SZ
}

soviez_retention_parse_utc_epoch() {
  local iso="$1"
  iso="$(printf '%s' "$iso" | sed -E 's/\.[0-9]+Z$/Z/; s/Z$//')"
  if date -u -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null; then
    return 0
  fi
  date -u -d "${iso}Z" +%s 2>/dev/null || date -u -d "$iso" +%s
}

soviez_retention_add_calendar_days_utc() {
  local created_iso="$1"
  local days="$2"
  CREATED="$created_iso" DAYS="$days" TZ_NAME="${SOVIEZ_RETENTION_HOST_TZ:-UTC}" python3 - <<'PY'
import os, datetime
created = os.environ["CREATED"].replace("Z", "+00:00")
if "." in created:
    head, rest = created.split(".", 1)
    for i, ch in enumerate(rest):
        if ch in "+-" and i > 0:
            created = head + rest[i:]
            break
    else:
        created = head + "+00:00"
days = int(os.environ["DAYS"])
tzname = os.environ["TZ_NAME"]
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(tzname)
except Exception:
    tz = datetime.timezone.utc
dt = datetime.datetime.fromisoformat(created)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=datetime.timezone.utc)
local = dt.astimezone(tz)
deadline_date = (local.date() + datetime.timedelta(days=days))
local_eod = datetime.datetime.combine(deadline_date, datetime.time(23, 59, 59), tzinfo=tz)
utc_eod = local_eod.astimezone(datetime.timezone.utc)
print(utc_eod.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
}

soviez_retention_calendar_date_in_host_tz() {
  local iso="$1"
  ISO="$iso" TZ_NAME="${SOVIEZ_RETENTION_HOST_TZ:-UTC}" python3 - <<'PY'
import os, datetime
iso = os.environ["ISO"].replace("Z", "+00:00")
if "." in iso:
    head, rest = iso.split(".", 1)
    for i, ch in enumerate(rest):
        if ch in "+-" and i > 0:
            iso = head + rest[i:]
            break
    else:
        iso = head + "+00:00"
tzname = os.environ["TZ_NAME"]
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(tzname)
except Exception:
    tz = datetime.timezone.utc
dt = datetime.datetime.fromisoformat(iso)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=datetime.timezone.utc)
print(dt.astimezone(tz).date().isoformat())
PY
}

soviez_retention_days_remaining() {
  local deadline_iso="$1"
  local now_iso="${2:-$(soviez_retention_now_utc)}"
  DEADLINE="$deadline_iso" NOW="$now_iso" TZ_NAME="${SOVIEZ_RETENTION_HOST_TZ:-UTC}" python3 - <<'PY'
import os, datetime
def parse(s):
    s = s.replace("Z", "+00:00")
    if "." in s:
        head, rest = s.split(".", 1)
        for i, ch in enumerate(rest):
            if ch in "+-" and i > 0:
                s = head + rest[i:]
                break
        else:
            s = head + "+00:00"
    dt = datetime.datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt
tzname = os.environ["TZ_NAME"]
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(tzname)
except Exception:
    tz = datetime.timezone.utc
now = parse(os.environ["NOW"]).astimezone(tz).date()
deadline = parse(os.environ["DEADLINE"]).astimezone(tz).date()
print((deadline - now).days)
PY
}

soviez_retention_format_date_display() {
  local iso="$1"
  ISO="$iso" TZ_NAME="${SOVIEZ_RETENTION_HOST_TZ:-UTC}" python3 - <<'PY'
import os, datetime
iso = os.environ["ISO"].replace("Z", "+00:00")
if "." in iso:
    head, rest = iso.split(".", 1)
    for i, ch in enumerate(rest):
        if ch in "+-" and i > 0:
            iso = head + rest[i:]
            break
    else:
        iso = head + "+00:00"
tzname = os.environ["TZ_NAME"]
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(tzname)
except Exception:
    tz = datetime.timezone.utc
dt = datetime.datetime.fromisoformat(iso)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=datetime.timezone.utc)
local = dt.astimezone(tz)
print(local.strftime("%d %b %Y"))
PY
}

soviez_retention_remaining_phrase() {
  local days="$1"
  if [[ "$days" -lt 0 ]]; then
    printf 'Deletion overdue — Needs Action'
  elif [[ "$days" -eq 0 ]]; then
    printf 'Deletion scheduled today'
  elif [[ "$days" -eq 1 ]]; then
    printf '1 day remaining'
  else
    printf '%s days remaining' "$days"
  fi
}
