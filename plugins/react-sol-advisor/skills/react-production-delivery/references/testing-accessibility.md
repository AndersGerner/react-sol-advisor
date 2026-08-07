# Testing and accessibility reference

## Testing contract

Define tests that prove behavior before implementation.

Prioritize:

- User-visible outcomes
- State transitions
- Loading, empty, success, and failure paths
- Boundary values
- Retry and duplicate-action behavior
- Permission/authorization behavior at the correct layer
- Keyboard, focus, and accessibility interactions
- Stale async response and race regressions
- The exact bug reproduction for fixes

Avoid tests coupled only to internal implementation details. Use the repository's
established test stack and helpers.

## Verification order

1. Run the narrowest relevant test.
2. Run affected package type checking.
3. Run relevant linting.
4. Run affected broader tests.
5. Run build or platform smoke checks when the changed boundary warrants it.
6. Inspect the complete diff and changed-file scope.

A missing command must be reported, not invented.

## Accessibility checklist

- Prefer native semantic elements and platform controls.
- Provide accessible names, descriptions, states, and errors.
- Preserve keyboard operation, focus order, and visible focus.
- Restore or move focus intentionally after modal, removal, navigation, and validation
  events.
- Use live regions only for meaningful asynchronous updates.
- Respect reduced motion and dynamic text/font scaling where applicable.
- Do not rely on color alone.
- Test the actual interaction, not only static attributes.
