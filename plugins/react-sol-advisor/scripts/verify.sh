#!/bin/sh
# React Sol Advisor repository verification (Task 2 focused: role subsystem).

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1

installer=$script_dir/install-agents.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
manifest=$plugin_dir/.codex-plugin/plugin.json
marketplace=$repo_dir/.agents/plugins/marketplace.json
template_dir=$plugin_dir/agents

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml
terra_template=$template_dir/$terra_file
sol_template=$template_dir/$sol_file

for required in "$installer" "$runtime_inspector" "$manifest" "$marketplace" "$terra_template" "$sol_template"; do
  test -f "$required" || fail "required file missing: $required"
done

jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = '0.1.0' ] || fail "manifest version is not 0.1.0"
[ "$(jq -r '.name' "$manifest")" = 'react-sol-advisor' ] || fail "manifest name is not react-sol-advisor"
[ "$(jq -r '.interface.displayName' "$manifest")" = 'React Sol Advisor' ] || fail "manifest displayName is not React Sol Advisor"
pass "manifest JSON and identity"

jq empty "$marketplace"
[ "$(jq -r '.name' "$marketplace")" = 'react-sol-advisor' ] || fail "marketplace name is not react-sol-advisor"
[ "$(jq -r '.interface.displayName' "$marketplace")" = 'React Sol Advisor' ] || fail "marketplace displayName is not React Sol Advisor"
[ "$(jq -r '.plugins[0].name' "$marketplace")" = 'react-sol-advisor' ] || fail "marketplace plugin name is not react-sol-advisor"
[ "$(jq -r '.plugins[0].source.path' "$marketplace")" = './plugins/react-sol-advisor' ] || fail "marketplace plugin path is not ./plugins/react-sol-advisor"
pass "marketplace JSON and identity"

python3 - "$template_dir" <<'PY'
from pathlib import Path
import sys, tomllib

root = Path(sys.argv[1])
expected = {
    "react-sol-advisor-terra-implementer.toml": {
        "name": "react_sol_advisor_terra_implementer",
        "model": "gpt-5.6-terra",
        "model_reasoning_effort": "high",
    },
    "react-sol-advisor-sol-reviewer.toml": {
        "name": "react_sol_advisor_sol_reviewer",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
}
actual = {path.name for path in root.glob("*.toml")}
if actual != set(expected):
    raise SystemExit(f"expected exactly {sorted(expected)}, found {sorted(actual)}")
for filename, pins in expected.items():
    data = tomllib.loads((root / filename).read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{filename}: missing {field}")
    for field, value in pins.items():
        if data.get(field) != value:
            raise SystemExit(f"{filename}: {field}={data.get(field)!r}, expected {value!r}")
print("two exact role pins are valid")
PY
pass "two exact role TOML pins"

sh -n "$installer"
sh -n "$runtime_inspector"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/react-sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "ERROR: refusing cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/react-sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"

clean_target=$tmp_dir/clean
sh "$installer" --target-dir "$clean_target"
cmp -s "$terra_template" "$clean_target/$terra_file" || fail "clean Terra install mismatch"
cmp -s "$sol_template" "$clean_target/$sol_file" || fail "clean Sol install mismatch"
sh "$installer" --target-dir "$clean_target" --check
before=$(find "$clean_target" -mindepth 1 -maxdepth 1 -type f -print | LC_ALL=C sort)
sh "$installer" --target-dir "$clean_target"
after=$(find "$clean_target" -mindepth 1 -maxdepth 1 -type f -print | LC_ALL=C sort)
[ "$before" = "$after" ] || fail "idempotent install changed files"
pass "clean install, exact check, and idempotence"

missing_target=$tmp_dir/missing
if sh "$installer" --target-dir "$missing_target" --check; then fail "--check accepted missing target"; fi
test ! -e "$missing_target" || fail "--check created missing target"
pass "missing-target check refusal is non-mutating"

codex_home=$tmp_dir/codex-home
CODEX_HOME="$codex_home" sh "$installer"
cmp -s "$terra_template" "$codex_home/agents/$terra_file" || fail "CODEX_HOME Terra mismatch"
cmp -s "$sol_template" "$codex_home/agents/$sol_file" || fail "CODEX_HOME Sol mismatch"
pass "CODEX_HOME fallback"

relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$terra_template" "$relative_parent/relative-agents/$terra_file" || fail "relative target Terra mismatch"
cmp -s "$sol_template" "$relative_parent/relative-agents/$sol_file" || fail "relative target Sol mismatch"
pass "relative target"

coexistence_target=$tmp_dir/coexistence
mkdir -p "$coexistence_target"
cp "$terra_template" "$coexistence_target/$terra_file"
cp "$sol_template" "$coexistence_target/$sol_file"
cp "$terra_template" "$coexistence_target/sol-advisor-terra-implementer.toml"
cp "$sol_template" "$coexistence_target/sol-advisor-sol-reviewer.toml"
printf '%s\n' "upstream-terra-modified" >> "$coexistence_target/sol-advisor-terra-implementer.toml"
printf '%s\n' "upstream-sol-modified" >> "$coexistence_target/sol-advisor-sol-reviewer.toml"
before=$(find "$coexistence_target" -mindepth 1 -maxdepth 1 -type f -print | LC_ALL=C sort)
sh "$installer" --target-dir "$coexistence_target"
after=$(find "$coexistence_target" -mindepth 1 -maxdepth 1 -type f -print | LC_ALL=C sort)
[ "$before" = "$after" ] || fail "installer changed files in coexistence target"
for stale in sol-advisor-terra-implementer.toml sol-advisor-sol-reviewer.toml; do
  if cmp -s "$template_dir/$terra_file" "$coexistence_target/$stale" 2>/dev/null; then
    fail "installer overwrote the modified upstream file: $stale"
  fi
done
pass "coexistence: current fork and modified upstream files are not touched"

symlink_target=$tmp_dir/symlink
mkdir "$symlink_target"
ln -s "$terra_template" "$symlink_target/$terra_file"
if sh "$installer" --target-dir "$symlink_target"; then fail "installer accepted symlink"; fi
test ! -f "$symlink_target/$terra_file" || test -L "$symlink_target/$terra_file" || fail "installer replaced symlink"
pass "symlink refusal"

conflict_target=$tmp_dir/conflict
mkdir "$conflict_target"
cp "$terra_template" "$conflict_target/$terra_file"
cp "$sol_template" "$conflict_target/$sol_file"
printf '%s\n' "fork-terra-modified" >> "$conflict_target/$terra_file"
if sh "$installer" --target-dir "$conflict_target"; then fail "installer accepted modified fork"; fi
test -s "$conflict_target/$terra_file" || fail "installer removed modified fork file"
pass "modified fork conflict refusal"

runtime_sessions=$tmp_dir/sessions
runtime_day=$runtime_sessions/2026/08/02
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-08-02T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"react_sol_advisor_terra_implementer\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
printf '%s\n' "$runtime_output" | jq -e --arg id "$runtime_id" '
  .thread_id == $id and .agent_role == "react_sol_advisor_terra_implementer"
  and .model == "gpt-5.6-terra" and .effort == "high"
  and .sandbox_policy_type == "danger-full-access"
  and .permission_profile_type == "disabled"
' >/dev/null || fail "runtime inspector returned wrong Terra/High evidence"
if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi
zero_id=22222222-2222-7222-8222-222222222222
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$zero_id" >/dev/null 2>&1; then fail "runtime inspector accepted zero matches"; fi
pass "runtime inspector routing and safe refusal"

printf '%s\n' "VERIFY PASSED"
