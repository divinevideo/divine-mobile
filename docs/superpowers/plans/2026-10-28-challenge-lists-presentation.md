# Native challenge Lists presentation implementation plan

> **For agentic workers:** Use superpowers:executing-plans for native execution in this session, task by task. Steps use checkbox (`- [ ]`) syntax for tracking. The user approved the merged design and explicitly requested building; record and execute this plan without another feature-authorization prompt.

**Goal:** Replace the existing test-build challenge participant screen's text-heavy detail and selection UI with the approved Lists-based native presentation, preserving exact-video consent and durable delivery.

**Architecture:** Keep ChallengeParticipationCubit, ChallengeSubmissionRepository and ChallengeAppSession as the trusted action/data boundaries. Small presentation widgets consume their verified domain state, use existing Divine UI/thumbnail primitives and choose video revisions only by exact event ID. Production discovery, anonymous read wiring, reverse-association APIs and release activation remain separate, blocked dependencies; this branch does not pretend to provide them.

**Tech stack:** Flutter 3.47.2, Dart 3.13.2, BLoC, existing material_ui/divine_ui, existing flutter_staggered_grid_view and profile thumbnail components, generated ARB localization, widget/golden tests.

**Spec:** [Merged mobile experience design](https://github.com/divinevideo/divine-challenges/blob/10a035382cf92f17ebfff2af9d8234ad3db5697e/docs/superpowers/specs/2026-10-28-mobile-challenges-design.md). Implements the known-coordinate presentation portion of S2–S6/S9. S7 retains the existing pinned player for this slice; pooled-feed actions/attribution follow the association delivery.

## Global constraints

- Figma F3/F4/F5 determine the header, compact title, rounded grid and source chooser. Titles 24/32 Bricolage Grotesque 700; compact title 16/24 Bricolage Grotesque 800; body 14/20 Inter; 16 side inset, 8 header row spacing, 4 grid gaps, 32 outer grid corners, 48 minimum action targets.
- Reuse adaptive context.vineColors, VineTheme typography, DivineButton, VineBottomSheet and existing thumbnail rendering. Reuse ComposableVideoGrid where its ordinary owner actions/filtering fit; ordered winners must retain unavailable slots and signed labels.
- No hashtag, NIP-51 membership or NIP-32 curation becomes an official entry. No wire/fixture change or signing-key handling.
- No new signatures from source selection, display, rules expansion or tab changes. Keep existing preview-ready, current-owner, lease and async serialization checks before confirm.
- Index status and relay delivery remain independent; the persisted signed body remains exact. Do not remove pending actions or recording handoff recovery.
- Keep DIVINE_CHALLENGES_TEST production gate unchanged. No Funnelcake branch takeover, SQL, migrations, new API stubs, rollout, or Figma writes.
- Work in .worktrees/challenge-lists-ui on feat/challenge-lists-ui from mobile origin/main 2540633f71bc3ff1829a574429bdc1446c05ef15. The shared main checkout stays untouched.

## Review focus

- Organizer credit must use the definition signer, while review's signing-account label must retain the entrant identity (Task 1).
- A closed/cancelled challenge cannot offer new entry; pending delivery and withdrawal remain accessible (Task 1).
- Large text/long rules must not overflow, obscure actions, or force a new entry signature (Tasks 1–2).
- Restriction/lease expiry or backgrounding must remove thumbnail/media exposure without selecting a different revision (Task 2).
- Unavailable winners must retain signed order/labels and never become playable or be replaced by another entry (Task 2).

## Task 1: Lists header, organizer identity and source chooser

**Files:** Modify mobile/lib/features/challenges/{challenge_view,challenge_page}.dart and mobile/lib/l10n/app_en.arb; create mobile/lib/features/challenges/challenge_detail_view.dart; update mobile/test/features/challenges/{challenge_view_test,challenge_deadline_test}.dart and ARB fallback debt/generated outputs.

**Interfaces:** ChallengeDetailView consumes `ChallengeParticipationState state`, `String? organizerName`, `VoidCallback? onOrganizerTap`, `VoidCallback onEnter`, `Future<void> Function() onRefresh`, and `Widget deliveryActions`. The parent owns record/choose/withdraw/play dispatch and passes callbacks. ChallengeView gains optional organizerName/onOrganizerTap separately from ownerName. Organizer lookup in ChallengePage uses `state.read.view.definition.event.pubkey`; ownerName remains the session owner for review. Detail does not own signing or transport.

- [ ] Write widget tests that catch wrong signer credit, source actions displayed before Enter, closed/cancelled entry being offered, and compact title/rules expansion hiding or duplicating the main title. The chooser must expose Record a video / Choose one of your videos only after Enter, selecting neither signs, and cancellation returns unchanged.
- [ ] Run `flutter test --no-pub test/features/challenges/challenge_view_test.dart`; expect the new behavior tests to fail on the existing text-only UI.
- [ ] Implement the scrolling hero, expandable six-line rules, compact title, Entries/Winners selection, explicit source sheet, and organizer wiring using shared styles. Show the existing partial-read test notice and delivery status; never display a guessed total. Convert deadline instants to local before formatting and include the actual zone; keep organizer time available. Use new localized keys for changed copy rather than silently changing translated UTC text.
- [ ] Update deadline tests to exercise an explicitly injected display timezone/local instant boundary and preserve app locale. Keep exact reviewed rules and technical detail disclosure in review; change only the primary entry label to Enter this video.
- [ ] Run the complete `flutter test --no-pub test/features/challenges` suite and the ARB consistency test; expect all tests to pass with no signing regression. Commit the header/chooser behavior and its localization together.

## Task 2: Pinned entry/results tiles and full-screen video selection

**Files:** Create mobile/lib/features/challenges/{challenge_video_tile,challenge_video_picker}.dart; extend challenge_detail_view.dart; modify challenge_view.dart; create mobile/test/features/challenges/challenge_presentation_test.dart and extend challenge_view_test.dart.

**Interfaces:** ChallengeVideoTile consumes an exact verified `NostrEvent video`, a `bool Function(NostrEvent) allowed`, optional signed result label, and `VoidCallback onTap`. It adapts only that event to the existing VideoEvent thumbnail model, with permissive NIP-71 kind support and no latest resolver. ChallengeVideoPicker consumes the current candidate `List<VideoEvent>`, busy state, cancel callback and `Future<void> Function(String eventId) onContinue`; local selection never signs or prepares consent until Continue. Detail uses `cubit.playEntry(entryId)` for playback and `cubit.withdraw(jsonEncode(entry.event.toJson()))` for exact owned withdrawal.

- [ ] Write failing behavior tests for a selection that requires Continue, entry tiles without raw event IDs, signed winner labels/order with unavailable slots, and policy revocation/backgrounding hiding thumbnails. Include narrow width/2x text scaling and long labels. Test video conversion on all v1 kinds 21/22/34235/34236 without changing event ID/author.
- [ ] Run `flutter test --no-pub test/features/challenges/challenge_presentation_test.dart`; expect missing new presentation behavior.
- [ ] Compose shared thumbnail rendering with the Lists two-column masonry geometry for entries and row-ordered fixed-aspect results. Use a one-column fallback for large text/narrow widths. Preserve unavailable result slots, current policy checks and pinned playback. Keep owned-entry withdrawal reachable and delivery actions outside the selected tab.
- [ ] Implement the full-screen single-selection picker and Continue, with clear Back/cancel behavior, no raw identifier subtitles and no automatic entry. Keep the current repository's exact revision/ownership recheck at review preparation. Do not add fake pagination or claim full author-feed discovery; candidate pagination remains a later data-adapter task.
- [ ] Run `flutter test --no-pub test/features/challenges test/services/challenges test/blocs/background_publish_bloc/challenge_handoff_test.dart`; expect consent, policy, restart and UI tests to pass. Commit the independently tested presentation.

## Task 3: Visual, localization and delivery verification

**Files:** Update mobile/test/goldens/widgets/challenge_golden_test.dart and its Linux-generated reference PNGs; update this plan with actual delivery status. No CI/workflow or production configuration changes.

**Interfaces:** Goldens render the real test-build view and drain GoogleFonts.pendingFonts. Existing dark/light references are generated on the Ubuntu runner, never committed from macOS. Existing locale fallback debt remains explicitly enumerated and generated files are generated, not hand-edited.

- [ ] Add resting/scrolled and picker/results coverage where behavior tests do not establish visual layout, including light/dark and long content. Run mobile/scripts/golden.sh verify to inspect structural failures; macOS pixel differences remain non-authoritative.
- [ ] Run the repository localization skill checker, `flutter gen-l10n`, exact ARB consistency test, Dart formatting and `flutter analyze --no-pub`. Run the relevant protocol/repository package suites if their production code changed (none is planned).
- [ ] Run the app test command per the repository's normal shard workflow and record failures by name, including unrelated failures. Never label a skipped/broken suite green. Use CI as the authoritative Linux pixel check.
- [ ] Obtain one fresh-context adversarial review of the whole branch, fix verified blockers with regression tests, push and open a focused PR linked to the merged design and Funnelcake #1402. Request the mapped mobile review team once after checks finish. Do not merge or activate the feature.

## Remaining plans, not silently included

| Work | Dependency / next owning plan |
| --- | --- |
| Signed-out browsing | Separate challenge read-session lifetime from signing session; blocked production API/policy boundary must be designed and tested without weakening current leases. |
| Active/Upcoming/Results discovery and topic ingress | Funnelcake global discovery completeness, absent from its current known-coordinate read plan; then mobile API DTO/repository adapters and gallery. |
| Reverse video links and winning-version attribution | Proposed association API plus complete result verification; no hashtag-based shortcut. |
| Full pooled-player engagement and result history routes | Revision/policy-safe player adapter and paginated backend reads. |
| Production activation | Linked mobile/backend PRs, inspected required CI and cross-client web → native entry → organizer result acceptance in an owned environment. |

Native presentation delivery is not end-to-end delivery. Record its PR, checks and
remaining dependencies in the handback; never mark the broader design complete.
