#!/bin/sh
# Install React Sol Advisor's shipped custom-agent templates without changing Codex config.

set -eu

usage() {
  cat <<'USAGE'
Usage: install-agents.sh [--target-dir PATH] [--check]

Install React Sol Advisor's two current custom-agent templates into the target directory.
It never overwrites a modified, nonregular, or symlinked destination, rejects the
unsupported namespaced native Luna companion, and never touches upstream sol-advisor-*
files.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --check            Verify that Terra and Sol match exactly and no conflicting file
                     remains; do not create, replace, or remove anything.
  --help             Show this help text.
USAGE
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

report_preflight_error() {
  printf '%s\n' "ERROR: $*" >&2
  preflight_failed=1
}

# Normalize dot segments without following symlinks, then reject any existing symlink
# in the target path. The final target may be missing, but every existing ancestor must
# be a real directory. This keeps mkdir -p from escaping through a symlinked ancestor.
canonicalize_path() {
  python3 - "$1" <<'PY'
import os
import stat
import sys

path = os.path.abspath(sys.argv[1])
# POSIX gives exactly two leading slashes implementation-defined semantics, and Python
# deliberately preserves them. The installer has no valid need for that namespace, so
# reject it rather than allowing "//" to bypass the filesystem-root guard.
if path == os.path.sep or path.startswith(os.path.sep * 2):
    raise SystemExit("target resolves to the filesystem root or an ambiguous double-slash namespace")

current = os.path.sep
parts = [part for part in path.split(os.path.sep) if part]
for index, part in enumerate(parts):
    current = os.path.join(current, part)
    try:
        mode = os.lstat(current).st_mode
    except FileNotFoundError:
        break

    if stat.S_ISLNK(mode):
        raise SystemExit(f"target path contains a symlink: {current}")
    if index < len(parts) - 1 and not stat.S_ISDIR(mode):
        raise SystemExit(f"target ancestor is not a directory: {current}")

print(path)
PY
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
  else
    shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
  fi
}

classify_destination() {
  destination=$1
  template=$2

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    digest=$(sha256_file "$destination")
    if [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

same_state() {
  label=$1
  expected=$2
  actual=$3
  [ "$expected" = "$actual" ] || fail "$label changed after preflight; no further destination files were changed."
}

mark_installed_destination() {
  destination=$1
  if [ "$destination" = "$terra_destination" ]; then
    terra_installed_this_run=1
  elif [ "$destination" = "$sol_destination" ]; then
    sol_installed_this_run=1
  else
    fail "refusing to track an unexpected installation destination: $destination"
  fi
}

install_missing() {
  template=$1
  destination=$2
  staged=''

  if path_exists "$destination"; then
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  staged=$(mktemp "$target_dir/.react-sol-advisor-agent.XXXXXX") || fail "could not stage template for installation: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $destination"
  fi

  if ! ln "$staged" "$destination"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  # Mark immediately after the destination is created so the EXIT trap can roll it
  # back even if later staging cleanup or the second installation fails.
  mark_installed_destination "$destination"

  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

rollback_destination() {
  label=$1
  installed_this_run=$2
  destination=$3
  template=$4

  [ "$installed_this_run" -eq 1 ] || return 0

  if [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$template" "$destination"; then
    if ! rm -f "$destination"; then
      printf '%s\n' "ERROR: could not roll back $label destination: $destination" >&2
    fi
  else
    printf '%s\n' "ERROR: refusing to roll back changed $label destination: $destination" >&2
  fi
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

check_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a path."
      [ -n "$2" ] || fail "--target-dir requires a non-empty path."
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
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

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

for template in "$terra_template" "$sol_template"; do
  [ -f "$template" ] && [ ! -L "$template" ] ||
    fail "shipped template is missing or not a regular file: $template"
done

preflight_failed=0
if path_exists "$target_dir"; then
  if [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; then
    report_preflight_error "target directory is not a real directory: $target_dir"
  fi
fi

if path_exists "$luna_destination"; then
  report_preflight_error "unsupported native Luna companion must be removed manually: $luna_destination"
fi

terra_state=$(classify_destination "$terra_destination" "$terra_template")
sol_state=$(classify_destination "$sol_destination" "$sol_template")

if [ "$check_only" -eq 1 ]; then
  [ "$terra_state" = current ] ||
    report_preflight_error "Terra template is $terra_state, not the current exact file: $terra_destination"
  [ "$sol_state" = current ] ||
    report_preflight_error "Sol template is $sol_state, not the current exact file: $sol_destination"
else
  case "$terra_state" in
    current|missing) ;;
    *) report_preflight_error "Terra destination is $terra_state and will not be replaced: $terra_destination" ;;
  esac
  case "$sol_state" in
    current|missing) ;;
    *) report_preflight_error "Sol destination is $sol_state and will not be replaced: $sol_destination" ;;
  esac
fi

[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: Terra and Sol exactly match $template_dir; native Luna is absent."
  exit 0
fi

target_dir_created_this_run=0
if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
  target_dir_created_this_run=1
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

terra_installed_this_run=0
sol_installed_this_run=0
install_complete=0

cleanup_install() {
  if [ "$install_complete" -eq 0 ]; then
    rollback_destination Sol "$sol_installed_this_run" "$sol_destination" "$sol_template"
    rollback_destination Terra "$terra_installed_this_run" "$terra_destination" "$terra_template"
    if [ "$target_dir_created_this_run" -eq 1 ]; then
      rmdir "$target_dir" 2>/dev/null || true
    fi
  fi
}
trap cleanup_install 0 HUP INT TERM

same_state Terra "$terra_state" "$(classify_destination "$terra_destination" "$terra_template")"
same_state Sol "$sol_state" "$(classify_destination "$sol_destination" "$sol_template")"
[ ! -e "$luna_destination" ] && [ ! -L "$luna_destination" ] ||
  fail "native Luna companion appeared after preflight: $luna_destination"

case "$terra_state" in
  missing) install_missing "$terra_template" "$terra_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $terra_destination" ;;
  *) fail "unexpected Terra state: $terra_state" ;;
esac

case "$sol_state" in
  missing) install_missing "$sol_template" "$sol_destination" ;;
  current) printf '%s\n' "ALREADY CURRENT: $sol_destination" ;;
  *) fail "unexpected Sol state: $sol_state" ;;
esac

[ "$(classify_destination "$terra_destination" "$terra_template")" = current ] ||
  fail "post-install exactness check failed: $terra_destination"
[ "$(classify_destination "$sol_destination" "$sol_template")" = current ] ||
  fail "post-install exactness check failed: $sol_destination"
[ ! -e "$luna_destination" ] && [ ! -L "$luna_destination" ] ||
  fail "native Luna companion appeared during installation: $luna_destination"

install_complete=1
printf '%s\n' "INSTALL PASSED: Terra and Sol exactly match $template_dir; native Luna is absent."
