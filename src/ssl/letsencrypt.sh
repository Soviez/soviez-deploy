# shellcheck shell=bash

soviez_ssl_letsencrypt_render() {
  local domain="$1"
  local email="$2"
  printf 'certbot certonly --nginx -d %s --email %s --agree-tos --non-interactive\n' "$domain" "$email"
}

soviez_ssl_letsencrypt_map_error() {
  local stderr="$1"
  case "$stderr" in
    *rate*limit*) printf 'letsencrypt_rate_limited\n' ;;
    *dns*) printf 'dns_challenge_failed\n' ;;
    *) printf 'letsencrypt_failed\n' ;;
  esac
}
