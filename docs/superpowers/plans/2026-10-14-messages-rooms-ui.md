# Messages Direct / Rooms UI implementation

Goal: integrate the approved Messages navigation with the existing internal
Concord POC, retaining its disabled-by-default gate and protected-account gate.
Spec: ../specs/2026-10-13-messages-rooms-design.md.
Execution: implement in this session. Rabble subsequently authorized this
session to finish the combined PR after the backend provider failed.

Dependency: origin/feat/concord-mobile-chat at 60908610be, included for
integration testing. Publish the combined UI/backend through existing PR
#10093, preserving both remote backend fixes. No stacked or duplicate PR.

- [x] Test and implement account-scoped Direct / Rooms preference and Cubit.
- [x] Test and implement a Messages host that keeps both lists mounted, hides
      inactive semantics/tickers, and renders Direct alone when rooms are gated.
- [x] Bind the host in InboxView without changing Notifications or DM behavior.
- [x] Render the existing POC community/channel list, with public-test disclosure;
      navigate by community/channel parameters to the selected conversation.
- [x] Refactor chat session wiring into a Page, keyed by account and signer.
      Remove the local-only invite acceptance UI; show no unimplemented join,
      permissions, unread, moderation, or bridge status as working functionality.
- [x] Translate new strings and regenerate localizations. Test light/dark,
      large text, gate behavior, account switching and route selection.
- [x] Run affected tests, analyzer and applicable guards, review and commit UI.

Release remains blocked on the runtime requirements in the spec: authenticated
membership/permission snapshots, real join admission, durable read/mention state,
reporting, expiry and full interoperability. Public Rooms must not be enabled
by this UI patch. Native device validation remains separate from widget tests.


## Validation and handoff

- Full inbox directory, chat-route and ARB consistency run: 921 tests passed.
- App and test analysis: `mise exec -- flutter analyze --no-pub lib test`,
  no issues found.
- UI/service boundary, preference classification, grouped tests, unused ARB
  keys, localized accessibility labels and post-close emissions guards passed.
- The standalone personal l10n check script could not find its old debt
  allowlist in the current repository. The repository's ARB consistency test
  passed; no allowlist or test was loosened.
- A full-root analysis also inspected tooling outside lib/test and reported
  existing diagnostics in analysis_options.yaml and two scripts. The app/test
  analysis above is clean.
- Native iOS/Android device runs and real relay interop were not performed by
  this UI task. This is the internal POC navigation integration, not completion
  of the full release requirements in the design.

The UI patch removes the POC's local-only invite acceptance and reaction action
from the room screen rather than presenting those as successful network actions.
The timeline now filters the selected channel. Backend code still owns join,
permissions, delivery/retry semantics, received-message persistence, expiry,
read/mention state and moderation. The current fixed POC room catalog must be
replaced with verified repository snapshots before public launch.

The combined PR uses the validated Messages UI branch, which contains the
remote backend head as an ancestor. The backend session's five local picks
contain the same UI/docs; they must not be applied a second time. The unfinished
held-key path was removed per the reviewer's offered option because real
Community List sync is absent. Public POC behavior and the disabled gate remain.


## Review remediation

Rabble subsequently requested the remaining review findings be addressed in
this same PR. The session now binds a durable encrypted-wrap store, restores
and subscribes to the selected room, surfaces unacknowledged messages with a
retry action, preserves drafts when signing fails, and blocks sending after
failed initial restoration. Room disposal cancels listeners, socket and expiry
work. The milliseconds tag uses the actual subsecond remainder and channel
bindings use full 32-byte ids. Protocol and transport validation have independent
native and Chrome regression tests. The acceptance document records the exact
preview toggle path and the remaining real-community/device rollout gates.
