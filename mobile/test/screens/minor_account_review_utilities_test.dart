// ABOUTME: Keeps account deletion and diagnostics reachable during account review.
// ABOUTME: Exercises the real utility actions independently of the appeal route.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/scroll.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

const _pubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  late _MockAuthService authService;
  late _MockBugReportService bugReportService;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    bugReportService = _MockBugReportService();
    when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
    when(
      () => bugReportService.exportLogsToFile(
        currentScreen: any(named: 'currentScreen'),
        recentScreens: any(named: 'recentScreens'),
        userPubkey: any(named: 'userPubkey'),
        sharePositionOrigin: any(named: 'sharePositionOrigin'),
      ),
    ).thenAnswer((_) async => const LogExportResult.noLogs());
  });

  Future<void> pumpReview(
    WidgetTester tester,
    MinorReviewCase? reviewCase, {
    List<String> locations = const ['/home/0', '/account-review'],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          bugReportServiceProvider.overrideWithValue(bugReportService),
          accountDeletionServiceProvider.overrideWithValue(
            _MockAccountDeletionService(),
          ),
          profileRepositoryProvider.overrideWithValue(null),
          profileReadRepositoryProvider.overrideWithValue(null),
          goRouterProvider.overrideWith((ref) {
            final router = GoRouter(
              navigatorKey: NavigatorKeys.root,
              routes: appRoutes(ref),
            );
            ref.onDispose(router.dispose);
            return router;
          }),
          routerLocationStreamProvider.overrideWithValue(
            Stream.fromIterable(locations),
          ),
          currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
            return MinorAccountReviewStatus(
              restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
              currentCase: reviewCase,
            );
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinorAccountReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final scenarios = [
    (
      name: 'under-13 with the duplicate appeal suppressed',
      reviewCase: _case(
        SuspectedAgeBand.under13,
        MinorReviewResolutionType.supportEmailOnly,
        MinorReviewCaseState.restrictedPendingSupportEmail,
      ),
    ),
    (
      name: 'teen awaiting moderator review',
      reviewCase: _case(
        SuspectedAgeBand.age13To15,
        MinorReviewResolutionType.parentVideoOrEmail,
        MinorReviewCaseState.submittedForReview,
      ),
    ),
    (
      name: '16+ awaiting support review',
      reviewCase: _case(
        SuspectedAgeBand.age16PlusClaimed,
        MinorReviewResolutionType.supportReviewOnly,
        MinorReviewCaseState.restrictedPendingUserResponse,
      ),
    ),
    (
      name: 'unknown age and resolution',
      reviewCase: _case(
        SuspectedAgeBand.unknown,
        MinorReviewResolutionType.unknown,
        MinorReviewCaseState.unknown,
      ),
    ),
    (name: 'no review case', reviewCase: null),
    (
      name: 'a decided case',
      reviewCase: _case(
        SuspectedAgeBand.age13To15,
        MinorReviewResolutionType.parentVideoOrEmail,
        MinorReviewCaseState.deniedClosed,
      ),
    ),
  ];

  group('interactions', () {
    for (final scenario in scenarios) {
      testWidgets('can save logs and open deletion for ${scenario.name}', (
        tester,
      ) async {
        await pumpReview(tester, scenario.reviewCase);
        await scrollUntilTappable(
          tester,
          find.text(l10n.supportSaveLogs),
          300,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text(l10n.supportSaveLogs));
        await tester.pumpAndSettle();
        expect(find.text(l10n.supportNoLogsToExport), findsOneWidget);
        verify(
          () => bugReportService.exportLogsToFile(
            currentScreen: 'minorAccountReview',
            recentScreens: const ['home', 'minorAccountReview'],
            userPubkey: _pubkey,
            sharePositionOrigin: any(
              named: 'sharePositionOrigin',
              that: isNotNull,
            ),
          ),
        ).called(1);

        await scrollUntilTappable(
          tester,
          find.text(l10n.nostrSettingsDeleteAccount),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text(l10n.nostrSettingsDeleteAccount));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.deleteAccountFinalConfirmationTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.deleteAccountConfirmDeletePrompt),
          findsOneWidget,
        );
      });
    }

    testWidgets('exports the review location on a cold account-review entry', (
      tester,
    ) async {
      await pumpReview(tester, null, locations: const ['/account-review']);
      await scrollUntilTappable(
        tester,
        find.text(l10n.supportSaveLogs),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text(l10n.supportSaveLogs));
      await tester.pumpAndSettle();
      expect(find.text(l10n.supportNoLogsToExport), findsOneWidget);
      verify(
        () => bugReportService.exportLogsToFile(
          currentScreen: 'minorAccountReview',
          recentScreens: const ['minorAccountReview'],
          userPubkey: _pubkey,
          sharePositionOrigin: any(named: 'sharePositionOrigin'),
        ),
      ).called(1);
    });

    testWidgets('ignores repeated log-export taps during account review', (
      tester,
    ) async {
      final result = Completer<LogExportResult>();
      when(
        () => bugReportService.exportLogsToFile(
          currentScreen: any(named: 'currentScreen'),
          recentScreens: any(named: 'recentScreens'),
          userPubkey: any(named: 'userPubkey'),
          sharePositionOrigin: any(named: 'sharePositionOrigin'),
        ),
      ).thenAnswer((_) => result.future);
      await pumpReview(tester, null);
      await scrollUntilTappable(
        tester,
        find.text(l10n.supportSaveLogs),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text(l10n.supportSaveLogs));
      await tester.pump();
      await tester.tap(find.text(l10n.supportSaveLogs));
      await tester.pump();
      expect(find.text(l10n.supportExportingLogs), findsOneWidget);
      result.complete(const LogExportResult.noLogs());
      await tester.pumpAndSettle();
      verify(
        () => bugReportService.exportLogsToFile(
          currentScreen: any(named: 'currentScreen'),
          recentScreens: any(named: 'recentScreens'),
          userPubkey: any(named: 'userPubkey'),
          sharePositionOrigin: any(named: 'sharePositionOrigin'),
        ),
      ).called(1);
    });
  });
}

MinorReviewCase _case(
  SuspectedAgeBand ageBand,
  MinorReviewResolutionType resolution,
  MinorReviewCaseState state,
) => MinorReviewCase(
  id: 'utility-case',
  supportEmail: 'support@divine.video',
  state: state,
  suspectedAgeBand: ageBand,
  allowedResolution: resolution,
  instructions: const MinorReviewInstructions(
    title: 'Account review required',
    body: 'Review is pending.',
  ),
);
