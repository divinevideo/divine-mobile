import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:permissions_service/permissions_service.dart';

import '../helpers/scroll.dart';

class _FakeRecorder implements MinorConsentRecorder {
  @override
  void Function(String? path)? onAutoStopped;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async => true;

  @override
  Future<String?> stop() async => '/tmp/consent.mp4';

  @override
  Future<void> dispose() async {}
}

class _FakePermissions implements PermissionsService {
  @override
  Future<PermissionStatus> checkCameraStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestCameraPermission() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async =>
      PermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionStatus> checkGalleryStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestGalleryPermission() async =>
      PermissionStatus.granted;
}

void main() {
  group('MinorAccountReviewParentConsentScreen', () {
    testWidgets('opens support email with prepared subject and body', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      String? sentToEmail;
      String? sentSubject;
      String? sentBody;
      Rect? sentOrigin;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinorAccountReviewParentConsentScreen(
            composeEmail:
                ({
                  required String toEmail,
                  required String subject,
                  required String body,
                  Rect? sharePositionOrigin,
                }) async {
                  sentToEmail = toEmail;
                  sentSubject = subject;
                  sentBody = body;
                  sentOrigin = sharePositionOrigin;
                },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await scrollUntilTappable(
        tester,
        find.text(l10n.minorAccountReviewParentConsentEmailCta),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text(l10n.minorAccountReviewParentConsentEmailCta));
      await tester.pumpAndSettle();

      expect(sentToEmail, 'support@divine.video');
      expect(sentSubject, l10n.minorAccountReviewParentConsentEmailSubject);
      expect(sentBody, l10n.minorAccountReviewParentConsentEmailBody);
      expect(sentSubject, contains('Divine Greenlight'));
      expect(sentBody, contains('Divine Greenlight'));
      // The composer's share-sheet fallback is refused on iPad without an
      // anchor, so the screen has to resolve one (#7506).
      expect(sentOrigin, isNotNull);
      expect(sentOrigin!.isEmpty, isFalse);
    });

    testWidgets(
      'primary action routes to the record screen and email is secondary',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const MinorAccountReviewParentConsentScreen(),
            ),
            GoRoute(
              path: MinorAccountReviewRecordConsentScreen.path,
              builder: (context, state) =>
                  const MinorAccountReviewRecordConsentScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              minorConsentRecorderProvider.overrideWithValue(_FakeRecorder()),
              permissionsServiceProvider.overrideWithValue(_FakePermissions()),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable);
        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentRecordCta),
          200,
          scrollable: scrollable,
        );
        final recordButton = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.minorAccountReviewParentConsentRecordCta),
            matching: find.byType(DivineButton),
          ),
        );
        expect(recordButton.type, DivineButtonType.primary);

        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
          200,
          scrollable: scrollable,
        );
        final emailButton = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.minorAccountReviewParentConsentEmailCta),
            matching: find.byType(DivineButton),
          ),
        );
        expect(emailButton.type, DivineButtonType.secondary);

        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentRecordCta),
          -200,
          scrollable: scrollable,
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewParentConsentRecordCta),
        );
        // The captured screen shows an indeterminate camera-loading spinner
        // when no camera is initialized, so pump the route transition instead
        // of settling on a never-quiescent frame.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byType(MinorAccountReviewRecordConsentScreen),
          findsOneWidget,
        );
      },
    );
  });
}
