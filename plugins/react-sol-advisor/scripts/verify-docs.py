#!/usr/bin/env python3
"""Deterministic documentation, manifest-schema, and whitespace acceptance."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[3]
CURSOR = ROOT / "plugins" / "cursor-sol-development-advisor"
LINK = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)\n]+)\)")
TEXT_SUFFIXES = {".md", ".mdc", ".json", ".toml", ".yaml", ".yml", ".sh", ".py"}


class VerificationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise VerificationError(message)


def files_with_suffixes() -> list[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*")
        if path.is_file() and not path.is_symlink() and path.suffix in TEXT_SUFFIXES
        and ".git" not in path.parts
    )


def verify_whitespace(paths: list[Path]) -> None:
    for path in paths:
        for line_number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            if line.endswith((" ", "\t")):
                fail(f"trailing whitespace: {path.relative_to(ROOT)}:{line_number}")


def verify_links() -> None:
    for path in sorted(ROOT.rglob("*.md")):
        if not path.is_file() or path.is_symlink() or ".git" in path.parts:
            continue
        for match in LINK.finditer(path.read_text(errors="replace")):
            href = match.group(1).strip()
            if href.startswith("<") and ">" in href:
                href = href[1:href.index(">")]
            if href.startswith(("http://", "https://", "mailto:", "#")):
                continue
            href = href.split("#", 1)[0].split("?", 1)[0]
            if not href:
                continue
            target = (path.parent / unquote(href)).resolve()
            if not target.exists():
                fail(f"broken relative Markdown link: {path.relative_to(ROOT)} -> {href}")


def verify_cursor_schema() -> None:
    manifest_path = CURSOR / ".cursor-plugin" / "plugin.json"
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("$schema") != "https://raw.githubusercontent.com/cursor/plugins/main/schemas/plugin.schema.json":
        fail("Cursor manifest does not reference the current official plugin schema")
    if manifest.get("name") != "sol-development-advisor" or manifest.get("version") != "0.3.1":
        fail("Cursor manifest identity/version is invalid")
    allowed = {
        "$schema", "name", "displayName", "description", "version", "author", "homepage",
        "repository", "license", "keywords", "category", "tags", "minClientVersions", "commands",
        "agents", "skills", "rules", "hooks", "variables", "mcpServers", "logo", "publisher",
    }
    if set(manifest) - allowed:
        fail(f"Cursor manifest contains fields outside the official schema: {sorted(set(manifest) - allowed)}")
    for key in ("skills", "agents", "commands", "rules"):
        component = CURSOR / str(manifest[key]).removeprefix("./")
        if not component.is_dir() or component.is_symlink():
            fail(f"Cursor manifest component is not a real directory: {component.relative_to(ROOT)}")

    for path in sorted((CURSOR / "agents").glob("*.md")):
        text = path.read_text()
        if not text.startswith("---\n") or "\n---\n" not in text[4:]:
            fail(f"Cursor agent lacks official YAML frontmatter: {path.relative_to(ROOT)}")
        end = text.find("\n---\n", 4)
        fields = {}
        for line in text[4:end].splitlines():
            key, separator, value = line.partition(":")
            if not separator or not key.strip() or not value.strip():
                fail(f"invalid Cursor agent frontmatter: {path.relative_to(ROOT)}")
            fields[key.strip()] = value.strip()
        if not {"name", "description", "model"}.issubset(fields):
            fail(f"Cursor agent frontmatter is incomplete: {path.relative_to(ROOT)}")
        if set(fields) - {"name", "description", "model", "readonly"}:
            fail(f"Cursor agent has unsupported frontmatter: {path.relative_to(ROOT)}")
        if fields["name"] != path.stem or fields["model"] != "inherit":
            fail(f"Cursor agent binding is not generic/inherited: {path.relative_to(ROOT)}")

    marketplace = json.loads((ROOT / ".cursor-plugin" / "marketplace.json").read_text())
    if marketplace.get("$schema") != "https://raw.githubusercontent.com/cursor/plugins/main/schemas/marketplace.schema.json":
        fail("Cursor marketplace does not reference the current official marketplace schema")
    entries = marketplace.get("plugins")
    if not isinstance(entries, list) or len(entries) != 1:
        fail("Cursor marketplace must contain exactly one plugin entry")
    entry = entries[0]
    if entry.get("name") != manifest["name"] or entry.get("source") != "./plugins/cursor-sol-development-advisor":
        fail("Cursor marketplace entry does not match the plugin manifest")


def main() -> int:
    try:
        paths = files_with_suffixes()
        verify_whitespace(paths)
        verify_links()
        verify_cursor_schema()
        print("DOCS, LINKS, SCHEMA, AND WHITESPACE ACCEPTANCE PASSED")
        return 0
    except (VerificationError, OSError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
