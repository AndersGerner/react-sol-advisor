#!/bin/sh
set -eu

remote=${1-upstream}
git fetch "$remote" main >&2
head=$(git rev-parse "$remote/main")
base=$(git rev-parse HEAD)
printf '%s\n' "UPSTREAM_REMOTE=$remote" "UPSTREAM_HEAD=$head" "LOCAL_HEAD=$base"
printf '%s\n' "NEWER_COMMITS_BEGIN"
git log --oneline --decorate "$base..$remote/main"
printf '%s\n' "NEWER_COMMITS_END"
