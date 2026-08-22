#!/usr/bin/env bash
# shellcheck shell=bash
# Accept historical phase labels and current platform-cli lineage.

soviez_test_accept_dist_version() {
  local ver="$1"
  case "$ver" in
    0.21.0-phase21|0.22.0-phase22|0.23.0-phase23|0.24.0-phase24| \
    0.24.1-security-s1|0.24.2-security-s2|0.24.3-security-s3|0.24.4-security-s4| \
    0.24.5-security-s5|0.24.5.1-security-s5-corr1|0.24.5.2-postcert-corr1| \
    0.24.5.3-registry-gateway|0.24.6.*-platform-cli)
      return 0
      ;;
  esac
  return 1
}
