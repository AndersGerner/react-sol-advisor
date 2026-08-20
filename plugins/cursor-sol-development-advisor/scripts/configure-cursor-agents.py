#!/usr/bin/env python3
"""Safely configure exact Cursor-native model IDs for the 0.3.1 agent roles."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path


VERSION = "0.3.1"
RECEIPT = ".sol-development-advisor-models.json"
ROLE_FILES = {
    "composer": "sol-advisor-composer-routine.md",
    "luna": "sol-advisor-luna-specialist.md",
    "grok": "sol-advisor-grok-high-complexity.md",
}
MODEL_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*(?:\[[^\]\n]*\])?$")


class ConfigurationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ConfigurationError(message)


def lstat(path: Path):
    try:
        return path.lstat()
    except FileNotFoundError:
        return None


def assert_safe_directory_path(path: Path, label: str, allow_missing_leaf: bool = True) -> Path:
    absolute = Path(os.path.normpath(str(path.expanduser().absolute())))
    # macOS exposes /var and /tmp as stable system aliases. Normalize only those
    # aliases; arbitrary user-created symlink components remain a hard refusal below.
    for alias in ("/var", "/tmp"):
        if str(absolute) == alias or str(absolute).startswith(alias + os.path.sep):
            physical_alias = os.path.realpath(alias)
            absolute = Path(physical_alias + str(absolute)[len(alias) :])
            break
    if str(absolute) == os.path.sep or str(absolute).startswith(os.path.sep * 2):
        fail(f"{label} resolves to an unsafe filesystem root")
    current = Path(absolute.anchor)
    parts = absolute.parts[1:]
    for index, part in enumerate(parts):
        current /= part
        state = lstat(current)
        if state is None:
            if not allow_missing_leaf or index != len(parts) - 1:
                continue
            break
        if os.path.islink(current):
            fail(f"{label} contains a symlink path component: {current}")
        if index < len(parts) - 1 and not current.is_dir():
            fail(f"{label} contains a non-directory ancestor: {current}")
    return absolute


def assert_target_directory(path: Path, label: str) -> None:
    state = lstat(path)
    if state is not None and (os.path.islink(path) or not path.is_dir()):
        fail(f"{label} must be a real directory: {path}")


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read JSON configuration {path}: {error}")
    if not isinstance(value, dict):
        fail(f"JSON configuration must be an object: {path}")
    return value


def exact_models(path: Path) -> dict[str, str]:
    value = read_json(path)
    if set(value) != set(ROLE_FILES):
        fail("model configuration must contain exactly composer, luna, and grok")
    result: dict[str, str] = {}
    for role in ROLE_FILES:
        model = value.get(role)
        if not isinstance(model, str) or not model or not MODEL_PATTERN.fullmatch(model):
            fail(f"{role} must be a non-empty exact Cursor model identifier")
        result[role] = model
    return result


def optional_observed(path: Path | None, requested: dict[str, str]) -> dict[str, str | None]:
    observed: dict[str, str | None] = {role: None for role in ROLE_FILES}
    if path is None:
        return observed
    value = read_json(path)
    if set(value) != set(ROLE_FILES):
        fail("observed model evidence must contain exactly composer, luna, and grok")
    for role in ROLE_FILES:
        model = value.get(role)
        if model is not None and (not isinstance(model, str) or not model or not MODEL_PATTERN.fullmatch(model)):
            fail(f"observed {role} must be an exact Cursor model identifier or null")
        observed[role] = model
    return observed


def workspace_value(workspace: str | None) -> str | None:
    if workspace is None:
        return None
    path = assert_safe_directory_path(Path(workspace), "workspace")
    assert_target_directory(path, "workspace")
    if not path.is_dir():
        fail(f"workspace must be an existing directory: {path}")
    return str(path.resolve())


def target_for(scope: str, workspace: str | None, user_home: str | None) -> tuple[Path, str | None]:
    resolved_workspace = workspace_value(workspace)
    if scope == "project":
        if resolved_workspace is None:
            fail("project scope requires --workspace")
        target = Path(resolved_workspace) / ".cursor" / "agents"
    else:
        home = Path(user_home).expanduser() if user_home else Path.home()
        home = assert_safe_directory_path(home, "user home")
        if not home.is_dir():
            fail(f"user home must be an existing directory: {home}")
        target = home / ".cursor" / "agents"
    target = assert_safe_directory_path(target, "Cursor agents target")
    assert_target_directory(target, "Cursor agents target")
    return target, resolved_workspace


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def managed_state(target: Path, scope: str, workspace: str | None) -> dict | None:
    receipt_path = target / RECEIPT
    managed = [target / name for name in ROLE_FILES.values()]
    existing_managed = [path for path in managed if lstat(path) is not None]
    receipt_exists = lstat(receipt_path) is not None
    if receipt_exists:
        if os.path.islink(receipt_path) or not receipt_path.is_file():
            fail(f"managed receipt is unsafe: {receipt_path}")
        receipt = read_json(receipt_path)
        expected = {
            "schema", "version", "scope", "workspace", "managed_files",
            "requested_models", "observed_models", "reload_required",
        }
        if set(receipt) != expected or receipt.get("schema") != 1 or receipt.get("version") != VERSION:
            fail("managed receipt has an unknown schema or version")
        if receipt.get("scope") != scope or receipt.get("workspace") != workspace:
            fail("managed receipt belongs to another scope or workspace")
        files = receipt.get("managed_files")
        if not isinstance(files, dict) or set(files) != set(ROLE_FILES.values()):
            fail("managed receipt does not enumerate the exact managed agent files")
        for name in ROLE_FILES.values():
            path = target / name
            if lstat(path) is None or os.path.islink(path) or not path.is_file():
                fail(f"managed file is missing or unsafe: {path}")
            if files.get(name) != digest(path):
                fail(f"managed file changed; refusing to overwrite: {path}")
        return receipt
    if existing_managed:
        fail("managed agent exists without a receipt; refusing to overwrite unknown modifications")
    return None


def render_agent(role: str, model: str) -> str:
    common = {
        "composer": (
            "sol-advisor-composer-routine",
            "Composer routine worker for bounded green Sol Development Advisor tasks.",
            "Read the shared Sol Development Advisor core. Implement only the exact owned scope, apply the selected profiles, run deterministic verification, and stop on ambiguity or newly revealed risk. Do not choose architecture, publish, merge, or deploy.\n",
        ),
        "luna": (
            "sol-advisor-luna-specialist",
            "Luna specialist worker and reviewer for React, type, async, and integration slices.",
            "Read the shared core and inspect only the exact selected slice. Report concrete review findings and before/after state for consequential reviews. The requested read-only setting is not runtime isolation evidence. Do not choose a fallback, publish, merge, or deploy.\n",
        ),
        "grok": (
            "sol-advisor-grok-high-complexity",
            "Grok high-complexity worker and advisor for backend, data, worker, and integration boundaries.",
            "Read the shared core and parent route. Own only the declared high-complexity slice, run deterministic checks, surface newly revealed risk, and return requested versus observed model evidence. Do not choose profiles, publish, merge, or deploy.\n",
        ),
    }
    name, description, body = common[role]
    readonly = "readonly: true\n" if role == "luna" else ""
    return f"---\nname: {name}\ndescription: {description}\nmodel: {model}\n{readonly}---\n{body}"


def plan_for(args: argparse.Namespace, target: Path, workspace: str | None, requested: dict | None, observed: dict | None, action: str) -> dict:
    return {
        "action": action,
        "scope": args.scope,
        "workspace": workspace,
        "target": str(target),
        "requested_models": requested,
        "observed_models": observed,
    }


def confirmation_token(plan: dict) -> str:
    encoded = json.dumps(plan, sort_keys=True, separators=(",", ":")).encode()
    return "confirm-" + hashlib.sha256(encoded).hexdigest()[:16]


def print_plan(plan: dict, token: str) -> None:
    print(json.dumps({"plan": plan, "confirmation_token": token}, sort_keys=True, indent=2))
    print(f"CONFIRMATION_TOKEN={token}")


def atomic_write(path: Path, content: str, mode: int = 0o644) -> None:
    if lstat(path) is not None and (os.path.islink(path) or not path.is_file()):
        fail(f"managed destination is unsafe: {path}")
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def write_receipt(target: Path, scope: str, workspace: str | None, requested: dict[str, str], observed: dict[str, str | None]) -> None:
    receipt = {
        "schema": 1,
        "version": VERSION,
        "scope": scope,
        "workspace": workspace,
        "managed_files": {name: digest(target / name) for name in ROLE_FILES.values()},
        "requested_models": requested,
        "observed_models": observed,
        "reload_required": True,
    }
    atomic_write(target / RECEIPT, json.dumps(receipt, sort_keys=True, indent=2) + "\n", 0o600)


def configure(args: argparse.Namespace, target: Path, workspace: str | None) -> None:
    requested = exact_models(Path(args.config))
    observed = optional_observed(Path(args.observed_models) if args.observed_models else None, requested)
    existing = managed_state(target, args.scope, workspace) if target.exists() else None
    action = "update" if existing else "install"
    plan = plan_for(args, target, workspace, requested, observed, action)
    token = confirmation_token(plan)
    if args.confirm is None:
        print_plan(plan, token)
        return
    if args.confirm != token:
        print_plan(plan, token)
        raise ConfigurationError("confirmation token does not match the preview")

    target.mkdir(parents=True, exist_ok=True)
    assert_target_directory(target, "Cursor agents target")
    originals: dict[Path, bytes | None] = {}
    paths = [target / name for name in ROLE_FILES.values()] + [target / RECEIPT]
    for path in paths:
        if lstat(path) is not None:
            if os.path.islink(path) or not path.is_file():
                fail(f"managed path is unsafe: {path}")
            originals[path] = path.read_bytes()
        else:
            originals[path] = None
    try:
        for role, name in ROLE_FILES.items():
            atomic_write(target / name, render_agent(role, requested[role]))
        write_receipt(target, args.scope, workspace, requested, observed)
    except Exception:
        for path, content in originals.items():
            if content is None:
                if lstat(path) is not None and path.is_file() and not os.path.islink(path):
                    path.unlink()
            else:
                atomic_write(path, content.decode())
        raise
    print(json.dumps({"ok": True, "action": action, "target": str(target), "reload_required": True}, indent=2))
    print("Reload Cursor (Developer: Reload Window) before relying on the updated agents.")


def uninstall(args: argparse.Namespace, target: Path, workspace: str | None) -> None:
    receipt = managed_state(target, args.scope, workspace)
    if receipt is None:
        fail("no managed Sol Development Advisor agent set exists")
    plan = plan_for(args, target, workspace, receipt["requested_models"], receipt["observed_models"], "uninstall")
    token = confirmation_token(plan)
    if args.confirm is None:
        print_plan(plan, token)
        return
    if args.confirm != token:
        print_plan(plan, token)
        raise ConfigurationError("confirmation token does not match the preview")
    for name in ROLE_FILES.values():
        (target / name).unlink()
    (target / RECEIPT).unlink()
    print(json.dumps({"ok": True, "action": "uninstall", "target": str(target), "reload_required": True}, indent=2))
    print("Reload Cursor (Developer: Reload Window) before relying on the updated agents.")


def report(args: argparse.Namespace, target: Path, workspace: str | None) -> None:
    receipt = managed_state(target, args.scope, workspace)
    if receipt is None:
        fail("no managed Sol Development Advisor agent set exists")
    print(json.dumps({
        "version": receipt["version"],
        "scope": receipt["scope"],
        "workspace": receipt["workspace"],
        "model_evidence": {
            role: {"requested": receipt["requested_models"][role], "observed": receipt["observed_models"].get(role)}
            for role in ROLE_FILES
        },
        "reload_required": receipt["reload_required"],
    }, sort_keys=True, indent=2))


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--scope", choices=("project", "user"), required=True)
    value.add_argument("--workspace")
    value.add_argument("--user-home", help=argparse.SUPPRESS)
    value.add_argument("--config")
    value.add_argument("--observed-models")
    value.add_argument("--confirm")
    value.add_argument("--uninstall", action="store_true")
    value.add_argument("--report", action="store_true")
    return value


def main() -> int:
    try:
        args = parser().parse_args()
        if args.report and (args.uninstall or args.config or args.confirm or args.observed_models):
            fail("--report cannot be combined with configuration or mutation flags")
        if args.uninstall and args.config:
            fail("--uninstall does not accept --config")
        if not args.report and not args.uninstall and not args.config:
            fail("configuration requires --config")
        target, workspace = target_for(args.scope, args.workspace, args.user_home)
        if args.report:
            report(args, target, workspace)
        elif args.uninstall:
            uninstall(args, target, workspace)
        else:
            configure(args, target, workspace)
        return 0
    except (ConfigurationError, OSError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
