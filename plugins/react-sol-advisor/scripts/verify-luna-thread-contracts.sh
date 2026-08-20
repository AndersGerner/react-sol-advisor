#!/bin/sh
# Focused regression gate for the already validated detached Luna lane.
set -eu

fail() { printf '%s\n' "FAIL: $*" >&2; printf '%s\n' "::error::$*" >&2; exit 1; }
pass() { printf '%s\n' "PASS: $*"; }
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd)
skill=$plugin_dir/skills/orchestration/SKILL.md
lane=$plugin_dir/skills/orchestration/references/luna-task-lane.md
roles=$plugin_dir/skills/orchestration/references/role-contracts.md
adapter=$plugin_dir/skills/orchestration/references/codex-adapter.md
evidence=$repo_dir/docs/acceptance/2026-08-08-luna-read-thread-fallback.md

for file in "$skill" "$lane" "$roles" "$adapter" "$evidence"; do
  [ -f "$file" ] || fail "missing detached Luna contract input: $file"
done

for term in "Fast service tier" "wait_threads" "read_thread" "same real thread" "new completed turn" "archived = true" "absence of React never blocks"; do
  grep -Fq "$term" "$lane" "$skill" "$roles" "$adapter" "$evidence" || fail "detached Luna contract omits: $term"
done
pass "detached Luna lifecycle and Fast evidence"

grep -Fq 'LUNA FAST MODE: blocked' "$lane" || fail "detached lane lacks fail-closed Fast result"
grep -Fq 'infer Fast mode from' "$lane" || fail "detached lane permits inferring Fast from model or prompt"
grep -Fq 'capability-adaptive' "$skill" || fail "detached monitor is not capability-adaptive"
grep -Fq '0.3.1' "$plugin_dir/.codex-plugin/plugin.json" || fail "detached lane is not packaged at 0.3.1"
pass "detached Luna no-silent-fallback rules"

grep -Fq '## 0.1.1 - 2026-08-08' "$repo_dir/CHANGELOG.md" || fail "historical detached fallback release was removed"
grep -Fq '## 0.2.1 - 2026-08-10' "$repo_dir/CHANGELOG.md" || fail "historical Fast-only release was removed"
grep -Fq 'sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh' "$repo_dir/.github/workflows/verify.yml" || fail "CI omits detached Luna verifier"
pass "historical detached evidence and CI wiring"

printf '%s\n' "LUNA THREAD CONTRACTS PASSED"
