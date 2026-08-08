#!/bin/sh
# Shared POSIX helpers for disposable verifier fixtures. This file is sourced.

rsa_resolve_verifier_tmp_base() {
  rsa_tmp_candidate=${TMPDIR:-/tmp}
  case "$rsa_tmp_candidate" in
    /*) ;;
    *) rsa_tmp_candidate=/tmp ;;
  esac

  # Relative TMPDIR values safely fall back to /tmp. An absolute TMPDIR must already
  # name a directory; silently replacing a missing user-selected path would hide a
  # configuration error. pwd -P removes symlink aliases before verifier fixtures are
  # passed to install-agents.sh.
  if [ ! -d "$rsa_tmp_candidate" ]; then
    printf '%s\n' "ERROR: verifier TMPDIR is not an existing directory: $rsa_tmp_candidate" >&2
    return 1
  fi

  (CDPATH= cd "$rsa_tmp_candidate" && pwd -P)
}

rsa_cleanup_verifier_fixture() {
  rsa_cleanup_base=$1
  rsa_cleanup_prefix=$2
  rsa_cleanup_fixture=$3

  [ -n "$rsa_cleanup_fixture" ] || return 0
  case "$rsa_cleanup_fixture" in
    "$rsa_cleanup_base"/"$rsa_cleanup_prefix".*) ;;
    *)
      printf '%s\n' "ERROR: refusing cleanup of unexpected verifier fixture: $rsa_cleanup_fixture" >&2
      return 1
      ;;
  esac

  if [ -e "$rsa_cleanup_fixture" ] || [ -L "$rsa_cleanup_fixture" ]; then
    rm -rf "$rsa_cleanup_fixture"
  fi
}
