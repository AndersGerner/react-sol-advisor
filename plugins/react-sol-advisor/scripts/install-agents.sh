#!/bin/sh
# Install React Sol Advisor's shipped custom-agent templates without changing Codex config.

set -eu

usage() {
  cat <<'USAGE'
Usage: install-agents.sh [--target-dir PATH] [--check]

Install React Sol Advisor's two current custom-agent templates into the target directory.
It never overwrites a modified, nonregular, or symlinked destination and never touches
upstream sol-advisor-* files.

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

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
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

  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $destination"
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

case "$target_dir" in
  /|//) fail "refusing to use the filesystem root as an agent target directory." ;;
esac

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml
terra_template=$template_dir/$terra_file
sol_template=$template_dir/$sol_file
terra_destination=$target_dir/$terra_file
sol_destination=$target_dir/$sol_file

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
  printf '%s\n' "CHECK PASSED: Terra and Sol exactly match $template_dir."
  exit 0
fi

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
  fail "target directory changed after preflight: $target_dir"

same_state Terra "$terra_state" "$(classify_destination "$terra_destination" "$terra_template")"
same_state Sol "$sol_state" "$(classify_destination "$sol_destination" "$sol_template")"

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

printf '%s\n' "INSTALL PASSED: Terra and Sol exactly match $template_dir."
