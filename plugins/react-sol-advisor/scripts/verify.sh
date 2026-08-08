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
test_support=$script_dir/verifier-test-support.sh
manifest=$plugin_dir/.codex-plugin/plugin.json
marketplace=$repo_dir/.agents/plugins/marketplace.json
template_dir=$plugin_dir/agents

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml
terra_template=$template_dir/$terra_file
sol_template=$template_dir/$sol_file

for required in "$installer" "$runtime_inspector" "$test_support" "$manifest" "$marketplace" "$terra_template" "$sol_template"; do
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

skill_md=$plugin_dir/skills/orchestration/SKILL.md
model_routing=$plugin_dir/skills/orchestration/references/model-routing.md

for f in "$skill_md" "$model_routing"; do
  test -f "$f" || fail "missing $f"
done

for token in "ROUTING DECISION" "POLICY: economy" "RISK: green" "LANE: luna-app-task" "decomposed-mixed" "No silent fallback" "react_sol_advisor_terra_implementer" "react_sol_advisor_sol_reviewer" "Luna-first"; do
  grep -Fq "$token" "$skill_md" || fail "SKILL.md missing $token"
done

for token in "economy" "balanced" "critical" "green" "amber" "red" "luna-app-task" "terra-native" "sol-parent-only" "decomposed-mixed"; do
  grep -Fq "$token" "$model_routing" || fail "model-routing.md missing $token"
done

stale_skill=$(grep -E 'sol_advisor_' "$skill_md" | grep -vE 'react_sol_advisor_' || true)
[ -z "$stale_skill" ] || fail "SKILL.md contains stale sol_advisor role names"

stale_routing=$(grep -E 'sol_advisor_' "$model_routing" | grep -vE 'react_sol_advisor_' || true)
[ -z "$stale_routing" ] || fail "model-routing.md contains stale sol_advisor role names"
pass "routing contract covers policies, risk classes, lanes, and namespaced roles"

react_skill=$plugin_dir/skills/react-production-delivery/SKILL.md
react_next=$plugin_dir/skills/react-production-delivery/references/nextjs.md
react_native=$plugin_dir/skills/react-production-delivery/references/react-native-expo.md
react_testing=$plugin_dir/skills/react-production-delivery/references/testing-accessibility.md

for f in "$react_skill" "$react_next" "$react_native" "$react_testing"; do
  test -f "$f" || fail "missing React production-delivery file: $f"
done

for token in "Pre-edit requirements" "Core implementation rules" "Conditional references" "Specialist skill selection" "Structured worker return"; do
  grep -Fq "$token" "$react_skill" || fail "react-production-delivery/SKILL.md missing $token"
done

grep -Fq "react-production-delivery" "$skill_md" || fail "orchestration SKILL.md does not reference react-production-delivery"
grep -Fq "../react-production-delivery/SKILL.md" "$skill_md" || fail "orchestration SKILL.md does not link to react-production-delivery"
for token in "server components" "caching" "revalidation" "Serializable server-to-client props"; do
  grep -Fq "$token" "$react_next" || fail "nextjs.md missing $token"
done
for token in "React Native" "Expo" "navigation" "offline" "Native module"; do
  grep -Fq "$token" "$react_native" || fail "react-native-expo.md missing $token"
done
for token in "Testing contract" "Verification order" "Accessibility checklist"; do
  grep -Fq "$token" "$react_testing" || fail "testing-accessibility.md missing $token"
done
luna_lane=$plugin_dir/skills/orchestration/references/luna-task-lane.md
thread_lifecycle=$plugin_dir/skills/orchestration/references/thread-lifecycle.md

for f in "$luna_lane" "$thread_lifecycle"; do
  test -f "$f" || fail "missing lifecycle file: $f"
done

for token in "Capability preflight" "Complete Luna task packet" "Thread identity" "Monitoring and handoff" "Correction loop" "PR authorization" "Concurrency and dependency rules"; do
  grep -Fq "$token" "$luna_lane" || fail "luna-task-lane.md missing $token"
done

for token in "Capability-gated archiving" "Supported archive operation exists" "No supported archive operation exists" "Parent final return" "Concurrency and dependency rules"; do
  grep -Fq "$token" "$thread_lifecycle" || fail "thread-lifecycle.md missing $token"
done

grep -Fq "luna-task-lane.md" "$skill_md" || fail "orchestration SKILL.md does not link to luna-task-lane.md"
grep -Fq "thread-lifecycle.md" "$skill_md" || fail "orchestration SKILL.md does not link to thread-lifecycle.md"

linear_intake=$plugin_dir/skills/orchestration/references/linear-intake.md
for token in "Optional Linear intake" "Read-only default" "ISSUE INTAKE" "Untrusted content rule" "Connector unavailable"; do
  grep -Fq "$token" "$linear_intake" || fail "linear-intake.md missing $token"
done
grep -Fq "linear-intake.md" "$skill_md" || fail "orchestration SKILL.md does not link to linear-intake.md"
grep -Fq "MISSING CAPABILITY: Linear issue read access" "$skill_md" || fail "orchestration SKILL.md missing fail-closed Linear response"
pass "Luna task lifecycle and thread-lifecycle references are present"

# Semantic contract checks (feedback-driven)
role_contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
for token in "Green economy work uses the Luna task lane by default" "ACCEPTANCE CRITERIA" "REPOSITORY CONTEXT" "REACT QUALITY CONTRACT" "STRUCTURED RETURN"; do
  grep -Fq "$token" "$role_contracts" || fail "role-contracts.md missing $token"
done

grep -Fq "Require fresh Sol review only at commitment boundaries" "$skill_md" || fail "orchestration SKILL.md missing conditional Sol review section"
if grep -Fq "always spawn a new, fresh reviewer" "$skill_md"; then
  fail "orchestration SKILL.md still requires unconditional fresh Sol review"
fi

grep -Fq "Fresh Sol review" "$model_routing" || fail "model-routing.md missing Fresh Sol review section"
grep -Fq "This reference is a focused companion" "$thread_lifecycle" || fail "thread-lifecycle.md must point to luna-task-lane.md as canonical"
grep -Fq "# Luna task-lane contract" "$luna_lane" || fail "luna-task-lane.md title should mark it as the canonical lane contract"
pass "semantic contract checks pass"

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
sh -n "$test_support"
sh -n "$script_dir/verify.sh"
sh -n "$script_dir/verify-hardening.sh"
sh -n "$script_dir/verify-contracts.sh"
sh -n "$script_dir/verify-tmpdir-portability.sh"
pass "shell syntax"

. "$test_support"
tmp_base=$(rsa_resolve_verifier_tmp_base) || fail "could not resolve verifier TMPDIR"
tmp_dir=''
cleanup() {
  rsa_cleanup_verifier_fixture "$tmp_base" react-sol-advisor-verify "$tmp_dir" || true
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

# Semantic failure matrix
if sh "$installer" --target-dir "/nonexistent/a/../../.." >/dev/null 2>&1; then
  fail "installer accepted path traversal to the root"
fi
pass "installer path traversal is rejected by canonical root guard"

rollback_target=$tmp_dir/rollback
mkdir "$rollback_target"
fake_ln_dir=$tmp_dir/fake-bin
mkdir "$fake_ln_dir"
cat > "$fake_ln_dir/ln" <<'EOF'
#!/bin/sh
case "${2-}" in
  *react-sol-advisor-sol-reviewer.toml)
    printf '%s\n' "SIMULATED SECOND-LINK FAILURE" >&2
    exit 1
    ;;
esac
exec /bin/ln "$@"
EOF
chmod +x "$fake_ln_dir/ln"
if rollback_output=$(PATH="$fake_ln_dir:$PATH" sh "$installer" --target-dir "$rollback_target" 2>&1); then
  fail "installer did not stop on simulated Sol installation failure"
fi
printf '%s\n' "$rollback_output" | grep -Fq "INSTALLED: $rollback_target/$terra_file" ||
  fail "simulated rollback test did not install Terra before the second link"
printf '%s\n' "$rollback_output" | grep -Fq "SIMULATED SECOND-LINK FAILURE" ||
  fail "simulated rollback test did not reach the second link"
if [ -f "$rollback_target/$terra_file" ] || [ -f "$rollback_target/$sol_file" ]; then
  fail "installer left partial files after a second-install failure"
fi
pass "installer rolls back partial install when the second file fails"

runtime_invalid_dir=$runtime_sessions/2026/08/03
mkdir -p "$runtime_invalid_dir"
invalid_model_id=33333333-3333-7333-8333-333333333333
broadened_sandbox_id=44444444-4444-7444-8444-444444444444
unknown_role_id=55555555-5555-7555-8555-555555555555

printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$invalid_model_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"react_sol_advisor_terra_implementer\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-sol","effort":"max","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_invalid_dir/rollout-2026-08-03T00-00-00-$invalid_model_id.jsonl"

printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$broadened_sandbox_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"react_sol_advisor_sol_reviewer\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-sol","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_invalid_dir/rollout-2026-08-03T00-00-00-$broadened_sandbox_id.jsonl"

printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$unknown_role_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"some_other_role\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_invalid_dir/rollout-2026-08-03T00-00-00-$unknown_role_id.jsonl"

if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$invalid_model_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted Terra with Sol model"
fi
broadened_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$broadened_sandbox_id")
printf '%s\n' "$broadened_output" | jq -e '
  .agent_role == "react_sol_advisor_sol_reviewer"
  and .model == "gpt-5.6-sol"
  and .effort == "high"
  and .sandbox_policy_type == "danger-full-access"
  and .permission_profile_type == "disabled"
' >/dev/null || fail "runtime inspector did not report broadened reviewer isolation"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$unknown_role_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted unrecognized agent role"
fi
pass "runtime inspector enforces role/model/effort and reports observed isolation"

# Stale-identifier scan (only tracked files)
stale_exceptions="
UPSTREAM.md
CHANGELOG.md
LICENSE
BUILD-PROGRESS.md
plugins/sol-advisor
plugins/react-sol-advisor/scripts/verify.sh
plugins/react-sol-advisor/scripts/install-agents.sh
"

python3 - "$repo_dir" "$stale_exceptions" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

repo = Path(sys.argv[1])
raw_exceptions = sys.argv[2].strip().splitlines()

# Build file and directory exception sets
excluded_files = set()
excluded_dirs = set()
for e in raw_exceptions:
    e = e.strip()
    if not e:
        continue
    p = repo / e
    if p.is_dir():
        excluded_dirs.add(p)
    else:
        excluded_files.add(p)

stale_re = re.compile(r'(?<!react-)sol-advisor|(?<!react_)sol_advisor_', re.IGNORECASE)
allowed_exts = {'.md', '.json', '.yaml', '.yml', '.toml', '.sh'}

try:
    tracked = subprocess.check_output(['git', '-C', str(repo), 'ls-files'], text=True)
except subprocess.CalledProcessError as e:
    raise SystemExit(f"could not list tracked files: {e}")

for line in tracked.splitlines():
    p = repo / line
    if p.suffix not in allowed_exts:
        continue
    if p in excluded_files:
        continue
    if any(p.is_relative_to(d) for d in excluded_dirs):
        continue
    text = p.read_text(encoding='utf-8')
    for m in stale_re.finditer(text):
        lineno = text[:m.start()].count('\n') + 1
        raise SystemExit(f"stale identifier in {line}:{lineno}: {m.group()}")
print("stale-identifier scan passed")
PY
pass "stale-identifier scan has no outside-attribution stale names"

# Relative-link existence check
python3 - "$plugin_dir" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
link_re = re.compile(r'\[[^\]]*\]\(([^)]+)\)')

for md in root.rglob('*.md'):
    text = md.read_text(encoding='utf-8')
    for m in link_re.finditer(text):
        href = m.group(1)
        if href.startswith('http') or href.startswith('#') or href.startswith('mailto:'):
            continue
        if ' ' in href:
            href = href.split()[0]
        target = (md.parent / href).resolve()
        if not target.exists():
            raise SystemExit(f"broken relative link in {md}: {href}")
print("relative-link scan passed")
PY
pass "all relative Markdown links resolve"

printf '%s\n' "VERIFY PASSED"
