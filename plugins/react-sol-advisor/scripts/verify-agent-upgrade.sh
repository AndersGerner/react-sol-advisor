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
if grep -Eq 'RSA_INSTALL_TEST_SWAP|run_swap_hook|swap-terra|swap-sol' "$installer"; then
  record_failure "installer retains an arbitrary production swap-source test surface"
else
  pass "installer exposes no arbitrary production swap-source test surface"
fi
rollback_masked=$(awk '
  /^  rollback_upgrade\(\) \{/ { in_rollback = 1; next }
  in_rollback && /^  upgrade_on_exit\(\) \{/ { exit }
  in_rollback && /trap/ && /HUP INT TERM/ { masked = 1 }
  in_rollback && /upgrade_active=0/ { if (masked) print "yes"; exit }
' "$installer")
signal_masked=$(awk '
  /^  upgrade_on_signal\(\) \{/ { in_signal = 1; next }
  in_signal && /^  # Install the transaction traps/ { exit }
  in_signal && /trap/ && /HUP INT TERM/ { masked = 1 }
  in_signal && /exit 1/ { if (masked) print "yes"; exit }
' "$installer")
if [ "$rollback_masked" = yes ] && [ "$signal_masked" = yes ]; then
  pass "rollback masks repeat HUP/INT/TERM before clearing active state and signal exit"
else
  record_failure "rollback does not mask repeat HUP/INT/TERM before active-state mutation"
fi

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

prepare_current_pair() {
  target=$1
  mkdir -p "$target" || return 1
  cp "$terra_current" "$target/$terra_file" || return 1
  cp "$sol_current" "$target/$sol_file" || return 1
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

wait_for_path() {
  path=$1
  label=$2
  attempts=0
  while [ ! -e "$path" ] && [ "$attempts" -lt 200 ]; do
    sleep 0.05
    attempts=$((attempts + 1))
  done
  if [ ! -e "$path" ]; then
    record_failure "timed out waiting for $label: $path"
    return 1
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

# Simulate a concurrent process creating an unknown Sol backup inside the private
# transaction. The installer may clean only its exact Terra artifact; it must preserve
# the unknown sentinel in an explicitly reported recovery transaction and both old role
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
  '  */terra.backup)' \
  '    exec "$RSA_TEST_REAL_LN" "$@"' \
  '    ;;' \
  '  */sol.backup)' \
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
elif ! printf '%s\n' "$toctou_output" | grep -Fq "could not create guarded Sol upgrade backup"; then
  record_failure "guarded backup creation race omitted exact failure marker"
elif ! cmp -s "$terra_fixture" "$toctou_target/$terra_file" || ! cmp -s "$sol_fixture" "$toctou_target/$sol_file"; then
  record_failure "guarded backup creation race changed an accepted 0.1.1 destination"
elif ! printf '%s\n' "$toctou_output" | grep -Fq "private recovery transaction"; then
  record_failure "guarded backup creation race did not report its preserved recovery transaction"
elif ! recovery_backup=$(find "$toctou_target" -path '*/sol.backup' -type f -print -quit) || [ -z "$recovery_backup" ] || ! cmp -s "$sol_backup_sentinel" "$recovery_backup"; then
  record_failure "guarded backup creation race did not preserve unknown Sol backup sentinel"
elif terra_backup_paths=$(find "$toctou_target" -path '*/terra.backup' -type f -print) && [ -n "$terra_backup_paths" ]; then
  record_failure "guarded backup creation race left a run-created Terra backup"
elif [ "$(role_and_upstream_signature "$toctou_target")" != "$toctou_before" ]; then
  record_failure "guarded backup creation race changed a role or upstream sentinel"
else
  pass "guarded backup creation failure preserves concurrent backup and reports private recovery state"
fi

# A destination can change after the final pair preflight. Terra must not overwrite
# that unknown replacement, Sol must remain old, and the private old state is retained
# only as an explicitly reported recovery transaction.
fake_mv_bin=$tmp_dir/fake-mv-bin
mkdir "$fake_mv_bin" || record_failure "could not prepare fake mv directory"
real_mv=$(command -v mv) || record_failure "could not resolve system mv"
fake_mv=$fake_mv_bin/mv
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1:$2" in' \
  '  "$RSA_TEST_TERRA_DEST":*/terra.displaced)' \
  '    "$RSA_TEST_REAL_MV" "$RSA_TEST_TERRA_SENTINEL" "$1"' \
  '    exec "$RSA_TEST_REAL_MV" "$@"' \
  '    ;;' \
  '  "$RSA_TEST_SOL_DEST":*/sol.displaced)' \
  '    "$RSA_TEST_REAL_MV" "$RSA_TEST_SOL_SENTINEL" "$1"' \
  '    exec "$RSA_TEST_REAL_MV" "$@"' \
  '    ;;' \
  '  *)' \
  '    exec "$RSA_TEST_REAL_MV" "$@"' \
  '    ;;' \
  'esac' > "$fake_mv" || record_failure "could not create fake mv wrapper"
chmod 755 "$fake_mv" || record_failure "could not make fake mv wrapper executable"

swap_terra_target=$tmp_dir/destination-swap-terra
prepare_stale_pair "$swap_terra_target" || record_failure "could not prepare Terra destination swap fixture"
add_upstream_sentinels "$swap_terra_target" || record_failure "could not prepare Terra destination swap sentinels"
swap_terra_reference=$tmp_dir/unknown-terra-reference
printf '%s\n' "concurrent unknown Terra destination" > "$swap_terra_reference" ||
  record_failure "could not prepare unknown Terra destination"
swap_terra_inject=$swap_terra_target/.verifier-unknown-terra
cp "$swap_terra_reference" "$swap_terra_inject" || record_failure "could not prepare Terra race injection"
swap_terra_upstream_before=$(role_and_upstream_signature "$swap_terra_target" | sed -n '3,4p')
if swap_terra_output=$(RSA_TEST_REAL_MV="$real_mv" RSA_TEST_TERRA_DEST="$swap_terra_target/$terra_file" RSA_TEST_TERRA_SENTINEL="$swap_terra_inject" PATH="$fake_mv_bin:$PATH" sh "$installer" --target-dir "$swap_terra_target" --upgrade-known 2>&1); then
  record_failure "Terra destination swap was accepted"
elif ! printf '%s\n' "$swap_terra_output" | grep -Fq "Terra displace revalidation failed; restored unknown destination without overwrite" ||
     ! printf '%s\n' "$swap_terra_output" | grep -Fq "private recovery transaction"; then
  record_failure "Terra destination swap omitted exact post-displacement revalidation markers"
elif printf '%s\n' "$swap_terra_output" | grep -Fq "known Terra destination changed before publication"; then
  record_failure "Terra destination swap was rejected by pre-displacement classification instead of CAS revalidation"
elif ! cmp -s "$swap_terra_reference" "$swap_terra_target/$terra_file" ||
     ! cmp -s "$sol_fixture" "$swap_terra_target/$sol_file"; then
  record_failure "Terra destination swap overwrote unknown Terra or accepted a partial publication"
elif [ -e "$swap_terra_target/$luna_file" ] || [ -L "$swap_terra_target/$luna_file" ] ||
     [ "$(role_and_upstream_signature "$swap_terra_target" | sed -n '3,4p')" != "$swap_terra_upstream_before" ]; then
  record_failure "Terra destination swap changed Luna or upstream sentinels"
elif ! find "$swap_terra_target" -maxdepth 1 -type d -name '.react-sol-advisor-upgrade-txn.*' -print -quit | grep -q .; then
  record_failure "Terra destination swap did not retain explicitly reported private recovery"
elif ! swap_terra_recovery=$(find "$swap_terra_target" -path '*/terra.backup' -type f -print -quit) || [ -z "$swap_terra_recovery" ] || ! cmp -s "$terra_fixture" "$swap_terra_recovery"; then
  record_failure "Terra destination swap did not preserve the guarded old Terra recovery copy"
elif swap_terra_extra=$(find "$swap_terra_target" -path '*/.react-sol-advisor-upgrade-txn.*/*' ! -name terra.backup -print) && [ -n "$swap_terra_extra" ]; then
  record_failure "Terra destination swap left owned private artifacts beyond the reported recovery copy: $swap_terra_extra"
else
  pass "Terra destination swap preserves unknown content and fails without partial publication"
fi

# Once Terra is published, a concurrent unknown Sol replacement must survive and the
# Terra side must roll back through a no-clobber publication of the guarded old state.
swap_sol_target=$tmp_dir/destination-swap-sol
prepare_stale_pair "$swap_sol_target" || record_failure "could not prepare Sol destination swap fixture"
add_upstream_sentinels "$swap_sol_target" || record_failure "could not prepare Sol destination swap sentinels"
swap_sol_reference=$tmp_dir/unknown-sol-reference
printf '%s\n' "concurrent unknown Sol destination" > "$swap_sol_reference" ||
  record_failure "could not prepare unknown Sol destination"
swap_sol_inject=$swap_sol_target/.verifier-unknown-sol
cp "$swap_sol_reference" "$swap_sol_inject" || record_failure "could not prepare Sol race injection"
swap_sol_upstream_before=$(role_and_upstream_signature "$swap_sol_target" | sed -n '3,4p')
if swap_sol_output=$(RSA_TEST_REAL_MV="$real_mv" RSA_TEST_SOL_DEST="$swap_sol_target/$sol_file" RSA_TEST_SOL_SENTINEL="$swap_sol_inject" PATH="$fake_mv_bin:$PATH" sh "$installer" --target-dir "$swap_sol_target" --upgrade-known 2>&1); then
  record_failure "Sol destination swap was accepted"
elif ! printf '%s\n' "$swap_sol_output" | grep -Fq "Sol displace revalidation failed; restored unknown destination without overwrite" ||
     ! printf '%s\n' "$swap_sol_output" | grep -Fq "ROLLBACK: restored known 0.1.1 Terra template" ||
     ! printf '%s\n' "$swap_sol_output" | grep -Fq "private recovery transaction"; then
  record_failure "Sol destination swap omitted exact post-displacement rollback/recovery markers"
elif printf '%s\n' "$swap_sol_output" | grep -Fq "known Sol destination changed before publication"; then
  record_failure "Sol destination swap was rejected by pre-displacement classification instead of CAS revalidation"
elif ! cmp -s "$terra_fixture" "$swap_sol_target/$terra_file" ||
     ! cmp -s "$swap_sol_reference" "$swap_sol_target/$sol_file"; then
  record_failure "Sol destination swap lost unknown Sol content or failed to restore Terra"
elif [ -e "$swap_sol_target/$luna_file" ] || [ -L "$swap_sol_target/$luna_file" ] ||
     [ "$(role_and_upstream_signature "$swap_sol_target" | sed -n '3,4p')" != "$swap_sol_upstream_before" ]; then
  record_failure "Sol destination swap changed Luna or upstream sentinels"
elif ! find "$swap_sol_target" -maxdepth 1 -type d -name '.react-sol-advisor-upgrade-txn.*' -print -quit | grep -q .; then
  record_failure "Sol destination swap did not retain explicitly reported private recovery"
elif ! swap_sol_recovery=$(find "$swap_sol_target" -path '*/sol.backup' -type f -print -quit) || [ -z "$swap_sol_recovery" ] || ! cmp -s "$sol_fixture" "$swap_sol_recovery"; then
  record_failure "Sol destination swap did not preserve the guarded old Sol recovery copy"
elif swap_sol_extra=$(find "$swap_sol_target" -path '*/.react-sol-advisor-upgrade-txn.*/*' ! -name sol.backup -print) && [ -n "$swap_sol_extra" ]; then
  record_failure "Sol destination swap left owned private artifacts beyond the reported recovery copy: $swap_sol_extra"
else
  pass "Sol destination swap preserves unknown content and restores Terra through guarded rollback"
fi

# Signals at both early transaction points must restore exact old/old state and remove
# all run-owned stages, backups, and transaction slots.
term_stage_target=$tmp_dir/term-after-stage
prepare_stale_pair "$term_stage_target" || record_failure "could not prepare TERM-after-stage fixture"
add_upstream_sentinels "$term_stage_target" || record_failure "could not prepare TERM-after-stage sentinels"
term_stage_before=$(target_signature "$term_stage_target")
if term_stage_output=$(RSA_INSTALL_TEST_HOOK=term-after-terra-stage sh "$installer" --target-dir "$term_stage_target" --upgrade-known 2>&1); then
  record_failure "TERM after Terra stage was accepted"
elif ! printf '%s\n' "$term_stage_output" | grep -Fq "TEST INJECTION: TERM after Terra stage" ||
     ! cmp -s "$terra_fixture" "$term_stage_target/$terra_file" ||
     ! cmp -s "$sol_fixture" "$term_stage_target/$sol_file" ||
     [ "$(target_signature "$term_stage_target")" != "$term_stage_before" ]; then
  record_failure "TERM after Terra stage did not restore exact unchanged state"
else
  assert_no_upgrade_artifacts "TERM after Terra stage" "$term_stage_target"
fi

term_backup_target=$tmp_dir/term-after-backup
prepare_stale_pair "$term_backup_target" || record_failure "could not prepare TERM-after-backup fixture"
add_upstream_sentinels "$term_backup_target" || record_failure "could not prepare TERM-after-backup sentinels"
term_backup_before=$(target_signature "$term_backup_target")
if term_backup_output=$(RSA_INSTALL_TEST_HOOK=term-after-terra-backup sh "$installer" --target-dir "$term_backup_target" --upgrade-known 2>&1); then
  record_failure "TERM after Terra backup was accepted"
elif ! printf '%s\n' "$term_backup_output" | grep -Fq "TEST INJECTION: TERM after Terra backup" ||
     ! cmp -s "$terra_fixture" "$term_backup_target/$terra_file" ||
     ! cmp -s "$sol_fixture" "$term_backup_target/$sol_file" ||
     [ "$(target_signature "$term_backup_target")" != "$term_backup_before" ]; then
  record_failure "TERM after Terra backup did not restore exact unchanged state"
else
  assert_no_upgrade_artifacts "TERM after Terra backup" "$term_backup_target"
fi

# Deliver TERM from verifier-owned command wrappers after each filesystem mutation has
# succeeded but before the parent shell can execute the following ownership assignment.
# Every boundary must restore exact old/old state and remove the owned lock/transaction.
term_transition_bin=$tmp_dir/term-transition-bin
mkdir "$term_transition_bin" || record_failure "could not prepare TERM transition wrappers"
real_mkdir=$(command -v mkdir) || record_failure "could not resolve system mkdir"
real_mv_for_term=$(command -v mv) || record_failure "could not resolve system mv for TERM transitions"
real_ln_for_term=$(command -v ln) || record_failure "could not resolve system ln for TERM transitions"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "$RSA_TEST_TERM_KIND" = lock ] && [ "$1" = "$RSA_TEST_LOCK" ]; then' \
  '  "$RSA_TEST_REAL_MKDIR" "$@" || exit 1' \
  '  kill -TERM "$PPID"' \
  '  exit 0' \
  'fi' \
  'exec "$RSA_TEST_REAL_MKDIR" "$@"' > "$term_transition_bin/mkdir" || record_failure "could not create TERM mkdir wrapper"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$RSA_TEST_TERM_KIND:$1:$2" in' \
  '  terra-displace:"$RSA_TEST_TERRA_DEST":*/terra.displaced|sol-displace:"$RSA_TEST_SOL_DEST":*/sol.displaced)' \
  '    "$RSA_TEST_REAL_MV" "$@" || exit 1' \
  '    kill -TERM "$PPID"' \
  '    exit 0' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_MV" "$@"' > "$term_transition_bin/mv" || record_failure "could not create TERM mv wrapper"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$RSA_TEST_TERM_KIND:$1:$2" in' \
  '  terra-publish:*/terra.stage:"$RSA_TEST_TERRA_DEST"|sol-publish:*/sol.stage:"$RSA_TEST_SOL_DEST")' \
  '    "$RSA_TEST_REAL_LN" "$@" || exit 1' \
  '    kill -TERM "$PPID"' \
  '    exit 0' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_LN" "$@"' > "$term_transition_bin/ln" || record_failure "could not create TERM ln wrapper"
chmod 755 "$term_transition_bin/mkdir" "$term_transition_bin/mv" "$term_transition_bin/ln" ||
  record_failure "could not make TERM transition wrappers executable"

run_term_transition_case() {
  kind=$1
  label=$2
  target=$tmp_dir/term-transition-$kind
  prepare_stale_pair "$target" || {
    record_failure "could not prepare $label fixture"
    return
  }
  add_upstream_sentinels "$target" || {
    record_failure "could not prepare $label sentinels"
    return
  }
  before=$(target_signature "$target")
  if output=$(RSA_TEST_TERM_KIND="$kind" RSA_TEST_LOCK="$target/.react-sol-advisor-upgrade-lock" \
    RSA_TEST_TERRA_DEST="$target/$terra_file" RSA_TEST_SOL_DEST="$target/$sol_file" \
    RSA_TEST_REAL_MKDIR="$real_mkdir" RSA_TEST_REAL_MV="$real_mv_for_term" \
    RSA_TEST_REAL_LN="$real_ln_for_term" PATH="$term_transition_bin:$PATH" \
    sh "$installer" --target-dir "$target" --upgrade-known 2>&1); then
    record_failure "$label was accepted"
  elif ! printf '%s\n' "$output" | grep -Fq "upgrade interrupted; attempting guarded rollback"; then
    record_failure "$label omitted the guarded interruption marker: $output"
  elif ! cmp -s "$terra_fixture" "$target/$terra_file" || ! cmp -s "$sol_fixture" "$target/$sol_file"; then
    record_failure "$label did not restore exact old/old state"
  elif [ "$(target_signature "$target")" != "$before" ]; then
    record_failure "$label did not restore the exact pre-upgrade target signature"
  else
    assert_no_upgrade_artifacts "$label" "$target"
  fi
}

run_term_transition_case lock "TERM after lock creation before ownership recording"
run_term_transition_case terra-displace "TERM after Terra displacement before ownership recording"
run_term_transition_case sol-displace "TERM after Sol displacement before ownership recording"
run_term_transition_case terra-publish "TERM after Terra publication before ownership recording"
run_term_transition_case sol-publish "TERM after Sol publication before ownership recording"

unreadable_target=$tmp_dir/unreadable-digest
prepare_stale_pair "$unreadable_target" || record_failure "could not prepare unreadable digest fixture"
add_upstream_sentinels "$unreadable_target" || record_failure "could not prepare unreadable digest sentinels"
assert_unchanged_refusal \
  "deterministic unreadable Terra digest" "$unreadable_target" "Terra destination is unreadable" \
  env RSA_INSTALL_TEST_HOOK=unreadable-terra sh "$installer" --target-dir "$unreadable_target" --upgrade-known
assert_no_upgrade_artifacts "deterministic unreadable Terra digest" "$unreadable_target"

# An existing lock is user/concurrent state. The installer must neither remove nor alter
# it, and it must refuse before any role destination mutation.
preexisting_lock_target=$tmp_dir/preexisting-lock
prepare_stale_pair "$preexisting_lock_target" || record_failure "could not prepare pre-existing lock fixture"
add_upstream_sentinels "$preexisting_lock_target" || record_failure "could not prepare pre-existing lock sentinels"
preexisting_lock=$preexisting_lock_target/.react-sol-advisor-upgrade-lock
mkdir "$preexisting_lock" || record_failure "could not create pre-existing lock"
printf '%s\n' "unknown lock owner" > "$preexisting_lock/owner-sentinel" ||
  record_failure "could not create pre-existing lock owner sentinel"
preexisting_lock_before=$(role_and_upstream_signature "$preexisting_lock_target")
if preexisting_lock_output=$(sh "$installer" --target-dir "$preexisting_lock_target" --upgrade-known 2>&1); then
  record_failure "pre-existing upgrade lock was accepted"
elif ! printf '%s\n' "$preexisting_lock_output" | grep -Fq "upgrade lock is already held"; then
  record_failure "pre-existing upgrade lock omitted exact refusal marker"
elif [ "$(role_and_upstream_signature "$preexisting_lock_target")" != "$preexisting_lock_before" ]; then
  record_failure "pre-existing upgrade lock refusal changed a role or upstream file"
elif [ "$(cat "$preexisting_lock/owner-sentinel" 2>/dev/null)" != "unknown lock owner" ]; then
  record_failure "pre-existing upgrade lock refusal changed unknown owner state"
else
  pass "pre-existing unknown upgrade lock is preserved without role mutation"
fi

# Current/current is an authorization decision, not an unlocked shortcut. Pause process
# A after Sol is published while it still owns the target lock; process B must refuse
# the held lock rather than printing ALREADY CURRENT. Terminating A then proves its
# still-active transaction rolls back exact old/old without touching unrelated bytes.
current_lock_target=$tmp_dir/current-current-held-lock
prepare_stale_pair "$current_lock_target" || record_failure "could not prepare current/current held-lock fixture"
add_upstream_sentinels "$current_lock_target" || record_failure "could not prepare current/current held-lock sentinels"
printf '%s\n' "user-owned held-lock sentinel" > "$current_lock_target/user-owned-sentinel" ||
  record_failure "could not prepare current/current user-owned sentinel"
current_lock_before=$(target_signature "$current_lock_target")
current_lock_control=$tmp_dir/current-current-held-lock-control
current_lock_bin=$tmp_dir/current-current-held-lock-bin
mkdir "$current_lock_control" "$current_lock_bin" || record_failure "could not prepare current/current held-lock controls"
real_python3=$(command -v python3) || record_failure "could not resolve system python3"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "$1" = - ] && [ "$2" = "$RSA_TEST_SOL_DEST" ] && [ ! -e "$RSA_TEST_CONTROL/a-current-before-commit" ] &&' \
  '   cmp -s "$RSA_TEST_TERRA_CURRENT" "$RSA_TEST_TERRA_DEST" && cmp -s "$RSA_TEST_SOL_CURRENT" "$RSA_TEST_SOL_DEST"; then' \
  '  : > "$RSA_TEST_CONTROL/a-current-before-commit"' \
  '  while [ ! -e "$RSA_TEST_CONTROL/release-a-current-before-commit" ]; do sleep 0.05; done' \
  'fi' \
  'exec "$RSA_TEST_REAL_PYTHON3" "$@"' > "$current_lock_bin/python3" ||
  record_failure "could not create current/current held-lock python wrapper"
chmod 755 "$current_lock_bin/python3" || record_failure "could not make current/current python wrapper executable"
current_lock_a_output=$current_lock_control/a.out
RSA_TEST_CONTROL="$current_lock_control" RSA_TEST_REAL_PYTHON3="$real_python3" \
RSA_TEST_TERRA_DEST="$current_lock_target/$terra_file" RSA_TEST_SOL_DEST="$current_lock_target/$sol_file" \
RSA_TEST_TERRA_CURRENT="$terra_current" RSA_TEST_SOL_CURRENT="$sol_current" PATH="$current_lock_bin:$PATH" \
sh "$installer" --target-dir "$current_lock_target" --upgrade-known >"$current_lock_a_output" 2>&1 &
current_lock_a_pid=$!
wait_for_path "$current_lock_control/a-current-before-commit" "current/current process A post-Sol publication" || true
if current_lock_b_output=$(sh "$installer" --target-dir "$current_lock_target" --upgrade-known 2>&1); then
  current_lock_b_status=0
else
  current_lock_b_status=$?
fi
kill -TERM "$current_lock_a_pid" 2>/dev/null || true
: > "$current_lock_control/release-a-current-before-commit"
if wait "$current_lock_a_pid"; then current_lock_a_status=0; else current_lock_a_status=$?; fi
if [ "$current_lock_b_status" -eq 0 ]; then
  record_failure "held-lock current/current process B was accepted"
elif printf '%s\n' "$current_lock_b_output" | grep -Fq "ALREADY CURRENT"; then
  record_failure "held-lock current/current process B printed ALREADY CURRENT"
elif ! printf '%s\n' "$current_lock_b_output" | grep -Fq "upgrade lock is already held"; then
  record_failure "held-lock current/current process B omitted exact lock refusal marker"
elif printf '%s\n' "$current_lock_b_output" | grep -Fq "ROLLBACK:"; then
  record_failure "held-lock current/current process B rolled back A's transaction"
elif [ "$current_lock_a_status" -eq 0 ] || ! printf '%s\n' "$(cat "$current_lock_a_output")" | grep -Fq "ROLLBACK: restored known 0.1.1"; then
  record_failure "terminated current/current process A did not perform guarded rollback"
elif ! cmp -s "$terra_fixture" "$current_lock_target/$terra_file" ||
     ! cmp -s "$sol_fixture" "$current_lock_target/$sol_file" ||
     [ "$(target_signature "$current_lock_target")" != "$current_lock_before" ]; then
  record_failure "terminated current/current process A did not restore exact old/old and unrelated bytes"
else
  pass "current/current authorization is serialized by the target lock and interrupted owner rolls back old/old"
  assert_no_upgrade_artifacts "current/current held-lock interruption" "$current_lock_target"
fi

# A current/current no-op must be equally signal-safe while its private stages and
# target lock are being removed. Pause the first cleanup removal, interrupt its parent,
# then release the wrapper so POSIX signal handling can complete.
current_cleanup_target=$tmp_dir/current-current-cleanup-signal
prepare_current_pair "$current_cleanup_target" || record_failure "could not prepare current/current cleanup fixture"
add_upstream_sentinels "$current_cleanup_target" || record_failure "could not prepare current/current cleanup sentinels"
printf '%s\n' "user-owned cleanup sentinel" > "$current_cleanup_target/user-owned-sentinel" ||
  record_failure "could not prepare current/current cleanup user sentinel"
current_cleanup_before=$(target_signature "$current_cleanup_target")
current_cleanup_upstream_before=$(role_and_upstream_signature "$current_cleanup_target" | sed -n '3,4p')
current_cleanup_control=$tmp_dir/current-current-cleanup-control
current_cleanup_bin=$tmp_dir/current-current-cleanup-bin
mkdir "$current_cleanup_control" "$current_cleanup_bin" || record_failure "could not prepare current/current cleanup controls"
real_rm_for_current_cleanup=$(command -v rm) || record_failure "could not resolve system rm for current/current cleanup"
printf '%s\n' \
  '#!/bin/sh' \
  'for argument in "$@"; do' \
  '  case "$argument" in' \
  '    */terra.stage)' \
  '      if [ ! -e "$RSA_TEST_CONTROL/a-at-current-cleanup" ]; then' \
  '        : > "$RSA_TEST_CONTROL/a-at-current-cleanup"' \
  '        while [ ! -e "$RSA_TEST_CONTROL/release-a-current-cleanup" ]; do sleep 0.05; done' \
  '      fi' \
  '      ;;' \
  '  esac' \
  'done' \
  'exec "$RSA_TEST_REAL_RM" "$@"' > "$current_cleanup_bin/rm" ||
  record_failure "could not create current/current cleanup rm wrapper"
chmod 755 "$current_cleanup_bin/rm" || record_failure "could not make current/current cleanup rm wrapper executable"
current_cleanup_output=$current_cleanup_control/a.out
RSA_TEST_CONTROL="$current_cleanup_control" RSA_TEST_REAL_RM="$real_rm_for_current_cleanup" PATH="$current_cleanup_bin:$PATH" \
sh "$installer" --target-dir "$current_cleanup_target" --upgrade-known >"$current_cleanup_output" 2>&1 &
current_cleanup_pid=$!
wait_for_path "$current_cleanup_control/a-at-current-cleanup" "current/current no-op cleanup pause" || true
kill -TERM "$current_cleanup_pid" 2>/dev/null || true
: > "$current_cleanup_control/release-a-current-cleanup"
if wait "$current_cleanup_pid"; then current_cleanup_status=0; else current_cleanup_status=$?; fi
if [ "$current_cleanup_status" -eq 0 ]; then
  record_failure "interrupted current/current cleanup was accepted"
elif grep -Fq "ALREADY CURRENT" "$current_cleanup_output"; then
  record_failure "interrupted current/current cleanup printed ALREADY CURRENT"
elif ! grep -Fq "upgrade interrupted; attempting guarded rollback" "$current_cleanup_output"; then
  record_failure "interrupted current/current cleanup omitted guarded interruption marker"
elif ! cmp -s "$terra_current" "$current_cleanup_target/$terra_file" ||
     ! cmp -s "$sol_current" "$current_cleanup_target/$sol_file" ||
     [ "$(cat "$current_cleanup_target/user-owned-sentinel" 2>/dev/null)" != "user-owned cleanup sentinel" ] ||
     [ "$(role_and_upstream_signature "$current_cleanup_target" | sed -n '3,4p')" != "$current_cleanup_upstream_before" ]; then
  record_failure "interrupted current/current cleanup changed current roles or unrelated bytes"
elif [ -e "$current_cleanup_target/.react-sol-advisor-upgrade-lock" ] || [ -L "$current_cleanup_target/.react-sol-advisor-upgrade-lock" ] ||
     find "$current_cleanup_target" -maxdepth 1 -type d -name '.react-sol-advisor-upgrade-txn.*' -print -quit | grep -q .; then
  record_failure "interrupted current/current cleanup stranded owned lock or transaction artifacts"
elif current_cleanup_retry=$(sh "$installer" --target-dir "$current_cleanup_target" --upgrade-known 2>&1); then
  if ! printf '%s\n' "$current_cleanup_retry" | grep -Fq "ALREADY CURRENT" ||
     [ "$(target_signature "$current_cleanup_target")" != "$current_cleanup_before" ]; then
    record_failure "clean current/current retry was not idempotent after interruption"
  else
    pass "interrupted current/current cleanup preserves current roles and releases owned state"
    assert_no_upgrade_artifacts "current/current cleanup retry" "$current_cleanup_target"
  fi
else
  record_failure "clean current/current retry failed after interruption"
fi

# Two installers may both finish initial preflight and enter verifier-controlled staging,
# but exactly one may own destination mutation. Process A is paused after it acquires the
# target lock (or, in an unsafe implementation, after its first backup); process B then
# resumes from staging. The loser must not publish or roll back A's committed pair.
concurrent_target=$tmp_dir/concurrent-upgrade
prepare_stale_pair "$concurrent_target" || record_failure "could not prepare concurrent upgrade fixture"
add_upstream_sentinels "$concurrent_target" || record_failure "could not prepare concurrent upgrade sentinels"
concurrent_upstream_before=$(role_and_upstream_signature "$concurrent_target" | sed -n '3,4p')
concurrent_control=$tmp_dir/concurrent-control
concurrent_bin=$tmp_dir/concurrent-bin
mkdir "$concurrent_control" "$concurrent_bin" || record_failure "could not prepare concurrent upgrade controls"
real_cp=$(command -v cp) || record_failure "could not resolve system cp"
real_ln_for_concurrency=$(command -v ln) || record_failure "could not resolve system ln for concurrency"
real_mv_for_concurrency=$(command -v mv) || record_failure "could not resolve system mv for concurrency"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$2" in' \
  '  */terra.stage)' \
  '    : > "$RSA_TEST_CONTROL/stage-$RSA_TEST_ID"' \
  '    while [ ! -e "$RSA_TEST_CONTROL/release-stage-$RSA_TEST_ID" ]; do sleep 0.05; done' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_CP" "$@"' > "$concurrent_bin/cp" || record_failure "could not create concurrent cp wrapper"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$RSA_TEST_ID:$2" in' \
  '  A:*/terra.backup)' \
  '    : > "$RSA_TEST_CONTROL/a-at-backup"' \
  '    while [ ! -e "$RSA_TEST_CONTROL/release-a-backup" ]; do sleep 0.05; done' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_LN" "$@"' > "$concurrent_bin/ln" || record_failure "could not create concurrent ln wrapper"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$RSA_TEST_ID:$1:$2" in' \
  '  B:"$RSA_TEST_TERRA_DEST":*/terra.displaced)' \
  '    : > "$RSA_TEST_CONTROL/b-at-terra-displace"' \
  '    attempts=0' \
  '    while { ! cmp -s "$RSA_TEST_TERRA_CURRENT" "$RSA_TEST_TERRA_DEST" || ! cmp -s "$RSA_TEST_SOL_CURRENT" "$RSA_TEST_SOL_DEST"; } && [ "$attempts" -lt 200 ]; do' \
  '      sleep 0.05' \
  '      attempts=$((attempts + 1))' \
  '    done' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_MV" "$@"' > "$concurrent_bin/mv" || record_failure "could not create concurrent mv wrapper"
chmod 755 "$concurrent_bin/cp" "$concurrent_bin/ln" "$concurrent_bin/mv" ||
  record_failure "could not make concurrent wrappers executable"
concurrent_a_output=$concurrent_control/a.out
concurrent_b_output=$concurrent_control/b.out
RSA_TEST_ID=A RSA_TEST_CONTROL="$concurrent_control" RSA_TEST_REAL_CP="$real_cp" \
RSA_TEST_REAL_LN="$real_ln_for_concurrency" RSA_TEST_REAL_MV="$real_mv_for_concurrency" \
RSA_TEST_TERRA_DEST="$concurrent_target/$terra_file" RSA_TEST_SOL_DEST="$concurrent_target/$sol_file" \
RSA_TEST_TERRA_CURRENT="$terra_current" RSA_TEST_SOL_CURRENT="$sol_current" \
PATH="$concurrent_bin:$PATH" sh "$installer" --target-dir "$concurrent_target" --upgrade-known >"$concurrent_a_output" 2>&1 &
concurrent_a_pid=$!
RSA_TEST_ID=B RSA_TEST_CONTROL="$concurrent_control" RSA_TEST_REAL_CP="$real_cp" \
RSA_TEST_REAL_LN="$real_ln_for_concurrency" RSA_TEST_REAL_MV="$real_mv_for_concurrency" \
RSA_TEST_TERRA_DEST="$concurrent_target/$terra_file" RSA_TEST_SOL_DEST="$concurrent_target/$sol_file" \
RSA_TEST_TERRA_CURRENT="$terra_current" RSA_TEST_SOL_CURRENT="$sol_current" \
PATH="$concurrent_bin:$PATH" sh "$installer" --target-dir "$concurrent_target" --upgrade-known >"$concurrent_b_output" 2>&1 &
concurrent_b_pid=$!
wait_for_path "$concurrent_control/stage-A" "concurrent process A staging" || true
wait_for_path "$concurrent_control/stage-B" "concurrent process B staging" || true
: > "$concurrent_control/release-stage-A"
wait_for_path "$concurrent_control/a-at-backup" "process A target ownership" || true
: > "$concurrent_control/release-stage-B"
handshake_attempts=0
while ! grep -Fq "upgrade lock is already held" "$concurrent_b_output" 2>/dev/null &&
      [ ! -e "$concurrent_control/b-at-terra-displace" ] &&
      [ "$handshake_attempts" -lt 200 ]; do
  sleep 0.05
  handshake_attempts=$((handshake_attempts + 1))
done
if ! grep -Fq "upgrade lock is already held" "$concurrent_b_output" 2>/dev/null &&
   [ ! -e "$concurrent_control/b-at-terra-displace" ]; then
  record_failure "timed out before process B produced a lock refusal or unsafe mutation handshake"
fi
: > "$concurrent_control/release-a-backup"
if wait "$concurrent_a_pid"; then concurrent_a_status=0; else concurrent_a_status=$?; fi
if wait "$concurrent_b_pid"; then concurrent_b_status=0; else concurrent_b_status=$?; fi
if [ "$concurrent_a_status" -ne 0 ]; then
  record_failure "target-lock winner failed concurrent upgrade"
elif [ "$concurrent_b_status" -eq 0 ]; then
  record_failure "concurrent loser was allowed to publish"
elif ! grep -Fq "upgrade lock is already held" "$concurrent_b_output"; then
  record_failure "concurrent loser omitted exact target-lock refusal marker"
elif grep -Fq "ROLLBACK:" "$concurrent_b_output"; then
  record_failure "concurrent loser rolled back a destination it did not own"
elif [ "$(grep -h 'UPGRADED KNOWN 0.1.1' "$concurrent_a_output" "$concurrent_b_output" | wc -l | tr -d ' ')" -ne 2 ]; then
  record_failure "concurrent upgrade did not have exactly one successful pair publication"
elif ! cmp -s "$terra_current" "$concurrent_target/$terra_file" ||
     ! cmp -s "$sol_current" "$concurrent_target/$sol_file"; then
  record_failure "successful concurrent process did not leave current/current"
elif [ "$(role_and_upstream_signature "$concurrent_target" | sed -n '3,4p')" != "$concurrent_upstream_before" ]; then
  record_failure "concurrent upgrade changed an upstream sentinel"
else
  pass "target-local lock serializes concurrent upgrades without loser rollback"
  assert_no_upgrade_artifacts "concurrent upgrade" "$concurrent_target"
fi

# Rollback has the same classify-to-move race as publication. Replace the canonical role
# immediately before each rollback-current displacement and require the unknown bytes to
# be restored without clobbering, while the guarded old copy remains recoverable.
rollback_swap_bin=$tmp_dir/rollback-swap-bin
mkdir "$rollback_swap_bin" || record_failure "could not prepare rollback swap wrappers"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1:$2" in' \
  '  "$RSA_TEST_SWAP_DEST":*/"$RSA_TEST_SWAP_SLOT")' \
  '    "$RSA_TEST_REAL_MV" "$RSA_TEST_SWAP_SENTINEL" "$1"' \
  '    exec "$RSA_TEST_REAL_MV" "$@"' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_MV" "$@"' > "$rollback_swap_bin/mv" || record_failure "could not create rollback swap mv wrapper"
chmod 755 "$rollback_swap_bin/mv" || record_failure "could not make rollback swap mv wrapper executable"

rollback_swap_terra_target=$tmp_dir/rollback-swap-terra
prepare_stale_pair "$rollback_swap_terra_target" || record_failure "could not prepare Terra rollback swap fixture"
add_upstream_sentinels "$rollback_swap_terra_target" || record_failure "could not prepare Terra rollback swap sentinels"
rollback_swap_terra_upstream=$(role_and_upstream_signature "$rollback_swap_terra_target" | sed -n '3,4p')
rollback_swap_terra_reference=$tmp_dir/rollback-unknown-terra
printf '%s\n' "concurrent unknown Terra during rollback" > "$rollback_swap_terra_reference"
rollback_swap_terra_inject=$rollback_swap_terra_target/.verifier-rollback-unknown-terra
cp "$rollback_swap_terra_reference" "$rollback_swap_terra_inject"
if rollback_swap_terra_output=$(RSA_INSTALL_TEST_FAIL_REPLACE=sol RSA_TEST_REAL_MV="$real_mv" \
  RSA_TEST_SWAP_DEST="$rollback_swap_terra_target/$terra_file" RSA_TEST_SWAP_SLOT=terra.rollback-current \
  RSA_TEST_SWAP_SENTINEL="$rollback_swap_terra_inject" PATH="$rollback_swap_bin:$PATH" \
  sh "$installer" --target-dir "$rollback_swap_terra_target" --upgrade-known 2>&1); then
  record_failure "Terra rollback destination swap was accepted"
elif ! printf '%s\n' "$rollback_swap_terra_output" | grep -Fq "Terra rollback revalidation failed; restored unknown destination without overwrite"; then
  record_failure "Terra rollback destination swap omitted exact CAS restoration marker"
elif ! cmp -s "$rollback_swap_terra_reference" "$rollback_swap_terra_target/$terra_file" ||
     ! cmp -s "$sol_fixture" "$rollback_swap_terra_target/$sol_file"; then
  record_failure "Terra rollback destination swap lost unknown Terra content or changed Sol"
elif [ "$(role_and_upstream_signature "$rollback_swap_terra_target" | sed -n '3,4p')" != "$rollback_swap_terra_upstream" ]; then
  record_failure "Terra rollback destination swap changed an upstream sentinel"
else
  pass "Terra rollback CAS restores unknown concurrent content without overwrite"
fi

rollback_swap_sol_target=$tmp_dir/rollback-swap-sol
prepare_stale_pair "$rollback_swap_sol_target" || record_failure "could not prepare Sol rollback swap fixture"
add_upstream_sentinels "$rollback_swap_sol_target" || record_failure "could not prepare Sol rollback swap sentinels"
rollback_swap_sol_upstream=$(role_and_upstream_signature "$rollback_swap_sol_target" | sed -n '3,4p')
rollback_swap_sol_reference=$tmp_dir/rollback-unknown-sol
printf '%s\n' "concurrent unknown Sol during rollback" > "$rollback_swap_sol_reference"
rollback_swap_sol_inject=$rollback_swap_sol_target/.verifier-rollback-unknown-sol
cp "$rollback_swap_sol_reference" "$rollback_swap_sol_inject"
printf '%s\n' \
  '#!/bin/sh' \
  'case "$1:$2" in' \
  '  */sol.stage:"$RSA_TEST_SOL_DEST")' \
  '    "$RSA_TEST_REAL_LN" "$@" || exit 1' \
  '    printf "%s\n" "concurrent retired Luna sentinel" > "$RSA_TEST_LUNA_DEST"' \
  '    exit 0' \
  '    ;;' \
  'esac' \
  'exec "$RSA_TEST_REAL_LN" "$@"' > "$rollback_swap_bin/ln" || record_failure "could not create post-publish Luna injection wrapper"
chmod 755 "$rollback_swap_bin/ln" || record_failure "could not make post-publish Luna injection wrapper executable"
if rollback_swap_sol_output=$(RSA_TEST_REAL_MV="$real_mv" RSA_TEST_REAL_LN="$real_ln" \
  RSA_TEST_SWAP_DEST="$rollback_swap_sol_target/$sol_file" RSA_TEST_SWAP_SLOT=sol.rollback-current \
  RSA_TEST_SWAP_SENTINEL="$rollback_swap_sol_inject" RSA_TEST_SOL_DEST="$rollback_swap_sol_target/$sol_file" \
  RSA_TEST_LUNA_DEST="$rollback_swap_sol_target/$luna_file" PATH="$rollback_swap_bin:$PATH" \
  sh "$installer" --target-dir "$rollback_swap_sol_target" --upgrade-known 2>&1); then
  record_failure "Sol rollback destination swap was accepted"
elif ! printf '%s\n' "$rollback_swap_sol_output" | grep -Fq "Sol rollback revalidation failed; restored unknown destination without overwrite"; then
  record_failure "Sol rollback destination swap omitted exact CAS restoration marker"
elif ! cmp -s "$rollback_swap_sol_reference" "$rollback_swap_sol_target/$sol_file" ||
     ! cmp -s "$terra_fixture" "$rollback_swap_sol_target/$terra_file"; then
  record_failure "Sol rollback destination swap lost unknown Sol content or failed to restore Terra"
elif [ "$(role_and_upstream_signature "$rollback_swap_sol_target" | sed -n '3,4p')" != "$rollback_swap_sol_upstream" ]; then
  record_failure "Sol rollback destination swap changed an upstream sentinel"
else
  pass "Sol rollback CAS restores unknown concurrent content without overwrite"
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

# After both replacements pass exact-current and Luna checks, cleanup is no longer a
# role-pair transaction. A private cleanup failure must retain current/current and the
# private old recovery artifact; no EXIT rollback may create a mixed pair.
cleanup_target=$tmp_dir/backup-cleanup-failure
prepare_stale_pair "$cleanup_target" || record_failure "could not prepare cleanup failure fixture"
add_upstream_sentinels "$cleanup_target" || record_failure "could not prepare cleanup failure sentinels"
cleanup_upstream_before=$(role_and_upstream_signature "$cleanup_target" | sed -n '3,4p')
fake_rm_bin=$tmp_dir/fake-rm-bin
mkdir "$fake_rm_bin" || record_failure "could not prepare fake rm directory"
real_rm=$(command -v rm) || record_failure "could not resolve system rm"
fake_rm=$fake_rm_bin/rm
printf '%s\n' \
  '#!/bin/sh' \
  'for argument in "$@"; do' \
  '  case "$argument" in' \
  '    */terra.backup)' \
  '      exit 1' \
  '      ;;' \
  '  esac' \
  'done' \
  'exec "$RSA_TEST_REAL_RM" "$@"' > "$fake_rm" || record_failure "could not create fake rm wrapper"
chmod 755 "$fake_rm" || record_failure "could not make fake rm wrapper executable"
if cleanup_output=$(RSA_TEST_REAL_RM="$real_rm" PATH="$fake_rm_bin:$PATH" sh "$installer" --target-dir "$cleanup_target" --upgrade-known 2>&1); then
  record_failure "guarded backup cleanup failure was accepted"
elif ! printf '%s\n' "$cleanup_output" | grep -Fq "could not clean committed private upgrade transaction"; then
  record_failure "guarded backup cleanup failure omitted exact cleanup marker"
elif ! cmp -s "$terra_current" "$cleanup_target/$terra_file" || ! cmp -s "$sol_current" "$cleanup_target/$sol_file"; then
  record_failure "guarded backup cleanup failure produced a mixed or stale role pair"
elif [ -e "$cleanup_target/$luna_file" ] || [ -L "$cleanup_target/$luna_file" ]; then
  record_failure "guarded backup cleanup failure created a native Luna role"
elif [ "$(role_and_upstream_signature "$cleanup_target" | sed -n '3,4p')" != "$cleanup_upstream_before" ]; then
  record_failure "guarded backup cleanup failure changed an upstream sentinel"
elif ! cleanup_recovery=$(find "$cleanup_target" -path '*/terra.backup' -type f -print -quit) || [ -z "$cleanup_recovery" ] || ! cmp -s "$terra_fixture" "$cleanup_recovery"; then
  record_failure "private cleanup failure did not preserve the old Terra recovery artifact"
else
  pass "private cleanup failure preserves current/current and old recovery state"
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
