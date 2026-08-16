#!/usr/bin/env python3
"""TDD acceptance tests for Cursor's exact-ID configuration flow."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONFIGURER = ROOT / "plugins" / "cursor-sol-development-advisor" / "scripts" / "configure-cursor-agents.py"


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run([sys.executable, str(CONFIGURER), *args], text=True, capture_output=True)
    if check and result.returncode != 0:
        raise AssertionError(f"command failed: {result.stderr.strip()}")
    return result


def main() -> int:
    try:
        if not CONFIGURER.is_file():
            raise AssertionError(f"missing Cursor configuration flow: {CONFIGURER}")
        with tempfile.TemporaryDirectory(prefix="sol-advisor-cursor-test-") as raw:
            root = Path(raw)
            workspace = root / "workspace"
            workspace.mkdir()
            config = root / "models.json"
            observed = root / "observed.json"
            config.write_text(json.dumps({
                "composer": "composer-2.5",
                "luna": "gpt-5.6-luna-max",
                "grok": "cursor-grok-4.5-high",
            }))
            observed.write_text(json.dumps({
                "composer": "composer-2.5",
                "luna": "gpt-5.6-luna-max",
                "grok": "cursor-grok-4.5-high",
            }))
            preview = run("--scope", "project", "--workspace", str(workspace), "--config", str(config), "--observed-models", str(observed))
            token_line = next(line for line in preview.stdout.splitlines() if line.startswith("CONFIRMATION_TOKEN="))
            token = token_line.split("=", 1)[1]
            agents = workspace / ".cursor" / "agents"
            if agents.exists():
                raise AssertionError("preview created Cursor agents")
            run(
                "--scope", "project", "--workspace", str(workspace), "--config", str(config),
                "--observed-models", str(observed), "--confirm", token,
            )
            names = {
                "sol-advisor-composer-routine.md": "composer-2.5",
                "sol-advisor-luna-specialist.md": "gpt-5.6-luna-max",
                "sol-advisor-grok-high-complexity.md": "cursor-grok-4.5-high",
            }
            for name, model in names.items():
                text = (agents / name).read_text()
                if f"model: {model}" not in text:
                    raise AssertionError(f"requested model was not written exactly for {name}")
            if "readonly: true" not in (agents / "sol-advisor-luna-specialist.md").read_text():
                raise AssertionError("Luna reviewer did not request read-only behavior")
            report = run("--scope", "project", "--workspace", str(workspace), "--report")
            report_json = json.loads(report.stdout)
            if report_json["model_evidence"]["luna"]["observed"] != "gpt-5.6-luna-max":
                raise AssertionError("observed model evidence was not recorded separately")

            user_home = root / "user-home"
            user_home.mkdir()
            user_preview = run(
                "--scope", "user", "--user-home", str(user_home), "--config", str(config),
                "--observed-models", str(observed),
            )
            user_token = next(line.split("=", 1)[1] for line in user_preview.stdout.splitlines() if line.startswith("CONFIRMATION_TOKEN="))
            run(
                "--scope", "user", "--user-home", str(user_home), "--config", str(config),
                "--observed-models", str(observed), "--confirm", user_token,
            )
            user_agents = user_home / ".cursor" / "agents"
            if not (user_agents / "sol-advisor-luna-specialist.md").is_file():
                raise AssertionError("user-scope Cursor agent was not installed")
            user_report = json.loads(run("--scope", "user", "--user-home", str(user_home), "--report").stdout)
            if user_report["scope"] != "user" or user_report["model_evidence"]["grok"]["requested"] != "cursor-grok-4.5-high":
                raise AssertionError("user-scope requested model evidence was not reported")

            workspace_link = root / "workspace-link"
            workspace_link.symlink_to(workspace, target_is_directory=True)
            refused_link = run(
                "--scope", "project", "--workspace", str(workspace_link), "--config", str(config), check=False,
            )
            if refused_link.returncode == 0 or "symlink path component" not in refused_link.stderr:
                raise AssertionError("Cursor project configuration accepted a symlinked workspace")

            tampered = agents / "sol-advisor-composer-routine.md"
            tampered.write_text(tampered.read_text() + "tampered\n")
            changed_config = root / "changed.json"
            changed_config.write_text(json.dumps({
                "composer": "user-configured-composer",
                "luna": "user-configured-luna",
                "grok": "user-configured-grok",
            }))
            changed_preview = run(
                "--scope", "project", "--workspace", str(workspace), "--config", str(changed_config),
                check=False,
            )
            if changed_preview.returncode == 0 or "managed file changed" not in changed_preview.stderr:
                raise AssertionError("unknown managed modification was not refused")

            unrelated = agents / "unrelated.md"
            unrelated.write_text("leave me\n")
            clean = tempfile.TemporaryDirectory(prefix="sol-advisor-cursor-uninstall-")
            try:
                clean_workspace = Path(clean.name) / "workspace"
                clean_workspace.mkdir()
                clean_config = Path(clean.name) / "models.json"
                clean_config.write_text(config.read_text())
                first = run("--scope", "project", "--workspace", str(clean_workspace), "--config", str(clean_config))
                clean_token = next(line.split("=", 1)[1] for line in first.stdout.splitlines() if line.startswith("CONFIRMATION_TOKEN="))
                run("--scope", "project", "--workspace", str(clean_workspace), "--config", str(clean_config), "--confirm", clean_token)
                clean_agents = clean_workspace / ".cursor" / "agents"
                (clean_agents / "unrelated.md").write_text("leave me\n")
                remove_preview = run("--scope", "project", "--workspace", str(clean_workspace), "--uninstall")
                remove_token = next(line.split("=", 1)[1] for line in remove_preview.stdout.splitlines() if line.startswith("CONFIRMATION_TOKEN="))
                run("--scope", "project", "--workspace", str(clean_workspace), "--uninstall", "--confirm", remove_token)
                if (clean_agents / "unrelated.md").read_text() != "leave me\n":
                    raise AssertionError("uninstall removed an unrelated Cursor agent")
            finally:
                clean.cleanup()
        print("CURSOR AGENT CONFIGURATION ACCEPTANCE PASSED")
        return 0
    except (AssertionError, OSError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
