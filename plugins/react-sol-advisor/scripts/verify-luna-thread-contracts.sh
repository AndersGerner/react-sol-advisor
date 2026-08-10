#!/bin/sh
# Semantic contract checks for capability-adaptive Luna task monitoring.

set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1

python3 - "$repo_dir" <<'PY'
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def passed(message: str) -> None:
    print(f"PASS: {message}")


def read(relative: str) -> str:
    path = repo / relative
    if not path.is_file():
        fail(f"missing required contract file: {relative}")
    return path.read_text(encoding="utf-8")


def normalize(value: str) -> str:
    value = value.replace("`", "")
    value = re.sub(r"\s+", " ", value)
    return value.strip().lower()


def has_all(value: str, *terms: str) -> bool:
    normalized = normalize(value)
    return all(normalize(term) in normalized for term in terms)


def between(value: str, start_marker: str, end_marker: str) -> str:
    start = value.find(start_marker)
    if start < 0:
        return ""
    end = value.find(end_marker, start + len(start_marker))
    if end < 0:
        return ""
    return value[start:end]


def require(message: str, condition: bool) -> None:
    if not condition:
        fail(message)
    passed(message)


skill_path = "plugins/react-sol-advisor/skills/orchestration/SKILL.md"
lane_path = "plugins/react-sol-advisor/skills/orchestration/references/luna-task-lane.md"
roles_path = "plugins/react-sol-advisor/skills/orchestration/references/role-contracts.md"
lifecycle_path = "plugins/react-sol-advisor/skills/orchestration/references/thread-lifecycle.md"
readme_path = "README.md"
changelog_path = "CHANGELOG.md"
build_path = "BUILD-PROGRESS.md"
manifest_path = "plugins/react-sol-advisor/.codex-plugin/plugin.json"
workflow_path = ".github/workflows/verify.yml"
verify_path = "plugins/react-sol-advisor/scripts/verify.sh"
contracts_path = "plugins/react-sol-advisor/scripts/verify-contracts.sh"
invocations_path = "plugins/react-sol-advisor/examples/invocations.md"
packet_path = "plugins/react-sol-advisor/examples/luna-task-packet.md"
profiles_path = "plugins/react-sol-advisor/skills/orchestration/references/delivery-profiles.md"
evidence_path = "docs/acceptance/2026-08-08-luna-read-thread-fallback.md"

skill = read(skill_path)
lane = read(lane_path)
roles = read(roles_path)
lifecycle = read(lifecycle_path)
readme = read(readme_path)
changelog = read(changelog_path)
build = read(build_path)
manifest = json.loads(read(manifest_path))
workflow = read(workflow_path)
verify = read(verify_path)
contracts = read(contracts_path)
invocations = read(invocations_path)
packet = read(packet_path)
profiles = read(profiles_path)

# 1. wait_threads is preferred when usable, not a hard dependency.
require(
    "wait_threads is preferred rather than mandatory",
    has_all(lane, "Preferred monitoring mode", "wait_threads", "preferred", "not mandatory")
    and has_all(skill, "wait_threads", "preferred", "not mandatory"),
)

# 2. The fallback exists only behind the proven five-tool capability gate.
fallback_tools = (
    "list_projects",
    "list_threads",
    "create_thread",
    "read_thread",
    "send_message_to_thread",
)
require(
    "exact-thread read_thread fallback is gated by all five proven operations",
    has_all(lane, "Supported exact-thread fallback", "wait_threads is absent", *fallback_tools)
    and has_all(lane, "only when", "all", *fallback_tools),
)

# 3. list_threads stops being a completion monitor once the real identity is known.
require(
    "list_threads is bounded identity discovery only",
    has_all(lane, "list_threads", "identity discovery only", "post-identity", "completion monitoring")
    and bool(re.search(r"list_threads.{0,260}(must not|never).{0,180}(completion|monitor)", normalize(lane))),
)

# 4-7. Success is latest-turn based and permits active/completed.
require(
    "success requires exact identity, latest completed turn, and readable handoff",
    has_all(
        lane,
        "Exact success condition",
        "exact real threadId",
        "hostId",
        "latest turn.status",
        "completed",
        "readable final assistant handoff",
    ),
)
require(
    "success does not require thread idle",
    has_all(lane, "thread.status.type", "idle", "not required"),
)
require(
    "active/completed is accepted when turn and handoff gates pass",
    has_all(lane, "active / completed", "accepted", "latest turn", "readable handoff"),
)

# 8-9. Idle alone and notLoaded are non-success.
require(
    "idle without a newly completed latest turn is non-success",
    has_all(lane, "idle", "without", "newly completed", "latest turn", "non-success"),
)
require(
    "notLoaded is not completion evidence",
    has_all(lane, "notLoaded", "not completion evidence"),
)

# 10. Polling is bounded by count, cadence, and usable elapsed-time evidence.
require(
    "exact-thread polling has concrete fail-closed bounds",
    has_all(
        lane,
        "Maximum 60 exact-thread reads per turn",
        "At least 2 seconds",
        "elapsed time",
        "bounded",
        "polling exhaustion",
        "fails closed",
        "no background callback",
    ),
)

# Additional failure semantics required by the lifecycle contract.
require(
    "terminal failures stop immediately and unknown states stay within the bound",
    has_all(
        lane,
        "explicit failure",
        "cancellation",
        "attention required",
        "stops immediately",
        "unknown",
        "within the polling bound",
        "tool error",
        "polling timeout",
    ),
)
require(
    "incidental child signals never prove completion",
    has_all(
        lane,
        "file appearance",
        "title",
        "preview",
        "elapsed time",
        "child-authored claims",
        "never prove completion",
    ),
)

# 11-12. Corrections are same-identity and require a different completed turn.
require(
    "corrections reuse the same real thread host and child worktree",
    has_all(lane, "same real threadId", "same hostId", "same child worktree"),
)
require(
    "corrections require a different newly completed turn and updated handoff",
    has_all(
        lane,
        "previous completed turn ID",
        "different",
        "newly completed turn ID",
        "updated handoff",
        "invalidates the earlier handoff",
    ),
)

# 13. Parent inspection and parent-run verification remain acceptance gates.
require(
    "parent worktree diff and verification remain mandatory",
    has_all(
        lane,
        "actual child worktree",
        "branch/base",
        "complete diff",
        "verification",
        "commit state",
        "PR state",
        "parent-run verification passes",
    ),
)

# 14. Missing exact project registration fails closed with manual guidance.
require(
    "missing exact project identity fails closed with manual registration guidance",
    has_all(
        lane,
        "list_projects",
        "exact current project",
        "add or open the folder as a project in the Codex app",
        "start a fresh task in that project",
        "do not invent a project ID",
        "do not attempt Computer Use",
        "do not fall back to another repository or local environment",
    ),
)

# Review hardening: creation-time data, project schema, and correction routing.
initial_starting_state = between(packet, "STARTING STATE / BASE", "VERIFICATION")
parent_lifecycle_record = between(
    packet,
    "## Parent-owned lifecycle record",
    "## Same-thread correction message",
)
require(
    "initial child packet is phase-separated from the parent lifecycle record",
    has_all(
        lane,
        "Pre-creation Luna child packet",
        "Parent-owned lifecycle record",
        "not sent in the initial create_thread prompt",
        "existing identity belongs in the correction message",
    )
    and has_all(
        initial_starting_state,
        "Project ID",
        "projectKind",
        "supportsWorktrees",
        "Requested environment",
        "Base",
        "Prior accepted stack",
    )
    and not any(
        normalize(forbidden) in normalize(initial_starting_state)
        for forbidden in (
            "Real threadId",
            "HostId",
            "Child worktree",
            "Latest completed turn ID",
            "Monitoring mode",
        )
    )
    and has_all(
        parent_lifecycle_record,
        "Real threadId",
        "HostId",
        "Child worktree",
        "Monitoring mode",
        "Latest completed turn ID",
    ),
)

require(
    "project environment selection uses the observed projectKind/supportsWorktrees schema",
    has_all(
        lane,
        "actual returned schema",
        "projectKind",
        "supportsWorktrees",
        "isGitRepository",
        "absent",
        "independently confirm",
        '{type: "worktree"}',
        "only when",
        "fail closed",
    )
    and has_all(
        skill,
        "projectKind",
        "supportsWorktrees",
        "isGitRepository",
        "absent",
        '{type: "worktree"}',
        "fail closed",
    )
    and has_all(
        roles,
        "projectKind",
        "supportsWorktrees",
        "isGitRepository",
        "not exposed",
        '{type: "worktree"}',
        "fail closed",
    )
    and "isgitrepository" not in normalize(packet),
)

for relative, value in ((lane_path, lane), (skill_path, skill), (roles_path, roles)):
    require(
        f"{relative} pins Luna Max on every correction call",
        has_all(
            value,
            "every correction call",
            "send_message_to_thread",
            "model",
            "gpt-5.6-luna",
            "thinking",
            "max",
            "returned routing metadata",
        ),
    )
require(
    "correction example reasserts Luna Max routing on the same identity",
    has_all(
        invocations,
        "correction call",
        "same real threadId",
        "same hostId",
        "model",
        "gpt-5.6-luna",
        "thinking",
        "max",
        "returned routing metadata",
    ),
)

# Review hardening: real identity permits the first exact read to discover the worktree.
real_identity_contract = between(
    lane,
    "## 6. Real thread identity",
    "## 7. Completion monitoring and handoff",
)
lifecycle_record_contract = between(
    lane,
    "## 5. Parent-owned lifecycle record",
    "## 6. Real thread identity",
)
require(
    "first exact read may discover and pin the child worktree",
    has_all(
        real_identity_contract,
        "real threadId",
        "hostId",
        "before the first",
        "wait_threads",
        "read_thread",
    )
    and has_all(
        real_identity_contract,
        "child worktree",
        "unresolved",
        "first exact read",
        "populate",
    )
    and has_all(
        real_identity_contract,
        "subsequent exact read",
        "same child worktree",
    )
    and has_all(
        real_identity_contract,
        "before correction",
        "acceptance",
        "PR authorization",
        "dependent-task creation",
    )
    and has_all(
        lifecycle_record_contract,
        "CHILD WORKTREE",
        "unresolved",
        "first exact read",
    )
    and has_all(
        skill,
        "threadId",
        "hostId",
        "first exact read",
        "child worktree",
        "unresolved",
        "same worktree",
    )
    and has_all(
        roles,
        "threadId",
        "hostId",
        "first exact read",
        "child worktree",
        "unresolved",
    )
    and has_all(
        packet,
        "CHILD WORKTREE",
        "unresolved",
        "first exact read",
    )
    and not has_all(
        real_identity_contract,
        "threadId",
        "hostId",
        "child worktree before waiting, reading",
    ),
)

# 15. Archive correctness requires explicit returned archived=true and remains optional.
require(
    "archive success requires exact identity and explicit returned archived true",
    has_all(
        lifecycle,
        "optional for correctness",
        "set_thread_archived",
        "exact real threadId",
        "hostId",
        "archived = true",
        "explicit returned",
        "notLoaded",
        "not proof",
        "never retroactively proves task completion",
        "THREADS_READY_TO_ARCHIVE",
    ),
)

# Authoritative summaries and user-facing examples must agree with the canonical lane.
for relative, value in ((skill_path, skill), (roles_path, roles)):
    require(
        f"{relative} describes capability-adaptive monitoring",
        has_all(
            value,
            "wait_threads",
            "preferred",
            "read_thread",
            "fallback",
            "latest turn",
            "completed",
            "readable final assistant handoff",
        ),
    )
    require(
        f"{relative} preserves same-identity correction semantics",
        has_all(value, "same real threadId", "same hostId", "newly completed turn ID"),
    )

require(
    "README documents preferred and fallback monitoring",
    has_all(readme, "wait_threads", "preferred", "exact-thread", "read_thread", "fallback"),
)
require(
    "invocation examples include fail-closed exact-thread fallback behavior",
    has_all(invocations, "wait_threads", "absent", "read_thread", "same real threadId", "new completed turn ID"),
)
require(
    "Luna example separates pre-creation fields from parent lifecycle evidence",
    has_all(
        packet,
        "Example pre-creation Luna child packet",
        "Parent-owned lifecycle record",
        "not sent in the initial child prompt",
        "Real threadId",
        "HostId",
        "Child worktree",
        "Latest completed turn ID",
    ),
)

# Delivery selection is generic and packet-specific. The mandatory core applies to every
# Luna implementation packet; specialist profiles are selected by owned paths and
# acceptance, so a non-React packet cannot be rejected for lacking a React slice.
require(
    "Luna packets require generic production delivery with conditional profiles, not mandatory React",
    has_all(
        lane,
        "production-delivery",
        "selected profiles",
        "owned paths",
        "acceptance",
        "absence of React never blocks non-React work",
    )
    and has_all(
        packet,
        "production-delivery",
        "delivery-profiles.md",
        "selected",
        "absence of React",
    )
    and has_all(
        profiles,
        "production-delivery",
        "always",
        "TypeScript is not auto-React",
    ),
)

# Release and CI integration.
require("plugin manifest version is 0.2.0", manifest.get("version") == "0.2.0")
require(
    "repository verifier asserts version 0.2.0",
    has_all(verify, "manifest version is not 0.2.0", "= '0.2.0'"),
)
require(
    "general contract verifier asserts version 0.2.0 while retaining the 0.1.1 record and focused gate",
    has_all(contracts, "0.2.0", "0.1.1", "verify-luna-thread-contracts.sh"),
)
require(
    "changelog records the 0.1.1 exact-thread compatibility release",
    has_all(changelog, "## 0.1.1 - 2026-08-08", "exact-thread", "read_thread"),
)
require(
    "build ledger records supported exact-thread fallback",
    has_all(build, "EXACT_THREAD_POLLING_FALLBACK: SUPPORTED", "red-green"),
)
require(
    "GitHub Actions runs the focused Luna thread contract verifier",
    "sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh" in workflow,
)

# Live evidence is allowlisted and complete.
evidence = read(evidence_path)
for required_value in (
    "/Users/andersgerner/Development/react-sol-advisor-luna-probe",
    "c2xpbmdzaG90OmVudl9lXzZhMDY2MWM2ZjFlNDgzMzFhMTRjMzQ4MzUzNmY0NTQ1Ci9Vc2Vycy9hbmRlcnNnZXJuZXIvRGV2ZWxvcG1lbnQvcmVhY3Qtc29sLWFkdmlzb3ItbHVuYS1wcm9iZQ==",
    "slingshot:env_e_6a0661c6f1e48331a14c3483536f4545",
    "019fe2f5-2307-7942-9876-89d25b47e847",
    "019fe2f5-2684-7402-9305-4372ce4e12cd",
    "019fe2f7-1c3f-7860-bae9-b1cdfd9bb5f9",
    "51cb1b6c4e5e3d84ea10e65a7fdd1b6eda15cd3b",
    "EXACT_THREAD_POLLING_FALLBACK: SUPPORTED",
):
    require(f"live evidence records {required_value}", required_value in evidence)
require(
    "live evidence records schema routing transitions worktree correction and archive result",
    has_all(
        evidence,
        "projectKind",
        "supportsWorktrees",
        "isGitRepository",
        "not exposed",
        '{type: "worktree"}',
        "model = gpt-5.6-luna",
        "thinking = max",
        "active / inProgress",
        "idle / completed",
        "active / completed",
        "readable",
        "byte-exact",
        "same-thread",
        "archived = true",
        "notLoaded / completed",
        "not used as completion evidence",
    ),
)

# 16. Native roles and their installer/runtime-inspector subsystem remain byte-identical.
protected_hashes = {
    "plugins/react-sol-advisor/agents/react-sol-advisor-terra-implementer.toml": "31ccc37af13e7a578436ec000d1867eaa0b638f8a1960e8261cc31a9fb77c9c8",
    "plugins/react-sol-advisor/agents/react-sol-advisor-sol-reviewer.toml": "968f44ec684abe3b89f2ef6c974d0d1a259043c32022caced93df8e553fa0788",
    "plugins/react-sol-advisor/scripts/install-agents.sh": "23938e775e2c7a160c797034522286bbbf15d50350e3d70aa57114a0a18f3ce4",
    "plugins/react-sol-advisor/scripts/inspect-agent-runtime.sh": "a186adfe471afa6b98000c6f5cd00185a6fdeb6abd575e32ddfd02a85b5d65a5",
}
for relative, expected in protected_hashes.items():
    path = repo / relative
    if not path.is_file():
        fail(f"protected native subsystem file is missing: {relative}")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    require(f"protected native subsystem file is unchanged: {relative}", actual == expected)

print("LUNA THREAD CONTRACTS PASSED")
PY
