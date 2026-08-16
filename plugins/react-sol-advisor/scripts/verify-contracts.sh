#!/bin/sh
# Focused shared and adapter contract checks.
set -eu

fail() { printf '%s\n' "FAIL: $*" >&2; printf '%s\n' "::error::$*" >&2; exit 1; }
pass() { printf '%s\n' "PASS: $*"; }
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd)
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
profiles=$plugin_dir/skills/orchestration/references/delivery-profiles.md
roles=$plugin_dir/skills/orchestration/references/role-contracts.md
codex=$plugin_dir/skills/orchestration/references/codex-adapter.md
cursor=$plugin_dir/skills/orchestration/references/cursor-adapter.md
changelog=$repo_dir/CHANGELOG.md
workflow=$repo_dir/.github/workflows/verify.yml

[ "$(jq -r '.version' "$manifest")" = "0.3.0" ] || fail "manifest version is not 0.3.0"
grep -Fq '## 0.3.0 - 2026-08-16' "$changelog" || fail "changelog does not record 0.3.0"
grep -Fq '## 0.2.1 - 2026-08-10' "$changelog" || fail "changelog no longer retains 0.2.1 history"
grep -Fq '## 0.2.0 - 2026-08-10' "$changelog" || fail "changelog no longer retains 0.2.0 history"
grep -Fq '## 0.1.1 - 2026-08-08' "$changelog" || fail "changelog no longer retains 0.1.1 history"
pass "version and release history"

for file in "$skill" "$roles" "$codex" "$cursor"; do
  [ -f "$file" ] || fail "missing contract file: $file"
  grep -Fq 'production-delivery' "$file" || fail "contract omits production-delivery: $file"
  grep -Fq 'ADVISOR ROUTE' "$file" || fail "contract omits ADVISOR ROUTE: $file"
done
grep -Fq 'production-delivery' "$profiles" || fail "delivery profile matrix omits production-delivery"
grep -Fq 'TypeScript is not auto-React' "$profiles" || fail "delivery profile matrix omits the generic TypeScript rule"
pass "shared route and profile contracts"

grep -Fq 'React Sol Advisor' "$codex" || fail "Codex adapter omits legacy alias"
grep -Fq 'React Sol Advisor' "$cursor" || fail "Cursor adapter omits legacy alias"
grep -Fq 'codex-luna-detached' "$codex" || fail "Codex detached lane is not documented"
grep -Fq 'codex-luna-native' "$codex" || fail "Codex native Luna lane is not documented"
grep -Fq 'requested_service_tier' "$codex" || fail "Codex requested service tier evidence is not documented"
grep -Fq 'observed_service_tier' "$codex" || fail "Codex observed service tier evidence is not documented"
grep -Fq 'Cursor CLI support is not claimed' "$cursor" || fail "Cursor CLI boundary is not documented"
pass "client-specific bindings and evidence"

grep -Fq 'TypeScript is not auto-React' "$profiles" || fail "delivery matrix lost the non-React TypeScript rule"
grep -Fq 'pg-boss admission plus ownership/orphan reconciliation' "$profiles" || fail "delivery matrix lost the worker/data example"
grep -Fq 'fle-1007-like' "$repo_dir/plugins/react-sol-advisor/scripts/fixtures/cross-client/cases.json" || fail "FLE-1007-like fixture is missing"
pass "generic non-React profile selection"

grep -Fq 'sh plugins/react-sol-advisor/scripts/verify-cross-client.sh' "$workflow" || fail "CI omits cross-client verifier"
grep -Fq 'verify-codex-adapter.py' "$workflow" || fail "CI omits Codex adapter verifier"
grep -Fq 'verify-cursor-agents.py' "$workflow" || fail "CI omits Cursor agent verifier"
grep -Fq 'verify-docs.py' "$workflow" || fail "CI omits manifest and Markdown verifier"
grep -Fq 'git diff --check' "$workflow" || fail "CI omits whitespace validation"
pass "CI contract wiring"

printf '%s\n' "CONTRACTS PASSED"
