#!/bin/sh
# Repository-level 0.3.1 verifier. Structured behavior belongs to the Python oracles;
# this shell gate checks packaging, syntax, identity, and their deterministic entrypoints.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; printf '%s\n' "::error::$*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd)
manifest=$plugin_dir/.codex-plugin/plugin.json
marketplace=$repo_dir/.agents/plugins/marketplace.json
cursor_manifest=$repo_dir/plugins/cursor-sol-development-advisor/.cursor-plugin/plugin.json
cursor_marketplace=$repo_dir/.cursor-plugin/marketplace.json

for required in "$manifest" "$marketplace" "$cursor_manifest" "$cursor_marketplace" \
  "$script_dir/verify-cross-client.sh" "$script_dir/verify-cursor-agents.py" \
  "$script_dir/verify-codex-adapter.py" "$script_dir/verify-docs.py"; do
  [ -f "$required" ] || fail "required 0.3.1 verifier input is missing: $required"
done

jq -e '
  .name == "react-sol-advisor" and .version == "0.3.1" and
  .interface.displayName == "Sol Development Advisor" and
  (.interface.longDescription | contains("React Sol Advisor remains a legacy alias"))
' "$manifest" >/dev/null || fail "Codex manifest identity or 0.3.1 metadata is invalid"
pass "Codex manifest identity and version"

jq -e '.plugins | length == 1 and .[0].name == "react-sol-advisor" and .[0].source.path == "./plugins/react-sol-advisor"' "$marketplace" >/dev/null ||
  fail "Codex marketplace identity is invalid"
pass "Codex marketplace identity"

jq -e '
  .name == "sol-development-advisor" and .displayName == "Sol Development Advisor" and
  .version == "0.3.1" and .skills == "./skills/" and .agents == "./agents/" and
  .commands == "./commands/" and .rules == "./rules/"
' "$cursor_manifest" >/dev/null || fail "Cursor manifest does not match the current plugin shape"
jq -e '.plugins | length == 1 and .[0].name == "sol-development-advisor" and .[0].source == "./plugins/cursor-sol-development-advisor"' "$cursor_marketplace" >/dev/null ||
  fail "Cursor marketplace manifest is invalid"
pass "Cursor manifest and marketplace"

python3 - "$plugin_dir/agents" <<'PY'
import pathlib
import sys
try:
    import tomllib
except ModuleNotFoundError:
    raise SystemExit("Python 3.11+ tomllib is required")
root = pathlib.Path(sys.argv[1])
expected = {
    "react-sol-advisor-luna-implementer.toml": {
        "name": "react_sol_advisor_luna_implementer",
        "model": "gpt-5.6-luna",
        "effort": "max",
        "service_tier": "fast",
    },
    "react-sol-advisor-terra-implementer.toml": {
        "name": "react_sol_advisor_terra_implementer",
        "model": "gpt-5.6-terra",
        "effort": "high",
    },
    "react-sol-advisor-sol-reviewer.toml": {
        "name": "react_sol_advisor_sol_reviewer",
        "model": "gpt-5.6-sol",
        "effort": "high",
    },
}
for filename, pins in expected.items():
    path = root / filename
    data = tomllib.loads(path.read_text())
    actual = {
        "name": data.get("name"),
        "model": data.get("model"),
        "effort": data.get("model_reasoning_effort"),
    }
    if "service_tier" in pins:
        actual["service_tier"] = data.get("service_tier")
    elif "service_tier" in data:
        raise SystemExit(f"unexpected service-tier pin for tier-agnostic role: {filename}")
    if actual != pins:
        raise SystemExit(f"wrong TOML pin: {filename}")
print("PASS: three exact native role pins")
PY

for shell_file in "$script_dir"/*.sh; do
  sh -n "$shell_file" || fail "invalid shell syntax: $shell_file"
done
pass "shell syntax"

for python_file in "$script_dir"/*.py "$repo_dir/plugins/cursor-sol-development-advisor/scripts"/*.py; do
  [ -f "$python_file" ] || continue
  python3 - "$python_file" <<'PY'
import ast
import pathlib
import sys
ast.parse(pathlib.Path(sys.argv[1]).read_text())
PY
done
pass "Python syntax"

sh "$script_dir/verify-cross-client.sh"
python3 "$script_dir/verify-cursor-agents.py"
python3 "$script_dir/verify-codex-adapter.py"
python3 "$script_dir/verify-docs.py"
pass "structured cross-client, Cursor, and Codex acceptance"
printf '%s\n' "VERIFY PASSED"
