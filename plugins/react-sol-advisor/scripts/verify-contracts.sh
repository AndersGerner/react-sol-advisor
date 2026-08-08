#!/bin/sh
# Focused consistency checks for the routing and native-role contracts.

set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
skill=$plugin_dir/skills/orchestration/SKILL.md
role_contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
model_routing=$plugin_dir/skills/orchestration/references/model-routing.md
installer=$script_dir/install-agents.sh
test_support=$script_dir/verifier-test-support.sh
manifest=$plugin_dir/.codex-plugin/plugin.json
readme=$repo_dir/README.md
workflow=$repo_dir/.github/workflows/verify.yml

fail() {
  printf '%s\n' "FAIL: $*" >&2
  printf '%s\n' "::error::$*" >&2
  exit 1
}

for required in "$skill" "$role_contracts" "$model_routing" "$installer" "$test_support" "$manifest" "$readme" "$workflow"; do
  [ -f "$required" ] || fail "missing contract file: $required"
done
. "$test_support"

if grep -Fq "before any explicitly authorized Luna task" "$skill"; then
  fail "orchestration still treats default policy-selected Luna work as separately opt-in"
fi

if grep -Eq 'five-part native specification|bounded five-part specification' "$skill"; then
  fail "orchestration still describes the expanded native packet as five-part"
fi

if grep -Fq "all balanced work that is not explicitly decomposed to Luna" "$skill"; then
  fail "Terra routing still captures balanced green work despite the balanced policy mapping"
fi

grep -Fq "balanced amber or red work" "$skill" ||
  fail "orchestration lacks an explicit balanced amber/red Terra boundary"

# Critical mode is the deliberately expensive safety policy. Its summary table and
# user-facing metadata must not imply that green or non-consequential amber work skips
# the fresh reviewer required by the authoritative orchestration contract.
grep -Eq '^\| Green \| Terra / High .*fresh Sol reviewer required' "$model_routing" ||
  fail "critical green routing does not explicitly require a fresh Sol reviewer"
grep -Fq '| Amber | Terra / High plus fresh Sol reviewer required |' "$model_routing" ||
  fail "critical amber routing still makes the fresh reviewer conditional"
grep -Fq 'All critical work receives a mandatory fresh Sol review.' "$readme" ||
  fail "README does not state the critical-mode final-review guarantee"
jq -e '.interface.longDescription | contains("critical policy always requires a fresh Sol review")' "$manifest" >/dev/null ||
  fail "plugin metadata does not state the critical-mode final-review guarantee"

# CI must reproduce the whitespace gate claimed by the README and PR verification
# packet, rather than relying on an unrecorded local command.
grep -Fq 'git diff --check' "$workflow" ||
  fail "GitHub Actions does not run git diff --check"

# If the role contract claims a retired native Luna companion is absent, the installer
# must actually reject that namespaced file. Otherwise the preflight statement is false.
if grep -Fq "retired companion file is absent" "$role_contracts"; then
  grep -Fq "react-sol-advisor-luna-implementer.toml" "$installer" ||
    fail "role contract claims retired Luna absence but installer does not enforce it"
fi

# Keep the numbered reference navigable and unambiguous.
section_numbers=$(grep -E '^## [0-9]+\.' "$model_routing" | sed -E 's/^## ([0-9]+)\..*/\1/' | tr '\n' ' ')
[ "$section_numbers" = "1 2 3 4 5 6 7 8 9 10 " ] ||
  fail "model-routing section numbering is not sequential: $section_numbers"

tmp_base=$(rsa_resolve_verifier_tmp_base) || fail "could not resolve verifier TMPDIR"
fixture=$(mktemp -d "$tmp_base/react-sol-advisor-contracts.XXXXXX") ||
  fail "could not create retired-role fixture"
cleanup() {
  rsa_cleanup_verifier_fixture "$tmp_base" react-sol-advisor-contracts "$fixture" || true
}
trap cleanup 0 HUP INT TERM

retired_luna=$fixture/react-sol-advisor-luna-implementer.toml
printf '%s\n' "user-owned stale native Luna role" > "$retired_luna"
before=$(cat "$retired_luna")
if retired_output=$(sh "$installer" --target-dir "$fixture" 2>&1); then
  fail "installer accepted a retired namespaced native Luna role"
fi
printf '%s\n' "$retired_output" |
  grep -Fq "unsupported native Luna companion must be removed manually: $retired_luna" ||
  fail "retired native Luna fixture did not reach the intended installer preflight"
[ "$(cat "$retired_luna")" = "$before" ] ||
  fail "installer modified the retired native Luna role while refusing it"
[ ! -e "$fixture/react-sol-advisor-terra-implementer.toml" ] ||
  fail "installer partially installed Terra before rejecting retired Luna"
[ ! -e "$fixture/react-sol-advisor-sol-reviewer.toml" ] ||
  fail "installer partially installed Sol before rejecting retired Luna"
printf '%s\n' "PASS: retired native Luna role reaches installer preflight"

printf '%s\n' "CONTRACTS PASSED"
