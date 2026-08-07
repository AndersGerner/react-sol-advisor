#!/bin/sh
# Focused regression tests for installer and runtime-inspector safety boundaries.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
failures=0
record_failure() {
  printf '%s\n' "FAIL: $*" >&2
  failures=$((failures + 1))
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
installer=$script_dir/install-agents.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh

terra_file=react-sol-advisor-terra-implementer.toml
sol_file=react-sol-advisor-sol-reviewer.toml

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac

tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/react-sol-advisor-hardening.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "ERROR: refusing cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM

tmp_dir=$(mktemp -d "$tmp_base/react-sol-advisor-hardening.XXXXXX") || {
  printf '%s\n' "FAIL: could not create disposable directory" >&2
  exit 1
}

# A non-existing target below a symlinked ancestor must be refused. Merely normalizing
# '..' components is insufficient because mkdir -p follows the ancestor symlink.
symlink_root=$tmp_dir/symlink-root
symlink_outside=$tmp_dir/symlink-outside
mkdir -p "$symlink_root" "$symlink_outside"
ln -s "$symlink_outside" "$symlink_root/linked"
if sh "$installer" --target-dir "$symlink_root/linked/agents" >/dev/null 2>&1; then
  record_failure "installer accepted a target below a symlinked ancestor"
elif [ -e "$symlink_outside/agents" ]; then
  record_failure "installer mutated the symlink destination before refusing it"
else
  pass "installer refuses a target below a symlinked ancestor"
fi

# Rollback bookkeeping must preserve a quoted path. A whitespace-containing explicit
# target is valid input and must not leave Terra behind when Sol installation fails.
rollback_target=$tmp_dir/'rollback target'
mkdir -p "$rollback_target"
fake_bin=$tmp_dir/fake-bin
mkdir -p "$fake_bin"
cat > "$fake_bin/ln" <<'EOF'
#!/bin/sh
case "${2-}" in
  *react-sol-advisor-sol-reviewer.toml)
    printf '%s\n' "SIMULATED SECOND-LINK FAILURE" >&2
    exit 1
    ;;
esac
exec /bin/ln "$@"
EOF
chmod +x "$fake_bin/ln"
if PATH="$fake_bin:$PATH" sh "$installer" --target-dir "$rollback_target" >/dev/null 2>&1; then
  record_failure "installer did not stop on the simulated second-link failure"
elif [ -e "$rollback_target/$terra_file" ] || [ -e "$rollback_target/$sol_file" ]; then
  record_failure "installer left a partial installation for a target containing spaces"
else
  pass "installer rollback preserves whitespace-containing target paths"
fi

runtime_sessions=$tmp_dir/sessions
runtime_day=$runtime_sessions/2026/08/07
mkdir -p "$runtime_day"

write_rollout() {
  id=$1
  role=$2
  model=$3
  effort=$4
  sandbox=$5
  permission=$6
  file=$runtime_day/rollout-2026-08-07T00-00-00-$id.jsonl

  printf '%s\n' \
    '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK","token":"DO_NOT_LEAK_TOKEN"}}' \
    "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"$role\",\"agent_path\":\"/fixture/agent\",\"model_provider\":\"openai\"}}" \
    "{\"type\":\"turn_context\",\"payload\":{\"model\":\"$model\",\"effort\":\"$effort\",\"sandbox_policy\":{\"type\":\"$sandbox\"},\"permission_profile\":{\"type\":\"$permission\"},\"cwd\":\"/fixture\"}}" \
    > "$file"
}

# The TOML requests read-only, but the host may broaden it. The inspector must report
# the observed sandbox; the parent contract decides whether behavioral isolation is safe.
broadened_id=66666666-6666-7666-8666-666666666666
write_rollout "$broadened_id" react_sol_advisor_sol_reviewer gpt-5.6-sol high danger-full-access disabled
if broadened_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$broadened_id" 2>/dev/null); then
  if ! printf '%s\n' "$broadened_output" | jq -e '
    .agent_role == "react_sol_advisor_sol_reviewer"
    and .model == "gpt-5.6-sol"
    and .effort == "high"
    and .sandbox_policy_type == "danger-full-access"
    and .permission_profile_type == "disabled"
  ' >/dev/null; then
    record_failure "runtime inspector returned incorrect broadened reviewer evidence"
  elif printf '%s\n' "$broadened_output" | grep -Eq 'DO_NOT_LEAK|DO_NOT_LEAK_TOKEN'; then
    record_failure "runtime inspector leaked non-allowlisted rollout content"
  else
    pass "runtime inspector reports a broadened reviewer sandbox without treating it as a model pin"
  fi
else
  record_failure "runtime inspector rejected an observable broadened reviewer sandbox"
fi

# A valid enforced-read-only reviewer remains accepted.
readonly_id=77777777-7777-7777-8777-777777777777
write_rollout "$readonly_id" react_sol_advisor_sol_reviewer gpt-5.6-sol high read-only disabled
if readonly_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$readonly_id" 2>/dev/null); then
  if printf '%s\n' "$readonly_output" | jq -e '
    .sandbox_policy_type == "read-only"
    and .permission_profile_type == "disabled"
  ' >/dev/null; then
    pass "runtime inspector accepts and reports enforced reviewer isolation"
  else
    record_failure "runtime inspector omitted reviewer sandbox or permission evidence"
  fi
else
  record_failure "runtime inspector rejected a valid Sol/high reviewer rollout"
fi

# Reviewer permission evidence is mandatory. A consistent null value is still missing.
missing_permission_id=88888888-8888-7888-8888-888888888888
missing_permission_file=$runtime_day/rollout-2026-08-07T00-00-00-$missing_permission_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$missing_permission_id\",\"agent_role\":\"react_sol_advisor_sol_reviewer\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-sol","effort":"high","sandbox_policy":{"type":"read-only"},"cwd":"/fixture"}}' \
  > "$missing_permission_file"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$missing_permission_id" >/dev/null 2>&1; then
  record_failure "runtime inspector accepted reviewer evidence without a permission profile"
else
  pass "runtime inspector rejects missing reviewer permission evidence"
fi

# Model and effort mismatches are independent failure modes.
wrong_effort_id=99999999-9999-7999-8999-999999999999
write_rollout "$wrong_effort_id" react_sol_advisor_terra_implementer gpt-5.6-terra max danger-full-access disabled
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$wrong_effort_id" >/dev/null 2>&1; then
  record_failure "runtime inspector accepted a Terra worker with the wrong effort"
else
  pass "runtime inspector rejects a Terra effort mismatch"
fi

# The exact thread id must resolve to one rollout only.
multiple_id=aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa
write_rollout "$multiple_id" react_sol_advisor_terra_implementer gpt-5.6-terra high danger-full-access disabled
second_day=$runtime_sessions/2026/08/08
mkdir -p "$second_day"
cp "$runtime_day/rollout-2026-08-07T00-00-00-$multiple_id.jsonl" \
  "$second_day/rollout-2026-08-08T00-00-00-$multiple_id.jsonl"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$multiple_id" >/dev/null 2>&1; then
  record_failure "runtime inspector accepted multiple rollout matches"
else
  pass "runtime inspector rejects multiple rollout matches"
fi

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "HARDENING FAILED: $failures regression(s)" >&2
  exit 1
fi

printf '%s\n' "HARDENING PASSED"
