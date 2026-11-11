import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

/// Fails the test if the screen reaches the backend: the simulation override
/// is supposed to short-circuit before any request.
class _UnreachableApiService implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    fail('ApiService.${invocation.memberName} called under a local override');
  }
}

class _MockMinorAccountReviewRepository extends Mock
    implements MinorAccountReviewRepository {}

const _teenCaseStatus = MinorAccountReviewStatus(
  restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
  currentCase: MinorReviewCase(
    id: 'case-teen',
    state: MinorReviewCaseState.restrictedPendingUserResponse,
    suspectedAgeBand: SuspectedAgeBand.age13To15,
    allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
    instructions: MinorReviewInstructions(
      title: 'Account review required',
      body: 'We need parental consent information.',
    ),
    supportEmail: 'support@divine.video',
  ),
);

const _under13CaseStatus = MinorAccountReviewStatus(
  restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
  currentCase: MinorReviewCase(
    id: 'case-under13',
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

Future<void> _pumpWithRouter(
  WidgetTester tester, {
  required MockGoRouter goRouter,
  required MinorAccountReviewStatus status,
  MinorAccountReviewRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentMinorAccountReviewStatusProvider.overrideWith(
          (ref) async => status,
        ),
        if (repository != null)
          minorAccountReviewRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockGoRouterProvider(
          goRouter: goRouter,
          child: const MinorAccountReviewParentContactScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
            // The real repository owns the override-vs-backend decision, so
            // wire it directly rather than building the ApiService chain.
            minorAccountReviewRepositoryProvider.overrideWithValue(
              MinorAccountReviewRepository(
                apiService: _UnreachableApiService(),
                overrideService: overrideService,
                allowLocalOverrides: true,
              ),
            ),
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              final localOverride = overrideService.getOverride();
              return localOverride ?? MinorAccountReviewStatus.active();
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
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
            localizationsDelegates: appLocalizationsDelegates,
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

    group('navigation', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      late MockGoRouter goRouter;
      late _MockMinorAccountReviewRepository repository;

      setUp(() {
        goRouter = MockGoRouter();
        repository = _MockMinorAccountReviewRepository();
        when(
          () => repository.submitParentContact(
            caseId: any(named: 'caseId'),
            email: any(named: 'email'),
            localReceipt: any(named: 'localReceipt'),
          ),
        ).thenAnswer((_) async {});
      });

      Future<void> submitParentEmail(WidgetTester tester) async {
        await _pumpWithRouter(
          tester,
          goRouter: goRouter,
          status: _teenCaseStatus,
          repository: repository,
        );
        await tester.enterText(
          find.byType(TextFormField),
          'parent@example.com',
        );
        await tester.tap(find.text(l10n.minorAccountReviewSubmitEmail));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
          findsOneWidget,
        );
      }

      testWidgets('back to review after a submit goes to the review screen', (
        tester,
      ) async {
        await submitParentEmail(tester);

        await tester.tap(find.text(l10n.minorAccountReviewBackToReview));
        await tester.pump();

        verify(
          () => goRouter.go('/account-review', extra: any(named: 'extra')),
        ).called(1);
        verifyNoMoreInteractions(goRouter);
      });

      testWidgets('check again after a submit goes to the review screen', (
        tester,
      ) async {
        await submitParentEmail(tester);

        await tester.tap(find.text(l10n.minorAccountReviewCheckAgain));
        await tester.pump();

        verify(
          () => goRouter.go('/account-review', extra: any(named: 'extra')),
        ).called(1);
        verifyNoMoreInteractions(goRouter);
      });

      testWidgets('back to review with no case goes to the review screen', (
        tester,
      ) async {
        await _pumpWithRouter(
          tester,
          goRouter: goRouter,
          status: MinorAccountReviewStatus.active(),
        );

        await tester.tap(find.text(l10n.minorAccountReviewBackToReview));
        await tester.pump();

        verify(
          () => goRouter.go('/account-review', extra: any(named: 'extra')),
        ).called(1);
        verifyNoMoreInteractions(goRouter);
      });

      testWidgets('an under-13 case is sent on to the under-13 support step', (
        tester,
      ) async {
        await _pumpWithRouter(
          tester,
          goRouter: goRouter,
          status: _under13CaseStatus,
        );

        await tester.tap(find.text(l10n.minorAccountReviewBackToReview));
        await tester.pump();

        verify(
          () => goRouter.go(
            '/account-review/under-13-support',
            extra: any(named: 'extra'),
          ),
        ).called(1);
        verifyNoMoreInteractions(goRouter);
      });
    });
  });
}
