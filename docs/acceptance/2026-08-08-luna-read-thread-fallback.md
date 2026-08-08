# Luna exact-thread `read_thread` fallback acceptance evidence

Date: 2026-08-08

This document contains only allowlisted, non-secret compatibility evidence from a
disposable Codex app project. It excludes full prompts, unrelated task data, secrets,
and internal payloads.

## Project and task identity

- Disposable project path:
  `/Users/andersgerner/Development/react-sol-advisor-luna-probe`
- Project ID:
  `c2xpbmdzaG90OmVudl9lXzZhMDY2MWM2ZjFlNDgzMzFhMTRjMzQ4MzUzNmY0NTQ1Ci9Vc2Vycy9hbmRlcnNnZXJuZXIvRGV2ZWxvcG1lbnQvcmVhY3Qtc29sLWFkdmlzb3ItbHVuYS1wcm9iZQ==`
- Host ID: `slingshot:env_e_6a0661c6f1e48331a14c3483536f4545`
- Luna thread ID: `019fe2f5-2307-7942-9876-89d25b47e847`
- Initial completed turn ID: `019fe2f5-2684-7402-9305-4372ce4e12cd`
- Follow-up completed turn ID: `019fe2f7-1c3f-7860-bae9-b1cdfd9bb5f9`

## Observed project schema and environment

- `list_projects` returned the exact disposable project and exposed `projectKind` and
  `supportsWorktrees` for it.
- `isGitRepository` was not exposed by the recorded live schema and was not used to
  choose the environment.
- The selected project explicitly supported worktrees, and `create_thread` used the
  schema-valid environment `{type: "worktree"}`.
- Repository Git state and the exact base commit were independently confirmed from the
  actual child worktree rather than inferred from project metadata.

## Observed lifecycle

- `wait_threads` was not exposed.
- `create_thread` accepted `gpt-5.6-luna` with `thinking = max` and returned the real
  Luna thread and host identity.
- Initial exact-thread reads observed:
  `active / inProgress` -> `idle / completed`.
- The completed initial turn contained a readable final assistant handoff.
- A follow-up sent with `send_message_to_thread` reused the same thread ID and host ID,
  explicitly supplied `model = gpt-5.6-luna` and `thinking = max`, and accepted that
  routing.
- Follow-up exact-thread reads observed:
  `active / inProgress` -> `active / completed`.
- The different follow-up turn ID contained a readable updated final assistant handoff.
  This proves that thread `idle` is not required when the latest turn is completed.

## Independent child-worktree verification

- Child worktree:
  `/Users/andersgerner/.codex/worktrees/05f073e9-451f-4a9b-9816-f56625177cb9/react-sol-advisor-luna-probe`
- Base commit: `51cb1b6c4e5e3d84ea10e65a7fdd1b6eda15cd3b`
- Git state: detached HEAD, no commits, no remotes.
- Initial artifact: `probe/luna-initial.txt`; independently inspected and verified
  byte-exact against the requested content.
- Follow-up artifact: `probe/luna-follow-up.txt`; independently inspected and verified
  byte-exact against the requested content.
- Both turns were accepted from exact thread/turn evidence plus independent worktree
  inspection, not from title, preview, elapsed time, file appearance, or child claims.

## Same-thread correction evidence

- The follow-up used the same Luna thread ID, same host ID, and same child worktree.
- The previous completed turn ID was recorded.
- The follow-up produced a different newly completed turn ID and an updated readable
  handoff.
- The updated child-worktree artifact was independently verified before acceptance.

## Archive evidence

- `set_thread_archived` was called after parent acceptance with the exact real thread ID,
  host ID, and `archived = true`.
- The operation explicitly returned the same thread identity with `archived = true`.
- A later `notLoaded / completed` observation was recorded but not used as completion
  evidence or as a substitute for the explicit archive acknowledgement.

## Conclusion

`EXACT_THREAD_POLLING_FALLBACK: SUPPORTED`
