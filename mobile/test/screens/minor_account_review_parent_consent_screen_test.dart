import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {}

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
    required String? caseId,
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

Override _authState(AuthState state) =>
    currentAuthStateProvider.overrideWithValue(state);

List<Override> _recordingEnabledOverrides({
  bool enabled = true,
  AuthState authState = AuthState.authenticated,
}) => [
  _authState(authState),
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
    testWidgets(
      'a family can opt into recording from the consent explanation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              _authState(AuthState.authenticated),
            ],
            child: const MaterialApp(
              locale: Locale('es'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewParentConsentScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('es'));
        expect(
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
          findsNothing,
        );
        await scrollUntilTappable(
          tester,
          find.byType(DivineSwitch),
          200,
          scrollable: find.byType(Scrollable),
        );
        expect(
          find.widgetWithText(
            ListTile,
            l10n.minorAccountReviewRecordConsentTitle,
          ),
          findsOneWidget,
        );
        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
          findsOneWidget,
        );
        expect(prefs.getBool('ff_minorConsentInAppRecording'), isTrue);
        expect(
          find.text(l10n.minorAccountReviewRecordConsentPrivacyBody),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.minorAccountReviewParentConsentBody),
          findsNothing,
        );
      },
    );

    testWidgets('names the recording opt-in on its switch for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
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
        find.byType(DivineSwitch),
        200,
        scrollable: find.byType(Scrollable),
      );

      expect(
        tester.getSemantics(find.byType(DivineSwitch)),
        isSemantics(
          label: l10n.minorAccountReviewRecordConsentTitle,
          hasToggledState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets(
      'a voluntary case keeps its email fallback after an interrupted upload',
      (tester) async {
        String? capturedEmailBody;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _authState(AuthState.authenticated),
              isFeatureEnabledProvider(FeatureFlag.minorConsentInAppRecording)
                  .overrideWithValue(true),
              currentMinorAccountReviewStatusProvider.overrideWith(
                (ref) async => const MinorAccountReviewStatus(
                  restrictionStatus: AccountRestrictionStatus.active,
                  currentCase: MinorReviewCase(
                    id: 'application-1',
                    state: MinorReviewCaseState.openReported,
                    suspectedAgeBand: SuspectedAgeBand.age13To15,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: MinorReviewInstructions(title: '', body: ''),
                    supportEmail: 'support@example.com',
                  ),
                ),
              ),
              minorAccountReviewSupportEmailComposerProvider.overrideWithValue(
                ({
                  required toEmail,
                  required subject,
                  required String body,
                  sharePositionOrigin,
                }) async {
                  // Capture the exact fallback rather than replacing navigation.
                  capturedEmailBody = body;
                },
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewParentConsentScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MinorAccountReviewParentConsentScreen)),
        );
        await container.read(currentMinorAccountReviewStatusProvider.future);
        final l10n = lookupAppLocalizations(const Locale('en'));
        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
        );
        await tester.pumpAndSettle();
        expect(
          capturedEmailBody,
          contains(l10n.minorAccountReviewParentConsentEmailBody),
        );
        expect(capturedEmailBody, contains('application-1'));
      },
    );

    testWidgets(
      'an already restricted consent case keeps its email fallback after an interrupted upload',
      (tester) async {
        String? capturedEmailBody;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _authState(AuthState.authenticated),
              isFeatureEnabledProvider(FeatureFlag.minorConsentInAppRecording)
                  .overrideWithValue(true),
              currentMinorAccountReviewStatusProvider.overrideWith(
                (ref) async => const MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'application-1',
                    state:
                        MinorReviewCaseState.restrictedPendingParentalConsent,
                    suspectedAgeBand: SuspectedAgeBand.age13To15,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: MinorReviewInstructions(title: '', body: ''),
                    supportEmail: 'support@example.com',
                  ),
                ),
              ),
              minorAccountReviewSupportEmailComposerProvider.overrideWithValue(
                ({
                  required toEmail,
                  required subject,
                  required String body,
                  sharePositionOrigin,
                }) async {
                  // Capture the exact fallback rather than replacing navigation.
                  capturedEmailBody = body;
                },
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewParentConsentScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MinorAccountReviewParentConsentScreen)),
        );
        await container.read(currentMinorAccountReviewStatusProvider.future);
        final l10n = lookupAppLocalizations(const Locale('en'));
        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
        );
        await tester.pumpAndSettle();
        expect(
          capturedEmailBody,
          contains(l10n.minorAccountReviewParentConsentEmailBody),
        );
        expect(capturedEmailBody, contains('application-1'));
      },
    );

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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MinorAccountReviewParentConsentScreen)),
      );
      await container.read(currentMinorAccountReviewStatusProvider.future);
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
      expect(
        sentBody,
        [
          l10n.minorAccountReviewParentConsentEmailBody,
          l10n.minorAccountReviewCaseId('case-1'),
        ].join('\n\n'),
      );
      expect(sentSubject, contains('Divine Greenlight'));
      expect(sentBody, contains('Divine Greenlight'));
      // The composer's share-sheet fallback is refused on iPad without an
      // anchor, so the screen has to resolve one (#7506).
      expect(sentOrigin, isNotNull);
      expect(sentOrigin!.isEmpty, isFalse);
    });

    testWidgets(
      'hands a restricted case awaiting the family to the parent-contact '
      'form instead of composing an email',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        var composed = false;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  MinorAccountReviewParentConsentScreen(
                    composeEmail:
                        ({
                          required String toEmail,
                          required String subject,
                          required String body,
                          Rect? sharePositionOrigin,
                        }) async {
                          composed = true;
                        },
                  ),
            ),
            GoRoute(
              path: MinorAccountReviewParentContactScreen.path,
              builder: (context, state) =>
                  const MinorAccountReviewParentContactScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _authState(AuthState.authenticated),
              isFeatureEnabledProvider(
                FeatureFlag.minorConsentInAppRecording,
              ).overrideWithValue(false),
              currentMinorAccountReviewStatusProvider.overrideWith(
                (ref) async => const MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'case-1',
                    state: MinorReviewCaseState.restrictedPendingUserResponse,
                    suspectedAgeBand: SuspectedAgeBand.age13To15,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: MinorReviewInstructions(title: '', body: ''),
                    supportEmail: 'support@divine.video',
                  ),
                ),
              ),
              minorAccountReviewRepositoryProvider.overrideWithValue(
                _FakeRepository(),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MinorAccountReviewParentConsentScreen)),
        );
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await scrollUntilTappable(
          tester,
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewParentConsentEmailCta),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(MinorAccountReviewParentContactScreen),
          findsOneWidget,
        );
        expect(composed, isFalse);
      },
    );

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
              minorConsentWakelockProvider.overrideWithValue((_) async {}),
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
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
          200,
          scrollable: scrollable,
        );
        final recordButton = tester.widget<DivineButton>(
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
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
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
          -200,
          scrollable: scrollable,
        );
        await tester.tap(
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
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
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
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

    testWidgets(
      'offers a signed-out visitor only the email route, even with recording '
      'on',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _recordingEnabledOverrides(
              authState: AuthState.unauthenticated,
            ),
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

        // The record route sends a signed-out visitor to Welcome, so neither
        // the opt-in nor the record action may be offered here.
        expect(find.byType(DivineSwitch), findsNothing);
        expect(
          find.widgetWithText(
            DivineButton,
            l10n.minorAccountReviewParentConsentRecordCta,
          ),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.minorAccountReviewParentConsentBody),
          findsOneWidget,
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
