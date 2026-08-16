# Cursor adapter

Cursor is a desktop/editor binding for the shared Sol Development Advisor core. The
Cursor package uses the current `.cursor-plugin/plugin.json` format, `skills/`,
`agents/`, `commands/`, and `rules/` components. It contains binding instructions,
not a second copy of `production-delivery` policy; the bundled shared-core skill is generated from
the canonical Codex-package source and checked byte-for-byte.

## Route binding

The parent emits this shared declaration before any Cursor call:

```text
ADVISOR ROUTE
CLIENT: cursor
POLICY: economy | balanced | critical
RISK: green | amber | red
IMPLEMENTATION MODE: cursor-composer | cursor-luna | cursor-grok | parent-only | decomposed-mixed
REASONS:
OWNERSHIP:
DELIVERY PROFILES:
ESCALATION TRIGGERS:
REVIEW:
PR POLICY:
MODEL EVIDENCE:
```

Before a Cursor agent call, emit the shared declaration with `CLIENT: cursor` and one
of:

- `cursor-composer` — bounded routine work;
- `cursor-luna` — specialist implementation or review when the owned slice warrants it;
- `cursor-grok` — high-complexity backend, data, worker, integration, or advice work;
- `decomposed-mixed` or `parent-only` when ownership or risk requires it.

The invocation phrase never selects a profile or model. `React Sol Advisor` is the
legacy alias of `Sol Development Advisor`, and both names have identical semantics. The
parent derives profiles from
owned paths and acceptance, then records requested and observed model evidence.

## Roles and exact IDs

The shipped role labels are:

- Composer routine worker;
- Luna specialist worker/reviewer;
- Grok high-complexity worker/advisor.

Bundled agents use `model: inherit` until the user configures exact current Cursor-native
IDs. The setup flow accepts those IDs from a model picker/catalog and writes them exactly;
it never guesses or silently normalizes a label. The current local catalog evidence used
by the acceptance fixture is `composer-2.5`, `gpt-5.6-luna-max`, and
`cursor-grok-4.5-high`, but these are fixture values, not defaults.

The Luna reviewer requests `readonly: true`, but requested read-only behavior is not
proof of enforced isolation. For consequential reviews, capture before/after state and
require observed runtime evidence or an explicit fresh manually selected model.

## Safe configuration

`configure-cursor-agents.py` writes project agents to `.cursor/agents/` and user agents
to `~/.cursor/agents/`, matching the current Cursor subagent paths. It previews a plan,
requires a deterministic confirmation token, writes only managed files atomically,
stores a receipt and per-role hashes, refuses symlinked paths or unknown modifications,
preserves unrelated agents, supports safe update/uninstall, and reports a required
Cursor reload after changes. `--report` displays requested and separately recorded
observed model values.

## Workflow and surface boundary

Routine work follows parent architecture -> Composer -> deterministic verification ->
Luna review when React, type, async, or integration risk warrants it -> Composer
correction -> parent acceptance. React-sensitive work may route directly to Luna.
Complex backend/data/worker work routes to Grok or remains with the configured parent;
Composer may own bounded helpers, fixtures, tests, docs, or call-site updates.

This build targets Cursor desktop/editor plugin discovery. Cursor CLI support is not claimed:
the local `cursor-agent --version` and `--list-models` checks prove only
the installed binary/catalog surface, not plugin loading or agent execution.

The Cursor adapter never owns Linear, worktrees, publication, review completion, merge,
closeout, or deployment boundaries.
