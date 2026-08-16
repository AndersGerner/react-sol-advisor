#!/bin/sh
set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
root=$(mktemp -d "$tmp_base/sol-advisor-tmpdir.XXXXXX")
physical_root=$(CDPATH= cd "$root" && pwd -P)
cleanup() {
  rm -rf -- "$physical_root"
}
trap cleanup 0 HUP INT TERM
physical=$physical_root/physical
mkdir "$physical"
link=$physical_root/link
ln -s "$physical" "$link"
TMPDIR="$link" sh "$script_dir/verify-cross-client.sh"
TMPDIR="$link" python3 "$script_dir/verify-codex-adapter.py"
printf '%s\n' "TMPDIR PORTABILITY PASSED"
