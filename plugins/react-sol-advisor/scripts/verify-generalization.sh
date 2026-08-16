#!/bin/sh
# Generic product and semantic non-React acceptance.
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd)
fail() { printf '%s\n' "FAIL: $*" >&2; printf '%s\n' "::error::$*" >&2; exit 1; }
pass() { printf '%s\n' "PASS: $*"; }

sh "$script_dir/verify-cross-client.sh"
python3 "$script_dir/verify-cursor-agents.py"
python3 "$script_dir/verify-codex-adapter.py"

for profile in production-delivery react-production-delivery typescript-backend-delivery postgres-data-delivery worker-integration-delivery; do
  [ -f "$plugin_dir/skills/$profile/SKILL.md" ] || fail "missing delivery profile: $profile"
done
pass "all generic and conditional delivery profiles exist"

if grep -RIlE 'React is required|React profile.*mandatory.*(backend|worker|data|typescript)|legacy.*(selects|forces).*React' \
  "$plugin_dir/skills" "$repo_dir/plugins/cursor-sol-development-advisor" "$repo_dir/docs"; then
  fail "authoritative delivery contract contains an obsolete React-only condition"
fi
pass "authoritative contracts contain no React-only eligibility"

grep -Fq 'React Sol Advisor' "$repo_dir/README.md" || fail "README omits legacy product alias"
grep -Fq 'fle-1007-like' "$repo_dir/plugins/react-sol-advisor/scripts/fixtures/cross-client/cases.json" || fail "FLE-1007-like semantic oracle is missing"
grep -Fq 'current fetched upstream head' "$repo_dir/docs/upstream-adoption.md" || fail "upstream adoption ledger is incomplete"
printf '%s\n' "GENERALIZATION ACCEPTANCE PASSED"
