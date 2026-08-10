# Upstream attribution

Sol Development Advisor is derived from `DannyMac180/sol-advisor` and retains the MIT
license. Its user-facing delivery scope intentionally diverges beyond React while its
repository, plugin, invocation, and native-role compatibility identifiers remain stable.

## Source

- Upstream repository: https://github.com/DannyMac180/sol-advisor
- Baseline upstream SHA: `154fd7ac282088f58246e192347960ba0bfc945f`
- Fork owner: Anders Gerner
- Fork repository: https://github.com/AndersGerner/react-sol-advisor
- Fork date: 2026-08-06

## License

MIT License (see [`LICENSE`](LICENSE)).

Copyright 2026 Daniel McAteer.

## Retained components

- Plugin directory layout and shell-script patterns.
- Native custom-agent TOML model and pin pattern.
- Marketplace manifest shape and category.
- Skill and reference file conventions.
- Runtime-inspector allowlist and safe-output approach.
- MIT license text.

## Intentional divergence

- User-facing **Sol Development Advisor** identity at version `0.2.0`, with
  `react-sol-advisor` retained as the repository directory, technical plugin name, and
  `@react-sol-advisor` compatibility invocation.
- Namespaced `react-sol-advisor-*` native role filenames and exact role IDs remain
  compatible with the fork’s existing native installation surface.
- Luna-first default routing for implementation work, with economy, balanced, and
  critical policies unchanged.
- Mandatory generic production delivery plus conditional React/UI, TypeScript backend,
  Postgres/data, and worker/integration specialist profiles.
- Optional Linear intake and capability-gated archiving.
- Safe exact-known-version native-role upgrade and updated marketplace manifest, plugin
  manifest, README, examples, and verifier coverage.

## Coexistence

Upstream `plugins/sol-advisor/` is not edited, deleted, migrated, or validated by this fork. Both plugins can be installed side-by-side in the same Codex workspace as long as their installed custom-agent filenames do not overlap.

## Upstream sync workflow

1. Add or refresh `upstream` remote: `git remote add upstream https://github.com/DannyMac180/sol-advisor.git`.
2. Fetch and inspect upstream changes: `git fetch upstream`.
3. Keep the list of intentionally-divergent files small; merge only safe, non-overlapping upstream fixes into this fork.
4. Never overwrite namespaced `react-sol-advisor-*` files with upstream `sol-advisor-*` files.
