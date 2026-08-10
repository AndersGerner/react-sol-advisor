#!/bin/sh
# Executable acceptance contract for Sol Development Advisor 0.2.0.

set -u

fail() {
  printf '%s\n' "FAIL: $*" >&2
  printf '%s\n' "::error::$*" >&2
  exit 1
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
luna_verifier=$script_dir/verify-luna-thread-contracts.sh

for required in "$luna_verifier" "$plugin_dir/.codex-plugin/plugin.json" \
  "$repo_dir/.agents/plugins/marketplace.json" "$repo_dir/.github/workflows/verify.yml"; do
  [ -f "$required" ] || fail "missing required acceptance input: $required"
done

# Luna lifecycle correctness is intentionally owned by the established focused verifier.
# This generalization contract must consume that verifier rather than cloning lifecycle
# assertions that could drift from the canonical Luna lane.
if ! luna_output=$(sh "$luna_verifier" 2>&1); then
  printf '%s\n' "$luna_output" >&2
  fail "existing Luna lifecycle verifier failed; generalization cannot supersede it"
fi
printf '%s\n' "PASS: existing Luna lifecycle verifier remains authoritative"

python3 - "$repo_dir" "$0" <<'PY'
from __future__ import annotations

import json
import copy
import re
import subprocess
import sys
import tomllib
from pathlib import Path

repo = Path(sys.argv[1])
this_verifier = Path(sys.argv[2]).resolve()
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        errors.append(message)


def read(relative: str) -> str:
    path = repo / relative
    if not path.is_file():
        errors.append(f"missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")


def includes_all(value: str, *needles: str) -> bool:
    folded = value.casefold()
    return all(needle.casefold() in folded for needle in needles)


def section(value: str, heading: str) -> str:
    match = re.search(
        rf"^### +{re.escape(heading)}\s*$([\s\S]*?)(?=^### +|\Z)",
        value,
        flags=re.MULTILINE,
    )
    return match.group(1) if match else ""


def parse_routing_truth_table(value: str) -> dict[str, object]:
    match = re.search(
        r"```json routing-truth-table\s*([\s\S]*?)\s*```",
        value,
        flags=re.MULTILINE,
    )
    if not match:
        return {}
    try:
        parsed = json.loads(match.group(1))
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def routing_truth_errors(table: dict[str, object]) -> list[str]:
    raw_cases = table.get("cases")
    if not isinstance(raw_cases, list):
        return ["routing truth table has no cases list"]
    cases = {
        case.get("id"): case
        for case in raw_cases
        if isinstance(case, dict) and isinstance(case.get("id"), str)
    }
    expected: dict[str, dict[str, object]] = {
        "pure-typescript-mapper": {
            "policy": "economy",
            "risk": "green",
            "lane": "luna-app-task",
            "profiles": ["production-delivery", "typescript-backend-delivery"],
            "fresh_sol_review_required": False,
        },
        "pg-boss-ownership-reconciliation": {
            "policy": "economy",
            "risk": "amber",
            "lane": "decomposed-mixed",
            "profiles": ["production-delivery", "postgres-data-delivery", "worker-integration-delivery"],
            "terra_owns": "consistency core",
            "luna_owns": "independently-green helpers, fixtures, tests, or docs only",
            "fresh_sol_review_required": False,
        },
        "schema-migration": {
            "risk": "red",
            "lane": "terra-native",
            "profiles": ["production-delivery", "postgres-data-delivery"],
            "fresh_sol_review_required": True,
        },
        "legacy-react-url-filter": {
            "policy": "economy",
            "risk": "green",
            "lane": "luna-app-task",
            "profiles": ["production-delivery", "react-production-delivery"],
            "invocation": "@react-sol-advisor",
            "fresh_sol_review_required": False,
        },
        "critical-mechanical-luna": {
            "policy": "critical",
            "risk": "green",
            "lane": "luna-app-task",
            "fresh_sol_review_required": True,
        },
        "bounded-queue-lease-transition": {
            "risk": "amber",
            "lane": "terra-native",
        },
        "bounded-orphan-reconciliation-state-machine": {
            "risk": "amber",
            "lane": "terra-native",
        },
        "bounded-unsettled-stale-response-race": {
            "risk": "amber",
            "lane": "terra-native",
        },
    }
    found: list[str] = []
    for case_id, fields in expected.items():
        actual = cases.get(case_id)
        if not isinstance(actual, dict):
            found.append(f"missing routing case: {case_id}")
            continue
        for field, expected_value in fields.items():
            actual_value = actual.get(field)
            if field == "profiles" and isinstance(actual_value, list):
                if set(actual_value) != set(expected_value):
                    found.append(f"{case_id}.{field} is {actual_value!r}, expected {expected_value!r}")
            elif actual_value != expected_value:
                found.append(f"{case_id}.{field} is {actual_value!r}, expected {expected_value!r}")
    pg_boss = cases.get("pg-boss-ownership-reconciliation")
    if isinstance(pg_boss, dict) and "react-production-delivery" in pg_boss.get("profiles", []):
        found.append("pg-boss routing must not select the React profile")
    return found


def routing_contradictions(value: str) -> list[str]:
    patterns = {
        "pg-boss cannot be green by boundedness alone": r"pg-boss[^\n.]*\b(?:is|as|classified)\s+green\b",
        "backend TypeScript cannot require React": r"React profile is mandatory for backend TypeScript",
        "critical mechanical Luna still requires fresh Sol": r"critical mechanical Luna[^\n.]*does not require (?:a )?fresh Sol",
        "bounded queue leases remain amber": r"bounded queue lease transition[^\n.]*\b(?:is|as|classified)\s+green\b",
    }
    return [message for message, pattern in patterns.items() if re.search(pattern, value, flags=re.IGNORECASE)]


manifest_path = "plugins/react-sol-advisor/.codex-plugin/plugin.json"
marketplace_path = ".agents/plugins/marketplace.json"
readme_path = "README.md"
changelog_path = "CHANGELOG.md"
skill_path = "plugins/react-sol-advisor/skills/orchestration/SKILL.md"
routing_path = "plugins/react-sol-advisor/skills/orchestration/references/model-routing.md"
roles_path = "plugins/react-sol-advisor/skills/orchestration/references/role-contracts.md"
examples_path = "plugins/react-sol-advisor/examples/invocations.md"
packet_path = "plugins/react-sol-advisor/examples/luna-task-packet.md"
production_path = "plugins/react-sol-advisor/skills/production-delivery/SKILL.md"
react_path = "plugins/react-sol-advisor/skills/react-production-delivery/SKILL.md"
typescript_path = "plugins/react-sol-advisor/skills/typescript-backend-delivery/SKILL.md"
postgres_path = "plugins/react-sol-advisor/skills/postgres-data-delivery/SKILL.md"
worker_path = "plugins/react-sol-advisor/skills/worker-integration-delivery/SKILL.md"
profiles_path = "plugins/react-sol-advisor/skills/orchestration/references/delivery-profiles.md"
workflow_path = ".github/workflows/verify.yml"

manifest = json.loads(read(manifest_path))
marketplace = json.loads(read(marketplace_path))
readme = read(readme_path)
changelog = read(changelog_path)
skill = read(skill_path)
routing = read(routing_path)
roles = read(roles_path)
examples = read(examples_path)
packet = read(packet_path)
production = read(production_path)
react = read(react_path)
typescript = read(typescript_path)
postgres = read(postgres_path)
worker = read(worker_path)
profiles = read(profiles_path)
workflow = read(workflow_path)

# 1-3. Product identity generalizes while the public technical namespace remains stable.
require(manifest.get("version") == "0.2.0", "plugin manifest version is 0.2.0")
require(
    manifest.get("interface", {}).get("displayName") == "Sol Development Advisor",
    "plugin display name is Sol Development Advisor",
)
require(
    marketplace.get("interface", {}).get("displayName") == "Sol Development Advisor",
    "marketplace display name is Sol Development Advisor",
)
plugins = marketplace.get("plugins", [])
marketplace_plugin = plugins[0] if len(plugins) == 1 and isinstance(plugins[0], dict) else {}
require(
    manifest.get("name") == "react-sol-advisor"
    and marketplace.get("name") == "react-sol-advisor"
    and marketplace_plugin.get("name") == "react-sol-advisor"
    and marketplace_plugin.get("source", {}).get("path") == "./plugins/react-sol-advisor",
    "technical plugin name and marketplace path remain react-sol-advisor",
)
require(
    "@react-sol-advisor" in readme
    and "react-sol-advisor@react-sol-advisor" in readme
    and marketplace_plugin.get("source", {}).get("path") == "./plugins/react-sol-advisor",
    "stable @react-sol-advisor technical invocation is documented",
)

# 4-8. Delivery profiles are actual skills, not summary prose in orchestration. The
# generic contract is mandatory for every implementation stream; specialists are added
# only by the canonical matrix below.
actual_profiles = {
    "production-delivery": production,
    "react-production-delivery": react,
    "typescript-backend-delivery": typescript,
    "postgres-data-delivery": postgres,
    "worker-integration-delivery": worker,
}
for relative in (production_path, react_path, typescript_path, postgres_path, worker_path, profiles_path):
    require((repo / relative).is_file(), f"actual delivery contract exists: {relative}")

route_sources = {
    "orchestration": skill,
    "routing": routing,
    "role contracts": roles,
    "invocation examples": examples,
}
for label, source in route_sources.items():
    require("DELIVERY PROFILES" in source, f"{label} uses DELIVERY PROFILES in authoritative route blocks")

# The generic production profile carries cross-domain engineering semantics, without
# absorbing framework, database-locking, or queue-lease specialist rules.
require(
    includes_all(
        production,
        "repository instructions", "actual", "versions", "observable acceptance",
        "canonical examples", "owned paths", "excluded paths", "dependency",
        "interface boundaries", "success", "failure", "retry", "timeout",
        "cancellation", "rollback", "security", "auth", "privacy", "secrets",
        "data integrity", "idempotency", "concurrency", "recovery",
        "error classification", "observability", "strict", "typed",
        "tests before implementation", "smallest coherent diff", "no cleanup",
        "architecture", "exact verification", "complete diff", "structured handoff",
        "ACCEPTANCE", "FILES", "TESTS", "VERIFICATION", "GIT", "JUDGMENT", "GAPS",
    ),
    "production-delivery contains the full mandatory generic delivery semantics",
)
require(
    bool(production)
    and not re.search(r"\b(useState|useEffect|accessibility|Postgres.{0,40}lock|queue.{0,40}lease)\b", production, flags=re.IGNORECASE),
    "production-delivery excludes React hooks/accessibility, Postgres locking, and queue lease rules",
)

require(
    includes_all(
        react,
        "production-delivery", "React", "Next.js", "React Native", "Expo", "UI",
        "state", "hooks", "effects", "accessibility", "rendering", "client/server",
        "native/JavaScript", "references/nextjs.md", "references/react-native-expo.md",
        "references/testing-accessibility.md",
    ),
    "react-production-delivery requires production-delivery and preserves React platform semantics and conditional references",
)
require(
    includes_all(
        typescript,
        "domain", "service", "repository", "dependency direction", "input", "output",
        "runtime validation", "exhaustive error", "timeout", "cancellation", "idempotency",
        "duplicate", "retry classification", "API", "event compatibility",
        "deterministic test seams", "logging", "tracing", "metrics", "correlation",
        "no swallowed errors", "strict TypeScript", "narrowed external data",
    ),
    "typescript-backend-delivery contains the required boundary, compatibility, retry, observability, and strict typing semantics",
)
require(
    includes_all(
        postgres,
        "authoritative ownership", "transaction boundaries", "constraints", "invariants", "unique",
        "advisory", "row locks", "concurrency", "isolation", "schema", "migration risk",
        "expand", "migrate", "contract", "idempotent migration", "backfill", "rollback",
        "forward repair", "index", "query plan", "RLS", "tenant isolation",
        "deterministic DB tests", "no destructive operation", "explicit authorization", "proof",
    ),
    "postgres-data-delivery contains the required ownership, lock, migration, tenant, and destructive-operation semantics",
)
require(
    includes_all(
        worker,
        "admission", "dedup", "job ownership", "leasing", "heartbeat", "expiry",
        "at-least-once", "idempotent", "reentrant", "retry", "backoff", "poison",
        "timeout", "cancel", "crash", "restart", "provider request state machine", "terminal",
        "out-of-order", "duplicate", "late", "orphan", "reconciliation", "race-safe transitions",
        "metrics", "alerts", "diagnostics", "deterministic fake provider", "clock", "queue tests",
        "external side-effect boundary",
    ),
    "worker-integration-delivery contains the required admission, lifecycle, provider, reconciliation, and deterministic-test semantics",
)

# Actual profile skills must not fork the canonical app-thread lifecycle or choose a
# model-routing lane. Ordinary Git state and the generic structured handoff are allowed.
for label, source in actual_profiles.items():
    require(
        bool(source)
        and not re.search(
            r"wait_threads|read_thread|list_threads|create_thread|send_message_to_thread|"
            r"threadId|hostId|set_thread_archived|PR AUTHORIZED|polling bounds|"
            r"luna-app-task|terra-native|sol-parent-only|decomposed-mixed|model-routing",
            source,
            flags=re.IGNORECASE,
        ),
        f"{label} contains no duplicated orchestration lifecycle or lane selection",
    )

require(
    includes_all(
        profiles,
        "production-delivery", "always", "owned path", "acceptance", "conditional",
        "combin", "absence of React", "TypeScript", "not auto-React", "provider",
        "worker", "database", "not green", "risk", "independent",
    ),
    "delivery-profiles.md is the canonical matrix: production always, conditional composable profiles, non-React allowed, and risk-independent selection",
)
representative_examples = {
    "pure deterministic TypeScript mapper": ("green", "Luna / Max", "production", "TypeScript backend"),
    "bounded REST handler following established pattern": ("green", "amber", "contract", "side effect"),
    "pg-boss admission plus ownership/orphan reconciliation": (
        "amber", "red", "schema", "consistency", "Terra", "irreducible core", "Luna",
        "independently green helpers", "fixtures", "tests", "docs",
    ),
    "schema migration": ("red", "Terra", "fresh Sol"),
    "React URL filter": ("green", "Luna", "production", "React"),
    "mixed React/backend": ("decomposed", "non-overlapping workstreams", "profiles per workstream"),
}
for example, terms in representative_examples.items():
    require(
        includes_all(profiles, example, *terms),
        f"delivery-profiles.md contains the representative {example} selection example",
    )
require(
    "pg-boss" in profiles.casefold() and not includes_all(profiles, "pg-boss", "rejected", "non-React"),
    "delivery-profiles.md does not reject pg-boss merely because it is non-React",
)

# Routing examples are executable policy, not a bag of vocabulary. Parse exact outcomes
# and reject both missing fields and contradictory claims attached to representative cases.
routing_truth = parse_routing_truth_table(profiles)
routing_truth_failures = routing_truth_errors(routing_truth)
require(
    not routing_truth_failures,
    "machine-readable routing/profile truth table has exact case-scoped outcomes"
    + (f": {'; '.join(routing_truth_failures)}" if routing_truth_failures else ""),
)
profile_contradictions = routing_contradictions(profiles)
require(
    not profile_contradictions,
    "delivery-profile prose contains no contradictory routing outcomes"
    + (f": {'; '.join(profile_contradictions)}" if profile_contradictions else ""),
)

# Mutation checks prove the oracle fails for associated outcomes rather than passing
# because expected words happen to occur elsewhere in the document.
if routing_truth:
    for case_id, field, contradictory_value in (
        ("pg-boss-ownership-reconciliation", "risk", "green"),
        ("critical-mechanical-luna", "fresh_sol_review_required", False),
        ("bounded-queue-lease-transition", "lane", "luna-app-task"),
    ):
        mutated = copy.deepcopy(routing_truth)
        for case in mutated.get("cases", []):
            if isinstance(case, dict) and case.get("id") == case_id:
                case[field] = contradictory_value
        require(
            bool(routing_truth_errors(mutated)),
            f"routing oracle rejects mutation {case_id}.{field}={contradictory_value!r}",
        )
    for sentence in (
        "pg-boss is classified green.",
        "The React profile is mandatory for backend TypeScript.",
        "Critical mechanical Luna does not require fresh Sol.",
        "A bounded queue lease transition is classified green.",
    ):
        require(
            bool(routing_contradictions(profiles + "\n" + sentence)),
            f"routing oracle rejects contradictory prose mutation: {sentence}",
        )

require(
    includes_all(skill, "No silent fallback", "explicit user authorization")
    and includes_all(routing, "No silent fallback", "explicit user authorization"),
    "no-silent-fallback remains explicit across authoritative routing contracts",
)

terra_prompt_match = re.search(
    r"## Terra / High - sole native implementation lane[\s\S]*?Prompt:\s*(?:```|~~~)text([\s\S]*?)(?:```|~~~)",
    roles,
)
terra_prompt = terra_prompt_match.group(1) if terra_prompt_match else ""
require(
    includes_all(
        roles,
        "Select conditional specialist profiles from the canonical",
        "parent includes its authoritative route decision",
    )
    and bool(re.search(
        r"Load only the parent-selected\s+profiles named in `?DELIVERY PROFILES`?;\s*do not select/change profiles,\s*architecture, or routing",
        terra_prompt,
        flags=re.IGNORECASE,
    ))
    and not re.search(r"Select and load|select(?:ion)? of .*profiles", terra_prompt, flags=re.IGNORECASE),
    "parent retains canonical profile selection while the Terra child prompt forbids profile-selection authority",
)

# Generalization must preserve the accepted economics rather than making any policy
# cheaper or collapsing the risk matrix into generic prose.
require(
    includes_all(
        routing,
        "Classify green only when", "all", "observable acceptance criteria",
        "established architecture", "canonical pattern", "State and data ownership are clear",
        "bounded file/module set", "Relevant tests", "local and reversible",
        "No unresolved product, architecture, data-consistency, or security decision",
        "No red trigger applies",
    ),
    "routing preserves the all-true green criteria: acceptance, canonical architecture, ownership, bounded scope, tests, reversible blast radius, no unresolved decision, and no red trigger",
)
require(
    includes_all(
        routing,
        "Non-local concurrency", "transaction/locking", "Async races", "cancellation",
        "stale responses", "Queues, retries, leases, reconciliation", "provider state machines",
        "Cross-package behavior", "broad reversible", "production bug whose cause is not localized",
        "React Server Component/client", "Hydration, streaming, Suspense", "caching, revalidation",
        "React Native", "accessibility focus", "Competing repository patterns",
    ),
    "routing preserves generalized and React-specific amber triggers",
)
require(
    includes_all(
        routing,
        "Authentication, authorization, security policy, secrets, or tenant isolation",
        "Database schema, migration, destructive data operation", "Public API, shared package contract",
        "Billing, financial calculations", "Irreversible operation", "Framework-wide upgrade",
        "Incident response with unclear root cause", "Unresolved consistency or ownership policy",
        "Native module", "New cross-application domain model", "conflicts with repository architecture or safety policy",
    ),
    "routing preserves generalized red triggers for security, data, contracts, irreversible work, incidents, native boundaries, and safety conflicts",
)
require(
    includes_all(
        routing,
        "| Green | Luna / Max app task; parent Sol verifies and accepts |",
        "| Amber | Sol decomposes into green Luna units", "| Red | Sol settles architecture; Terra / High implements; fresh Sol reviewer required |",
        "### Balanced", "| Green | Luna / Max app task |", "| Amber | Terra / High by default, or `decomposed-mixed` when extracted subparts independently satisfy every green criterion |",
        "| Red | Terra / High plus fresh Sol reviewer |", "### Critical",
        "| Green | Terra / High plus fresh Sol reviewer required", "purely mechanical Luna subtask; fresh Sol review still required",
        "| Amber | Terra / High plus fresh Sol reviewer required |",
        "| Red | Sol architecture, Terra / High implementation, mandatory fresh Sol reviewer |",
    ),
    "routing preserves the accepted economy, balanced, and critical green/amber/red mapping",
)
require(
    includes_all(
        routing,
        "**Red** work in any policy", "**Critical** work by definition",
        "**Amber** work in `balanced` or irreducible `economy` core", "consequential existing boundaries",
        "required after parent verification", "Routine green or non-consequential amber Terra work",
        "economy/balanced cost control", "critical task implemented wholly or partly",
    ),
    "fresh Sol review covers red, every critical task including Luna contributions, and consequential amber boundaries without lowering other review economics",
)

# 15. Native role identity and reviewer isolation are stable implementation interfaces.
agents_dir = repo / "plugins/react-sol-advisor/agents"
expected_roles = {
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
for filename, pins in expected_roles.items():
    path = agents_dir / filename
    try:
        role = tomllib.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, tomllib.TOMLDecodeError) as error:
        errors.append(f"native role is unreadable: {filename}: {error}")
        continue
    require(all(role.get(key) == value for key, value in pins.items()), f"{filename} preserves exact model/effort and sandbox pins")

# 19. New route decisions are profile-oriented. Existing historical reports may retain
# QUALITY CONTRACT wording, but migration guidance must explicitly call that compatible.
route_blocks = {skill_path: skill, roles_path: roles, examples_path: examples, readme_path: readme}
for relative, source in route_blocks.items():
    blocks = re.findall(r"ROUTING DECISION[\s\S]*?(?=\n```|\Z)", source)
    require(
        bool(blocks) and all("DELIVERY PROFILES:" in block and "QUALITY CONTRACT:" not in block for block in blocks),
        f"{relative} route decisions use DELIVERY PROFILES rather than QUALITY CONTRACT",
    )
require(
    includes_all(skill, "historical", "QUALITY CONTRACT", "compatib"),
    "historical QUALITY CONTRACT route blocks remain explicitly compatible",
)
for relative, source in route_sources.items():
    require("Sol Development Advisor" in source, f"{relative} agrees on the Sol Development Advisor product name")
require("## 0.2.0" in changelog and "Sol Development Advisor" in changelog, "changelog records the generalized 0.2.0 contract")

for relative, source in {
    skill_path: skill,
    routing_path: routing,
    roles_path: roles,
    packet_path: packet,
}.items():
    require(
        "delivery-profiles.md" in source,
        f"{relative} references canonical delivery-profiles.md selection authority",
    )

# 20. CI executes both new acceptance seams.
require(
    "sh plugins/react-sol-advisor/scripts/verify-generalization.sh" in workflow
    and "sh plugins/react-sol-advisor/scripts/verify-agent-upgrade.sh" in workflow,
    "CI runs both 0.2.0 acceptance verifiers",
)

# The fork must not use the generalization work as a vehicle to mutate the upstream
# sol-advisor payload. Fresh clones may not have origin/main, so evidence is conditional.
origin_main = subprocess.run(
    ["git", "show-ref", "--verify", "--quiet", "refs/remotes/origin/main"],
    cwd=repo,
    check=False,
).returncode == 0
if origin_main:
    changed = subprocess.run(
        ["git", "diff", "--name-only", "origin/main...HEAD", "--", "plugins/sol-advisor"],
        cwd=repo,
        check=False,
        text=True,
        capture_output=True,
    ).stdout.strip()
    require(not changed, "no tracked plugins/sol-advisor file changed relative to origin/main")
else:
    print("PASS: origin/main unavailable; upstream sol-advisor diff evidence is not applicable")

if errors:
    print(f"GENERALIZATION ACCEPTANCE FAILED: {len(errors)} requirement(s)", file=sys.stderr)
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("GENERALIZATION ACCEPTANCE PASSED")
PY
