#!/bin/sh
# Install Sol Development Advisor's shipped native roles without changing Codex config.

set -eu

usage() {
  cat <<'USAGE'
Usage: install-agents.sh [--target-dir PATH] [--check | --upgrade-known]

Install the shipped Sol Development Advisor Terra and Sol native roles.

Without an option, install only missing roles into CODEX_HOME/agents (or
~/.codex/agents). Existing roles are never overwritten. Use --target-dir to select a
different real, non-symlink directory.

Options:
  --check          Verify that both installed roles exactly match the shipped files.
                   This never changes files.
  --upgrade-known  Replace only the exact accepted 0.1.1 Terra/Sol pair. This is the
                   sole opt-in replacement path; it refuses missing, mixed, modified,
                   non-regular, symlinked, unreadable, or retired-Luna installations.
  --target-dir PATH
                   Explicit native-role directory.
  --help, -h       Show this help.

The installer never creates a native Luna role and never reads or changes upstream
sol-advisor-* role files.
USAGE
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

report() {
  printf '%s\n' "ERROR: $*" >&2
  preflight_failed=1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  if [ "${RSA_INSTALL_TEST_HOOK-}" = unreadable-terra ] && [ "${terra_destination-}" = "$1" ]; then
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk 'NF && length($1) == 64 { print $1; exit }'
  else
    shasum -a 256 "$1" 2>/dev/null | awk 'NF && length($1) == 64 { print $1; exit }'
  fi
}

canonicalize_path() {
  # Resolve an explicit physical target without following symlinked ancestors. This
  # keeps installer writes contained even on macOS paths such as /var -> /private/var.
  python3 - "$1" <<'PY'
import os, stat, sys
p = os.path.abspath(sys.argv[1])
if p == os.path.sep or p.startswith(os.path.sep * 2):
    raise SystemExit('target resolves to the filesystem root or an ambiguous double-slash namespace')
parts = [part for part in p.split(os.path.sep) if part]
cur = os.path.sep
for index, part in enumerate(parts):
    cur = os.path.join(cur, part)
    try:
        mode = os.lstat(cur).st_mode
    except FileNotFoundError:
        break
    if stat.S_ISLNK(mode):
        raise SystemExit(f'target path contains a symlink: {cur}')
    if index < len(parts) - 1 and not stat.S_ISDIR(mode):
        raise SystemExit(f'target ancestor is not a directory: {cur}')
print(p)
PY
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents
target_dir=${CODEX_HOME:+$CODEX_HOME/agents}
if [ -z "${target_dir-}" ]; then
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi
check_only=0
upgrade_known=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "--target-dir requires a path."
      case "$2" in
        --*) fail "--target-dir path must be explicit; prefix an option-like relative name with ./ or use an absolute path." ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --upgrade-known)
      upgrade_known=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done
[ "$check_only" -eq 0 ] || [ "$upgrade_known" -eq 0 ] ||
  fail "--check and --upgrade-known cannot be used together."
case "$target_dir" in
  /*) ;;
  *) target_dir=$(pwd -P)/$target_dir ;;
esac
if ! target_dir=$(canonicalize_path "$target_dir"); then
  fail "unsafe target directory path"
fi

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml
luna_file=react-sol-advisor-luna-implementer.toml
terra_template=$template_dir/$terra_file
sol_template=$template_dir/$sol_file
terra_destination=$target_dir/$terra_file
sol_destination=$target_dir/$sol_file
luna_destination=$target_dir/$luna_file
terra_old=8cd2ed825f58574fd578832dd35f7932d365214db91ab84f79af7a64d3c863b1
sol_old=cf96fa0b638d879b072b896748e985ded79e68f2814e9eeab8b9c8c841776241
for template in "$terra_template" "$sol_template"; do
  [ -f "$template" ] && [ ! -L "$template" ] ||
    fail "shipped template is missing or not a regular file: $template"
done
classify() {
  dest=$1
  template=$2
  old=$3

  if ! path_exists "$dest"; then
    printf '%s\n' missing
  elif [ -L "$dest" ] || [ ! -f "$dest" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$dest"; then
    printf '%s\n' current
  else
    digest=$(sha256_file "$dest")
    if [ -z "$digest" ]; then
      printf '%s\n' unreadable
    elif [ "$digest" = "$old" ]; then
      printf '%s\n' known-stale-0.1.1
    else
      printf '%s\n' conflict
    fi
  fi
}

has_exact_digest() {
  file=$1
  expected_digest=$2

  [ -f "$file" ] && [ ! -L "$file" ] &&
    [ "$(sha256_file "$file")" = "$expected_digest" ]
}

same_file() {
  python3 - "$1" "$2" <<'PY'
import os, sys
try:
    raise SystemExit(0 if os.path.samefile(sys.argv[1], sys.argv[2]) else 1)
except (FileNotFoundError, OSError):
    raise SystemExit(1)
PY
}

preflight_failed=0
if path_exists "$target_dir" && { [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; }; then
  report "target directory is not a real directory: $target_dir"
fi
if path_exists "$luna_destination"; then
  report "unsupported native Luna companion must be removed manually: $luna_destination"
fi
terra_state=$(classify "$terra_destination" "$terra_template" "$terra_old")
sol_state=$(classify "$sol_destination" "$sol_template" "$sol_old")
if [ "$check_only" -eq 1 ]; then
  case "$terra_state" in
    current) ;;
    known-stale-0.1.1)
      report "Terra template is known stale 0.1.1; rerun with --upgrade-known: $terra_destination"
      ;;
    *) report "Terra template is $terra_state, not the current exact file: $terra_destination" ;;
  esac
  case "$sol_state" in
    current) ;;
    known-stale-0.1.1)
      report "Sol template is known stale 0.1.1; rerun with --upgrade-known: $sol_destination"
      ;;
    *) report "Sol template is $sol_state, not the current exact file: $sol_destination" ;;
  esac
elif [ "$upgrade_known" -eq 1 ]; then
  case "$terra_state" in
    conflict|unreadable)
      report "Terra destination is $terra_state and not a known 0.1.1 template: $terra_destination"
      ;;
  esac
  case "$sol_state" in
    conflict|unreadable)
      report "Sol destination is $sol_state and not a known 0.1.1 template: $sol_destination"
      ;;
  esac
  case "$terra_state/$sol_state" in
    current/current|known-stale-0.1.1/known-stale-0.1.1) ;;
    *) report "--upgrade-known requires current/current or known/known; found mixed/partial: Terra=$terra_state Sol=$sol_state" ;;
  esac
  case "${RSA_INSTALL_TEST_FAIL_REPLACE-}" in
    ''|sol) ;;
    *) report "RSA_INSTALL_TEST_FAIL_REPLACE must be empty or sol" ;;
  esac
  case "${RSA_INSTALL_TEST_HOOK-}" in
    ''|term-after-terra-stage|term-after-terra-backup|unreadable-terra) ;;
    *) report "RSA_INSTALL_TEST_HOOK is unsupported" ;;
  esac
else
  case "$terra_state" in
    current|missing) ;;
    known-stale-0.1.1) report "Terra destination is known stale 0.1.1; rerun with --upgrade-known: $terra_destination" ;;
    *) report "Terra destination is $terra_state and will not be replaced: $terra_destination" ;;
  esac
  case "$sol_state" in
    current|missing) ;;
    known-stale-0.1.1) report "Sol destination is known stale 0.1.1; rerun with --upgrade-known: $sol_destination" ;;
    *) report "Sol destination is $sol_state and will not be replaced: $sol_destination" ;;
  esac
fi
[ "$preflight_failed" -eq 0 ] || exit 1
if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: Terra and Sol exactly match $template_dir; native Luna is absent."
  exit 0
fi

if [ "$upgrade_known" -eq 1 ]; then
  terra_backup=$target_dir/.react-sol-advisor-upgrade-terra.backup
  sol_backup=$target_dir/.react-sol-advisor-upgrade-sol.backup
  path_exists "$terra_backup" && fail "refusing existing upgrade backup: $terra_backup"
  path_exists "$sol_backup" && fail "refusing existing upgrade backup: $sol_backup"
fi

if [ "$upgrade_known" -eq 1 ]; then
  # All mutable upgrade artifacts live in a unique private directory beneath the exact
  # target.  Nothing is written to a public recovery filename: pre-existing legacy
  # backup names are still refused above, but each run owns only its private slot.
  upgrade_active=1
  upgrade_exit_handled=0
  transaction_dir=''
  stage_terra=''
  stage_sol=''
  terra_private_backup=''
  sol_private_backup=''
  terra_displaced=''
  sol_displaced=''
  terra_rollback_current=''
  sol_rollback_current=''
  terra_displaced_owned=0
  sol_displaced_owned=0
  terra_published_owned=0
  sol_published_owned=0
  upgrade_lock=$target_dir/.react-sol-advisor-upgrade-lock
  lock_owner_dir=''
  lock_acquired=0
  upgrade_deferred_signal=0
  terra_current=$(sha256_file "$terra_template")
  sol_current=$(sha256_file "$sol_template")
  [ -n "$terra_current" ] && [ -n "$sol_current" ] || fail "could not digest shipped upgrade templates"

  remove_private_exact() {
    label=$1
    artifact=$2
    expected=$3
    [ -n "$artifact" ] && path_exists "$artifact" || return 0
    if ! has_exact_digest "$artifact" "$expected"; then
      printf '%s\n' "ERROR: private $label artifact changed; preserved for recovery: $artifact" >&2
      return 1
    fi
    rm -f "$artifact" || {
      printf '%s\n' "ERROR: could not remove private $label artifact: $artifact" >&2
      return 1
    }
  }

  cleanup_transaction() {
    preserve_artifact=${1-}
    preserve_artifact_2=${2-}
    [ -n "$transaction_dir" ] && [ -d "$transaction_dir" ] || return 0
    cleanup_ok=1
    { [ "$stage_terra" = "$preserve_artifact" ] || [ "$stage_terra" = "$preserve_artifact_2" ]; } || remove_private_exact "Terra stage" "$stage_terra" "$terra_current" || cleanup_ok=0
    { [ "$stage_sol" = "$preserve_artifact" ] || [ "$stage_sol" = "$preserve_artifact_2" ]; } || remove_private_exact "Sol stage" "$stage_sol" "$sol_current" || cleanup_ok=0
    { [ "$terra_private_backup" = "$preserve_artifact" ] || [ "$terra_private_backup" = "$preserve_artifact_2" ]; } || remove_private_exact "Terra backup" "$terra_private_backup" "$terra_old" || cleanup_ok=0
    { [ "$sol_private_backup" = "$preserve_artifact" ] || [ "$sol_private_backup" = "$preserve_artifact_2" ]; } || remove_private_exact "Sol backup" "$sol_private_backup" "$sol_old" || cleanup_ok=0
    { [ "$terra_displaced" = "$preserve_artifact" ] || [ "$terra_displaced" = "$preserve_artifact_2" ]; } || remove_private_exact "Terra displaced destination" "$terra_displaced" "$terra_old" || cleanup_ok=0
    { [ "$sol_displaced" = "$preserve_artifact" ] || [ "$sol_displaced" = "$preserve_artifact_2" ]; } || remove_private_exact "Sol displaced destination" "$sol_displaced" "$sol_old" || cleanup_ok=0
    { [ "$terra_rollback_current" = "$preserve_artifact" ] || [ "$terra_rollback_current" = "$preserve_artifact_2" ]; } || remove_private_exact "Terra rollback destination" "$terra_rollback_current" "$terra_current" || cleanup_ok=0
    { [ "$sol_rollback_current" = "$preserve_artifact" ] || [ "$sol_rollback_current" = "$preserve_artifact_2" ]; } || remove_private_exact "Sol rollback destination" "$sol_rollback_current" "$sol_current" || cleanup_ok=0
    if ! rmdir "$transaction_dir" 2>/dev/null; then
      printf '%s\n' "ERROR: private upgrade transaction preserved for recovery: $transaction_dir" >&2
      cleanup_ok=0
    fi
    [ "$cleanup_ok" -eq 1 ]
  }

  defer_upgrade_signal() {
    upgrade_deferred_signal=1
  }

  begin_signal_safe_transition() {
    upgrade_deferred_signal=0
    trap defer_upgrade_signal HUP INT TERM
  }

  end_signal_safe_transition() {
    trap upgrade_on_signal HUP INT TERM
    if [ "$upgrade_deferred_signal" -eq 1 ]; then
      upgrade_on_signal
    fi
  }

  acquire_upgrade_lock() {
    owner_name=$(basename "$transaction_dir")
    lock_owner_dir=$upgrade_lock/$owner_name
    lock_created=0
    begin_signal_safe_transition
    if mkdir "$upgrade_lock" 2>/dev/null; then
      lock_acquired=1
      lock_created=1
    fi
    end_signal_safe_transition
    if [ "$lock_created" -ne 1 ]; then
      printf '%s\n' "ERROR: upgrade lock is already held or unsafe: $upgrade_lock" >&2
      return 1
    fi
    if ! mkdir "$lock_owner_dir" 2>/dev/null || [ -L "$upgrade_lock" ] ||
       [ ! -d "$upgrade_lock" ] || [ -L "$lock_owner_dir" ] || [ ! -d "$lock_owner_dir" ]; then
      printf '%s\n' "ERROR: could not establish ownership-verifiable upgrade lock: $upgrade_lock" >&2
      return 1
    fi
    return 0
  }

  owns_upgrade_lock() {
    [ "$lock_acquired" -eq 1 ] &&
      [ ! -L "$upgrade_lock" ] && [ -d "$upgrade_lock" ] &&
      [ ! -L "$lock_owner_dir" ] && [ -d "$lock_owner_dir" ]
  }

  release_upgrade_lock() {
    [ "$lock_acquired" -eq 1 ] || return 0
    if [ -L "$upgrade_lock" ] || [ ! -d "$upgrade_lock" ]; then
      printf '%s\n' "ERROR: upgrade lock ownership changed; preserved for recovery: $upgrade_lock" >&2
      return 1
    fi
    if path_exists "$lock_owner_dir"; then
      if [ -L "$lock_owner_dir" ] || [ ! -d "$lock_owner_dir" ] || ! rmdir "$lock_owner_dir" 2>/dev/null; then
        printf '%s\n' "ERROR: upgrade lock owner changed; preserved for recovery: $upgrade_lock" >&2
        return 1
      fi
    fi
    if ! rmdir "$upgrade_lock" 2>/dev/null; then
      printf '%s\n' "ERROR: could not release owned upgrade lock; preserved for recovery: $upgrade_lock" >&2
      return 1
    fi
    lock_acquired=0
    return 0
  }

  rollback_role() {
    label=$1
    destination=$2
    template=$3
    old_digest=$4
    current_digest=$5
    backup=$6
    rollback_current=$7
    stage=$8
    displaced_owned=$9
    published_owned=${10}

    # State 2 means publication displaced an unknown race and restored or preserved it;
    # keep the guarded old backup for explicit recovery without touching the destination.
    if [ "$displaced_owned" -eq 2 ]; then
      recovery_artifact=$backup
      return 1
    fi

    # A backup alone is not mutation ownership. If this transaction never displaced the
    # accepted old destination, rollback must not inspect, move, or replace it.
    [ "$displaced_owned" -eq 1 ] || return 0
    role_state=$(classify "$destination" "$template" "$old_digest")

    if [ "$published_owned" -eq 1 ]; then
      case "$role_state" in
        known-stale-0.1.1)
          return 0
          ;;
        current)
          if path_exists "$rollback_current"; then
            printf '%s\n' "ERROR: private $label rollback slot already exists; preserved for recovery: $transaction_dir" >&2
            return 1
          fi
          if ! mv "$destination" "$rollback_current"; then
            printf '%s\n' "ERROR: could not safely displace current $label during rollback; preserved for recovery: $transaction_dir" >&2
            return 1
          fi
          if ! has_exact_digest "$rollback_current" "$current_digest" ||
             ! same_file "$rollback_current" "$stage"; then
            recovery_artifact=$backup
            secondary_recovery_artifact=$rollback_current
            if ! path_exists "$destination" && ln "$rollback_current" "$destination" &&
               same_file "$rollback_current" "$destination"; then
              printf '%s\n' "ERROR: $label rollback revalidation failed; restored unknown destination without overwrite; private recovery transaction: $transaction_dir" >&2
            else
              printf '%s\n' "ERROR: $label rollback revalidation failed; concurrent destination present; preserved private recovery transaction: $transaction_dir" >&2
            fi
            return 1
          fi
          ;;
        missing)
          ;;
        *)
          recovery_artifact=$backup
          printf '%s\n' "ERROR: refusing to roll back concurrent changed $label destination; preserved for recovery: $transaction_dir" >&2
          return 1
          ;;
      esac
    else
      # Publication never completed. Restore the old backup only if the destination is
      # still absent; any present state belongs to a concurrent actor.
      case "$role_state" in
        known-stale-0.1.1) return 0 ;;
        missing) ;;
        *)
          recovery_artifact=$backup
          printf '%s\n' "ERROR: refusing to roll back unowned concurrent $label destination; preserved for recovery: $transaction_dir" >&2
          return 1
          ;;
      esac
    fi

    if ! has_exact_digest "$backup" "$old_digest"; then
      printf '%s\n' "ERROR: guarded $label backup changed; preserved for recovery: $transaction_dir" >&2
      return 1
    fi
    if ! ln "$backup" "$destination" || ! has_exact_digest "$destination" "$old_digest"; then
      printf '%s\n' "ERROR: refusing to overwrite concurrent $label destination during rollback; preserved for recovery: $transaction_dir" >&2
      return 1
    fi
    printf '%s\n' "ROLLBACK: restored known 0.1.1 $label template" >&2
    return 0
  }

  rollback_upgrade() {
    [ "${upgrade_active-0}" -eq 1 ] || return 0
    # A second termination signal must not interrupt rollback after the active flag is
    # cleared. Post-commit cleanup has already cleared that flag and remains non-rollback.
    trap '' HUP INT TERM
    upgrade_active=0
    rollback_ok=1
    recovery_artifact=''
    secondary_recovery_artifact=''
    if [ "$lock_acquired" -eq 1 ] && ! owns_upgrade_lock &&
       { [ "$terra_displaced_owned" -ne 0 ] || [ "$sol_displaced_owned" -ne 0 ] ||
         [ "$terra_published_owned" -ne 0 ] || [ "$sol_published_owned" -ne 0 ]; }; then
      printf '%s\n' "ERROR: refusing destination rollback after upgrade lock ownership changed: $upgrade_lock" >&2
      rollback_ok=0
    else
      [ -z "$sol_private_backup" ] || rollback_role Sol "$sol_destination" "$sol_template" "$sol_old" "$sol_current" "$sol_private_backup" "$sol_rollback_current" "$stage_sol" "$sol_displaced_owned" "$sol_published_owned" || rollback_ok=0
      [ -z "$terra_private_backup" ] || rollback_role Terra "$terra_destination" "$terra_template" "$terra_old" "$terra_current" "$terra_private_backup" "$terra_rollback_current" "$stage_terra" "$terra_displaced_owned" "$terra_published_owned" || rollback_ok=0
    fi
    if [ "$rollback_ok" -eq 1 ]; then
      cleanup_transaction || rollback_ok=0
    elif [ -n "$recovery_artifact" ]; then
      # A concurrent replacement needs the old guarded copy, but stages and other
      # exact private artifacts remain ours and are removed before reporting recovery.
      cleanup_transaction "$recovery_artifact" "$secondary_recovery_artifact" || true
    fi
    release_upgrade_lock || rollback_ok=0
    if [ "$rollback_ok" -ne 1 ]; then
      printf '%s\n' "ERROR: upgrade rollback failed closed; private recovery transaction: $transaction_dir" >&2
      return 1
    fi
    return 0
  }

  upgrade_on_exit() {
    status=$?
    [ "${upgrade_exit_handled-0}" -eq 1 ] && return "$status"
    upgrade_exit_handled=1
    if [ "${upgrade_active-0}" -eq 1 ]; then
      rollback_upgrade || true
    fi
    return "$status"
  }

  upgrade_on_signal() {
    trap '' HUP INT TERM
    printf '%s\n' "ERROR: upgrade interrupted; attempting guarded rollback" >&2
    exit 1
  }

  # Install the transaction traps before the first private stage or backup exists.
  trap upgrade_on_exit 0
  trap upgrade_on_signal HUP INT TERM
  transaction_dir=$(mktemp -d "$target_dir/.react-sol-advisor-upgrade-txn.XXXXXX") ||
    fail "could not create private upgrade transaction"
  stage_terra=$transaction_dir/terra.stage
  stage_sol=$transaction_dir/sol.stage
  terra_private_backup=$transaction_dir/terra.backup
  sol_private_backup=$transaction_dir/sol.backup
  terra_displaced=$transaction_dir/terra.displaced
  sol_displaced=$transaction_dir/sol.displaced
  terra_rollback_current=$transaction_dir/terra.rollback-current
  sol_rollback_current=$transaction_dir/sol.rollback-current

  cp "$terra_template" "$stage_terra" && has_exact_digest "$stage_terra" "$terra_current" ||
    fail "could not stage and verify Terra upgrade template"
  if [ "${RSA_INSTALL_TEST_HOOK-}" = term-after-terra-stage ]; then
    printf '%s\n' "TEST INJECTION: TERM after Terra stage" >&2
    kill -TERM "$$"
  fi
  cp "$sol_template" "$stage_sol" && has_exact_digest "$stage_sol" "$sol_current" ||
    fail "could not stage and verify Sol upgrade template"

  # Staging is private and may occur concurrently. Destination classification and every
  # subsequent mutation are serialized by one target-local, no-clobber directory lock.
  # The unique nested owner directory is removed only by this transaction through rmdir.
  acquire_upgrade_lock || fail "upgrade lock is already held; no destination mutation performed"
  owns_upgrade_lock || fail "upgrade lock ownership could not be verified before destination classification"

  locked_terra_state=$(classify "$terra_destination" "$terra_template" "$terra_old")
  locked_sol_state=$(classify "$sol_destination" "$sol_template" "$sol_old")
  if [ -e "$luna_destination" ] || [ -L "$luna_destination" ]; then
    fail "native Luna companion appeared before upgrade mutation: $luna_destination"
  fi
  case "$locked_terra_state/$locked_sol_state" in
    current/current)
      # Idempotence is authorized only after this transaction owns the target-local
      # lock and has reclassified both roles plus Luna absence. Remove private staging
      # and release the lock before exposing the successful no-op result.
      upgrade_active=0
      current_cleanup_ok=1
      cleanup_transaction || current_cleanup_ok=0
      release_upgrade_lock || current_cleanup_ok=0
      if [ "$current_cleanup_ok" -ne 1 ]; then
        fail "could not clean current known upgrade transaction"
      fi
      trap - 0 HUP INT TERM
      printf '%s\n' "ALREADY CURRENT: $terra_destination"
      printf '%s\n' "ALREADY CURRENT: $sol_destination"
      exit 0
      ;;
    known-stale-0.1.1/known-stale-0.1.1)
      ;;
    *)
      fail "known upgrade destinations changed after preflight"
      ;;
  esac

  if ! ln "$terra_destination" "$terra_private_backup" ||
     ! has_exact_digest "$terra_private_backup" "$terra_old" ||
     ! cmp -s "$terra_private_backup" "$terra_destination"; then
    fail "could not create guarded Terra upgrade backup"
  fi
  if [ "${RSA_INSTALL_TEST_HOOK-}" = term-after-terra-backup ]; then
    printf '%s\n' "TEST INJECTION: TERM after Terra backup" >&2
    kill -TERM "$$"
  fi
  if ! ln "$sol_destination" "$sol_private_backup" ||
     ! has_exact_digest "$sol_private_backup" "$sol_old" ||
     ! cmp -s "$sol_private_backup" "$sol_destination"; then
    fail "could not create guarded Sol upgrade backup"
  fi

  publish_role() {
    label=$1
    destination=$2
    template=$3
    old_digest=$4
    stage=$5
    displaced=$6
    backup=$7
    if ! owns_upgrade_lock; then
      printf '%s\n' "ERROR: upgrade lock ownership changed before $label publication" >&2
      return 1
    fi
    if [ "$(classify "$destination" "$template" "$old_digest")" != known-stale-0.1.1 ]; then
      printf '%s\n' "ERROR: known $label destination changed before publication; no overwrite performed" >&2
      return 1
    fi
    move_succeeded=0
    displace_valid=0
    unknown_restored=0
    restore_cleanup_failed=0
    begin_signal_safe_transition
    if mv "$destination" "$displaced"; then
      move_succeeded=1
    fi
    if [ "$move_succeeded" -eq 1 ] &&
       has_exact_digest "$displaced" "$old_digest" &&
       has_exact_digest "$backup" "$old_digest" &&
       cmp -s "$displaced" "$backup"; then
      if [ "$label" = Terra ]; then
        terra_displaced_owned=1
      else
        sol_displaced_owned=1
      fi
      displace_valid=1
    elif [ "$move_succeeded" -eq 1 ]; then
      # Provisional state 2 means this transaction moved a destination but did not prove
      # it was the accepted old inode. Rollback must preserve the guarded backup and may
      # not treat the moved bytes as transaction-owned.
      if [ "$label" = Terra ]; then
        terra_displaced_owned=2
      else
        sol_displaced_owned=2
      fi
      if ! path_exists "$destination" && ln "$displaced" "$destination" &&
         same_file "$displaced" "$destination"; then
        unknown_restored=1
        rm -f "$displaced" || restore_cleanup_failed=1
      fi
    fi
    end_signal_safe_transition
    if [ "$move_succeeded" -ne 1 ]; then
      printf '%s\n' "ERROR: could not atomically displace known $label destination; private recovery transaction: $transaction_dir" >&2
      return 1
    fi
    if [ "$displace_valid" -ne 1 ]; then
      # Classification is deliberately repeated after the atomic displacement. The
      # destination may have changed between the pre-publication check and mv; restore
      # that unknown displaced file only when the destination is still absent, never by
      # linking the accepted old backup over it.
      if [ "$unknown_restored" -eq 1 ] && [ "$restore_cleanup_failed" -eq 1 ]; then
        printf '%s\n' "ERROR: $label displace revalidation failed; restored unknown destination but preserved private recovery transaction: $transaction_dir" >&2
        return 1
      fi
      if [ "$unknown_restored" -eq 1 ]; then
        printf '%s\n' "ERROR: $label displace revalidation failed; restored unknown destination without overwrite; private recovery transaction: $transaction_dir" >&2
        return 1
      fi
      printf '%s\n' "ERROR: $label displace revalidation failed; concurrent destination present; preserved private recovery transaction: $transaction_dir" >&2
      return 1
    fi
    publish_succeeded=0
    begin_signal_safe_transition
    if ln "$stage" "$destination"; then
      if [ "$label" = Terra ]; then
        terra_published_owned=1
      else
        sol_published_owned=1
      fi
      publish_succeeded=1
    fi
    end_signal_safe_transition
    if [ "$publish_succeeded" -ne 1 ] ||
       [ "$(classify "$destination" "$template" "$old_digest")" != current ] ||
       ! same_file "$destination" "$stage"; then
      printf '%s\n' "ERROR: concurrent $label destination appeared; no overwrite performed; private recovery transaction: $transaction_dir" >&2
      return 1
    fi
    return 0
  }

  publish_role Terra "$terra_destination" "$terra_template" "$terra_old" "$stage_terra" "$terra_displaced" "$terra_private_backup" ||
    fail "could not publish Terra upgrade"
  if [ "${RSA_INSTALL_TEST_FAIL_REPLACE-}" = sol ]; then
    printf '%s\n' "TEST INJECTION: forced replacement failure for Sol" >&2
    exit 1
  fi
  publish_role Sol "$sol_destination" "$sol_template" "$sol_old" "$stage_sol" "$sol_displaced" "$sol_private_backup" ||
    fail "could not publish Sol upgrade"

  if [ "$(classify "$terra_destination" "$terra_template" "$terra_old")" != current ] ||
     [ "$(classify "$sol_destination" "$sol_template" "$sol_old")" != current ]; then
    fail "post-upgrade exactness check failed"
  fi
  owns_upgrade_lock || fail "upgrade lock ownership changed before commit"
  if [ -e "$luna_destination" ] || [ -L "$luna_destination" ]; then
    fail "native Luna companion appeared during upgrade: $luna_destination"
  fi

  # Current/current plus Luna absence is the commit point. A later cleanup failure
  # deliberately preserves that committed pair and private recovery evidence.
  upgrade_active=0
  committed_cleanup_ok=1
  cleanup_transaction || committed_cleanup_ok=0
  release_upgrade_lock || committed_cleanup_ok=0
  if [ "$committed_cleanup_ok" -ne 1 ]; then
    fail "could not clean committed private upgrade transaction"
  fi
  trap - 0 HUP INT TERM
  printf '%s\n' "UPGRADED KNOWN 0.1.1: $terra_destination"
  printf '%s\n' "UPGRADED KNOWN 0.1.1: $sol_destination"
  exit 0
fi

# Default installation preserves the established missing-only, hard-link publication and
# rollback behavior used by the hardening regression suite.
created=0
terra_installed=0
sol_installed=0
install_complete=0

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
  created=1
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

install_missing() {
  template=$1
  dest=$2
  label=$3

  path_exists "$dest" && fail "destination changed after preflight and will not be overwritten: $dest"
  staged=$(mktemp "$target_dir/.react-sol-advisor-agent.XXXXXX") ||
    fail "could not stage template for installation: $dest"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $dest"
  fi
  if ! ln "$staged" "$dest"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $dest"
  fi

  # Mark before staged cleanup so a later cleanup failure rolls back publication.
  if [ "$label" = Terra ]; then
    terra_installed=1
  else
    sol_installed=1
  fi
  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $dest"
}

rollback_install() {
  [ "$install_complete" -eq 0 ] || return 0

  if [ "$sol_installed" -eq 1 ]; then
    if [ -f "$sol_destination" ] && [ ! -L "$sol_destination" ] && cmp -s "$sol_template" "$sol_destination"; then
      rm -f "$sol_destination"
    else
      printf '%s\n' "ERROR: refusing to roll back changed Sol destination: $sol_destination" >&2
    fi
  fi
  if [ "$terra_installed" -eq 1 ]; then
    if [ -f "$terra_destination" ] && [ ! -L "$terra_destination" ] && cmp -s "$terra_template" "$terra_destination"; then
      rm -f "$terra_destination"
    else
      printf '%s\n' "ERROR: refusing to roll back changed Terra destination: $terra_destination" >&2
    fi
  fi
  if [ "$created" -eq 1 ]; then
    rmdir "$target_dir" 2>/dev/null || true
  fi
}

trap rollback_install 0 HUP INT TERM
[ "$(classify "$terra_destination" "$terra_template" "$terra_old")" = "$terra_state" ] ||
  fail "Terra changed after preflight; no further destination files were changed."
[ "$(classify "$sol_destination" "$sol_template" "$sol_old")" = "$sol_state" ] ||
  fail "Sol changed after preflight; no further destination files were changed."
[ ! -e "$luna_destination" ] && [ ! -L "$luna_destination" ] || fail "native Luna companion appeared after preflight: $luna_destination"
case "$terra_state" in
  missing) install_missing "$terra_template" "$terra_destination" Terra ;;
  current) printf '%s\n' "ALREADY CURRENT: $terra_destination" ;;
esac
case "$sol_state" in
  missing) install_missing "$sol_template" "$sol_destination" Sol ;;
  current) printf '%s\n' "ALREADY CURRENT: $sol_destination" ;;
esac
if [ "$(classify "$terra_destination" "$terra_template" "$terra_old")" != current ] ||
   [ "$(classify "$sol_destination" "$sol_template" "$sol_old")" != current ]; then
  fail "post-install exactness check failed"
fi
[ ! -e "$luna_destination" ] && [ ! -L "$luna_destination" ] ||
  fail "native Luna companion appeared during installation: $luna_destination"
install_complete=1
printf '%s\n' "INSTALL PASSED: Terra and Sol exactly match $template_dir; native Luna is absent."
