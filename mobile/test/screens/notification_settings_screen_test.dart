// ABOUTME: Widget tests for NotificationSettingsScreen — verifies the
// ABOUTME: mark-all-as-read action card's success snackbar, failure
// ABOUTME: snackbar, disabled-when-repo-null behaviour, and that toggling a
// ABOUTME: notification-type switch persists the flipped preference.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/services/notification_preferences_service.dart';

import '../helpers/scroll.dart';
import '../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockNotificationPreferencesService extends Mock
    implements NotificationPreferencesService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
  });

  group(NotificationSettingsScreen, () {
    late _MockNotificationRepository mockRepo;
    late _MockNotificationPreferencesService mockPrefsService;

    setUp(() {
      mockRepo = _MockNotificationRepository();
      mockPrefsService = _MockNotificationPreferencesService();
      when(
        mockPrefsService.loadPreferences,
      ).thenAnswer((_) async => const NotificationPreferences());
      when(
        () => mockPrefsService.updatePreferences(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject({
      NotificationRepository? repo,
      bool newPostNotifications = true,
    }) {
      return testMaterialApp(
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          notificationPreferencesServiceProvider.overrideWithValue(
            mockPrefsService,
          ),
          // Ships default-off, so the new-posts row has to be asked for.
          isFeatureEnabledProvider(
            FeatureFlag.newPostNotifications,
          ).overrideWithValue(newPostNotifications),
        ],
        home: const NotificationSettingsScreen(),
      );
    }

    testWidgets('shows success snackbar when markAllAsRead succeeds', (
      tester,
    ) async {
      when(mockRepo.markAllAsRead).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(repo: mockRepo));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      );

      await scrollUntilTappable(
        tester,
        find.text(l10n.notificationSettingsMarkAllAsRead),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(mockRepo.markAllAsRead).called(1);
      expect(
        find.text(l10n.notificationSettingsAllMarkedAsRead),
        findsOneWidget,
      );
      final banner = tester.widget<DivineSnackbarContainer>(
        find.byType(DivineSnackbarContainer),
      );
      expect(banner.error, isFalse);
    });

    testWidgets('shows failure snackbar when markAllAsRead throws', (
      tester,
    ) async {
      when(mockRepo.markAllAsRead).thenThrow(Exception('server fail'));

      await tester.pumpWidget(buildSubject(repo: mockRepo));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      );

      await scrollUntilTappable(
        tester,
        find.text(l10n.notificationSettingsMarkAllAsRead),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(mockRepo.markAllAsRead).called(1);
      expect(
        find.text(l10n.notificationSettingsMarkAllAsReadFailed),
        findsOneWidget,
      );
      final banner = tester.widget<DivineSnackbarContainer>(
        find.byType(DivineSnackbarContainer),
      );
      expect(banner.error, isTrue);
    });

    testWidgets('ignores repeat taps while markAllAsRead is still in flight', (
      tester,
    ) async {
      final inFlight = Completer<void>();
      var callCount = 0;
      when(mockRepo.markAllAsRead).thenAnswer((_) {
        callCount++;
        return inFlight.future;
      });

      await tester.pumpWidget(buildSubject(repo: mockRepo));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      );

      await scrollUntilTappable(
        tester,
        find.text(l10n.notificationSettingsMarkAllAsRead),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
      await tester.pump();
      await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
      await tester.pump();

      expect(callCount, equals(1));

      inFlight.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'swaps the action card caret for a spinner while marking as read',
      (tester) async {
        final inFlight = Completer<void>();
        when(mockRepo.markAllAsRead).thenAnswer((_) => inFlight.future);

        await tester.pumpWidget(buildSubject(repo: mockRepo));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        await scrollUntilTappable(
          tester,
          find.text(l10n.notificationSettingsMarkAllAsRead),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        final actionTile = find
            .ancestor(
              of: find.text(l10n.notificationSettingsMarkAllAsRead),
              matching: find.byType(ListTile),
            )
            .first;
        final spinner = find.descendant(
          of: actionTile,
          matching: find.byType(CircularProgressIndicator),
        );

        expect(spinner, findsNothing);

        await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
        await tester.pump();

        expect(spinner, findsOneWidget);
        expect(
          tester.getSemantics(spinner).getSemanticsData().label,
          equals(l10n.commonLoading),
        );

        inFlight.complete();
        await tester.pumpAndSettle();

        expect(spinner, findsNothing);
      },
    );

    testWidgets(
      'disables the action card when notificationRepository is null',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.notificationSettingsMarkAllAsRead),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        final cardListTile = tester.widget<ListTile>(
          find
              .ancestor(
                of: find.text(l10n.notificationSettingsMarkAllAsRead),
                matching: find.byType(ListTile),
              )
              .first,
        );
        expect(cardListTile.onTap, isNull);
      },
    );

    testWidgets(
      'toggling a notification-type switch persists the flipped preference',
      (tester) async {
        await tester.pumpWidget(buildSubject(repo: mockRepo));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        final likesSwitch = find.descendant(
          of: find.ancestor(
            of: find.text(l10n.notificationSettingsLikes),
            matching: find.byType(Card),
          ),
          matching: find.byType(Switch),
        );

        await tester.tap(likesSwitch);
        await tester.pump();

        verify(
          () => mockPrefsService.updatePreferences(
            const NotificationPreferences(likesEnabled: false),
          ),
        ).called(1);
      },
    );

    testWidgets('toggling new vines off persists newPostsEnabled false', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(repo: mockRepo));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      );

      final newPostsSwitch = find.descendant(
        of: find.ancestor(
          of: find.text(l10n.notificationSettingsNewPosts),
          matching: find.byType(Card),
        ),
        matching: find.byType(Switch),
      );
      await scrollUntilTappable(tester, newPostsSwitch, 100);

      await tester.tap(newPostsSwitch);
      await tester.pump();

      verify(
        () => mockPrefsService.updatePreferences(
          const NotificationPreferences(newPostsEnabled: false),
        ),
      ).called(1);
    });

    testWidgets('hides the new vines row behind the flag', (tester) async {
      await tester.pumpWidget(
        buildSubject(repo: mockRepo, newPostNotifications: false),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      );

      expect(find.text(l10n.notificationSettingsNewPosts), findsNothing);
      // The neighbouring rows still render, so this is the flag and not a
      // failed build.
      expect(find.text(l10n.notificationSettingsLikes), findsOneWidget);
    });
  });
}
