#!/usr/bin/env python3
"""Install the three namespaced Codex companion roles with guarded transactions."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import signal
import sys
import tempfile
import time
from pathlib import Path


KNOWN_STALE_DIGESTS = {
    # The current 0.3.0 Luna role predates the native Fast pin.
    "luna": {
        "0.3.0": "fa3772a4a392e39261db337c167c512f159d35b5ac592223884aed2e744a4daf",
    },
    "terra": {
        "0.1.1": "8cd2ed825f58574fd578832dd35f7932d365214db91ab84f79af7a64d3c863b1",
    },
    "sol": {
        "0.1.1": "cf96fa0b638d879b072b896748e985ded79e68f2814e9eeab8b9c8c841776241",
    },
}
ROLES = (
    ("luna", "react-sol-advisor-luna-implementer.toml"),
    ("terra", "react-sol-advisor-terra-implementer.toml"),
    ("sol", "react-sol-advisor-sol-reviewer.toml"),
)


class InstallerError(RuntimeError):
    pass


class InstallerInterrupted(InstallerError):
    pass


def fail(message: str) -> None:
    raise InstallerError(message)


def lstat(path: Path):
    try:
        return path.lstat()
    except FileNotFoundError:
        return None


def physical_alias(path: Path) -> Path:
    value = str(path)
    for alias in ("/var", "/tmp"):
        if value == alias or value.startswith(alias + os.path.sep):
            return Path(os.path.realpath(alias) + value[len(alias) :])
    return path


def safe_path(path: Path, label: str) -> Path:
    absolute = Path(os.path.normpath(str(physical_alias(path.expanduser().absolute()))))
    if str(absolute) == os.path.sep or str(absolute).startswith(os.path.sep * 2):
        fail(f"{label} resolves to the filesystem root or an ambiguous namespace")
    current = Path(absolute.anchor)
    parts = absolute.parts[1:]
    for index, part in enumerate(parts):
        current /= part
        info = lstat(current)
        if info is None:
            continue
        if os.path.islink(current):
            fail(f"{label} contains a symlink path component: {current}")
        if index < len(parts) - 1 and not current.is_dir():
            fail(f"{label} contains a non-directory ancestor: {current}")
    return absolute


def assert_directory(path: Path, label: str, allow_missing: bool = True) -> None:
    info = lstat(path)
    if info is None:
        if not allow_missing:
            fail(f"{label} is unavailable: {path}")
        return
    if os.path.islink(path) or not path.is_dir():
        fail(f"{label} is not a real directory: {path}")


def digest(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return ""


def exact_file(path: Path, expected: str) -> bool:
    info = lstat(path)
    return bool(info and not os.path.islink(path) and path.is_file() and digest(path) == expected)


def templates() -> dict[str, tuple[str, Path]]:
    root = Path(__file__).resolve().parent.parent / "agents"
    result: dict[str, tuple[str, Path]] = {}
    for role, filename in ROLES:
        path = root / filename
        info = lstat(path)
        if not info or os.path.islink(path) or not path.is_file():
            fail(f"shipped template is missing or unsafe: {path}")
        result[role] = (filename, path)
    return result


def classify(path: Path, template: Path, role: str) -> str:
    info = lstat(path)
    if info is None:
        return "missing"
    if os.path.islink(path) or not path.is_file():
        return "unsafe"
    if path.read_bytes() == template.read_bytes():
        return "current"
    for version, expected in KNOWN_STALE_DIGESTS.get(role, {}).items():
        if digest(path) == expected:
            return f"known-stale-{version}"
    return "conflict"


def stale_digest(role: str, state: str) -> str:
    version = state.removeprefix("known-stale-")
    expected = KNOWN_STALE_DIGESTS.get(role, {}).get(version)
    if expected is None:
        fail(f"no guarded digest is registered for {role} state {state}")
    return expected


def target_from(args: argparse.Namespace) -> Path:
    if args.target_dir:
        target = Path(args.target_dir)
    elif os.environ.get("CODEX_HOME"):
        target = Path(os.environ["CODEX_HOME"]) / "agents"
    elif os.environ.get("HOME"):
        target = Path(os.environ["HOME"]) / ".codex" / "agents"
    else:
        fail("HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly")
    target = safe_path(target, "target directory")
    assert_directory(target, "target directory")
    return target


def preflight(target: Path, templates_by_role: dict[str, tuple[str, Path]]) -> dict[str, str]:
    return {
        role: classify(target / filename, template, role)
        for role, (filename, template) in templates_by_role.items()
    }


class Transaction:
    def __init__(self, target: Path, templates_by_role: dict[str, tuple[str, Path]], initial: dict[str, str], upgrade: bool):
        self.target = target
        self.templates = templates_by_role
        self.initial = initial
        self.upgrade = upgrade
        self.created_target = False
        self.transaction: Path | None = None
        self.lock: Path | None = None
        self.stages: dict[str, Path] = {}
        self.displaced: dict[str, Path] = {}
        self.backups: dict[str, Path] = {}
        self.published_new: list[str] = []
        self.published_replace: list[str] = []
        self.committed = False
        self.previous_signal_handlers: dict[int, object] = {}
        self.preserve_transaction = False

    def install_signal_handlers(self) -> None:
        self.previous_signal_handlers = {
            sig: signal.getsignal(sig)
            for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)
        }

        def interrupted(signum: int, _frame: object) -> None:
            raise InstallerInterrupted(f"installation interrupted by signal {signum}")

        for sig in self.previous_signal_handlers:
            signal.signal(sig, interrupted)

    def restore_signal_handlers(self) -> None:
        for sig, handler in self.previous_signal_handlers.items():
            signal.signal(sig, handler)

    def prepare(self) -> None:
        assert_directory(self.target, "target directory")
        if lstat(self.target) is None:
            self.target.mkdir(parents=True, mode=0o700)
            self.created_target = True
        assert_directory(self.target, "target directory", allow_missing=False)
        self.transaction = Path(tempfile.mkdtemp(prefix=".react-sol-advisor-upgrade-txn.", dir=self.target))
        os.chmod(self.transaction, 0o700)
        for role, (_, template) in self.templates.items():
            stage = self.transaction / f"{role}.stage"
            shutil.copyfile(template, stage)
            if stage.read_bytes() != template.read_bytes():
                fail(f"could not stage and verify {role} template")
            self.stages[role] = stage
            self.displaced[role] = self.transaction / f"{role}.displaced"
            if role in KNOWN_STALE_DIGESTS:
                self.backups[role] = self.transaction / f"{role}.backup"

    def acquire_lock(self) -> None:
        self.lock = self.target / ".react-sol-advisor-upgrade-lock"
        try:
            self.lock.mkdir(mode=0o700)
        except FileExistsError:
            fail(f"upgrade lock is already held or unsafe: {self.lock}")
        owner = self.lock / "owner"
        owner.write_text(f"pid={os.getpid()}\ntransaction={self.transaction}\n")
        os.chmod(owner, 0o600)

    def verify_lock(self) -> None:
        if self.lock is None or os.path.islink(self.lock) or not self.lock.is_dir():
            fail(f"upgrade lock ownership changed: {self.lock}")
        owner = self.lock / "owner"
        if os.path.islink(owner) or not owner.is_file():
            fail(f"upgrade lock owner is unavailable: {owner}")

    def backup_old(self, role: str, destination: Path, state: str) -> None:
        backup = self.backups[role]
        if lstat(backup) is not None:
            fail(f"private {role} backup already exists: {backup}")
        os.link(destination, backup)
        expected = stale_digest(role, state)
        if not exact_file(backup, expected) or backup.read_bytes() != destination.read_bytes():
            fail(f"could not create guarded {role} upgrade backup")

    def publish_new(self, role: str) -> None:
        filename, template = self.templates[role]
        destination = self.target / filename
        if classify(destination, template, role) != "missing":
            fail(f"known {role} destination changed before publication: {destination}")
        if os.environ.get("RSA_INSTALL_TEST_FAIL_ROLE") == role:
            fail(f"TEST INJECTION: forced replacement failure for {role}")
        os.link(self.stages[role], destination)
        # The destination is transaction-owned before any post-publication check
        # can fail.  Record it first so rollback removes a partially published
        # new role instead of leaving a public artifact behind.
        self.published_new.append(role)
        pause_role = os.environ.get("RSA_INSTALL_TEST_PAUSE_ROLE")
        ready_path = os.environ.get("RSA_INSTALL_TEST_READY")
        if pause_role == role and ready_path:
            Path(ready_path).touch()
            while True:
                time.sleep(0.05)
        if not exact_file(destination, digest(template)):
            fail(f"post-publication exactness check failed for {role}")

    def publish_replace(self, role: str) -> None:
        filename, template = self.templates[role]
        destination = self.target / filename
        state = classify(destination, template, role)
        if not state.startswith("known-stale-"):
            fail(f"known {role} destination changed before publication: {destination}")
        expected = stale_digest(role, state)
        self.backup_old(role, destination, state)
        displaced = self.displaced[role]
        if lstat(displaced) is not None:
            fail(f"private {role} displaced slot already exists: {displaced}")
        os.replace(destination, displaced)
        if not exact_file(displaced, expected):
            # A concurrent writer may have replaced the destination between the
            # preflight classification and os.replace(). Never discard those bytes:
            # restore them when the public slot is still empty, otherwise preserve
            # the private recovery transaction and its lock for operator inspection.
            if lstat(destination) is None:
                try:
                    os.replace(displaced, destination)
                except OSError as error:
                    self.preserve_transaction = True
                    fail(f"{role} displacement revalidation could not restore the unknown destination: {error}")
                fail(f"{role} displacement revalidation failed; restored unknown destination")
            self.preserve_transaction = True
            fail(f"{role} displacement revalidation failed; preserved private recovery transaction")
        # From this point the old destination has been transaction-owned even if the
        # new publication fails; rollback must restore the displaced inode.
        self.published_replace.append(role)
        if os.environ.get("RSA_INSTALL_TEST_FAIL_ROLE") == role:
            fail(f"TEST INJECTION: forced replacement failure for {role}")
        os.link(self.stages[role], destination)
        pause_role = os.environ.get("RSA_INSTALL_TEST_PAUSE_ROLE")
        ready_path = os.environ.get("RSA_INSTALL_TEST_READY")
        if pause_role == role and ready_path:
            Path(ready_path).touch()
            while True:
                time.sleep(0.05)
        if classify(destination, template, role) != "current":
            fail(f"post-publication exactness check failed for {role}")

    def rollback(self) -> None:
        rollback_ok = True
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(sig, signal.SIG_IGN)
        for role in reversed(self.published_new):
            filename, template = self.templates[role]
            destination = self.target / filename
            if classify(destination, template, role) == "current":
                destination.unlink()
            else:
                print(f"ERROR: refusing to roll back changed new {role} destination: {destination}", file=sys.stderr)
                rollback_ok = False
        for role in reversed(self.published_replace):
            filename, template = self.templates[role]
            destination = self.target / filename
            displaced = self.displaced[role]
            current_state = classify(destination, template, role)
            if current_state == "current":
                destination.unlink()
            elif current_state != "missing":
                print(f"ERROR: refusing to overwrite concurrent {role} destination during rollback: {destination}", file=sys.stderr)
                rollback_ok = False
                continue
            expected_state = self.initial[role]
            if lstat(displaced) is None or not exact_file(displaced, stale_digest(role, expected_state)):
                print(f"ERROR: guarded {role} displacement is unavailable for rollback: {displaced}", file=sys.stderr)
                rollback_ok = False
                continue
            os.replace(displaced, destination)
            if classify(destination, template, role) != expected_state:
                rollback_ok = False
        if self.transaction is not None and self.transaction.exists():
            if rollback_ok and not self.preserve_transaction:
                shutil.rmtree(self.transaction)
            else:
                print(f"ERROR: private recovery transaction preserved: {self.transaction}", file=sys.stderr)
        if self.lock is not None and self.lock.exists():
            if self.preserve_transaction:
                print(f"ERROR: upgrade lock retained with private recovery transaction: {self.lock}", file=sys.stderr)
            elif rollback_ok and self.lock.is_dir() and not os.path.islink(self.lock):
                shutil.rmtree(self.lock)
            else:
                rollback_ok = False
        if self.created_target and self.target.exists() and rollback_ok:
            try:
                self.target.rmdir()
            except OSError:
                pass
        if self.preserve_transaction:
            raise InstallerError("upgrade rollback preserved a private recovery transaction; inspect it before retrying")
        if not rollback_ok:
            raise InstallerError("upgrade rollback failed closed; inspect the private recovery transaction")

    def run(self) -> None:
        self.install_signal_handlers()
        try:
            self.prepare()
            self.acquire_lock()
            self.verify_lock()
            current = preflight(self.target, self.templates)
            if current != self.initial:
                fail(f"destinations changed after preflight: {current}")
            if self.upgrade:
                for role in ("terra", "sol", "luna"):
                    if current[role].startswith("known-stale-"):
                        self.publish_replace(role)
                if current["luna"] == "missing":
                    self.publish_new("luna")
            else:
                for role, current_state in current.items():
                    if current_state == "missing":
                        self.publish_new(role)
            for role, (filename, template) in self.templates.items():
                if classify(self.target / filename, template, role) != "current":
                    fail(f"post-transaction exactness check failed for {role}")
            self.verify_lock()
            # Commit cleanup is the small window where a signal must not turn a
            # successfully published set into an unrecoverable partial state. Keep
            # the private transaction until the lock is gone; if either cleanup
            # operation fails, the exception path still has the displaced inodes.
            for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
                signal.signal(sig, signal.SIG_IGN)
            if self.lock is not None and self.lock.exists():
                if os.path.islink(self.lock) or not self.lock.is_dir():
                    fail(f"upgrade lock ownership changed during cleanup: {self.lock}")
                shutil.rmtree(self.lock)
            if self.transaction is not None and self.transaction.exists():
                shutil.rmtree(self.transaction)
            self.committed = True
        except BaseException:
            if not self.committed:
                self.rollback()
            raise
        finally:
            self.restore_signal_handlers()


def validate_mode(states: dict[str, str], mode: str) -> None:
    if mode == "check":
        for role, state in states.items():
            if state.startswith("known-stale-"):
                fail(f"{role} template is known stale {state.removeprefix('known-stale-')}; rerun with --upgrade-known")
        for role, current in states.items():
            if current != "current":
                fail(f"{role} template is {current}, not the current exact file")
        return
    if mode == "install":
        for role, current in states.items():
            if current not in {"missing", "current"}:
                fail(f"{role} destination is {current} and will not be replaced")
        return
    if (states["terra"], states["sol"]) not in {
        ("current", "current"),
        ("known-stale-0.1.1", "known-stale-0.1.1"),
    }:
        fail(f"--upgrade-known requires a current/current or known-stale/known-stale Terra/Sol pair; found {(states['terra'], states['sol'])}")
    if states["luna"] not in {"missing", "current", "known-stale-0.3.0"}:
        fail(f"native Luna destination is {states['luna']} and will not be replaced")


def parse() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-dir")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true")
    group.add_argument("--upgrade-known", action="store_true")
    return parser.parse_args()


def main() -> int:
    try:
        args = parse()
        mode = "check" if args.check else "upgrade" if args.upgrade_known else "install"
        target = target_from(args)
        templates_by_role = templates()
        states = preflight(target, templates_by_role)
        validate_mode(states, mode)
        if mode == "check":
            print("CHECK PASSED: Luna, Terra, and Sol exactly match the shipped templates.")
            return 0
        old_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)}
        try:
            transaction = Transaction(target, templates_by_role, states, mode == "upgrade")
            transaction.run()
        finally:
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
        if mode == "upgrade":
            print("UPGRADED KNOWN 0.1.1 / 0.3.0: Luna, Terra, and Sol are current.")
        else:
            print("INSTALL PASSED: Luna, Terra, and Sol exactly match the shipped templates.")
        return 0
    except KeyboardInterrupt:
        print("ERROR: installation interrupted; guarded rollback attempted", file=sys.stderr)
        return 1
    except (InstallerError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
