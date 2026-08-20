#!/usr/bin/env python3
"""Deterministic acceptance for the Codex three-role adapter and runtime evidence."""

from __future__ import annotations

import json
import os
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - CI and supported local runtimes are 3.11+
    tomllib = None


ROOT = Path(__file__).resolve().parents[3]
PLUGIN = ROOT / "plugins" / "react-sol-advisor"
AGENTS = PLUGIN / "agents"
INSTALLER = PLUGIN / "scripts" / "install-agents.sh"
INSPECTOR = PLUGIN / "scripts" / "inspect-agent-runtime.sh"
FIXTURES = PLUGIN / "scripts" / "fixtures" / "native-roles-0.1.1"
LUNA_STALE_FIXTURE = PLUGIN / "scripts" / "fixtures" / "native-roles-0.3.0" / "react-sol-advisor-luna-implementer.toml"
ROLE_FILES = {
    "luna": "react-sol-advisor-luna-implementer.toml",
    "terra": "react-sol-advisor-terra-implementer.toml",
    "sol": "react-sol-advisor-sol-reviewer.toml",
}


def run(*args: str, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, text=True, capture_output=True, env=env)
    if check and result.returncode != 0:
        raise AssertionError(f"command failed: {' '.join(args)}\n{result.stderr}")
    return result


def snapshot(path: Path) -> dict[str, object] | None:
    if not path.exists():
        return None
    result: dict[str, object] = {}
    for child in sorted(path.iterdir(), key=lambda item: item.name):
        if child.is_symlink():
            result[child.name] = ("symlink", os.readlink(child))
        elif child.is_dir():
            result[child.name] = ("directory",)
        else:
            result[child.name] = ("file", child.read_bytes())
    return result


def main() -> int:
    try:
        if tomllib is None:
            raise AssertionError("Python tomllib is required for structured TOML verification")
        role_pins = {
            "luna": {"model": "gpt-5.6-luna", "effort": "max", "service_tier": "fast"},
            "terra": {"model": "gpt-5.6-terra", "effort": "high"},
            "sol": {"model": "gpt-5.6-sol", "effort": "high"},
        }
        for role, filename in ROLE_FILES.items():
            path = AGENTS / filename
            if path.is_symlink() or not path.is_file():
                raise AssertionError(f"missing managed role: {path}")
            data = tomllib.loads(path.read_text())
            if data.get("name") != f"react_sol_advisor_{role}_implementer" and role != "sol":
                raise AssertionError(f"wrong native role name for {role}")
            if role == "sol" and data.get("name") != "react_sol_advisor_sol_reviewer":
                raise AssertionError("wrong native Sol reviewer role name")
            expected_pin = role_pins[role]
            actual_pin = {
                "model": data.get("model"),
                "effort": data.get("model_reasoning_effort"),
            }
            if "service_tier" in expected_pin:
                actual_pin["service_tier"] = data.get("service_tier")
            elif "service_tier" in data:
                raise AssertionError(f"unexpected service-tier pin for tier-agnostic role {role}")
            if actual_pin != expected_pin:
                raise AssertionError(f"wrong native routing pin for {role}")
        codex_adapter = (PLUGIN / "skills" / "orchestration" / "references" / "codex-adapter.md").read_text()
        for term in ("codex-luna-detached", "codex-luna-native", "requested_service_tier", "observed_service_tier", "LUNA FAST MODE: blocked"):
            if term not in codex_adapter:
                raise AssertionError(f"Codex adapter omits {term}")

        with tempfile.TemporaryDirectory(prefix="sol-advisor-codex-test-") as raw:
            # Exercise a symlinked TMPDIR while keeping installer targets
            # physically resolved.  The installer must retain its symlink-path
            # refusal; tests must not accidentally turn portability into a
            # symlink-acceptance exception.
            root = Path(raw).resolve()
            clean = root / "clean"
            run("sh", str(INSTALLER), "--target-dir", str(clean))
            for filename in ROLE_FILES.values():
                if not (clean / filename).is_file():
                    raise AssertionError(f"clean install omitted {filename}")
            run("sh", str(INSTALLER), "--target-dir", str(clean), "--check")
            before_idempotent = snapshot(clean)
            run("sh", str(INSTALLER), "--target-dir", str(clean))
            if snapshot(clean) != before_idempotent:
                raise AssertionError("re-running a current install changed managed state")

            codex_home = root / "codex-home"
            run("sh", str(INSTALLER), env={**os.environ, "CODEX_HOME": str(codex_home)})
            if not (codex_home / "agents" / ROLE_FILES["luna"]).is_file():
                raise AssertionError("CODEX_HOME fallback did not install native Luna")

            missing_check = root / "missing-check"
            missing_result = run("sh", str(INSTALLER), "--target-dir", str(missing_check), "--check", check=False)
            if missing_result.returncode == 0 or missing_check.exists():
                raise AssertionError("--check created or accepted a missing target")

            default_stale = root / "default-stale"
            default_stale.mkdir()
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                shutil.copyfile(FIXTURES / filename, default_stale / filename)
            stale_before = snapshot(default_stale)
            default_result = run("sh", str(INSTALLER), "--target-dir", str(default_stale), check=False)
            if default_result.returncode == 0 or snapshot(default_stale) != stale_before:
                raise AssertionError("default installation replaced a known-stale role pair")

            stale_check = run("sh", str(INSTALLER), "--target-dir", str(default_stale), "--check", check=False)
            if stale_check.returncode == 0 or "known stale 0.1.1" not in stale_check.stderr:
                raise AssertionError("--check did not identify the known-stale role pair")

            coexistence = root / "coexistence"
            coexistence.mkdir()
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                shutil.copyfile(AGENTS / filename, coexistence / filename)
            upstream_sentinels = {
                "sol-advisor-terra-implementer.toml": b"upstream Terra sentinel\n",
                "sol-advisor-sol-reviewer.toml": b"upstream Sol sentinel\n",
            }
            for filename, content in upstream_sentinels.items():
                (coexistence / filename).write_bytes(content)
            run("sh", str(INSTALLER), "--target-dir", str(coexistence))
            for filename, content in upstream_sentinels.items():
                if (coexistence / filename).read_bytes() != content:
                    raise AssertionError(f"installer changed unrelated upstream sentinel: {filename}")

            symlink_file = root / "symlink-file"
            symlink_file.mkdir()
            symlink_file.joinpath("react-sol-advisor-terra-implementer.toml").symlink_to(AGENTS / ROLE_FILES["terra"])
            symlink_result = run("sh", str(INSTALLER), "--target-dir", str(symlink_file), check=False)
            if symlink_result.returncode == 0 or not symlink_file.joinpath("react-sol-advisor-terra-implementer.toml").is_symlink():
                raise AssertionError("installer accepted or replaced a managed symlink")

            symlink_parent = root / "symlink-parent"
            symlink_outside = root / "symlink-outside"
            symlink_parent.mkdir()
            symlink_outside.mkdir()
            symlink_parent.joinpath("linked").symlink_to(symlink_outside, target_is_directory=True)
            ancestor_result = run("sh", str(INSTALLER), "--target-dir", str(symlink_parent / "linked" / "agents"), check=False)
            if ancestor_result.returncode == 0 or (symlink_outside / "agents").exists():
                raise AssertionError("installer accepted or mutated a target below a symlinked ancestor")

            conflict = root / "conflict"
            conflict.mkdir()
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                shutil.copyfile(AGENTS / filename, conflict / filename)
            conflict_terra = conflict / ROLE_FILES["terra"]
            conflict_terra.write_bytes(conflict_terra.read_bytes() + b"local modification\n")
            conflict_before = conflict_terra.read_bytes()
            conflict_result = run("sh", str(INSTALLER), "--target-dir", str(conflict), check=False)
            if conflict_result.returncode == 0 or conflict_terra.read_bytes() != conflict_before:
                raise AssertionError("installer replaced a locally modified managed role")

            traversal = run("sh", str(INSTALLER), "--target-dir", "/nonexistent/a/../../..", check=False)
            if traversal.returncode == 0:
                raise AssertionError("installer accepted lexical traversal to the filesystem root")

            stale = root / "stale"
            stale.mkdir()
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                (stale / filename).write_bytes((FIXTURES / filename).read_bytes())
            (stale / "sol-advisor-terra-implementer.toml").write_text("upstream sentinel\n")
            (stale / "sol-advisor-sol-reviewer.toml").write_text("upstream sentinel\n")
            run("sh", str(INSTALLER), "--target-dir", str(stale), "--upgrade-known")
            run("sh", str(INSTALLER), "--target-dir", str(stale), "--check")
            if (stale / "sol-advisor-terra-implementer.toml").read_text() != "upstream sentinel\n":
                raise AssertionError("upgrade mutated an upstream companion sentinel")
            if (stale / ROLE_FILES["luna"]).read_text() != (AGENTS / ROLE_FILES["luna"]).read_text():
                raise AssertionError("upgrade did not install exact native Luna")

            luna_stale = root / "luna-stale"
            luna_stale.mkdir()
            for role in ("terra", "sol"):
                (luna_stale / ROLE_FILES[role]).write_bytes((AGENTS / ROLE_FILES[role]).read_bytes())
            (luna_stale / ROLE_FILES["luna"]).write_bytes(LUNA_STALE_FIXTURE.read_bytes())
            luna_stale_check = run("sh", str(INSTALLER), "--target-dir", str(luna_stale), "--check", check=False)
            if luna_stale_check.returncode == 0 or "known stale 0.3.0" not in luna_stale_check.stderr:
                raise AssertionError("--check did not identify the known-stale 0.3.0 Luna role")
            run("sh", str(INSTALLER), "--target-dir", str(luna_stale), "--upgrade-known")
            run("sh", str(INSTALLER), "--target-dir", str(luna_stale), "--check")
            if (luna_stale / ROLE_FILES["luna"]).read_bytes() != (AGENTS / ROLE_FILES["luna"]).read_bytes():
                raise AssertionError("known-stale 0.3.0 Luna upgrade did not install the exact current role")

            failed = root / "failed"
            failed.mkdir()
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                (failed / filename).write_bytes((FIXTURES / filename).read_bytes())
            failed_result = run(
                "sh", str(INSTALLER), "--target-dir", str(failed), "--upgrade-known",
                env={**os.environ, "RSA_INSTALL_TEST_FAIL_ROLE": "sol"}, check=False,
            )
            if failed_result.returncode == 0:
                raise AssertionError("forced three-role upgrade failure was accepted")
            for filename in ("react-sol-advisor-terra-implementer.toml", "react-sol-advisor-sol-reviewer.toml"):
                if (failed / filename).read_bytes() != (FIXTURES / filename).read_bytes():
                    raise AssertionError(f"failed upgrade did not restore {filename}")
            if (failed / ROLE_FILES["luna"]).exists():
                raise AssertionError("failed upgrade left a native Luna role")
            if any(path.name.startswith(".react-sol-advisor-upgrade") for path in failed.iterdir()):
                raise AssertionError("failed upgrade left a public transaction artifact")

            failed_luna = root / "failed-luna"
            failed_luna.mkdir()
            for role in ("terra", "sol"):
                (failed_luna / ROLE_FILES[role]).write_bytes((AGENTS / ROLE_FILES[role]).read_bytes())
            (failed_luna / ROLE_FILES["luna"]).write_bytes(LUNA_STALE_FIXTURE.read_bytes())
            failed_luna_result = run(
                "sh", str(INSTALLER), "--target-dir", str(failed_luna), "--upgrade-known",
                env={**os.environ, "RSA_INSTALL_TEST_FAIL_ROLE": "luna"}, check=False,
            )
            if failed_luna_result.returncode == 0:
                raise AssertionError("forced native Luna replacement failure was accepted")
            if (failed_luna / ROLE_FILES["luna"]).read_bytes() != LUNA_STALE_FIXTURE.read_bytes():
                raise AssertionError("failed native Luna replacement did not restore the known-stale role")
            if any(path.name.startswith(".react-sol-advisor-upgrade") for path in failed_luna.iterdir()):
                raise AssertionError("failed native Luna replacement left a public transaction artifact")

            interrupted = root / "interrupted"
            ready = root / "interrupted.ready"
            process = subprocess.Popen(
                ["sh", str(INSTALLER), "--target-dir", str(interrupted)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={
                    **os.environ,
                    "RSA_INSTALL_TEST_PAUSE_ROLE": "luna",
                    "RSA_INSTALL_TEST_READY": str(ready),
                },
            )
            deadline = time.monotonic() + 5
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            if not ready.exists():
                process.kill()
                process.communicate(timeout=5)
                raise AssertionError("signal rollback fixture did not reach its guarded pause")
            os.kill(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            if process.returncode == 0:
                raise AssertionError("SIGTERM during install was accepted")
            if interrupted.exists():
                public = {path.name for path in interrupted.iterdir()}
                if public & set(ROLE_FILES.values()) or any(name.startswith(".react-sol-advisor-upgrade") for name in public):
                    raise AssertionError(f"signal rollback left public installer state: {public}")
                if public:
                    raise AssertionError(f"signal rollback left unexpected target state: {public}")

            session = root / "sessions"
            session.mkdir()
            thread_id = str(uuid.uuid4())
            rollout = session / f"rollout-test-{thread_id}.jsonl"
            records = [
                {"type": "session_meta", "payload": {"id": thread_id, "agent_role": "react_sol_advisor_luna_implementer", "model_provider": "openai"}},
                {"type": "turn_context", "payload": {"model": "gpt-5.6-luna", "effort": "max", "sandbox_policy": {"type": "workspace-write"}, "permission_profile": {"type": "default"}, "cwd": str(root), "serviceTier": "priority", "requestedServiceTier": "priority"}},
            ]
            rollout.write_text("\n".join(json.dumps(record) for record in records) + "\n")
            observed = run("sh", str(INSPECTOR), "--sessions-dir", str(session), thread_id)
            evidence = json.loads(observed.stdout)
            if evidence["agent_role"] != "react_sol_advisor_luna_implementer" or evidence["model"] != "gpt-5.6-luna" or evidence["effort"] != "max":
                raise AssertionError("native Luna runtime evidence did not validate exact role/model/effort")
            if evidence["observed_service_tier"] != "priority" or evidence["requested_service_tier"] != "priority":
                raise AssertionError("native Luna service-tier evidence was not reported separately")

            fast_tier = root / "fast-tier"
            fast_tier.mkdir()
            fast_rollout = fast_tier / f"rollout-test-{thread_id}.jsonl"
            fast_rollout.write_text("\n".join(json.dumps(record) for record in records[:-1] + [{"type": "turn_context", "payload": {"model": "gpt-5.6-luna", "effort": "max", "sandbox_policy": {"type": "workspace-write"}, "permission_profile": {"type": "default"}, "cwd": str(root), "serviceTier": "fast", "requestedServiceTier": "fast"}}]) + "\n")
            fast_evidence = json.loads(run("sh", str(INSPECTOR), "--sessions-dir", str(fast_tier), thread_id).stdout)
            if fast_evidence["observed_service_tier"] != "fast" or fast_evidence["requested_service_tier"] != "fast":
                raise AssertionError("native Luna Fast alias was not accepted as observed service-tier evidence")

            no_tier = root / "no-tier"
            no_tier.mkdir()
            no_tier_rollout = no_tier / f"rollout-test-{thread_id}.jsonl"
            no_tier_rollout.write_text("\n".join(json.dumps(record) for record in records[:-1] + [{"type": "turn_context", "payload": {"model": "gpt-5.6-luna", "effort": "max", "sandbox_policy": {"type": "workspace-write"}, "permission_profile": {"type": "default"}, "cwd": str(root)}}]) + "\n")
            no_tier_result = run("sh", str(INSPECTOR), "--sessions-dir", str(no_tier), thread_id, check=False)
            if no_tier_result.returncode == 0:
                raise AssertionError("missing native service-tier metadata was accepted")

            invalid_tier = root / "invalid-tier"
            invalid_tier.mkdir()
            invalid_rollout = invalid_tier / f"rollout-test-{thread_id}.jsonl"
            invalid_rollout.write_text("\n".join(json.dumps(record) for record in records[:-1] + [{"type": "turn_context", "payload": {"model": "gpt-5.6-luna", "effort": "max", "sandbox_policy": {"type": "workspace-write"}, "permission_profile": {"type": "default"}, "cwd": str(root), "serviceTier": "default", "requestedServiceTier": "default"}}]) + "\n")
            invalid_result = run("sh", str(INSPECTOR), "--sessions-dir", str(invalid_tier), thread_id, check=False)
            if invalid_result.returncode == 0:
                raise AssertionError("unsupported native Luna service-tier metadata was accepted")
        print("CODEX ADAPTER ACCEPTANCE PASSED")
        return 0
    except (AssertionError, OSError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
