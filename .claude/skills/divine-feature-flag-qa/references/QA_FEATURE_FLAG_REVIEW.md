# QA brief: decide what Divine should release, fix, keep controlled, or retire

Snapshot prepared 2026-11-19. Refresh inventories, deployment checks, and linked PR/issue states for the actual review target; historical blockers below are not current assertions.

## Assignment

Audit every feature-flagged experience in Divine mobile and web. Our goal is to make ready features part of the normal product, identify the concrete work that prevents release, and remove obsolete flags. A feature being behind a flag is not itself a reason to delay it. A flag being enabled is not proof the feature works.

Return a release decision for every item below, backed by actual user-visible behavior and relevant service results. Review and report; do not merge, deploy, change global defaults, widen OAuth permissions, collect contacts, or make unrequested code changes. Use approved QA accounts/environments for publishing, messaging, notifications and uploads. Public creator content can be browsed read-only for realistic visual checks. Livestream, live spaces, LiveKit and divine-live-server remain explicitly paused: record that hold and exclude them from testing, repair and release recommendations.

Divine is a human-made short-video network built on Nostr. Evaluate whether a feature helps people watch, create, follow and communicate without confusing permissions, leaking account data or interrupting playback unexpectedly.

## Establish what you are testing

Record app version, commit SHA, platform, environment, backend revision where available, build-time flag settings, developer mode, persisted overrides, account state and the effective value of each flag. Test a clean default configuration as well as intentional QA overrides. Do not infer deployed settings from source defaults.

The starting inventory below contains **23 flags** from the Find people branch at `be97ddad3474c1db7ab94923fb16a44ad308060c`. Reconcile it against current main and the actual release candidate before testing. Find people currently needs its feature-branch build; absence from another build is not a functional test result.

The snapshot was already behind main when it was written. On main at `d9d853fa52` (2026-11-20) the registry has 22 flags: rows 1 and 2 exist only on the Find people branch, and row 24, `FF_LARGE_SCREEN_LAYOUT` from #11217, exists only on main. The other 21 rows match on both commits.

Authoritative starting sources:

- [Flag definitions and descriptions](https://github.com/divinevideo/divine-mobile/blob/be97ddad3474c1db7ab94923fb16a44ad308060c/mobile/lib/features/feature_flags/models/feature_flag.dart)
- [Build defaults and environment keys](https://github.com/divinevideo/divine-mobile/blob/be97ddad3474c1db7ab94923fb16a44ad308060c/mobile/lib/features/feature_flags/services/build_configuration.dart)
- [Find people implementation/release context](https://github.com/divinevideo/divine-mobile/pull/11157)

The feature-flags README has an obsolete inventory; use current code and observed behavior. Trace each flag to its actual UI/service call sites. Identify dead flags, incomplete implementations, additional gates outside the central registry, and platform-specific behavior. Internal flags need Developer Mode for local overrides. Reset overrides when establishing defaults, with Developer Mode on: with it off, Reset All leaves stored overrides of internal flags in place, and they take effect again as soon as Developer Mode is turned on.

## Starting inventory

Defaults below describe this source configuration **without build overrides**, not confirmed production settings. “On” features still need regression and flag-retirement assessment.

| # | Feature / key | Code default | QA focus |
|---|---|---|---|
| 1 | Find People — `FF_FIND_PEOPLE` | Off; internal | Explore/empty Following/onboarding entry points; real creator/video pairs; real thumbnails; matching video/profile navigation; follow, dismiss, pagination and exclusions. |
| 2 | Feed People Suggestions — `FF_FEED_PEOPLE_SUGGESTIONS` | Off; internal | Requires both `FF_FIND_PEOPLE` and `FF_FEED_PEOPLE_SUGGESTIONS`. In the native Home feed, verify one slot after ten videos, up to three creators in a carousel with no Load more action, pause/resume, Keep watching, video pagination, late responses and logical video indices. |
| 3 | Short Links — `FF_SHORT_LINKS_SHARING` | On native, off web; internal | Share real video/profile links; resolve externally, across browsers, logged out and with the app installed. Verify web CORS and full-link fallback. |
| 4 | Publishing Ideas — `FF_PUBLISHING_IDEAS` | Off; internal | Meaningful title/description/hashtag ideas, editable and optional; cancellation, service failure, data handling and no unintended publication. |
| 5 | Enhanced Analytics — `FF_ENHANCED_ANALYTICS` | Off | The snapshot defines the flag but has no feature call site. Recheck usage before testing events, destinations, consent, revocation and account isolation. Assess retirement if still unused. |
| 6 | Debug Tools — `FF_DEBUG_TOOLS` | On, for every user | Gates only the "Event JSON" and "Event ID" copy actions in a video's share sheet, under More actions. Check that both copy the complete event and its full ID, and decide whether every user should see them. |
| 7 | Bluesky Publishing — `FF_BLUESKY_PUBLISHING` | Off | Existing approved test connection; actual remote delivery, media/caption fidelity, cancellation, retry and duplicate prevention. Report required new permissions; do not grant them as a workaround. |
| 8 | Integrated Apps — `FF_INTEGRATED_APPS` | Off | Directory and sandbox load; signing/permission boundaries, deny/cancel paths, navigation and app failure. No private-key exposure or silent permission grants. |
| 9 | Account Switching — `FF_ACCOUNT_SWITCHING` | Off | Correct signer/account on reads and writes; remembered-account restoration; follows, blocks, messages, drafts, pending uploads and caches do not cross accounts. |
| 10 | Video Replies — `FF_VIDEO_REPLIES` | On | Record, preview, publish and play a reply; correct parent/thread; cancel/retry/offline; recording permissions and existing account restrictions. |
| 11 | Advanced Relay Settings — `FF_ADVANCED_RELAY_SETTINGS` | Off | Expert configuration/diagnostics, understandable effects, invalid/unreachable relays and recovery to working settings. Assess whether intentional opt-in should remain. |
| 12 | Feed Tuning Swipes — `FF_FEED_TUNING` | Off; internal | Gestures preserve navigation; actual signals reach the recommendation backend; failure/duplicate handling. Backend dependency: [funnelcake #691](https://github.com/divinevideo/divine-funnelcake/issues/691), open at briefing. |
| 13 | Profile Monetization Links — `FF_PROFILE_MONETIZATION_LINKS` | On | Correct profile/destination, valid and malformed links, external navigation, presentation and existing account restrictions. |
| 14 | Community Content Warnings — `FF_COMMUNITY_CONTENT_WARNINGS` | Off; internal | Label submission, thresholds, warning/blur/hide behavior and user preferences across previews/playback. Confirm T&S decision and [#4771](https://github.com/divinevideo/divine-mobile/issues/4771); do not waive policy questions. |
| 15 | New Post Notifications — `FF_NEW_POST_NOTIFICATIONS` | Off | Followed-creator bell through actual push delivery for kind 34236; device permissions, unsubscribe, account switch and duplicate suppression. A saved subscription alone is not success. |
| 16 | Client Seen-Video Filtering — `FF_CLIENT_SEEN_FILTERING` | On | Home demotion versus discovery/classic exclusion; persistence, pagination, account isolation, exhausted feeds and flag-off recovery. |
| 17 | Post-Publish Confirmation Test — `FF_POST_PUBLISH_CONFIRMATION_EXPERIMENT` | On; internal | Assignment and persistence, control behavior, successful publication exactly once, and interaction with the treatment flag. |
| 18 | Post-Publish Confirmation Treatment — `FF_POST_PUBLISH_CONFIRMATION_TREATMENT` | On; internal | All four experiment/treatment combinations; correct View/Share actions and identical-group behavior when treatment is off. Recommend experiment conclusion/cleanup separately from rollout. |
| 19 | Group Messages — `FF_GROUP_MESSAGES` | Off; internal | Create, invite, send, receive and restore a group with QA participants; correct identity/membership and isolation. [#8269](https://github.com/divinevideo/divine-mobile/issues/8269) is open at briefing. |
| 20 | B2 Playback Canary — `FF_B2_PLAYBACK_CANARY` | Always off: the build never reads `FF_B2_PLAYBACK_CANARY`, so a `--dart-define` does nothing; internal device opt-in | Feeds drawn by the shared native-player feed (`FeedVideos`) only, on every platform that feed runs on, web included; operator-approved eligible clips; same rendition, actual selected source, fallback, authenticated denial and cache behavior. Turning it on also starts playback telemetry, signed and sent to the analytics intake only while analytics consent is on: check that no telemetry leaves the device without consent and that the queue resets when the flag or consent is turned off. This is a controlled infrastructure test, not a global release toggle. |
| 21 | Bunny Playback Canary — `FF_BUNNY_PLAYBACK_CANARY` | Always off: the build never reads `FF_BUNNY_PLAYBACK_CANARY`, so a `--dart-define` does nothing; internal device opt-in | Android and iOS only: on web and desktop the feed ignores the path list, so no Bunny source can appear there. Needs an operator-approved private `BUNNY_PLAYBACK_PATHS` list. Verify actual equivalent source/rendition, timeout/503 fallback, denial behavior and no viewer-auth leakage. Test CDN canaries separately; B2 takes precedence if both are on. |
| 22 | Concord Rooms — `FF_CONCORD_CHAT` | On with configured `CONCORD_INVITE_URL`, otherwise off unless explicitly enabled; internal | Public signed community chat, not private DMs: clear visibility, valid/invalid invitation, membership, delivery and navigation. Do not expose invitation secrets. If any path invokes held live/LiveKit functionality, stop that part and mark excluded. |
| 23 | In-App Parent Consent Recording — `FF_MINOR_CONSENT_IN_APP_RECORDING` | Off; also requires `PARENT_CONSENT_DELIVERY_VERIFIED` | Approved test deployment and test participants/media only. Entry points, record/cancel/retry, confirmed receipt, private handling and correct review state. A local preference must not bypass the verified-delivery gate. |
| 24 | Large Screen Layout — `FF_LARGE_SCREEN_LAYOUT` | Off; on main only, not in the snapshot | Tablet and foldable layouts: whole videos instead of cropped ones, more grid columns, rotation on large windows, and side navigation with comments beside the video in landscape. With the flag off every window must lay out as before; with it on, phones stay portrait and only windows past the large breakpoint rotate. Check resize, split-screen and screens that lock portrait. |

## Additional gates and dependencies

Find and report release-affecting gates outside the enum, including backend flags, build configuration and service availability. At minimum examine:

- `CONSUMPTION_ANALYTICS_ENABLED`: followed/engagement/linkability measurements remain held. QA enabling a UI flag does not authorize changing consent or these analytics gates. Distinguish optional telemetry from dependencies that actually block the user flow; propose any separation explicitly for owner review.
- `PARENT_CONSENT_DELIVERY_VERIFIED`, `CONCORD_INVITE_URL` and the CDN enrollment list above: configuration has independent meaning; do not fabricate values to bypass a requirement.
- Backend endpoint and migration availability, platform-specific support, signing/account state and any feature dependencies discovered in call sites.

## Find people: context that needs particular attention

- [Mobile PR #11157](https://github.com/divinevideo/divine-mobile/pull/11157) is still draft at briefing. [Backend PR #1494](https://github.com/divinevideo/divine-funnelcake/pull/1494) merged on 2026-11-18, but a fresh public follow-suggestions endpoint check still returned 404. **Merged code is not a deployed working service.** Verify the actual target environment again.
- Existing screenshots use test-pattern media and staged suggestion responses. They establish layout/state behavior, not real-media or live recommendation integration. Six real thumbnail URLs passed HTTP/JPEG decoding/browser CORS checks separately; a fresh real-media in-app capture was not completed. Do not count that as an end-to-end pass.
- Verify a returned creator owns the preview video, the thumbnail comes from that video, and tapping opens the matching video. Use representative actual media and actual backend responses. Label any staged responses/error injection separately. Evaluate grid and carousel with long names, missing/broken previews and different aspect ratios. Rendering a card must not start a player or count as a video view.
- Test fresh accounts, accounts with follows/mutes/blocks/dismissals, pagination, follow failure, dismissal persistence, account switch, offline/503 recovery and foreground/background exposure. Verify owner-authenticated versus public-fallback behavior without collecting personal viewing histories.
- The [existing T&S review](https://github.com/divinevideo/divine-mobile/pull/11157#pullrequestreview-5940083673) records three unresolved pre-enable decisions: archive-label provenance, thumbnail hide/warn preferences and approved-minor candidate exclusion. Verify their latest dispositions and name the owner/acceptance criteria. QA must not silently waive them or invent a policy choice.
- [Analytics contract PR #203](https://github.com/divinevideo/divine-context/pull/203) remains open at briefing. Check required artifact pins, deployed intake behavior and migration 316 before claiming the associated rollout is ready. UI availability and analytics expansion are separate decisions.

## How to test and judge

1. Exercise the real feature on every supported target: iOS, Android and web where applicable. Record intentional platform limits. Cover fresh/returning users, light/dark appearance, larger text, basic accessibility, navigation, background/resume, restart, slow/offline networks and retry where relevant.
2. Test enabled, disabled and reset-to-default states, including persisted overrides and relevant flag combinations. Identify intended device-scoped versus account-scoped preferences; protect account-scoped data without assuming every developer toggle must reset on account switch.
3. Follow the whole operation to its result. Visible UI, HTTP 200, green CI, a queued job or a published subscription alone does not establish playback, posting, recommendation changes, message delivery or notifications. Trace failures to UI, repository/cache, API, backend, configuration or a missing product decision.
4. Use realistic media and actual service responses for success-path evidence. Mocks and injected failures can supplement it, clearly labeled. Screenshots/clips and network evidence are useful when practical; their absence alone is not a release blocker, but an unexecuted critical flow must be marked unverified.
5. Separate reproducible release blockers from nonblocking polish. Do not add process-only gates. If something cannot be tested, name the missing build/service/configuration and the first step that would unblock testing.

## Required output

Start with a prioritized **release / fix / keep controlled / retire** recommendation list. Use **not verified** when the evidence is insufficient instead of guessing pass or fail.

Return one row per flag, plus every additional gate discovered:

| Feature / flag | Exact build/platform/environment and effective state | What actually ran and result | Release decision | Blocking fixes/dependencies | Owner and acceptance/retest criteria | Recommended flag fate | Evidence |
|---|---|---|---|---|---|---|---|

Flag fate must distinguish **enable by default**, **remove obsolete gate**, **retain rollback control**, and **retain intentional consent/expert/canary control**. An otherwise releasable feature can retain a useful rollback switch.

For each bug, provide severity and whether it blocks release, reproducible steps, expected/actual behavior, user impact, affected layer and evidence. Keep secrets, private messages, raw keys and identity-linked logs out of shared artifacts. Prepare actionable bug drafts; this review does not authorize filing unrelated issues or implementing fixes.

Finish with:

- The smallest sensible release batch and the exact work needed to ship it.
- Features ready for normal availability versus features still missing backend or user-visible functionality.
- Temporary flags/finished experiments that should be removed, and controls worth retaining with a named purpose.
- Specific product/T&S decisions needed, with an owner and concrete question.
- Unverified areas, why they are unverified, and the next test that resolves each gap.

Do not leave an item indefinitely “experimental” without a concrete reason, owner and exit criterion. Do not call the overall audit complete while flags are silently omitted.
