#!/bin/sh
# Regression coverage for verifier-owned fixture roots below symlinked TMPDIR aliases.

set -eu

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
test_support=$script_dir/verifier-test-support.sh
[ -f "$test_support" ] || fail "missing verifier test support: $test_support"
. "$test_support"

physical_tmp_base=${TMPDIR:-/tmp}
case "$physical_tmp_base" in
  /*) ;;
  *) physical_tmp_base=/tmp ;;
esac
[ -d "$physical_tmp_base" ] || physical_tmp_base=/tmp
physical_tmp_base=$(CDPATH= cd "$physical_tmp_base" && pwd -P) ||
  fail "could not resolve a physical base for the portability regression"

fixture_root=$(mktemp -d "$physical_tmp_base/react-sol-advisor-tmpdir-portability.XXXXXX") ||
  fail "could not create the portability regression fixture"
cleanup() {
  case "$fixture_root" in
    "$physical_tmp_base"/react-sol-advisor-tmpdir-portability.*) rm -rf "$fixture_root" ;;
    *) printf '%s\n' "ERROR: refusing cleanup of unexpected fixture: $fixture_root" >&2 ;;
  esac
}
trap cleanup 0 HUP INT TERM

physical_fixture=$fixture_root/physical
tmpdir_alias=$fixture_root/tmpdir-alias
mkdir "$physical_fixture"
ln -s "$physical_fixture" "$tmpdir_alias"

resolved_physical=$(TMPDIR="$physical_fixture" rsa_resolve_verifier_tmp_base) ||
  fail "physical TMPDIR did not resolve"
[ "$resolved_physical" = "$physical_fixture" ] ||
  fail "physical TMPDIR was not preserved"

resolved_alias=$(TMPDIR="$tmpdir_alias" rsa_resolve_verifier_tmp_base) ||
  fail "symlinked TMPDIR did not resolve"
[ "$resolved_alias" = "$physical_fixture" ] ||
  fail "symlinked TMPDIR did not resolve to its physical directory"

fallback_base=$(CDPATH= cd /tmp && pwd -P) || fail "could not resolve fallback /tmp"
resolved_relative=$(TMPDIR=relative-tmp rsa_resolve_verifier_tmp_base) ||
  fail "relative TMPDIR did not use the safe fallback"
[ "$resolved_relative" = "$fallback_base" ] ||
  fail "relative TMPDIR did not fall back to physical /tmp"

missing_tmpdir=$fixture_root/missing-tmpdir
if missing_output=$(TMPDIR="$missing_tmpdir" rsa_resolve_verifier_tmp_base 2>&1); then
  fail "missing TMPDIR directory was accepted"
fi
printf '%s\n' "$missing_output" |
  grep -Fq "ERROR: verifier TMPDIR is not an existing directory: $missing_tmpdir" ||
  fail "missing TMPDIR directory did not produce the documented error"

relative_output=$fixture_root/relative-tmpdir.out
if ! TMPDIR=relative-tmp sh "$script_dir/verify-contracts.sh" >"$relative_output" 2>&1; then
  cat "$relative_output" >&2
  fail "a verifier did not safely fall back from relative TMPDIR"
fi
grep -Fq "CONTRACTS PASSED" "$relative_output" ||
  fail "relative TMPDIR verifier run did not complete"

missing_verifier_output=$fixture_root/missing-tmpdir.out
if TMPDIR="$missing_tmpdir" sh "$script_dir/verify-contracts.sh" >"$missing_verifier_output" 2>&1; then
  fail "a verifier accepted a missing TMPDIR directory"
fi
grep -Fq "ERROR: verifier TMPDIR is not an existing directory: $missing_tmpdir" \
  "$missing_verifier_output" ||
  fail "a verifier did not report the documented missing TMPDIR error"

outside_fixture=$fixture_root/not-verifier-owned
mkdir "$outside_fixture"
printf '%s\n' keep > "$outside_fixture/sentinel"
if rsa_cleanup_verifier_fixture "$physical_fixture" react-sol-advisor-verify "$outside_fixture" >/dev/null 2>&1; then
  fail "cleanup accepted a directory outside the resolved verifier prefix"
fi
[ -f "$outside_fixture/sentinel" ] ||
  fail "cleanup removed data outside the resolved verifier prefix"
printf '%s\n' "PASS: TMPDIR resolution and cleanup-prefix guards"

run_verifier() {
  verifier_name=$1
  intended_marker=$2
  output_file=$fixture_root/$verifier_name.out

  if ! TMPDIR="$tmpdir_alias" sh "$script_dir/$verifier_name" >"$output_file" 2>&1; then
    cat "$output_file" >&2
    fail "$verifier_name failed with TMPDIR through a symlink alias"
  fi
  grep -Fq "$intended_marker" "$output_file" || {
    cat "$output_file" >&2
    fail "$verifier_name did not reach its intended installer behavior"
  }
  if find "$physical_fixture" -mindepth 1 -print | grep -q .; then
    find "$physical_fixture" -mindepth 1 -print >&2
    fail "$verifier_name left verifier-owned fixtures behind"
  fi
  printf '%s\n' "PASS: $verifier_name accepts a symlinked TMPDIR and reaches intended installer behavior"
}

run_verifier verify.sh \
  "PASS: installer rolls back partial install when the second file fails"
run_verifier verify-hardening.sh \
  "PASS: installer rollback preserves whitespace-containing target paths"
run_verifier verify-contracts.sh \
  "PASS: retired native Luna role reaches installer preflight"

printf '%s\n' "TMPDIR PORTABILITY PASSED"
