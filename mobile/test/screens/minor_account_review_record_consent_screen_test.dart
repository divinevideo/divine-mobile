// ABOUTME: Tests for the in-app consent capture screen's confirm-and-submit
// ABOUTME: step, covering the accepted clip, the submitted email, and failures.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository implements MinorAccountReviewRepository {
  bool throwOnSubmit = false;
  String? submittedCaseId;
  String? submittedEmail;
  String? submittedVideoPath;

  @override
  Future<MinorAccountReviewStatus> fetchCurrentStatus() async =>
      MinorAccountReviewStatus.active();

  @override
  Future<void> submitParentContact({
    required String caseId,
    required String email,
  }) async {}

  @override
  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
  }) async {
    if (throwOnSubmit) {
      throw Exception('submit failed');
    }
    submittedCaseId = caseId;
    submittedEmail = email;
    submittedVideoPath = videoPath;
  }
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

/// Keeps both review-status providers listened so an invalidation re-reads
/// them, which is what the post-submit refresh depends on.
class _ProviderWatcher extends ConsumerWidget {
  const _ProviderWatcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentMinorAccountReviewStatusProvider);
    ref.watch(protectedMinorStatusProvider);
    return child;
  }
}

void main() {
  group('MinorConsentSubmitView', () {
    testWidgets('submits the accepted clip with the confirmed email', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repository = _FakeRepository();
      var fallbackTapped = false;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            minorAccountReviewOverrideServiceProvider.overrideWithValue(
              MinorAccountReviewOverrideService(prefs: prefs),
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
            minorAccountReviewRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MinorConsentSubmitView(
                videoPath: '/tmp/consent.mp4',
                onUseEmailFallback: () => fallbackTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'parent@example.com',
      );
      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
      );
      await tester.pumpAndSettle();

      expect(repository.submittedCaseId, 'case-1');
      expect(repository.submittedEmail, 'parent@example.com');
      expect(repository.submittedVideoPath, '/tmp/consent.mp4');
      expect(
        find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
        findsOneWidget,
      );
      expect(fallbackTapped, isFalse);
    });

    testWidgets('keeps the clip and offers retry when submit fails', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repository = _FakeRepository()..throwOnSubmit = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            minorAccountReviewOverrideServiceProvider.overrideWithValue(
              MinorAccountReviewOverrideService(prefs: prefs),
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
            minorAccountReviewRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MinorConsentSubmitView(
                videoPath: '/tmp/consent.mp4',
                onUseEmailFallback: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'parent@example.com',
      );
      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.minorAccountReviewRecordConsentSubmitError),
        findsOneWidget,
      );
      // The retry (submit) control and the email fallback stay visible.
      expect(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
        findsNothing,
      );
    });

    testWidgets(
      'invalidates both review status providers after a successful submit',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = _FakeRepository();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var reviewStatusReads = 0;
        var protectedStatusReads = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              minorAccountReviewOverrideServiceProvider.overrideWithValue(
                MinorAccountReviewOverrideService(prefs: prefs),
              ),
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                reviewStatusReads++;
                return _statusWithCase();
              }),
              protectedMinorStatusProvider.overrideWith((ref) async {
                protectedStatusReads++;
                return ProtectedMinorStatus.notProtected();
              }),
              minorAccountReviewRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: _ProviderWatcher(
                  child: MinorConsentSubmitView(
                    videoPath: '/tmp/consent.mp4',
                    onUseEmailFallback: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reviewReadsBefore = reviewStatusReads;
        final protectedReadsBefore = protectedStatusReads;
        expect(reviewReadsBefore, greaterThan(0));
        expect(protectedReadsBefore, greaterThan(0));

        await tester.enterText(
          find.byType(TextFormField),
          'parent@example.com',
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        );
        await tester.pumpAndSettle();

        expect(reviewStatusReads, greaterThan(reviewReadsBefore));
        expect(protectedStatusReads, greaterThan(protectedReadsBefore));
      },
    );
  });
}
