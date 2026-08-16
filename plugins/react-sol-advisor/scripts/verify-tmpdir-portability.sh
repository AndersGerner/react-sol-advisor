#!/bin/sh
set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
root=$(mktemp -d /private/tmp/sol-advisor-tmpdir.XXXXXX)
physical=$root/physical
mkdir "$physical"
link=$root/link
ln -s "$physical" "$link"
TMPDIR="$link" sh "$script_dir/verify-cross-client.sh"
TMPDIR="$link" python3 "$script_dir/verify-codex-adapter.py"
printf '%s\n' "TMPDIR PORTABILITY PASSED"
