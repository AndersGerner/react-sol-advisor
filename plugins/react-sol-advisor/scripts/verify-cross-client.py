#!/usr/bin/env python3
"""Deterministic 0.3.1 cross-client and non-React acceptance oracle."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PLUGIN = ROOT / "plugins" / "react-sol-advisor"
CURSOR = ROOT / "plugins" / "cursor-sol-development-advisor"
CASES = PLUGIN / "scripts" / "fixtures" / "cross-client" / "cases.json"


class VerificationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise VerificationError(message)


def require_file(path: Path) -> None:
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {path.relative_to(ROOT)}")


def load_json(path: Path) -> dict:
    require_file(path)
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        fail(f"JSON object required: {path.relative_to(ROOT)}")
    return value


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    require_file(path)
    text = path.read_text()
    if not text.startswith("---\n"):
        fail(f"Cursor component has no YAML frontmatter: {path.relative_to(ROOT)}")
    end = text.find("\n---\n", 4)
    if end < 0:
        fail(f"Cursor component frontmatter is unterminated: {path.relative_to(ROOT)}")
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if not line.strip():
            continue
        key, separator, value = line.partition(":")
        if not separator or not key.strip() or not value.strip():
            fail(f"invalid Cursor frontmatter line in {path.relative_to(ROOT)}: {line}")
        fields[key.strip()] = value.strip()
    return fields, text[end + len("\n---\n") :]


def assert_equal(label: str, actual: object, expected: object) -> None:
    if actual != expected:
        fail(f"{label}: expected {expected!r}, got {actual!r}")


def expected_route(case: dict, client: str) -> dict:
    expected = dict(case["expected"])
    expected["client"] = client
    return expected


def evaluate(case: dict, client: str, invocation: str) -> dict:
    owned = case["owned_paths"]
    acceptance = case["acceptance"]
    react_files = case["react_files"]
    if not owned or not acceptance:
        fail(f"fixture {case['id']} has no owned code or acceptance criteria")

    profiles = ["production-delivery"]
    if react_files:
        profiles.append("react-production-delivery")
    if any(path.endswith(".ts") and path not in react_files for path in owned):
        if "typescript-backend-delivery" not in profiles:
            profiles.append("typescript-backend-delivery")
    if case["id"] == "fle-1007-like-backend-data-worker":
        profiles = [
            "production-delivery",
            "typescript-backend-delivery",
            "postgres-data-delivery",
            "worker-integration-delivery",
        ]
    if case["id"] == "fle-1007-like-schema-migration":
        profiles = ["production-delivery", "postgres-data-delivery"]

    if case["id"] in {"pure-typescript-provider-error-classifier", "real-react-green", "legacy-name-alias"}:
        risk = "green"
        codex_mode = "codex-luna-detached"
        cursor_mode = "cursor-composer"
    elif case["id"] == "mixed-react-backend":
        risk = "green"
        codex_mode = cursor_mode = "decomposed-mixed"
    elif case["id"] == "fle-1007-like-backend-data-worker":
        risk = "amber"
        codex_mode = "decomposed-mixed"
        cursor_mode = "cursor-grok"
    elif case["id"] == "fle-1007-like-schema-migration":
        risk = "red"
        codex_mode = "codex-terra-native"
        cursor_mode = "cursor-grok"
    else:
        fail(f"oracle has no route implementation for {case['id']}")

    result = {
        "client": client,
        "invocation": invocation,
        "eligible": True,
        "risk": risk,
        "profiles": profiles,
        "codex_mode": codex_mode,
        "cursor_mode": cursor_mode,
        "confirmation_required": False,
        "blocked_reasons": [],
    }
    if case["id"] == "fle-1007-like-schema-migration":
        result["fresh_sol_review_required"] = True
    return result


def verify_fixtures() -> None:
    document = load_json(CASES)
    assert_equal("fixture schema", document.get("schema"), 1)
    cases = document.get("cases")
    if not isinstance(cases, list) or len(cases) != 6:
        fail("cross-client fixture set must contain six semantic cases")
    by_id = {case.get("id"): case for case in cases}
    assert_equal("fixture IDs", sorted(by_id), sorted([
        "fle-1007-like-backend-data-worker",
        "fle-1007-like-schema-migration",
        "legacy-name-alias",
        "mixed-react-backend",
        "pure-typescript-provider-error-classifier",
        "real-react-green",
    ]))

    for case in cases:
        expected = case["expected"]
        if not case["react_files"]:
            result = evaluate(case, "codex", "Sol Development Advisor")
            assert_equal(f"{case['id']} non-React eligibility", result["eligible"], True)
            assert_equal(f"{case['id']} non-React confirmation", result["confirmation_required"], False)
            assert_equal(f"{case['id']} non-React blocked", result["blocked_reasons"], [])
        for client in ("codex", "cursor"):
            invocation = "React Sol Advisor" if case["id"] == "legacy-name-alias" else "Sol Development Advisor"
            result = evaluate(case, client, invocation)
            for field in ("eligible", "risk", "profiles", "confirmation_required", "blocked_reasons"):
                assert_equal(f"{case['id']} {client} {field}", result[field], expected[field])
            route_field = "codex_mode" if client == "codex" else "cursor_mode"
            assert_equal(f"{case['id']} {client} route", result[route_field], expected[route_field])
            if "fresh_sol_review_required" in expected:
                assert_equal(
                    f"{case['id']} {client} fresh review",
                    result.get("fresh_sol_review_required"),
                    expected["fresh_sol_review_required"],
                )

    alias = by_id["legacy-name-alias"]
    generic = evaluate(alias, "codex", "Sol Development Advisor")
    legacy = evaluate(alias, "codex", "React Sol Advisor")
    generic.pop("invocation")
    legacy.pop("invocation")
    assert_equal("legacy product names are semantic aliases", legacy, generic)


def verify_manifests_and_core() -> None:
    codex_manifest = load_json(PLUGIN / ".codex-plugin" / "plugin.json")
    assert_equal("Codex manifest name", codex_manifest.get("name"), "react-sol-advisor")
    assert_equal("Codex manifest version", codex_manifest.get("version"), "0.3.1")
    assert_equal("Codex display name", codex_manifest.get("interface", {}).get("displayName"), "Sol Development Advisor")

    cursor_manifest = load_json(CURSOR / ".cursor-plugin" / "plugin.json")
    assert_equal("Cursor manifest name", cursor_manifest.get("name"), "sol-development-advisor")
    assert_equal("Cursor manifest version", cursor_manifest.get("version"), "0.3.1")
    if cursor_manifest.get("displayName") != "Sol Development Advisor":
        fail("Cursor manifest displayName is not the generic product name")
    for field, path in (("skills", "./skills/"), ("agents", "./agents/"), ("commands", "./commands/"), ("rules", "./rules/")):
        assert_equal(f"Cursor manifest {field}", cursor_manifest.get(field), path)
    if any(key not in {
        "$schema", "name", "displayName", "description", "version", "author", "homepage",
        "repository", "license", "keywords", "category", "tags", "minClientVersions", "commands",
        "agents", "skills", "rules", "hooks", "variables", "mcpServers", "logo", "publisher",
    } for key in cursor_manifest):
        fail("Cursor manifest contains a field outside the current official schema")

    canonical = PLUGIN / "skills" / "orchestration" / "references" / "shared-core.md"
    generated = CURSOR / "skills" / "sol-development-advisor-core" / "SKILL.md"
    require_file(canonical)
    require_file(generated)
    if canonical.read_bytes() != generated.read_bytes():
        fail("Cursor shared core is not the generated byte-identical canonical core")
    digest = hashlib.sha256(canonical.read_bytes()).hexdigest()
    receipt = ROOT / "docs" / "shared-core.sha256"
    require_file(receipt)
    if receipt.read_text().strip() != digest:
        fail("shared-core.sha256 does not match the canonical core")


def verify_adapters_and_agents() -> None:
    codex_adapter = PLUGIN / "skills" / "orchestration" / "references" / "codex-adapter.md"
    cursor_adapter = PLUGIN / "skills" / "orchestration" / "references" / "cursor-adapter.md"
    for path in (codex_adapter, cursor_adapter):
        require_file(path)
        text = path.read_text()
        for required in ("requested", "observed", "ADVISOR ROUTE", "production-delivery", "React Sol Advisor"):
            if required not in text:
                fail(f"{path.relative_to(ROOT)} omits adapter contract term: {required}")

    role_files = {
        "composer": CURSOR / "agents" / "sol-advisor-composer-routine.md",
        "luna": CURSOR / "agents" / "sol-advisor-luna-specialist.md",
        "grok": CURSOR / "agents" / "sol-advisor-grok-high-complexity.md",
    }
    for role, path in role_files.items():
        fields, body = parse_frontmatter(path)
        assert_equal(f"Cursor {role} agent name", fields.get("name"), path.stem)
        if fields.get("model") != "inherit":
            fail(f"bundled Cursor {role} agent must use inherit until exact user IDs are configured")
        if "model" not in body and role != "composer":
            fail(f"Cursor {role} agent does not explain model evidence")
    luna_fields, luna_body = parse_frontmatter(role_files["luna"])
    assert_equal("Cursor Luna requested read-only field", luna_fields.get("readonly"), "true")
    for forbidden in ("proves enforced isolation", "guarantees isolation"):
        if forbidden in luna_body.lower():
            fail("Cursor Luna role overclaims read-only isolation")

    for path in (CURSOR / "commands" / "sol-advisor-route.md", CURSOR / "rules" / "sol-advisor-routing.mdc"):
        require_file(path)
    cursor_skill = CURSOR / "skills" / "sol-development-advisor" / "SKILL.md"
    fields, body = parse_frontmatter(cursor_skill)
    assert_equal("Cursor skill name", fields.get("name"), "sol-development-advisor")
    for required in ("Composer", "Luna", "Grok", "requested", "observed", "CLI support is not claimed"):
        if required.lower() not in body.lower():
            fail(f"Cursor skill omits required client rule: {required}")


def verify_forbidden_authoritative_claims() -> None:
    excluded = {"CHANGELOG.md", "UPSTREAM.md", "BUILD-PROGRESS.md"}
    authoritative: list[Path] = []
    for root in (PLUGIN, CURSOR, ROOT / "docs"):
        if not root.exists():
            continue
        authoritative.extend(path for path in root.rglob("*") if path.is_file() and not path.is_symlink())
    forbidden = [
        re.compile(r"React\s+is\s+required", re.I),
        re.compile(r"non[- ]React.{0,80}(confirmation|blocked|ineligible)", re.I | re.S),
        re.compile(r"React\s+profile.{0,80}(mandatory|required).{0,80}(backend|worker|data|typescript)", re.I | re.S),
        re.compile(r"legacy.{0,40}(selects|forces).{0,40}React", re.I | re.S),
    ]
    for path in authoritative:
        if path.name == "verify-cross-client.py" or (path.parent.name == "scripts" and path.name.startswith("verify-")):
            continue
        if path.relative_to(ROOT).parts[0] == "docs" and path.name in excluded:
            continue
        text = path.read_text(errors="replace")
        for pattern in forbidden:
            if pattern.search(text):
                fail(f"authoritative file contains obsolete React-only claim: {path.relative_to(ROOT)}")


def verify_upstream_ledger() -> None:
    ledger = ROOT / "docs" / "upstream-adoption.md"
    require_file(ledger)
    text = ledger.read_text()
    for commit in (
        "37b75cad535abdd46531f0227483a8842d045ab8",
        "550ab1f71ae360c4adc733e572357bded7f70e5d",
        "6f54e9fc43ddd385cd6c99f66caba5d852524aed",
        "ec15017c986118a5c077f347499a5e3920e1f163",
        "91e2999ae6862f376317e9a0a5954ac72c5e0dfd",
    ):
        if commit not in text:
            fail(f"upstream adoption ledger omits {commit}")
    for word in ("adopted", "adapted", "rejected", "pending", "verification"):
        if word not in text.lower():
            fail(f"upstream adoption ledger omits status vocabulary: {word}")
    require_file(ROOT / "scripts" / "report-upstream.sh")
    if "git fetch" not in (ROOT / "scripts" / "report-upstream.sh").read_text():
        fail("upstream report does not inspect fetched history")


def main() -> int:
    try:
        verify_fixtures()
        verify_manifests_and_core()
        verify_adapters_and_agents()
        verify_forbidden_authoritative_claims()
        verify_upstream_ledger()
    except (OSError, json.JSONDecodeError, VerificationError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("CROSS-CLIENT ACCEPTANCE PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
