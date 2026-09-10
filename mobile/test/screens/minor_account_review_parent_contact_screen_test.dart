import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MinorAccountReviewParentContactScreen', () {
    testWidgets('submits locally when a simulation override is active', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrideService = MinorAccountReviewOverrideService(prefs: prefs);

      await overrideService.setOverride(
        const MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
          currentCase: MinorReviewCase(
            id: 'sim-teen-review',
            state: MinorReviewCaseState.restrictedPendingUserResponse,
            suspectedAgeBand: SuspectedAgeBand.age13To15,
            allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
            instructions: MinorReviewInstructions(
              title: 'Account review required',
              body: 'We need parental consent information.',
            ),
            supportEmail: 'support@divine.video',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            minorAccountReviewOverrideServiceProvider.overrideWithValue(
              overrideService,
            ),
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              final localOverride = overrideService.getOverride();
              return localOverride ?? MinorAccountReviewStatus.active();
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewParentContactScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'parent@example.com');
      await tester.tap(find.text('Submit Email'));
      await tester.pumpAndSettle();

      expect(find.text('Email submitted'), findsOneWidget);

      final updatedOverride = overrideService.getOverride();
      expect(
        updatedOverride?.currentCase?.state,
        MinorReviewCaseState.submittedForReview,
      );
      expect(
        updatedOverride?.currentCase?.instructions.title,
        'Email submitted',
      );
    });

    testWidgets('does not render submit form for under-13 support cases', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'sim-under-13-review',
                  state: MinorReviewCaseState.restrictedPendingSupportEmail,
                  suspectedAgeBand: SuspectedAgeBand.under13,
                  allowedResolution: MinorReviewResolutionType.supportEmailOnly,
                  instructions: MinorReviewInstructions(
                    title: 'Account review required',
                    body: 'Contact support by email.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewParentContactScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'For likely under-13 accounts, the next step is parent or guardian contact by email.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Submit Email'), findsNothing);
    });
  });
}
