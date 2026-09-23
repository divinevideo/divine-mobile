# Crossposting CTAs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface Divine's already-built crossposting feature with brand-aligned CTAs in settings, the per-video share menu, and the post-publish flow, and remove the web-setup hops that break the native flow.

**Architecture:** Keep the existing `CrosspostingSettingsCubit` (settings) and `VideoCrosspostCubit` (share menu) as mutation owners. Add a shared client-side platform-visibility rule (hides X), replace the boolean eligibility gate with a tri-state availability provider, and add presentational CTA widgets that read those. No new data source: the post-publish Share action is routed into the existing in-app share menu by resolving the just-published `VideoEvent` from local storage.

**Tech Stack:** Flutter (Dart), flutter_bloc, flutter_riverpod, go_router, url_launcher, mocktail, `divine_ui` package, Firebase Analytics via `analytics` package.

**Spec:** `docs/superpowers/specs/2026-09-23-crossposting-cta-design.md`

## Global Constraints

- Run all Flutter commands from `mobile/` (the repo's Flutter root).
- Work in the existing worktree `.worktrees/crossposting-cta` on branch `feat/crossposting-cta`.
- Brand name is **Divine** — capital D, lowercase rest. Never "DiVine" or "diVine" in copy.
- Copy follows `brand-guidelines/TONE_OF_VOICE.md`: candid, collective, a little punk, active voice, benefits over features, no corporate speak. Never promise crossposting growth on TikTok/Instagram/YouTube (those platforms suppress watermarks and outbound links).
- Never add watermarking.
- Every new string is a new `app_en.arb` key read through `context.l10n` in the same change. Mirror into the other 21 `app_*.arb` locales, or add to `_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart`. Run `flutter test test/l10n/arb_consistency_test.dart`.
- New UI must use `context.vineColors.*`, `VineTheme.*Font()`, and `divine_ui` components. No raw `Colors.*`, no raw `TextStyle(`, no direct Material buttons.
- No new `Future.delayed()` in `mobile/lib`. Use `unawaited()` only for fire-and-forget work with internal error handling.
- Every test declaration lives inside a `group()`. New test files mirror `lib/` under `mobile/test/`. Never add under `mobile/test/unit/`.
- Commit messages use Conventional Commits: `type(scope): summary`.
- Reference the X OAuth tracking issue in Task 1.

---

## File Structure

Created:

- `mobile/lib/features/crossposting/crossposting_analytics.dart` — the one analytics helper.
- `mobile/lib/widgets/crossposting/crossposting_benefit_card.dart` — settings benefit CTA.
- `mobile/lib/widgets/crossposting/crossposting_auto_card.dart` — settings automatic-mode CTA.

Modified:

- `mobile/lib/services/crossposting_api_client.dart` — `CrosspostingPlatform.isVisibleInApp`.
- `mobile/lib/repositories/crossposting_repository.dart` — filter invisible platforms.
- `mobile/lib/blocs/video_crosspost/video_crosspost_cubit.dart` — filter invisible platforms.
- `mobile/lib/providers/crossposting_providers.dart` — tri-state availability + web opener.
- `mobile/lib/screens/settings/general_settings_screen.dart` — tile gate.
- `mobile/lib/screens/settings/crossposting_settings_screen.dart` — screen guard + cards.
- `mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart` — always-visible Crosspost row.
- `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart` — zero-connection dispatch.
- `mobile/lib/widgets/crosspost_sheet.dart` — native reconnect.
- `mobile/lib/startup/upload_failure_listener.dart` — post-publish Share into in-app menu.
- `mobile/lib/l10n/app_en.arb` (+ 21 locales) — new keys.

---

### Task 1: Hide X client-side behind a shared visibility rule

**Files:**
- Modify: `mobile/lib/services/crossposting_api_client.dart`
- Modify: `mobile/lib/repositories/crossposting_repository.dart`
- Modify: `mobile/lib/blocs/video_crosspost/video_crosspost_cubit.dart`
- Test: `mobile/test/repositories/crossposting_repository_test.dart`
- Test: `mobile/test/blocs/video_crosspost/video_crosspost_cubit_test.dart`

**Interfaces:**
- Produces: `bool CrosspostingPlatform.isVisibleInApp`.
- Consumes: nothing from earlier tasks.

- [ ] **Step 0: Open the tracking issue for the server-side X OAuth fix**

```bash
cd /Users/rabble/code/divine/divine-mobile
gh issue create --repo divinevideo/divine-mobile \
  --title "fix(crossposting): X OAuth connect never completes" \
  --body "X reports as enabled from crossposter.divine.video but the connect round trip has never completed. The mobile app hides X client-side until this is fixed. See divine-connections docs/crossposting-roadmap.md and cutover-secrets.md for the missing X developer-portal configuration."
```

Record the returned issue number; Task 1 Step 1 and Task 3 reference it as `#<N>`.

- [ ] **Step 1: Add the visibility predicate**

In `mobile/lib/services/crossposting_api_client.dart`, inside `enum CrosspostingPlatform`, after `fromWireName`:

```dart
  /// Whether this build offers the platform at all.
  ///
  /// X's OAuth connect has never completed end to end while the service still
  /// reports it enabled, so offering it would dead-end the user. Remove this
  /// exclusion once the server-side X OAuth fix lands (#<N>).
  bool get isVisibleInApp => this != CrosspostingPlatform.x;
```

- [ ] **Step 2: Write the failing repository test**

In `mobile/test/repositories/crossposting_repository_test.dart`, inside the existing `group(CrosspostingRepository, ...)`:

```dart
    test('drops platforms that are not visible in the app', () async {
      when(apiClient.getPlatforms).thenAnswer(
        (_) async => const [
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.instagram,
            enabled: true,
            supportsAutomatic: true,
          ),
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.x,
            enabled: true,
            supportsAutomatic: true,
          ),
        ],
      );
      when(apiClient.getConnections).thenAnswer((_) async => const []);
      when(apiClient.getPreferences).thenAnswer((_) async => const []);

      final entries = await repository.loadSettings();

      expect(
        entries.map((entry) => entry.platform),
        equals([CrosspostingPlatform.instagram]),
      );
    });
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd mobile && flutter test test/repositories/crossposting_repository_test.dart`
Expected: FAIL — the returned list contains `x`.

- [ ] **Step 4: Filter in the repository**

In `mobile/lib/repositories/crossposting_repository.dart`, change `loadSettings`'s comprehension condition:

```dart
      for (final platformInfo in platforms)
        if (platformInfo.enabled && platformInfo.platform.isVisibleInApp)
          _settingsFor(platformInfo, connections, preferences),
```

- [ ] **Step 5: Run the repository test to verify it passes**

Run: `cd mobile && flutter test test/repositories/crossposting_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing cubit test**

In `mobile/test/blocs/video_crosspost/video_crosspost_cubit_test.dart`, inside the existing group, following the file's existing `buildCubit` + `blocTest` pattern:

```dart
    blocTest<VideoCrosspostCubit, VideoCrosspostState>(
      'drops connections for platforms that are not visible in the app',
      build: () {
        when(apiClient.getConnections).thenAnswer(
          (_) async => const [
            CrosspostingConnection(
              id: 'ig',
              platform: CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
            ),
            CrosspostingConnection(
              id: 'x',
              platform: CrosspostingPlatform.x,
              status: CrosspostingConnectionStatus.connected,
            ),
          ],
        );
        return buildCubit();
      },
      act: (cubit) => cubit.loadConnections(),
      verify: (cubit) {
        expect(
          cubit.state.connections.map((c) => c.platform),
          equals([CrosspostingPlatform.instagram]),
        );
      },
    );
```

- [ ] **Step 7: Run the cubit test to verify it fails**

Run: `cd mobile && flutter test test/blocs/video_crosspost/video_crosspost_cubit_test.dart`
Expected: FAIL — both connections are present.

- [ ] **Step 8: Filter in the cubit**

In `mobile/lib/blocs/video_crosspost/video_crosspost_cubit.dart`, replace the fetch in `loadConnections`:

```dart
      final connections = [
        for (final connection in await _client.getConnections())
          if (connection.platform.isVisibleInApp) connection,
      ];
```

- [ ] **Step 9: Run both tests to verify they pass**

Run: `cd mobile && flutter test test/repositories/crossposting_repository_test.dart test/blocs/video_crosspost/video_crosspost_cubit_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/services/crossposting_api_client.dart \
  mobile/lib/repositories/crossposting_repository.dart \
  mobile/lib/blocs/video_crosspost/video_crosspost_cubit.dart \
  mobile/test/repositories/crossposting_repository_test.dart \
  mobile/test/blocs/video_crosspost/video_crosspost_cubit_test.dart
git commit -m "feat(crossposting): hide X in-app until its OAuth connect works"
```

---

### Task 2: Replace the boolean eligibility gate with tri-state availability

**Files:**
- Modify: `mobile/lib/providers/crossposting_providers.dart`
- Modify: `mobile/lib/screens/settings/general_settings_screen.dart`
- Modify: `mobile/lib/screens/settings/crossposting_settings_screen.dart`
- Test: `mobile/test/providers/crossposting_providers_test.dart`
- Test: `mobile/test/screens/settings/general_settings_screen_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `enum CrosspostingAvailability { native, webOnly, unavailable }`; `final crosspostingAvailabilityProvider = Provider<CrosspostingAvailability>`; `typedef CrosspostingWebOpener = Future<bool> Function(Uri url)`; `final crosspostingWebOpenerProvider = Provider<CrosspostingWebOpener>`.
- Removes: `crosspostingEligibleProvider`.

- [ ] **Step 1: Write the failing provider tests**

Replace the `group('crosspostingEligibleProvider', ...)` block in `mobile/test/providers/crossposting_providers_test.dart` with:

```dart
  group('crosspostingAvailabilityProvider', () {
    ProviderContainer buildContainer({
      bool oauthSupported = true,
      bool resolveSupport = true,
      bool authenticated = true,
      bool registered = true,
    }) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(registered);
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(
            authenticated ? AuthState.authenticated : AuthState.unauthenticated,
          ),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async {
            if (!resolveSupport) return Completer<bool>().future;
            return oauthSupported;
          }),
        ],
      );
    }

    test('is native when authenticated and OAuth is supported', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.native,
      );
    });

    test('is webOnly when OAuth is unsupported', () async {
      final container = buildContainer(oauthSupported: false);
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is webOnly while the support lookup is unresolved', () async {
      final container = buildContainer(resolveSupport: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is unavailable when signed out', () async {
      final container = buildContainer(authenticated: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );
    });

    test('is unavailable when the account is not registered', () async {
      final container = buildContainer(registered: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );
    });
  });
```

- [ ] **Step 2: Run the provider tests to verify they fail**

Run: `cd mobile && flutter test test/providers/crossposting_providers_test.dart`
Expected: FAIL — `crosspostingAvailabilityProvider` is not defined.

- [ ] **Step 3: Add the enum, provider, and web opener**

In `mobile/lib/providers/crossposting_providers.dart`, replace `crosspostingEligibleProvider` with:

```dart
/// How this build can drive the crossposting connect flow.
enum CrosspostingAvailability {
  /// Authenticated and in-app OAuth works; connect inside the app.
  native,

  /// Authenticated, but in-app OAuth cannot deliver the callback (iOS < 17.4,
  /// or the system version could not be determined). Connect on the web.
  webOnly,

  /// Signed out or not registered; show no crossposting CTA.
  unavailable,
}

/// Opens the crossposter web setup page; the fallback when in-app OAuth is
/// unsupported.
typedef CrosspostingWebOpener = Future<bool> Function(Uri url);

final crosspostingWebOpenerProvider = Provider<CrosspostingWebOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});

final crosspostingAvailabilityProvider = Provider<CrosspostingAvailability>((
  ref,
) {
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final registered =
      authState == AuthState.authenticated &&
      authService.currentPublicKeyHex != null &&
      authService.isRegistered;
  if (!registered) return CrosspostingAvailability.unavailable;
  // Fail to webOnly, not unavailable: an unresolved lookup must not hide the
  // feature, and the web page is a working connect path regardless.
  final oauthSupported = ref.watch(appOAuthSupportProvider).value ?? false;
  return oauthSupported
      ? CrosspostingAvailability.native
      : CrosspostingAvailability.webOnly;
});
```

Add the import at the top of the file (keep the existing imports):

```dart
import 'package:url_launcher/url_launcher.dart';
```

- [ ] **Step 4: Update the settings tile gate**

In `mobile/lib/screens/settings/general_settings_screen.dart`, change the `showCrossposting` computation:

```dart
    final showCrossposting =
        ref.watch(crosspostingAvailabilityProvider) !=
        CrosspostingAvailability.unavailable;
```

- [ ] **Step 5: Update the settings screen guard**

In `mobile/lib/screens/settings/crossposting_settings_screen.dart`, change the top guard:

```dart
    if (ref.watch(crosspostingAvailabilityProvider) ==
        CrosspostingAvailability.unavailable) {
```

- [ ] **Step 6: Update the general-settings test override**

In `mobile/test/screens/settings/general_settings_screen_test.dart`, replace every `crosspostingEligibleProvider.overrideWithValue(...)` with:

```dart
          crosspostingAvailabilityProvider.overrideWithValue(
            CrosspostingAvailability.native,
          ),
```

and add `import 'package:openvine/providers/crossposting_providers.dart';` if absent.

- [ ] **Step 7: Run the affected tests**

Run: `cd mobile && flutter test test/providers/crossposting_providers_test.dart test/screens/settings/general_settings_screen_test.dart test/screens/settings/crossposting_settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/providers/crossposting_providers.dart \
  mobile/lib/screens/settings/general_settings_screen.dart \
  mobile/lib/screens/settings/crossposting_settings_screen.dart \
  mobile/test/providers/crossposting_providers_test.dart \
  mobile/test/screens/settings/general_settings_screen_test.dart
git commit -m "feat(crossposting): replace eligibility boolean with tri-state availability"
```

---

### Task 3: Settings benefit and automatic-mode CTAs

**Files:**
- Create: `mobile/lib/widgets/crossposting/crossposting_benefit_card.dart`
- Create: `mobile/lib/widgets/crossposting/crossposting_auto_card.dart`
- Modify: `mobile/lib/screens/settings/crossposting_settings_screen.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Test: `mobile/test/screens/settings/crossposting_settings_screen_test.dart`

**Interfaces:**
- Consumes: `crosspostingAvailabilityProvider`, `crosspostingWebOpenerProvider` (Task 2).
- Produces: `class CrosspostingBenefitCard extends ConsumerWidget` with `const CrosspostingBenefitCard({required CrosspostingPlatform platform, super.key})`; `class CrosspostingAutoCard extends ConsumerWidget` with `const CrosspostingAutoCard({required CrosspostingPlatform platform, super.key})`.

- [ ] **Step 1: Add the ARB keys**

In `mobile/lib/l10n/app_en.arb`, add:

```json
  "crosspostingBenefitTitle": "Take your loops everywhere",
  "@crosspostingBenefitTitle": {
    "description": "Headline of the crossposting benefit card in settings"
  },
  "crosspostingBenefitBody": "Post once on Divine, share straight to Instagram. Your people are already out there — go meet them. Every loop you send carries a little link home, so the next creator finds us too.",
  "@crosspostingBenefitBody": {
    "description": "Body of the crossposting benefit card in settings"
  },
  "crosspostingBenefitConnect": "Connect {platform}",
  "@crosspostingBenefitConnect": {
    "description": "Primary action on the crossposting benefit card",
    "placeholders": {
      "platform": { "type": "String", "example": "Instagram" }
    }
  },
  "crosspostingAutoTitle": "Set it once",
  "@crosspostingAutoTitle": {
    "description": "Headline of the automatic crossposting encouragement card"
  },
  "crosspostingAutoBody": "Every new loop you post goes out to {platform} for you — no extra taps. Only applies to loops you publish after you turn it on.",
  "@crosspostingAutoBody": {
    "description": "Body of the automatic crossposting encouragement card",
    "placeholders": {
      "platform": { "type": "String", "example": "Instagram" }
    }
  },
  "crosspostingAutoEnable": "Turn on automatic",
  "@crosspostingAutoEnable": {
    "description": "Action that switches a platform to automatic crossposting"
  },
```

- [ ] **Step 2: Regenerate localizations**

Run: `cd mobile && flutter gen-l10n`
Expected: `mobile/lib/l10n/generated/` regenerated with the new getters.

- [ ] **Step 3: Write the failing benefit-card test**

In `mobile/test/screens/settings/crossposting_settings_screen_test.dart`, inside the screen group, add (the file's `buildApp` and `_defaultEntries` already exist; `_defaultEntries` must be modified in this task — see Step 6):

```dart
    testWidgets('shows the benefit card when nothing is connected', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => const [
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.instagram,
            supportsAutomatic: true,
            mode: CrosspostingMode.disabled,
          ),
        ],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingBenefitTitle), findsOneWidget);
      expect(
        find.text(l10n.crosspostingBenefitConnect('Instagram')),
        findsOneWidget,
      );
    });
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/settings/crossposting_settings_screen_test.dart --plain-name "shows the benefit card"`
Expected: FAIL — the benefit title is not found.

- [ ] **Step 5: Create the benefit card widget**

Create `mobile/lib/widgets/crossposting/crossposting_benefit_card.dart`:

```dart
// ABOUTME: Benefit-forward CTA shown in crossposting settings when nothing
// ABOUTME: is connected yet, routing to native OAuth or the web fallback.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/crossposting_api_client.dart';

/// Encourages a creator with no connected platform to connect one.
class CrosspostingBenefitCard extends ConsumerWidget {
  const CrosspostingBenefitCard({required this.platform, super.key});

  final CrosspostingPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DivineInfoCard(
        icon: DivineIconName.shareNetwork,
        title: context.l10n.crosspostingBenefitTitle,
        message: context.l10n.crosspostingBenefitBody,
        footer: DivineButton(
          label: context.l10n.crosspostingBenefitConnect(platform.displayName),
          expanded: true,
          onPressed: () => _connect(context, ref),
        ),
      ),
    );
  }

  void _connect(BuildContext context, WidgetRef ref) {
    if (ref.read(crosspostingAvailabilityProvider) ==
        CrosspostingAvailability.webOnly) {
      ref.read(crosspostingWebOpenerProvider)(
        Uri.parse(AppConfig.crossposterBaseUrl),
      );
      return;
    }
    context.read<CrosspostingSettingsCubit>().connect(platform);
  }
}
```

- [ ] **Step 6: Render the benefit card in the settings list**

In `mobile/lib/screens/settings/crossposting_settings_screen.dart`, replace `_LoadedSettingsList.build`'s `ListView.separated` with a plain `ListView`:

```dart
    return RefreshIndicator(
      color: context.vineColors.accentPositive,
      backgroundColor: context.vineColors.surfaceContainer,
      onRefresh: context.read<CrosspostingSettingsCubit>().refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: DivineButton(
                label: refreshLabel,
                size: DivineButtonSize.small,
                type: DivineButtonType.secondary,
                leadingIcon: DivineIconName.arrowClockwise,
                onPressed: state.hasPendingAction
                    ? null
                    : context.read<CrosspostingSettingsCubit>().refresh,
              ),
            ),
          ),
          if (state.entries.isNotEmpty &&
              state.entries.every((entry) => !entry.isConnected))
            CrosspostingBenefitCard(platform: state.entries.first.platform),
          for (final entry in state.entries) ...[
            Divider(height: 1, color: context.vineColors.outlineMuted),
            _PlatformSection(entry: entry, state: state),
          ],
        ],
      ),
    );
```

Add the import `import 'package:openvine/widgets/crossposting/crossposting_benefit_card.dart';`.

Then update `_defaultEntries` in the test file so the pre-existing tests keep their connected state; leave it unchanged (it already represents connected platforms) and only the new test overrides it. If `_defaultEntries` has all-disconnected entries and other tests break, adjust those tests' setups, not `_defaultEntries`.

- [ ] **Step 7: Run the benefit-card test to verify it passes**

Run: `cd mobile && flutter test test/screens/settings/crossposting_settings_screen_test.dart --plain-name "shows the benefit card"`
Expected: PASS.

- [ ] **Step 8: Write the failing auto-card test**

Add to the same test file:

```dart
    testWidgets('encourages automatic mode for a connected manual platform', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => const [
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.instagram,
            supportsAutomatic: true,
            mode: CrosspostingMode.manual,
            connection: CrosspostingConnection(
              id: 'ig',
              platform: CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingAutoTitle), findsOneWidget);
      await tester.tap(find.text(l10n.crosspostingAutoEnable));
      await tester.pump();
      verify(
        () => repository.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        ),
      ).called(1);
    });
```

- [ ] **Step 9: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/settings/crossposting_settings_screen_test.dart --plain-name "encourages automatic mode"`
Expected: FAIL — the auto title is not found.

- [ ] **Step 10: Create the auto card widget**

Create `mobile/lib/widgets/crossposting/crossposting_auto_card.dart`:

```dart
// ABOUTME: Encourages switching a connected platform to automatic
// ABOUTME: crossposting, with an honest forward-looking-only qualifier.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Promotes automatic mode for a connected platform currently off or manual.
class CrosspostingAutoCard extends ConsumerWidget {
  const CrosspostingAutoCard({required this.platform, super.key});

  final CrosspostingPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DivineInfoCard(
        icon: DivineIconName.arrowsClockwise,
        title: context.l10n.crosspostingAutoTitle,
        message: context.l10n.crosspostingAutoBody(platform.displayName),
        footer: DivineButton(
          label: context.l10n.crosspostingAutoEnable,
          expanded: true,
          onPressed: () => context
              .read<CrosspostingSettingsCubit>()
              .setMode(platform, CrosspostingMode.automatic),
        ),
      ),
    );
  }
}
```

- [ ] **Step 11: Render the auto card**

In `_LoadedSettingsList.build`, compute the target and insert the card before the platform rows:

```dart
    CrosspostingPlatformSettings? autoTarget;
    for (final entry in state.entries) {
      if (entry.isConnected &&
          entry.supportsAutomatic &&
          entry.mode != CrosspostingMode.automatic) {
        autoTarget = entry;
        break;
      }
    }
```

Then, in the `children` list, after the benefit card:

```dart
          if (autoTarget != null)
            CrosspostingAutoCard(platform: autoTarget.platform),
```

Add `import 'package:openvine/widgets/crossposting/crossposting_auto_card.dart';`.

- [ ] **Step 12: Run both new tests to verify they pass**

Run: `cd mobile && flutter test test/screens/settings/crossposting_settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/widgets/crossposting/crossposting_benefit_card.dart \
  mobile/lib/widgets/crossposting/crossposting_auto_card.dart \
  mobile/lib/screens/settings/crossposting_settings_screen.dart \
  mobile/lib/l10n/app_en.arb mobile/lib/l10n/generated \
  mobile/test/screens/settings/crossposting_settings_screen_test.dart
git commit -m "feat(crossposting): add settings benefit and automatic-mode CTAs"
```

---

### Task 4: Share-menu Crosspost row always visible, and native reconnect

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart`
- Modify: `mobile/lib/widgets/crosspost_sheet.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/share_action_button_test.dart`
- Test: `mobile/test/widgets/crosspost_sheet_test.dart`

**Interfaces:**
- Consumes: `crosspostingAvailabilityProvider`, `crosspostingWebOpenerProvider` (Task 2).
- Produces: no new public API.

- [ ] **Step 1: Write the failing share-row tests**

In `mobile/test/widgets/video_feed_item/actions/share_action_button_test.dart`, inside the existing `group('owner actions', ...)` (its `l10n` and `pumpOwnerSheet` helpers already exist), add:

```dart
        testWidgets('offers Crosspost when nothing is connected', (
          tester,
        ) async {
          await pumpOwnerSheet(tester);

          expect(find.text(l10n.shareSheetCrosspost), findsOneWidget);
        });

        testWidgets('Crosspost routes to settings with no connections', (
          tester,
        ) async {
          final goRouter = MockGoRouter();
          when(
            () => goRouter.push<void>(any(), extra: any(named: 'extra')),
          ).thenAnswer((_) async {});

          await pumpOwnerSheet(tester, goRouter: goRouter);

          await tester.tap(find.text(l10n.shareSheetCrosspost));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          verify(
            () => goRouter.push<void>(RoutePaths.crosspostingSettings),
          ).called(1);
        });
```

Add `import 'package:openvine/router/route_paths.dart';` to the test file. The share-menu test's connections come back empty because the test does not stub `crossposterApiClientProvider`, so `connectedConnections` is empty.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/widgets/video_feed_item/actions/share_action_button_test.dart`
Expected: FAIL — the Crosspost row is absent with zero connections.

- [ ] **Step 3: Always render the row**

In `mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart`, delete the `connectedCrosspostPlatforms` selection (lines 56-63) and change the condition at the Crosspost entry:

```dart
      if (onCrosspost != null)
        _ActionData(
          icon: DivineIconName.arrowsClockwise,
          label: context.l10n.shareSheetCrosspost,
          onTap: () => onCrosspost!.call(),
        ),
```

Remove the now-unused `VideoCrosspostCubit` selection. If the import becomes unused, remove it.

- [ ] **Step 4: Dispatch on connection state**

In `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart`, replace `_handleCrosspost`:

```dart
  Future<void> _handleCrosspost() async {
    final connections =
        _crosspostCubit?.state.connectedConnections ??
        const <CrosspostingConnection>[];
    if (connections.isNotEmpty) {
      await _presentAfterDismiss<void>((hostContext) {
        return showCrosspostSheet(
          context: hostContext,
          ref: ref,
          video: widget.video,
          connections: connections,
        );
      });
      return;
    }

    final availability = ref.read(crosspostingAvailabilityProvider);
    _safePop(context);
    if (availability == CrosspostingAvailability.webOnly) {
      await ref.read(crosspostingWebOpenerProvider)(
        Uri.parse(AppConfig.crossposterBaseUrl),
      );
      return;
    }
    ref.read(goRouterProvider).push(RoutePaths.crosspostingSettings);
  }
```

Add imports as needed: `dart:async` (for `unawaited`), `package:openvine/config/app_config.dart`, `package:openvine/providers/crossposting_providers.dart`, `package:openvine/router/route_paths.dart`, `package:openvine/router/router.dart`, and `package:openvine/blocs/video_crosspost/video_crosspost_state.dart` (re-exports `CrosspostingConnection`).

- [ ] **Step 5: Run the share-row test to verify it passes**

Run: `cd mobile && flutter test test/widgets/video_feed_item/actions/share_action_button_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing reconnect test**

In `mobile/test/widgets/crosspost_sheet_test.dart`, add to the `group(CrosspostSheetView, ...)`:

```dart
    testWidgets('reconnect runs the supplied callback', (tester) async {
      var reconnected = false;
      when(() => cubit.state).thenReturn(
        const VideoCrosspostState(
          status: VideoCrosspostStatus.finished,
          jobs: [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.needsReauth,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoCrosspostCubit>.value(
              value: cubit,
              child: CrosspostSheetView(onReconnect: () => reconnected = true),
            ),
          ),
        ),
      );

      await tester.tap(find.text(l10n.crosspostReconnect));
      await tester.pump();

      expect(reconnected, isTrue);
    });
```

- [ ] **Step 7: Run the test to verify it fails**

Run: `cd mobile && flutter test test/widgets/crosspost_sheet_test.dart --plain-name "reconnect runs the supplied callback"`
Expected: FAIL — `CrosspostSheetView` has no `onReconnect` parameter.

- [ ] **Step 8: Make reconnect a supplied callback that routes natively**

In `mobile/lib/widgets/crosspost_sheet.dart`, give `CrosspostSheetView` an optional `onReconnect` and thread it to `_ReconnectPrompt`:

```dart
class CrosspostSheetView extends StatelessWidget {
  @visibleForTesting
  const CrosspostSheetView({this.onReconnect, super.key});

  final VoidCallback? onReconnect;
```

Then in its body, pass `onReconnect: onReconnect` where `_ReconnectPrompt` is built (the `CrosspostJobStatus.needsReauth` branch), and change `_ReconnectPrompt` to a plain `StatelessWidget`:

```dart
class _ReconnectPrompt extends StatelessWidget {
  const _ReconnectPrompt({required this.platformName, required this.onReconnect});

  final String platformName;
  final VoidCallback? onReconnect;
```

with the button:

```dart
        DivineButton(
          label: context.l10n.crosspostReconnect,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: onReconnect,
        ),
```

Finally, `showCrosspostSheet` builds the callback (it already receives `WidgetRef ref`), so `_ReconnectPrompt` needs no Riverpod or router dependency of its own:

```dart
    body: BlocProvider(
      create: (_) => VideoCrosspostCubit(
        client: client,
        eventId: video.id,
        initialConnections: connections,
      ),
      child: CrosspostSheetView(
        onReconnect: () {
          Navigator.of(context).pop();
          if (ref.read(crosspostingAvailabilityProvider) ==
              CrosspostingAvailability.webOnly) {
            ref.read(crosspostingWebOpenerProvider)(
              Uri.parse(AppConfig.crossposterBaseUrl),
            );
            return;
          }
          ref.read(goRouterProvider).push(RoutePaths.crosspostingSettings);
        },
      ),
    ),
```

Add imports `package:openvine/providers/crossposting_providers.dart`, `package:openvine/router/route_paths.dart`, and `package:openvine/router/router.dart`. Keep `url_launcher` (still used by `_ViewPostLink`).

- [ ] **Step 9: Run both tests to verify they pass**

Run: `cd mobile && flutter test test/widgets/crosspost_sheet_test.dart test/widgets/video_feed_item/actions/share_action_button_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart \
  mobile/lib/widgets/video_feed_item/actions/share_action_button.dart \
  mobile/lib/widgets/crosspost_sheet.dart \
  mobile/test/widgets/video_feed_item/actions/share_action_button_test.dart \
  mobile/test/widgets/crosspost_sheet_test.dart
git commit -m "feat(crossposting): always offer crosspost in the share menu and reconnect natively"
```

---

### Task 5: Post-publish Share opens the in-app share menu

**Files:**
- Modify: `mobile/lib/startup/upload_failure_listener.dart`
- Test: `mobile/test/widgets/upload_failure_listener_test.dart`

**Interfaces:**
- Consumes: `videoEventServiceProvider.getVideoEventByVineId(String)`; `ShareActionButton.showShareSheet(BuildContext, VideoEvent)`.
- Produces: no new public API.

- [ ] **Step 1: Add overrides to the harness and write the failing tests**

Add an `additionalOverrides` parameter to `_buildHarness` in `mobile/test/widgets/upload_failure_listener_test.dart`:

```dart
Widget _buildHarness({
  required _MockBackgroundPublishBloc publishBloc,
  required _MockAuthService authService,
  bool wireRootNavigatorKey = true,
  PostPublishExperiment? experiment,
  GoRouter? router,
  List<Override> additionalOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      if (experiment != null)
        postPublishExperimentProvider.overrideWithValue(experiment),
      if (router != null) goRouterProvider.overrideWithValue(router),
      ...additionalOverrides,
    ],
    // ...unchanged below
```

Declare these near the other test doubles:

```dart
class _MockVideoSharingService extends Mock implements VideoSharingService {}
class _FakeVideoEvent extends Fake implements VideoEvent {}
```

Add `registerFallbackValue(_FakeVideoEvent());` to the file's `setUpAll`, plus imports for `package:models/models.dart`, `package:openvine/services/video_sharing_service.dart`, `videoEventServiceProvider`, `videoSharingServiceProvider`, `profileReadRepositoryProvider` from `package:openvine/providers/app_providers.dart`, and `createMockProfileRepository`, `createMockVideoEventService` from `../../../helpers/test_provider_overrides.dart`.

Then add these two tests in the treatment-arm group:

```dart
    testWidgets('Share opens the in-app share menu when the event resolves', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');
      final videoEventService = createMockVideoEventService();
      when(
        () => videoEventService.getVideoEventByVineId(any()),
      ).thenReturn(_FakeVideoEvent());

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
          additionalOverrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
            profileReadRepositoryProvider.overrideWithValue(
              createMockProfileRepository(),
            ),
            videoSharingServiceProvider.overrideWithValue(
              _MockVideoSharingService(),
            ),
          ],
        ),
      );

      publishStream.add(_succeededState('draft-treatment'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.postPublishConfirmationShare));
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareSheetMoreActions), findsOneWidget);
      verify(
        () => videoEventService.getVideoEventByVineId(_publishedStableId),
      ).called(1);
    });

    testWidgets('Share falls back when the event cannot be resolved', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');
      final videoEventService = createMockVideoEventService();
      when(
        () => videoEventService.getVideoEventByVineId(any()),
      ).thenReturn(null);

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
          additionalOverrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        ),
      );

      publishStream.add(_succeededState('draft-treatment'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.postPublishConfirmationShare));
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareSheetMoreActions), findsNothing);
    });
```

If a provider override's static type does not match the provider declaration, follow the types used in `share_action_button_test.dart` (which wires the same dependencies through `testMaterialApp`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/widgets/upload_failure_listener_test.dart`
Expected: FAIL — the in-app share menu is not shown.

- [ ] **Step 3: Resolve the event and route Share**

In `mobile/lib/startup/upload_failure_listener.dart`, replace `_onConfirmationShare`:

```dart
void _onConfirmationShare(
  BuildContext context,
  ProviderContainer container,
  PostPublishConfirmationOffer offer,
  String stableId,
) {
  unawaited(container.read(postPublishExperimentProvider).shareTapped(offer));
  // The in-app share menu needs a hydrated VideoEvent, which a relay usually
  // cannot serve seconds after publish. The publisher already wrote the signed
  // event into VideoEventService (video_event_publisher.dart), so resolve it
  // locally and fall back to the OS sheet only when it is genuinely absent.
  final video = container
      .read(videoEventServiceProvider)
      .getVideoEventByVineId(stableId);
  if (video != null) {
    ShareActionButton.showShareSheet(context, video);
    return;
  }
  unawaited(
    showShareSheet(
      context,
      ShareParams(text: VideoSharingService.shareUrlForStableId(stableId)),
    ),
  );
}
```

Add the import `package:openvine/widgets/video_feed_item/actions/share_action_button.dart`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/widgets/upload_failure_listener_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/startup/upload_failure_listener.dart \
  mobile/test/widgets/upload_failure_listener_test.dart
git commit -m "feat(crossposting): route post-publish Share into the in-app share menu"
```

---

### Task 6: Analytics for CTA taps

**Files:**
- Create: `mobile/lib/features/crossposting/crossposting_analytics.dart`
- Modify: `mobile/lib/widgets/crossposting/crossposting_benefit_card.dart`
- Modify: `mobile/lib/widgets/crossposting/crossposting_auto_card.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart`
- Test: `mobile/test/features/crossposting/crossposting_analytics_test.dart`

**Interfaces:**
- Consumes: `AnalyticsEventSink` (`package:analytics/analytics.dart`); `analyticsEventSinkProvider` (`package:openvine/providers/analytics_providers.dart`).
- Produces: `Future<void> logCrosspostCtaTapped(AnalyticsEventSink sink, String surface)`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/features/crossposting/crossposting_analytics_test.dart`:

```dart
// ABOUTME: Tests the crossposting CTA analytics helper.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

class _ThrowingSink implements AnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => throw StateError('nope');

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

void main() {
  group(logCrosspostCtaTapped, () {
    test('logs the event with the surface', () async {
      final sink = _RecordingSink();

      await logCrosspostCtaTapped(sink, 'settings');

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'crosspost_cta_tapped');
      expect(sink.events.single.parameters, {'surface': 'settings'});
    });

    test('swallows sink failures', () async {
      await expectLater(
        logCrosspostCtaTapped(_ThrowingSink(), 'share_sheet'),
        completes,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/features/crossposting/crossposting_analytics_test.dart`
Expected: FAIL — `logCrosspostCtaTapped` is not defined.

- [ ] **Step 3: Implement the helper**

Create `mobile/lib/features/crossposting/crossposting_analytics.dart`:

```dart
// ABOUTME: Analytics for crossposting call-to-action taps.
// ABOUTME: Fire-and-forget; a failed log must never break a CTA.

import 'package:analytics/analytics.dart';
import 'package:unified_logger/unified_logger.dart';

/// Records a crossposting CTA tap. [surface] is `settings`, `share_sheet`, or
/// `post_publish`.
Future<void> logCrosspostCtaTapped(
  AnalyticsEventSink sink,
  String surface,
) async {
  try {
    await sink.logEvent(
      name: 'crosspost_cta_tapped',
      parameters: {'surface': surface},
    );
  } catch (error) {
    Log.warning(
      'Crosspost CTA analytics failed: $error',
      name: 'CrosspostingAnalytics',
      category: LogCategory.ui,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/features/crossposting/crossposting_analytics_test.dart`
Expected: PASS.

- [ ] **Step 5: Call the helper from the CTA taps**

In `crossposting_benefit_card.dart` `_connect`, first line (before the branch):

```dart
    unawaited(
      logCrosspostCtaTapped(
        ref.read(analyticsEventSinkProvider),
        'settings',
      ),
    );
```

In `crossposting_auto_card.dart`, extract the button's `onPressed` into a method `_enableAutomatic(BuildContext, WidgetRef)` that logs `'settings'` then calls `setMode`.

In `share_sheet_more_actions.dart`, the Crosspost entry's `onTap` becomes a small closure that logs `'share_sheet'` then calls `onCrosspost!.call()`:

```dart
          onTap: () {
            unawaited(
              logCrosspostCtaTapped(
                ref.read(analyticsEventSinkProvider),
                'share_sheet',
              ),
            );
            onCrosspost!.call();
          },
```

Add imports: `dart:async` (for `unawaited`), `package:openvine/features/crossposting/crossposting_analytics.dart`, `package:openvine/providers/analytics_providers.dart`.

- [ ] **Step 6: Run the affected tests**

Run: `cd mobile && flutter test test/features/crossposting/crossposting_analytics_test.dart test/screens/settings/crossposting_settings_screen_test.dart test/widgets/video_feed_item/actions/share_action_button_test.dart`
Expected: PASS. If a widget test now fails on an unstubbed analytics sink, override `analyticsEventSinkProvider` with `NoOpAnalyticsEventSink()` in that test's setup.

- [ ] **Step 7: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/features/crossposting/crossposting_analytics.dart \
  mobile/lib/widgets/crossposting/crossposting_benefit_card.dart \
  mobile/lib/widgets/crossposting/crossposting_auto_card.dart \
  mobile/lib/widgets/video_feed_item/actions/share_sheet_more_actions.dart \
  mobile/test/features/crossposting/crossposting_analytics_test.dart
git commit -m "feat(crossposting): track CTA taps by surface"
```

---

### Task 7: Localize, verify, and guard

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb` and the 21 sibling `app_*.arb` files (or `_knownUntranslatedDebt`)
- Test: `mobile/test/l10n/arb_consistency_test.dart`

- [ ] **Step 1: Translate the new keys into all locales**

New keys from Task 3: `crosspostingBenefitTitle`, `crosspostingBenefitBody`, `crosspostingBenefitConnect`, `crosspostingAutoTitle`, `crosspostingAutoBody`, `crosspostingAutoEnable`. Add a translation to each `mobile/lib/l10n/app_<locale>.arb` for all 21 non-English locales. If translation is deferred for some locales, add those keys to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart` instead.

- [ ] **Step 2: Regenerate and run the consistency test**

Run: `cd mobile && flutter gen-l10n && flutter test test/l10n/arb_consistency_test.dart`
Expected: PASS.

- [ ] **Step 3: Run the whole touched test set**

Run:

```bash
cd mobile
flutter test \
  test/providers/crossposting_providers_test.dart \
  test/repositories/crossposting_repository_test.dart \
  test/blocs/video_crosspost/video_crosspost_cubit_test.dart \
  test/screens/settings/crossposting_settings_screen_test.dart \
  test/screens/settings/general_settings_screen_test.dart \
  test/widgets/crosspost_sheet_test.dart \
  test/widgets/video_feed_item/actions/share_action_button_test.dart \
  test/widgets/upload_failure_listener_test.dart \
  test/features/crossposting/crossposting_analytics_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run analyze and the guard scripts**

Run:

```bash
cd mobile
flutter analyze
bash scripts/check_orphaned_arb_key_floor.sh
bash scripts/check_raw_colors_ceiling.sh
bash scripts/check_raw_textstyle_ceiling.sh
bash scripts/check_material_button_ceiling.sh
bash scripts/check_ungrouped_tests.sh
bash scripts/check_future_delayed_production_ceiling.sh
bash scripts/check_pubkey_log_encoding.sh
```

Expected: all pass. Fix any new finding rather than baselining it, except a genuine shrink, which is locked with the script's `UPDATE_BASELINE=1` command and committed.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/crossposting-cta
git add mobile/lib/l10n
git commit -m "feat(l10n): translate crossposting CTA strings"
```

---

## Notes for the implementer

- The post-publish Share change alters the live `viewShare` experiment arm's behaviour. Before executing Task 5, confirm with the experiment owner whether the Share destination change needs a variant bump or a new arm. If it does, split that decision into a follow-up and keep Task 5 out of this branch.
- With X hidden, the only visible platform is Instagram. If `GET /platforms` reports no visible enabled platform, the settings screen already renders `_NoPlatforms`; the benefit card is gated on `state.entries.isNotEmpty` so it cannot offer a connect that has no target.
- The `webOnly` path opens `AppConfig.crossposterBaseUrl` (`https://crossposter.divine.video/`). The service has no per-platform deep link, so the generic setup page is the intended fallback.
- Do not add a `crosspostingStatusProvider`; the settings screen's cubit and the share menu's cubit already own their connection state, and the post-publish path reaches connections through the share menu.