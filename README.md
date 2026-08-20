# Sol Development Advisor 0.3.1

Sol Development Advisor is one generic production-delivery advisor with Codex and
Cursor execution adapters. Every implementation uses production-delivery; React/UI,
TypeScript backend, Postgres/data, and worker/integration profiles are selected from
owned code and acceptance criteria. A backend, data, provider, queue, or worker task
does not need a React slice.

React Sol Advisor is a legacy product-name and invocation alias. It has identical
eligibility, risk, profiles, and lane semantics to Sol Development Advisor.

The compatibility identifiers remain stable:

- repository: AndersGerner/react-sol-advisor
- Codex plugin: react-sol-advisor@react-sol-advisor
- direct invocation: @react-sol-advisor

The parent session remains the outer owner of architecture, Linear, worktrees,
publication, review, merge, closeout, and deployment boundaries.

## Shared route

Before a client-specific call, emit one complete declaration:

    ADVISOR ROUTE
    CLIENT: codex | cursor
    POLICY: economy | balanced | critical
    RISK: green | amber | red
    IMPLEMENTATION MODE:
    - codex-luna-native
    - codex-luna-detached
    - codex-terra-native
    - cursor-composer
    - cursor-luna
    - cursor-grok
    - parent-only
    - decomposed-mixed
    REASONS:
    OWNERSHIP:
    DELIVERY PROFILES:
    ESCALATION TRIGGERS:
    REVIEW:
    PR POLICY:
    MODEL EVIDENCE:

The route records requested and observed model/tier values separately. There is no
silent client, model, tier, or profile fallback.

## Codex adapter

The existing detached codex-luna-detached lane remains the Fast-capable path. It
retains the validated project/schema preflight, real thread/host identity, exact
worktree discovery, preferred wait_threads, bounded exact-thread read_thread
fallback, same-thread correction, parent diff verification, and explicit archive proof.
Fast is a service tier, not a property of the model name or prompt. If the tier cannot
be set and observed, the lane stops with LUNA FAST MODE: blocked.

The optional native role is:

    react_sol_advisor_luna_implementer
    model: gpt-5.6-luna
    reasoning: max
    service tier: fast

Native Luna is eligible only when exact role/model/effort and effective service-tier
evidence are observable. The shipped role requests `service_tier = "fast"`; the runtime
must report `fast` or its effective request ID `priority`. Missing or other tier
evidence blocks the native lane. It is bounded generic implementation work and never owns
architecture, PRs, Linear, publication, review completion, merge, closeout, deployment,
or external state. Amber/red work escalates to the namespaced Terra / High role; red and
critical boundaries receive a fresh Sol / High review.

Install or verify all three managed roles:

    plugin_dir="$(pwd)/plugins/react-sol-advisor"
    sh "$plugin_dir/scripts/install-agents.sh" --target-dir "$HOME/.codex/agents"
    sh "$plugin_dir/scripts/install-agents.sh" --target-dir "$HOME/.codex/agents" --check
    # Upgrade only the accepted 0.1.1 Terra/Sol or 0.3.0 Luna roles:
    sh "$plugin_dir/scripts/install-agents.sh" --target-dir "$HOME/.codex/agents" --upgrade-known

The installer changes only the three namespaced files, refuses unknown or modified
managed roles, protects symlinked paths, preserves upstream sol-advisor-* files,
publishes through a guarded transaction, rolls back on failure/signal, and is
idempotent. Start a fresh Codex task after installing or updating roles.

Runtime evidence reports exact role/model/effort and requested/observed service-tier
fields. Native Luna inspection rejects missing or unsupported effective tiers rather than
upgrading them into a Fast claim; Terra and Sol reviewer remain tier-agnostic.

## Cursor adapter

The Cursor package is at
plugins/cursor-sol-development-advisor/. It uses the current Cursor Plugin manifest at
.cursor-plugin/plugin.json with skills/, agents/, commands/, and rules/. The bundled
roles are:

- Composer — bounded routine work;
- Luna — specialist implementation/review;
- Grok — high-complexity backend, data, worker, integration, and advice work.

Bundled agents use model: inherit; no guessed IDs are hardcoded. Configure exact
current IDs from the Cursor model picker/catalog with the safe flow:

    python3 plugins/cursor-sol-development-advisor/scripts/configure-cursor-agents.py \
      --scope project \
      --workspace "$PWD" \
      --config /path/to/exact-cursor-models.json
    # Copy CONFIRMATION_TOKEN from the preview, then rerun with --confirm TOKEN.

The JSON must contain exactly composer, luna, and grok string identifiers. The flow
supports project (.cursor/agents/) and user (~/.cursor/agents/) scopes, previews before
writing, requires an explicit confirmation token, writes managed files atomically,
records per-file hashes, refuses symlinks and unknown managed changes, preserves
unrelated agents, supports safe update/uninstall, and reports the required Cursor
reload. Pass --observed-models only with separately observed runtime values; --report
shows requested versus observed evidence. Frontmatter alone never proves the observed
model.

The Luna agent requests readonly: true, but that request is not proof of enforced
isolation. Consequential reviews capture before/after state or require independently
observed runtime evidence. This build targets Cursor desktop/editor plugin discovery;
Cursor CLI support is not claimed because plugin loading was not live-tested here.

## Generic examples

Both Sol Development Advisor and React Sol Advisor accept these without a React
confirmation gate:

    Add a deterministic TypeScript provider-error classifier with table-driven tests.
    Use production-delivery plus typescript-backend-delivery.

    Implement pg-boss admission, database ownership metadata, provider-request state,
    worker safeguards, and orphan reconciliation. Use production-delivery plus TypeScript
    backend, Postgres/data, and worker/integration. Treat consistency as amber or red and
    do not route the irreducible core through a routine green lane.

For a React URL filter, select react-production-delivery because the owned UI slice
requires it. For a mixed React/backend request, decompose into non-overlapping slices
and select profiles per slice; backend ownership does not inherit React requirements.

## Upstream references

The listed upstream commits and their adopted/adapted/rejected decisions are recorded
in docs/upstream-adoption.md. Run the read-only report to inspect newer fetched
upstream commits without merging them:

    sh scripts/report-upstream.sh upstream

## Verification

Run the full deterministic suite before accepting or publishing a change:

    sh plugins/react-sol-advisor/scripts/verify.sh
    sh plugins/react-sol-advisor/scripts/verify-hardening.sh
    sh plugins/react-sol-advisor/scripts/verify-contracts.sh
    sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh
    sh plugins/react-sol-advisor/scripts/verify-tmpdir-portability.sh
    sh plugins/react-sol-advisor/scripts/verify-generalization.sh
    sh plugins/react-sol-advisor/scripts/verify-agent-upgrade.sh
    sh plugins/react-sol-advisor/scripts/verify-cross-client.sh
    python3 plugins/react-sol-advisor/scripts/verify-cursor-agents.py
    python3 plugins/react-sol-advisor/scripts/verify-codex-adapter.py
    python3 plugins/react-sol-advisor/scripts/verify-docs.py
    git diff --check

The semantic oracle includes pure TypeScript, the exact FLE-1007-like non-React
backend/data/worker shape, schema migration, React, mixed, and legacy-alias cases. CI
runs every deterministic gate and does not merge pull requests.
