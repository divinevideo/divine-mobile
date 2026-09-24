import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

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

class _FakeRepository implements MinorAccountReviewRepository {
  @override
  Future<MinorAccountReviewStatus> fetchCurrentStatus() async =>
      MinorAccountReviewStatus.active();

  @override
  Future<void> submitParentContact({
    required String caseId,
    required String email,
    MinorReviewInstructions? localReceipt,
  }) async {}

  @override
  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
    MinorReviewInstructions? localReceipt,
  }) async {}
}

MinorAccountReviewStatus _statusWithCase() {
  return const MinorAccountReviewStatus(
    restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    currentCase: MinorReviewCase(
      id: 'case-1',
      state: MinorReviewCaseState.restrictedPendingParentalConsent,
      suspectedAgeBand: SuspectedAgeBand.age13To15,
      allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
      instructions: MinorReviewInstructions(
        title: 'Account review required',
        body: 'We need parental consent information.',
      ),
      supportEmail: 'support@divine.video',
    ),
  );
}

List<Override> _recordingEnabledOverrides({bool enabled = true}) => [
  isFeatureEnabledProvider(
    FeatureFlag.minorConsentInAppRecording,
  ).overrideWithValue(enabled),
  currentMinorAccountReviewStatusProvider.overrideWith(
    (ref) async => _statusWithCase(),
  ),
  minorAccountReviewRepositoryProvider.overrideWithValue(
    _FakeRepository(),
  ),
];

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
        ProviderScope(
          overrides: _recordingEnabledOverrides(enabled: false),
          child: MaterialApp(
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
              ..._recordingEnabledOverrides(),
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

    testWidgets(
      'hides in-app recording while the feature is off and keeps email primary',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _recordingEnabledOverrides(enabled: false),
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewParentConsentScreen(),
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

        expect(
          find.text(l10n.minorAccountReviewParentConsentRecordCta),
          findsNothing,
        );
        final emailButton = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.minorAccountReviewParentConsentEmailCta),
            matching: find.byType(DivineButton),
          ),
        );
        expect(emailButton.type, equals(DivineButtonType.primary));
      },
    );
  });
}
