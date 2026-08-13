# shellcheck shell=bash

soviez_migration_compress_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if command -v zstd >/dev/null 2>&1; then
    if zstd -q -T1 -3 -f "$src" -o "$dest" 2>/dev/null; then
      printf 'zstd\n'
      return 0
    fi
  fi
  gzip -c "$src" > "$dest"
  printf 'gzip\n'
}

soviez_migration_decompress_file() {
  local src="$1" dest="$2" algo="${3:-auto}"
  mkdir -p "$(dirname "$dest")"
  case "$algo" in
    zstd)
      zstd -q -T1 -d -f "$src" -o "$dest"
      ;;
    gzip)
      gzip -dc "$src" > "$dest"
      ;;
    auto|*)
      if [[ "$src" == *.zst ]] || file "$src" 2>/dev/null | grep -qi zstd; then
        zstd -q -T1 -d -f "$src" -o "$dest" 2>/dev/null || gzip -dc "$src" > "$dest"
      else
        gzip -dc "$src" > "$dest" 2>/dev/null || zstd -q -T1 -d -f "$src" -o "$dest"
      fi
      ;;
  esac
}
