#!/bin/sh
# Executable acceptance tests for safe replacement of accepted 0.1.1 native roles.

set -u

pass() { printf '%s\n' "PASS: $*"; }
failures=0
record_failure() {
  printf '%s\n' "FAIL: $*" >&2
  printf '%s\n' "::error::$*" >&2
  failures=$((failures + 1))
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
test_support=$script_dir/verifier-test-support.sh
fixture_dir=$script_dir/fixtures/native-roles-0.1.1
current_dir=$plugin_dir/agents

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml
luna_file=react-sol-advisor-luna-implementer.toml
terra_fixture=$fixture_dir/$terra_file
sol_fixture=$fixture_dir/$sol_file
terra_current=$current_dir/$terra_file
sol_current=$current_dir/$sol_file

for required in "$installer" "$test_support" "$terra_fixture" "$sol_fixture" \
  "$terra_current" "$sol_current"; do
  [ -f "$required" ] || {
    record_failure "missing upgrade acceptance input: $required"
    continue
  }
done

[ "$failures" -eq 0 ] || exit 1

[ -x "$installer" ] || record_failure "install-agents.sh is not executable"

# Fixtures are immutable, accepted 0.1.1 templates rather than copies manufactured by
# the installer. The hashes protect the only files eligible for automatic replacement.
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

[ "$(sha256_file "$terra_fixture")" = "8cd2ed825f58574fd578832dd35f7932d365214db91ab84f79af7a64d3c863b1" ] ||
  record_failure "immutable 0.1.1 Terra fixture hash changed"
[ "$(sha256_file "$sol_fixture")" = "cf96fa0b638d879b072b896748e985ded79e68f2814e9eeab8b9c8c841776241" ] ||
  record_failure "immutable 0.1.1 Sol fixture hash changed"

sh -n "$installer" || record_failure "install-agents.sh has invalid shell syntax"
sh -n "$test_support" || record_failure "verifier-test-support.sh has invalid shell syntax"

. "$test_support"
tmp_base=$(rsa_resolve_verifier_tmp_base) || {
  record_failure "could not resolve verifier TMPDIR"
  exit 1
}
tmp_dir=''
cleanup() {
  rsa_cleanup_verifier_fixture "$tmp_base" react-sol-advisor-agent-upgrade "$tmp_dir" || true
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/react-sol-advisor-agent-upgrade.XXXXXX") || {
  record_failure "could not create upgrade fixture directory"
  exit 1
}

prepare_stale_pair() {
  target=$1
  mkdir -p "$target" || return 1
  cp "$terra_fixture" "$target/$terra_file" || return 1
  cp "$sol_fixture" "$target/$sol_file" || return 1
}

add_upstream_sentinels() {
  target=$1
  printf '%s\n' "upstream-terra-sentinel" > "$target/sol-advisor-terra-implementer.toml" || return 1
  printf '%s\n' "upstream-sol-sentinel" > "$target/sol-advisor-sol-reviewer.toml" || return 1
}

target_signature() {
  target=$1
  (
    cd "$target" || exit 1
    find . -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort | while IFS= read -r entry; do
      if [ -L "$entry" ]; then
        printf 'symlink %s -> %s\n' "$entry" "$(readlink "$entry")"
      elif [ -f "$entry" ]; then
        printf 'file %s %s\n' "$entry" "$(sha256_file "$entry")"
      elif [ -d "$entry" ]; then
        printf 'directory %s\n' "$entry"
      else
        printf 'other %s\n' "$entry"
      fi
    done
  )
}

role_and_upstream_signature() {
  target=$1
  for name in \
    "$terra_file" \
    "$sol_file" \
    sol-advisor-terra-implementer.toml \
    sol-advisor-sol-reviewer.toml; do
    printf '%s %s\n' "$name" "$(sha256_file "$target/$name")"
  done
}

assert_no_upgrade_artifacts() {
  label=$1
  target=$2

  if artifact=$(find "$target" -maxdepth 1 -name '.react-sol-advisor-upgrade-*' -print -quit) && [ -n "$artifact" ]; then
    record_failure "$label left an upgrade stage or backup artifact: $artifact"
  else
    pass "$label leaves no upgrade stage or backup artifacts"
  fi
}

assert_unchanged_refusal() {
  label=$1
  target=$2
  expected_marker=$3
  shift 3
  before=$(target_signature "$target") || {
    record_failure "$label could not capture pre-refusal state"
    return
  }
  if output=$("$@" 2>&1); then
    record_failure "$label was accepted instead of refused"
  elif ! printf '%s\n' "$output" | grep -Fq -- "$expected_marker"; then
    record_failure "$label refusal omitted exact marker: $expected_marker"
  elif [ "$(target_signature "$target")" != "$before" ]; then
    record_failure "$label mutated a destination before refusing it"
  else
    pass "$label refuses before mutation"
  fi
}

# A default invocation must never replace an older accepted template implicitly.
default_target=$tmp_dir/default-stale
prepare_stale_pair "$default_target" || record_failure "could not prepare default stale fixture"
add_upstream_sentinels "$default_target" || record_failure "could not prepare upstream sentinels"
assert_unchanged_refusal \
  "default install of known 0.1.1 roles" "$default_target" "--upgrade-known" \
  sh "$installer" --target-dir "$default_target"

# Check is read-only and must identify an eligible stale state, not describe it as an
# arbitrary conflict. This lets operators distinguish a safe upgrade from a manual case.
check_target=$tmp_dir/check-stale
prepare_stale_pair "$check_target" || record_failure "could not prepare check stale fixture"
assert_unchanged_refusal \
  "--check of known 0.1.1 roles" "$check_target" "known stale 0.1.1" \
  sh "$installer" --target-dir "$check_target" --check

# Mutually exclusive flags and invalid failure-injection values must fail before any
# stage, backup, or destination mutation. These are deliberate safety interfaces, not
# convenience argument parsing.
combined_target=$tmp_dir/combined-flags
prepare_stale_pair "$combined_target" || record_failure "could not prepare combined-flags fixture"
assert_unchanged_refusal \
  "--check plus --upgrade-known" "$combined_target" "--check and --upgrade-known cannot be used together" \
  sh "$installer" --target-dir "$combined_target" --check --upgrade-known

invalid_injection_target=$tmp_dir/invalid-injection
prepare_stale_pair "$invalid_injection_target" || record_failure "could not prepare invalid injection fixture"
assert_unchanged_refusal \
  "invalid replacement failure injection" "$invalid_injection_target" "RSA_INSTALL_TEST_FAIL_REPLACE must be empty or sol" \
  env RSA_INSTALL_TEST_FAIL_REPLACE=terra sh "$installer" --target-dir "$invalid_injection_target" --upgrade-known

backup_target=$tmp_dir/preexisting-backup
prepare_stale_pair "$backup_target" || record_failure "could not prepare preexisting backup fixture"
printf '%s\n' "preserve this guarded recovery artifact" > "$backup_target/.react-sol-advisor-upgrade-terra.backup" ||
  record_failure "could not prepare preexisting guarded backup"
assert_unchanged_refusal \
  "pre-existing upgrade backup" "$backup_target" "refusing existing upgrade backup" \
  sh "$installer" --target-dir "$backup_target" --upgrade-known

# Simulate a concurrent process creating an unknown Sol backup between the preflight
# absence check and the second hard-link call. The installer may clean only the Terra
# backup it created itself; it must preserve the unknown Sol sentinel and both old role
# destinations unchanged.
toctou_target=$tmp_dir/backup-creation-race
prepare_stale_pair "$toctou_target" || record_failure "could not prepare backup race fixture"
add_upstream_sentinels "$toctou_target" || record_failure "could not prepare backup race sentinels"
toctou_before=$(role_and_upstream_signature "$toctou_target")
fake_bin=$tmp_dir/fake-ln-bin
mkdir "$fake_bin" || record_failure "could not prepare fake ln directory"
real_ln=$(command -v ln) || record_failure "could not resolve system ln"
sol_backup_sentinel=$tmp_dir/unknown-sol-backup-sentinel
printf '%s\n' "concurrent unknown Sol backup" > "$sol_backup_sentinel" ||
  record_failure "could not prepare unknown Sol backup sentinel"
fake_ln=$fake_bin/ln
printf '%s\n' \
  '#!/bin/sh' \
  'case "$2" in' \
  '  */.react-sol-advisor-upgrade-terra.backup)' \
  '    exec "$RSA_TEST_REAL_LN" "$@"' \
  '    ;;' \
  '  */.react-sol-advisor-upgrade-sol.backup)' \
  '    cp "$RSA_TEST_SOL_BACKUP_SENTINEL" "$2"' \
  '    exit 1' \
  '    ;;' \
  '  *)' \
  '    exec "$RSA_TEST_REAL_LN" "$@"' \
  '    ;;' \
  'esac' > "$fake_ln" || record_failure "could not create fake ln wrapper"
chmod 755 "$fake_ln" || record_failure "could not make fake ln wrapper executable"
if toctou_output=$(RSA_TEST_REAL_LN="$real_ln" RSA_TEST_SOL_BACKUP_SENTINEL="$sol_backup_sentinel" PATH="$fake_bin:$PATH" sh "$installer" --target-dir "$toctou_target" --upgrade-known 2>&1); then
  record_failure "guarded backup creation race was accepted"
elif ! printf '%s\n' "$toctou_output" | grep -Fq "could not create guarded upgrade backups"; then
  record_failure "guarded backup creation race omitted exact failure marker"
elif ! cmp -s "$terra_fixture" "$toctou_target/$terra_file" || ! cmp -s "$sol_fixture" "$toctou_target/$sol_file"; then
  record_failure "guarded backup creation race changed an accepted 0.1.1 destination"
elif ! cmp -s "$sol_backup_sentinel" "$toctou_target/.react-sol-advisor-upgrade-sol.backup"; then
  record_failure "guarded backup creation race did not preserve unknown Sol backup sentinel"
elif [ -e "$toctou_target/.react-sol-advisor-upgrade-terra.backup" ] || [ -L "$toctou_target/.react-sol-advisor-upgrade-terra.backup" ]; then
  record_failure "guarded backup creation race left the run-created Terra backup"
elif stage_paths=$(find "$toctou_target" -maxdepth 1 -type f -name '.react-sol-advisor-upgrade-*' ! -name '*.backup' -print) && [ -n "$stage_paths" ]; then
  record_failure "guarded backup creation race left staged upgrade files: $stage_paths"
elif [ "$(role_and_upstream_signature "$toctou_target")" != "$toctou_before" ]; then
  record_failure "guarded backup creation race changed a role or upstream sentinel"
else
  pass "guarded backup creation failure preserves concurrent backup and cleans owned state"
fi

# Exact accepted pair is the sole automatic-upgrade admission case.
upgrade_target=$tmp_dir/upgrade-known
prepare_stale_pair "$upgrade_target" || record_failure "could not prepare upgrade stale fixture"
add_upstream_sentinels "$upgrade_target" || record_failure "could not prepare upgrade sentinels"
upstream_terra_before=$(sha256_file "$upgrade_target/sol-advisor-terra-implementer.toml")
upstream_sol_before=$(sha256_file "$upgrade_target/sol-advisor-sol-reviewer.toml")
if upgrade_output=$(sh "$installer" --target-dir "$upgrade_target" --upgrade-known 2>&1); then
  if ! printf '%s\n' "$upgrade_output" | grep -Fq "UPGRADED KNOWN 0.1.1"; then
    record_failure "known upgrade omitted its explicit UPGRADED KNOWN 0.1.1 marker"
  elif ! cmp -s "$terra_current" "$upgrade_target/$terra_file" || ! cmp -s "$sol_current" "$upgrade_target/$sol_file"; then
    record_failure "known upgrade did not install both current shipped templates"
  elif [ -e "$upgrade_target/$luna_file" ] || [ -L "$upgrade_target/$luna_file" ]; then
    record_failure "known upgrade created a native Luna role"
  elif [ "$(sha256_file "$upgrade_target/sol-advisor-terra-implementer.toml")" != "$upstream_terra_before" ] || \
       [ "$(sha256_file "$upgrade_target/sol-advisor-sol-reviewer.toml")" != "$upstream_sol_before" ]; then
    record_failure "known upgrade changed an upstream sol-advisor sentinel"
  else
    pass "--upgrade-known replaces only both exact accepted 0.1.1 roles"
  fi
  assert_no_upgrade_artifacts "successful known upgrade" "$upgrade_target"
else
  record_failure "--upgrade-known rejected the exact accepted 0.1.1 role pair"
fi

# Unknown and unsafe states are all preflight failures. Every case begins with a known
# pair so a failure cannot hide a partial replacement behind an unrelated missing file.
modified_target=$tmp_dir/unknown-modified
prepare_stale_pair "$modified_target" || record_failure "could not prepare modified fixture"
printf '%s\n' "user-owned modification" >> "$modified_target/$terra_file"
assert_unchanged_refusal \
  "unknown modified role" "$modified_target" "not a known 0.1.1 template" \
  sh "$installer" --target-dir "$modified_target" --upgrade-known

modified_sol_target=$tmp_dir/unknown-modified-sol
prepare_stale_pair "$modified_sol_target" || record_failure "could not prepare modified Sol fixture"
printf '%s\n' "user-owned Sol modification" >> "$modified_sol_target/$sol_file"
assert_unchanged_refusal \
  "unknown modified Sol role" "$modified_sol_target" "not a known 0.1.1 template" \
  sh "$installer" --target-dir "$modified_sol_target" --upgrade-known

symlink_target=$tmp_dir/symlinked
prepare_stale_pair "$symlink_target" || record_failure "could not prepare symlink fixture"
rm "$symlink_target/$terra_file" || record_failure "could not prepare symlink target"
ln -s "$terra_fixture" "$symlink_target/$terra_file" || record_failure "could not create symlinked destination"
assert_unchanged_refusal \
  "symlinked role" "$symlink_target" "unsafe" \
  sh "$installer" --target-dir "$symlink_target" --upgrade-known

nonregular_target=$tmp_dir/nonregular
prepare_stale_pair "$nonregular_target" || record_failure "could not prepare nonregular fixture"
rm "$nonregular_target/$terra_file" || record_failure "could not prepare nonregular target"
mkdir "$nonregular_target/$terra_file" || record_failure "could not create nonregular destination"
assert_unchanged_refusal \
  "nonregular role" "$nonregular_target" "unsafe" \
  sh "$installer" --target-dir "$nonregular_target" --upgrade-known

mixed_target=$tmp_dir/mixed-partial
prepare_stale_pair "$mixed_target" || record_failure "could not prepare mixed fixture"
cp "$terra_current" "$mixed_target/$terra_file" || record_failure "could not prepare mixed current Terra"
assert_unchanged_refusal \
  "mixed current/stale role pair" "$mixed_target" "mixed/partial" \
  sh "$installer" --target-dir "$mixed_target" --upgrade-known

missing_target=$tmp_dir/missing-partial
mkdir "$missing_target" || record_failure "could not prepare missing fixture"
cp "$terra_fixture" "$missing_target/$terra_file" || record_failure "could not prepare missing stale Terra"
assert_unchanged_refusal \
  "missing partial role pair" "$missing_target" "mixed/partial" \
  sh "$installer" --target-dir "$missing_target" --upgrade-known

retired_target=$tmp_dir/retired-luna
prepare_stale_pair "$retired_target" || record_failure "could not prepare retired Luna fixture"
printf '%s\n' "retired native Luna role" > "$retired_target/$luna_file"
assert_unchanged_refusal \
  "retired native Luna state" "$retired_target" "unsupported native Luna companion" \
  sh "$installer" --target-dir "$retired_target" --upgrade-known

# The deterministic test hook forces the second replacement to fail after Terra has
# changed. The failure and rollback markers are contractual so a generic nonzero exit
# cannot accidentally satisfy this safety test.
rollback_target=$tmp_dir/rollback-known
prepare_stale_pair "$rollback_target" || record_failure "could not prepare rollback fixture"
add_upstream_sentinels "$rollback_target" || record_failure "could not prepare rollback upstream sentinels"
rollback_before=$(target_signature "$rollback_target")
if rollback_output=$(RSA_INSTALL_TEST_FAIL_REPLACE=sol sh "$installer" --target-dir "$rollback_target" --upgrade-known 2>&1); then
  record_failure "deterministic second replacement failure was accepted"
elif ! printf '%s\n' "$rollback_output" | grep -Fq "TEST INJECTION: forced replacement failure for Sol"; then
  record_failure "second replacement failure omitted its deterministic injection marker"
elif ! printf '%s\n' "$rollback_output" | grep -Fq "ROLLBACK: restored known 0.1.1 Terra template"; then
  record_failure "second replacement failure omitted the exact Terra rollback marker"
elif ! cmp -s "$terra_fixture" "$rollback_target/$terra_file" || ! cmp -s "$sol_fixture" "$rollback_target/$sol_file"; then
  record_failure "second replacement failure did not restore both exact old templates"
elif [ "$(target_signature "$rollback_target")" != "$rollback_before" ]; then
  record_failure "second replacement failure did not restore the exact pre-upgrade state"
else
  pass "second replacement failure rolls back both known old roles exactly"
fi

# Once current, --upgrade-known is a no-op and retains upstream sentinels unchanged.
idempotent_before=$(target_signature "$upgrade_target")
if idempotent_output=$(sh "$installer" --target-dir "$upgrade_target" --upgrade-known 2>&1); then
  if ! printf '%s\n' "$idempotent_output" | grep -Fq "ALREADY CURRENT"; then
    record_failure "current/current --upgrade-known omitted ALREADY CURRENT marker"
  elif [ "$(target_signature "$upgrade_target")" != "$idempotent_before" ]; then
    record_failure "current/current --upgrade-known was not idempotent"
  else
    pass "current/current --upgrade-known is idempotent"
  fi
  assert_no_upgrade_artifacts "idempotent current/current upgrade" "$upgrade_target"
else
  record_failure "current/current --upgrade-known unexpectedly failed"
fi

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "AGENT UPGRADE ACCEPTANCE FAILED: $failures regression(s)" >&2
  exit 1
fi

printf '%s\n' "AGENT UPGRADE ACCEPTANCE PASSED"
