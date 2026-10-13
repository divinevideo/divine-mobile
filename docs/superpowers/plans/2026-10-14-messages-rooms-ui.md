# Messages Direct / Rooms UI implementation

Goal: integrate the approved Messages navigation with the existing internal
Concord POC, retaining its disabled-by-default gate and protected-account gate.
Spec: ../specs/2026-10-13-messages-rooms-design.md.
Execution: implement in this session; no backend ownership changes.

Dependency: origin/feat/concord-mobile-chat at 60908610be, included locally for
integration testing. The backend owner retains PR #10093. UI changes remain in
separate commits for that owner to integrate into the combined feature PR; do
not push their branch or open a stacked/duplicate feature PR.

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

Integrate the UI commit into the existing Concord feature PR. Do not
cherry-pick the local dependency merge commit: that PR already contains the
Concord dependency. Do not create a stacked or duplicate feature PR. The other
session retains ownership of its branch and PR; this session has not pushed
that branch, posted to that PR, merged, or deployed anything.
