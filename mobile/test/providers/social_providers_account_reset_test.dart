// ABOUTME: Tests for the account-boundary preference reset: it must drop the
// ABOUTME: departing account's cached preferences, and must not leave a watched
// ABOUTME: service for a widget build to rebuild (#8121).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('accountScopedPreferenceServicesResetProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// Mounts [container] the way the app does, so Riverpod schedules its
    /// refreshes through the scope rather than through a timer.
    Future<ProviderContainer> pumpScope(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );
      return container;
    }

    /// Builds [dependent], then drops its only listener, the way a feed that
    /// read it and was then left leaves it paused rather than disposed.
    void buildThenPause(
      ProviderContainer container,
      ProviderListenable<Object?> dependent,
    ) {
      container.listen<Object?>(dependent, (_, _) {}).close();
    }

    /// Mounts a widget whose first build reads [service], the way the home
    /// shell reads its bridges right after sign-in redirects to it.
    Future<void> pumpReader(
      WidgetTester tester,
      ProviderContainer container,
      ProviderListenable<Object?> service,
    ) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(service);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    Future<void> expectResetLeavesServiceReadable(
      WidgetTester tester, {
      required ProviderListenable<Object?> dependent,
      required ProviderListenable<Object?> service,
      Future<void> Function(ProviderContainer container)? warmUp,
    }) async {
      final container = await pumpScope(tester);
      if (warmUp != null) {
        // Asset futures may have been cached by a regular test in the merged
        // isolate. Finish that real async work before entering widget builds.
        await tester.runAsync(() => warmUp(container));
      }
      buildThenPause(container, dependent);

      // Reset can await the same provider future created during warmup.
      await tester.runAsync(
        () => container.read(accountScopedPreferenceServicesResetProvider)(),
      );
      await tester.pump();

      await pumpReader(tester, container, service);

      expect(tester.takeException(), isNull);
    }

    testWidgets(
      'lets the next build read the content filter without refreshing '
      'a paused dependent mid-build',
      (tester) => expectResetLeavesServiceReadable(
        tester,
        dependent: contentFilterVersionProvider,
        service: contentFilterServiceProvider,
      ),
    );

    testWidgets(
      'lets the next build read the Divine-host filter without refreshing '
      'a paused dependent mid-build',
      (tester) => expectResetLeavesServiceReadable(
        tester,
        dependent: divineHostFilterVersionProvider,
        service: divineHostFilterServiceProvider,
      ),
    );

    testWidgets(
      'lets the next build read the provenance filter without refreshing '
      'a paused dependent mid-build',
      (tester) => expectResetLeavesServiceReadable(
        tester,
        dependent: videoProvenanceFilterVersionProvider,
        service: videoProvenanceFilterServiceProvider,
      ),
    );

    testWidgets(
      'lets the next build read the content language without refreshing '
      'a paused dependent mid-build',
      (tester) => expectResetLeavesServiceReadable(
        tester,
        dependent: languagePreferenceVersionProvider,
        service: languagePreferenceServiceProvider,
      ),
    );

    testWidgets(
      'lets the next build read the sound library without refreshing '
      'a paused dependent mid-build',
      (tester) => expectResetLeavesServiceReadable(
        tester,
        dependent: soundLibraryServiceSyncProvider,
        service: soundLibraryServiceProvider,
        warmUp: (container) =>
            container.read(soundLibraryServiceProvider.future),
      ),
    );

    test(
      "drops the departing account's subtitle language preferences",
      () async {
        SharedPreferences.setMockInitialValues({
          SubtitleLanguagePreferenceService.targetLanguageStorageKey: 'pt',
          SubtitleLanguagePreferenceService.keepOriginalLanguagesStorageKey: [
            'ja',
          ],
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final departing = container.read(
          subtitleLanguagePreferenceServiceProvider,
        );
        await departing.initialize();
        expect(departing.targetLanguage, equals('pt'));
        expect(departing.keepOriginalLanguages, equals({'ja'}));

        // The sweep removes the stored keys before it runs the reset.
        await prefs.remove(
          SubtitleLanguagePreferenceService.targetLanguageStorageKey,
        );
        await prefs.remove(
          SubtitleLanguagePreferenceService.keepOriginalLanguagesStorageKey,
        );
        await container.read(accountScopedPreferenceServicesResetProvider)();

        final incoming = container.read(
          subtitleLanguagePreferenceServiceProvider,
        );
        await incoming.initialize();
        expect(incoming.targetLanguage, isNull);
        expect(incoming.keepOriginalLanguages, isEmpty);
      },
    );
  });
}
