# PRD: Incremental UI Migration from Riverpod to BLoC

Status: Current
Validated against: current mobile architecture direction on 2026-05-20.

## Status
- **Owner:** mobile team
- **State:** In progress
- **Scope:** UI state management migration (incremental, feature-by-feature)

## Problem
The codebase currently uses mixed patterns (Riverpod + BLoC + service notifiers). This increases cognitive load, makes onboarding harder, and causes inconsistent state propagation behavior across screens.

Recent profile/follower issues exposed fragility in layered provider/service paths and motivated a clearer UI-state direction.

## Decision
For UI state, Divine is moving incrementally toward **BLoC/Cubit as the default pattern**.

Riverpod is not being removed everywhere immediately. Existing Riverpod code remains where migration has not yet happened or where non-UI/service-level usage is still stable.

## Why BLoC (for UI)
1. **Explicit event/state flow** makes UI logic easier to reason about and debug.
2. **Feature-local boundaries** reduce hidden coupling from globally watched providers.
3. **Predictable rebuild control** with `BlocBuilder`, `BlocSelector`, and `context.select`.
4. **Better phased migration ergonomics**: convert one feature/screen without a big-bang rewrite.

## Completed Migration Evidence
- **#1282 (merged):** migrate username validation from Riverpod to BLoC
- **#1894 (merged 2026-03-09):** wire `MyProfileBloc` into main profile screen
- **#1903 (merged 2026-03-10):** retire `UserProfileService`; migrate to Drift-backed `ProfileRepository`

## Ownership Boundary (enforced by convention + code review)

Riverpod **owns**:
- App-level dependency injection (repositories, services, clients)
- Long-lived infrastructure side-effects (relay sync, blocklist sync, push token sync)
- DI bridges: `ConsumerWidget` pages that read Riverpod deps and hand them into `BlocProvider`

BLoC/Cubit **owns**:
- All feature UI state
- All UI side effects (navigation triggers, snackbar signals, dialog sequencing)
- All loading/error/success state managed by a screen or feature

## Sanctioned Riverpod (STAYS — not migration targets)

The following files are **DI / infrastructure**, not feature UI state, and are
out of scope for the #4744 Riverpod → BLoC migration. They are baselined by the
`check_changenotifier_boundary.sh` ratchet (#4738) so the list cannot silently
regrow.

**Inclusion criterion:** the file owns infrastructure / a service / a cache /
router-plumbing / preferences; it holds **0 feature UI state**. Migrating it to
a UI BLoC would be the wrong layer.

| File | Role |
|------|------|
| `lib/features/feature_flags/services/feature_flag_service.dart` | Feature-flag service. |
| `lib/router/app_router.dart` | `_StreamListenable extends ChangeNotifier` — GoRouter `refreshListenable` adapter. |
| `lib/services/community_content_label_service.dart` | Per-video community content-warning label cache (#4771). |
| `lib/services/connection_status_service.dart` | Connectivity monitor. |
| `lib/services/content_filter_service.dart` | Adult-content / category filters. |
| `lib/services/curated_list_service.dart` | NIP-51 curated lists. |
| `lib/services/divine_host_filter_service.dart` | Divine-hosted-only filter preference. |
| `lib/services/video_provenance_filter_service.dart` | Capture-verified-only filter preference. |
| `lib/services/environment_service.dart` | Build environment (dev/staging/prod). |
| `lib/services/feed_aspect_ratio_preference_service.dart` | Feed aspect-ratio preference. |
| `lib/services/nip05_verification_service.dart` | NIP-05 verification cache. |
| `lib/services/og_viner_cache_service.dart` | OG Vine cache. |
| `lib/services/pending_action_service.dart` | Offline action queue. |
| `lib/services/relay_statistics_service.dart` | Per-relay stats counters. |
| `lib/services/subscribed_list_video_cache.dart` | Subscribed-list video cache. |
| `lib/services/video_event_service.dart` | Video-event god-object cache. **Dissolved separately by #4338 Track D**, not by #4744. |

The "ChangeNotifier count trends down" outcome of #4744 is delivered by the
#4738 ratchet (no new ones land) and by #4338 Track D (god-object removal) —
**not** by migrating any file in this table.

**Guard scope.** `check_changenotifier_boundary.sh` matches both
`extends ChangeNotifier` and the `with … ChangeNotifier` mixin form, so the
boundary can't be sidestepped with mixin syntax. It scans `mobile/lib/` only —
`mobile/packages/**` is intentionally out of scope: the standalone pub packages
(e.g. `pooled_video_player`, `hls_auth_web_player`) own their own architecture
and are not part of #4744's app-UI-state lane. This mirrors
`check_riverpod_boundary.sh`, which also scans `mobile/lib/` only.

## Allowed / Disallowed Patterns

| Pattern | Verdict | Notes |
|---------|---------|-------|
| `ConsumerWidget` outer Page + `BlocProvider` → `StatelessWidget` inner View | **Allowed** | Canonical bridge. Use `ref.watch` on deps + `ValueKey` guard (see below). |
| `ConsumerWidget` that only creates a `BlocProvider` without reading any Riverpod dep | **Disallowed** | Use plain `StatelessWidget` instead — no Riverpod involvement needed. |
| `ConsumerStatefulWidget` storing UI state in `_state` fields instead of a Cubit | **Disallowed** | Extract the state into a `Cubit`. The widget becomes a `ConsumerWidget` or `StatefulWidget`. |
| New `@riverpod` / `StateProvider` for feature UI state | **Disallowed** | Use `BLoC`/`Cubit` for all new UI state. |
| `*BridgeProvider` as infrastructure side-effect (relay sync, blocklist sync, etc.) | **Allowed with issue link** | Must have a `// TODO(#NNNN):` removal comment. See bridge inventory below. |
| `ref.read` capturing a dep inside `BlocProvider.create` without a `ValueKey` guard | **Disallowed** | Stale dep on auth flip. Use `ref.watch` + `ValueKey((dep1, dep2, ...))` on the `BlocProvider`. |
| `ref.watch` inside `BlocProvider.create` | **Disallowed** | `create` is called once; `ref.watch` has no effect there. Watch in `build`, pass via `ValueKey`. |

### ValueKey guard — required pattern when bridging watched deps

When a `BlocProvider` inside a `ConsumerWidget` captures Riverpod dependencies that can change
(e.g. repository instances that are replaced on auth flip), always supply a `ValueKey` composed
of all captured deps. Flutter will recreate the `BlocProvider` subtree when the key changes,
giving the bloc fresh dependencies and resetting its state intentionally.

```dart
class MySomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(someRepositoryProvider);
    return BlocProvider<SomeBloc>(
      key: ValueKey(repo),                    // ← recreates bloc when repo identity changes
      create: (_) => SomeBloc(repo: repo)..add(const SomeStarted()),
      child: const _SomeView(),
    );
  }
}
```

When multiple deps are captured, use a record:

```dart
key: ValueKey((likesRepo, repostsRepo, eventId, type)),
```

## CI Enforcement (ratchets)

The ownership boundary and disallowed patterns above are enforced in CI by shell
guards under `mobile/scripts/` (run in the `guards` job of
`.github/workflows/mobile_ci.yaml`). `custom_lint` / `riverpod_lint` are
currently disabled by an rxdart version conflict, so enforcement is shell-based.

| Guard | Enforces | Model |
|-------|----------|-------|
| `check_riverpod_boundary.sh` | No new `@riverpod` / `StateProvider` for UI state outside allowed provider dirs | Zero-tolerance (directory exclusion) |
| `check_changenotifier_boundary.sh` | No new `extends ChangeNotifier` or `with … ChangeNotifier` mixin form in `lib/` outside the file allowlist (the "Sanctioned Riverpod (STAYS)" list above); `packages/**` out of scope | Zero-tolerance (file allowlist). Adding a new sanctioned ChangeNotifier requires extending both the docs table and the script's allowlist together. |
| `check_ui_service_boundary.sh` | UI files under `mobile/lib/**/{screens,widgets,view,views}/**` must not import a service (`package:openvine/services/` or relative `../services/`, either quote style) — reach data through a BLoC/Cubit | **True ratchet vs `origin/main`**: NEW (undeclared), STALE (fixed but still baselined), and GROWTH (baseline grew vs `origin/main`) all fail; baseline may only shrink |

**Working with the UI→service ratchet.** Pre-existing violators are frozen in
`mobile/scripts/baseline/ui_service_imports.txt`, and the guard compares the
branch's baseline against `origin/main`'s — so the baseline **cannot grow in-PR**:
adding a new UI→service import and re-running `UPDATE_BASELINE` fails the GROWTH
check. The check **fails closed**: if `origin/main`'s baseline can't be loaded the
guard fails (CI fetches the base ref first); a local/offline run can opt out with
`UI_SERVICE_ALLOW_NO_BASE=1`. The only allowed direction is shrinking. When you migrate a screen/widget
off a direct service import, the guard flags it as stale — regenerate to lock the
win in:

```bash
UPDATE_BASELINE=1 bash mobile/scripts/check_ui_service_boundary.sh
```

A trailing `# reason` documents why an *existing* frozen entry crosses the
boundary; regeneration preserves those annotations for surviving entries. It is
not a way to add new ones (the ratchet is intentionally shrink-only).

## Canonical Template Screens

These three screens are the correct reference implementations to copy from when writing new
bridged screens. Do not invent a new pattern — pick the closest example below.

| Screen | File | Pattern demonstrated |
|--------|------|---------------------|
| `NotificationsPage` | `mobile/lib/notifications/view/notifications_page.dart` | Nullable dep gate: returns loading widget until Riverpod dep is non-null, then creates `BlocProvider` re-keyed on the watched repositories. |
| `AppsDirectoryScreen` | `mobile/lib/screens/apps/apps_directory_screen.dart` | `ref.read` on a stable service (no auth-flip risk); no `ValueKey` needed. |
| `VideoEngagementListScreen` | `mobile/lib/screens/video_engagement/video_engagement_list_screen.dart` | `ref.watch` on auth-sensitive repos with a record `ValueKey` guard; view extracted to `video_engagement_list_view.dart`. |

## Current Bridge Inventory

The following `*BridgeProvider`s are watched in `AppShell.build()` as infrastructure
side-effects. They are **not** UI state — they are long-lived service wiring that has not yet
been moved to a dedicated cubit/service lifecycle. Each is annotated with a removal criterion.
Tracking issue: **#3339**.

| Provider | Purpose | Removal criterion |
|----------|---------|------------------|
| `relayStatisticsBridgeProvider` | Records relay connection events for analytics | Remove when relay management moves to a dedicated cubit/service |
| `relaySetChangeBridgeProvider` | Refreshes feeds when the relay set changes | Remove when feed refresh is driven by a relay event stream in a cubit |
| `notificationPreferencesDirtySyncBridgeProvider` | Syncs notification preferences on auth change | Remove when `NotificationPreferencesCubit` owns this lifecycle |
| `blocklistSyncBridgeProvider` | Syncs block/mute list after login | Remove when `BlocklistCubit` owns post-login sync |

## Migration Model
### Principles
- Prefer BLoC/Cubit for all new UI state logic.
- Migrate touched Riverpod UI paths opportunistically.
- Keep compatibility bridges only as temporary scaffolding.
- Avoid broad rewrites that combine architecture migration with unrelated behavior changes.

### Incremental rollout
1. Identify one feature boundary (e.g., profile, comments, editor controls).
2. Introduce feature bloc + tests.
3. Switch widget tree consumption to bloc selectors/builders.
4. Keep old provider bridge only if still required by adjacent flows.
5. Remove bridge provider once all consumers are migrated.

## Non-goals
- Immediate deletion of all Riverpod usage.
- Rewriting stable non-UI infrastructure purely for pattern uniformity.
- One-PR whole-app migration.

## Definition of Done (per feature)
- Feature UI no longer depends on Riverpod UI providers.
- Event/state transitions covered by bloc unit tests.
- Integration/widget tests pass for migrated flow.
- Any temporary Riverpod bridge usage is documented with removal follow-up.

## Risks and mitigations
- **Risk:** Regression during mixed-mode period.  
  **Mitigation:** phase-by-phase migration, strict tests, no behavior+architecture bundling.

- **Risk:** Team confusion from stale docs.  
  **Mitigation:** mark Riverpod migration docs as historical and point to this PRD + active PRs.

## BLoC Best Practices (VGV + bloclibrary aligned)

This section is intentionally written as implementation guidance for both humans and LLM agents.

### 1) Keep BLoCs feature-scoped and single-purpose
- One feature boundary per bloc/cubit where possible.
- Avoid "god blocs" that own unrelated flows.
- Keep business logic in bloc/repository layers, not in widgets.

### 2) Unidirectional flow and explicit contracts
- Events represent intent (`ProfileRequested`, `ProfileRefreshRequested`).
- States represent renderable outcomes (loading/success/failure/data-updated).
- Favor immutable state objects and equality semantics to avoid noisy rebuilds.

### 3) UI wiring rules
- Use `BlocBuilder` for render state.
- Use `BlocListener` for one-off side effects (navigation/snackbars/dialogs).
- Use `BlocSelector`/`context.select` for fine-grained rebuild control.
- Keep builder functions pure.

### 4) Concurrency/event handling (critical)
- Be explicit about event concurrency behavior when handlers can overlap.
- For user typing/search-like flows, prefer cancellation/restart semantics.
- For idempotent refresh/fetch events, avoid duplicate in-flight work.
- Do not assume global sequential ordering unless explicitly enforced.

### 5) Dependency boundaries
- Inject repositories/services at app/screen boundary (`BlocProvider`/`MultiBlocProvider`).
- UI should not call APIs directly.
- Avoid bloc-to-bloc tight coupling; prefer shared repository streams or higher-level orchestration.

### 6) Testing contract (required)
- `bloc_test` for event→state transitions.
- Widget tests for critical selector/listener behavior.
- Migration PRs should include tests that prove parity with prior behavior.

## Anti-patterns to avoid (especially for LLM-generated code)
- Creating a new bloc when a feature-local existing bloc should be extended.
- Putting network calls and parsing directly in widgets.
- Emitting many transient states that trigger full subtree rebuilds.
- Mixing migration with unrelated refactors in the same PR.
- Keeping temporary Riverpod bridges without TODO/issue linkage.

## External references
- VGV: Why we use flutter_bloc  
  https://www.verygood.ventures/blog/why-we-use-flutter-bloc
- VGV: BLoC streams and concurrency  
  https://www.verygood.ventures/blog/how-to-use-bloc-with-streams-and-concurrency
- bloclibrary/flutter_bloc package docs  
  https://pub.dev/packages/flutter_bloc

## Documentation policy update
When migration direction changes, docs must be updated in the same PR (or a paired docs PR) to avoid contradictory guidance.
