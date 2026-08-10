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

remove_run_created_backup() {
  label=$1
  backup=$2
  expected_digest=$3
  created_this_run=$4

  [ "$created_this_run" -eq 1 ] || return 0
  if has_exact_digest "$backup" "$expected_digest"; then
    if ! rm -f "$backup"; then
      printf '%s\n' "ERROR: could not remove run-created guarded $label backup: $backup" >&2
    fi
  else
    printf '%s\n' "ERROR: guarded $label backup changed; preserved for recovery: $backup" >&2
  fi
}

remove_verified_backup() {
  label=$1
  backup=$2
  expected_digest=$3

  if ! has_exact_digest "$backup" "$expected_digest"; then
    printf '%s\n' "ERROR: guarded $label backup changed; preserved for recovery: $backup" >&2
    return 1
  fi
  rm -f "$backup" || {
    printf '%s\n' "ERROR: could not remove guarded $label backup: $backup" >&2
    return 1
  }
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

if [ "$upgrade_known" -eq 1 ] && [ "$terra_state/$sol_state" = current/current ]; then
  printf '%s\n' "ALREADY CURRENT: $terra_destination"
  printf '%s\n' "ALREADY CURRENT: $sol_destination"
  exit 0
fi

if [ "$upgrade_known" -eq 1 ]; then
  terra_backup_created=0
  sol_backup_created=0
  stage_terra=$(mktemp "$target_dir/.react-sol-advisor-upgrade-terra.XXXXXX") ||
    fail "could not stage Terra upgrade"
  stage_sol=$(mktemp "$target_dir/.react-sol-advisor-upgrade-sol.XXXXXX") || {
    rm -f "$stage_terra"
    fail "could not stage Sol upgrade"
  }
  if ! cp "$terra_template" "$stage_terra" ||
     ! cp "$sol_template" "$stage_sol" ||
     ! cmp -s "$terra_template" "$stage_terra" ||
     ! cmp -s "$sol_template" "$stage_sol"; then
    rm -f "$stage_terra" "$stage_sol"
    fail "could not stage and verify both upgrade templates"
  fi

  if [ "$(classify "$terra_destination" "$terra_template" "$terra_old")" != known-stale-0.1.1 ] ||
     [ "$(classify "$sol_destination" "$sol_template" "$sol_old")" != known-stale-0.1.1 ]; then
    rm -f "$stage_terra" "$stage_sol"
    fail "known upgrade destinations changed after preflight"
  fi

  if ln "$terra_destination" "$terra_backup"; then
    terra_backup_created=1
  else
    rm -f "$stage_terra" "$stage_sol"
    fail "could not create guarded upgrade backups"
  fi

  if ln "$sol_destination" "$sol_backup"; then
    sol_backup_created=1
  else
    rm -f "$stage_terra" "$stage_sol"
    remove_run_created_backup Terra "$terra_backup" "$terra_old" "$terra_backup_created"
    fail "could not create guarded upgrade backups"
  fi

  if ! has_exact_digest "$terra_backup" "$terra_old" ||
     ! has_exact_digest "$sol_backup" "$sol_old" ||
     ! cmp -s "$terra_backup" "$terra_destination" ||
     ! cmp -s "$sol_backup" "$sol_destination"; then
    rm -f "$stage_terra" "$stage_sol"
    remove_run_created_backup Sol "$sol_backup" "$sol_old" "$sol_backup_created"
    remove_run_created_backup Terra "$terra_backup" "$terra_old" "$terra_backup_created"
    fail "guarded backups are not exact known 0.1.1 files"
  fi
  if [ "$(classify "$terra_destination" "$terra_template" "$terra_old")" != known-stale-0.1.1 ] ||
     [ "$(classify "$sol_destination" "$sol_template" "$sol_old")" != known-stale-0.1.1 ]; then
    rm -f "$stage_terra" "$stage_sol"
    remove_run_created_backup Sol "$sol_backup" "$sol_old" "$sol_backup_created"
    remove_run_created_backup Terra "$terra_backup" "$terra_old" "$terra_backup_created"
    fail "known upgrade destinations changed before mutation"
  fi
  if [ -e "$luna_destination" ] || [ -L "$luna_destination" ]; then
    rm -f "$stage_terra" "$stage_sol"
    remove_run_created_backup Sol "$sol_backup" "$sol_old" "$sol_backup_created"
    remove_run_created_backup Terra "$terra_backup" "$terra_old" "$terra_backup_created"
    fail "native Luna companion appeared before upgrade mutation: $luna_destination"
  fi

  upgrade_active=1
  rollback_upgrade() {
    [ "${upgrade_active-0}" -eq 1 ] || return 0
    upgrade_active=0
    rollback_role Sol "$sol_destination" "$sol_template" "$sol_backup" "$sol_old"
    rollback_role Terra "$terra_destination" "$terra_template" "$terra_backup" "$terra_old"
    rm -f "$stage_terra" "$stage_sol" 2>/dev/null || true
  }
  rollback_role() {
    label=$1
    destination=$2
    template=$3
    backup=$4
    expected_digest=$5

    [ -e "$backup" ] || return 0

    if ! has_exact_digest "$backup" "$expected_digest"; then
      printf '%s\n' "ERROR: guarded $label backup changed; preserved for recovery: $backup" >&2
      return 0
    fi

    if [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$template" "$destination"; then
      if mv "$backup" "$destination"; then
        printf '%s\n' "ROLLBACK: restored known 0.1.1 $label template" >&2
      else
        printf '%s\n' "ERROR: refusing to roll back changed $label destination: $destination" >&2
      fi
    elif [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$backup" "$destination"; then
      if ! rm -f "$backup"; then
        printf '%s\n' "ERROR: could not remove guarded $label backup: $backup" >&2
      fi
    else
      printf '%s\n' "ERROR: refusing to roll back changed $label destination; preserved backup: $backup" >&2
    fi
  }

  rollback_signal() {
    rollback_upgrade
    exit 1
  }

  trap rollback_upgrade 0
  trap rollback_signal HUP INT TERM

  mv "$stage_terra" "$terra_destination" || fail "could not replace Terra known template"
  if [ "${RSA_INSTALL_TEST_FAIL_REPLACE-}" = sol ]; then
    printf '%s\n' "TEST INJECTION: forced replacement failure for Sol" >&2
    exit 1
  fi
  mv "$stage_sol" "$sol_destination" || fail "could not replace Sol known template"

  if [ "$(classify "$terra_destination" "$terra_template" "$terra_old")" != current ] ||
     [ "$(classify "$sol_destination" "$sol_template" "$sol_old")" != current ]; then
    fail "post-upgrade exactness check failed"
  fi
  if [ -e "$luna_destination" ] || [ -L "$luna_destination" ]; then
    fail "native Luna companion appeared during upgrade: $luna_destination"
  fi

  # Do not clear upgrade_active until both guarded backups are verified and gone. A
  # changed backup is preserved for recovery and cannot be moved over a destination.
  if ! remove_verified_backup Sol "$sol_backup" "$sol_old" ||
     ! remove_verified_backup Terra "$terra_backup" "$terra_old"; then
    fail "could not remove guarded upgrade backups"
  fi
  upgrade_active=0
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
