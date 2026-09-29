// ABOUTME: Regression tests for #8121: the account-boundary preference reset
// ABOUTME: must not leave a watched service for a widget build to rebuild

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/services/auth_service.dart';
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
      await warmUp?.call(container);
      buildThenPause(container, dependent);

      await container.read(accountScopedPreferenceServicesResetProvider)();
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
  });
}
