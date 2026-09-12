// ABOUTME: Tests the profile badge explainer sheet's video-pause integration.
// ABOUTME: Both badges also render over a playing video in the feed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/widgets/profile_badge_explanation_sheet.dart';

void main() {
  group('showProfileBadgeExplanationSheet', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    Widget buildSubject(ProfileBadgeExplanationType type) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      showProfileBadgeExplanationSheet(context, type),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final type in ProfileBadgeExplanationType.values) {
      testWidgets('pauses the feed video while $type is explained', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(type));

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Without this the video keeps playing behind the sheet, because
        // activeVideoProvider is gated on hasVisibleOverlay.
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(
          find.text(lookupAppLocalizations(const Locale('en')).commonClose),
        );
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      });
    }
  });
}
