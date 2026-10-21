// ABOUTME: Keeps account deletion and diagnostics reachable during account review.
// ABOUTME: Exercises the real utility actions independently of the appeal route.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
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

import '../helpers/go_router.dart';
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

  // Every fetch after the first returns [refreshedCase] when it is given, or
  // throws [refreshError] when that is.
  Future<void> pumpReview(
    WidgetTester tester,
    MinorReviewCase? reviewCase, {
    List<String> locations = const ['/home/0', '/account-review'],
    MinorReviewCase? refreshedCase,
    Object? refreshError,
    MockGoRouter? goRouter,
    ThemeData? theme,
  }) async {
    var fetches = 0;
    final app = MaterialApp(
      theme: theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MinorAccountReviewScreen(),
    );
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
            final isRefresh = fetches++ > 0;
            final error = refreshError;
            if (isRefresh && error != null) throw error;
            return MinorAccountReviewStatus(
              restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
              currentCase: isRefresh ? refreshedCase ?? reviewCase : reviewCase,
            );
          }),
        ],
        child: goRouter == null
            ? app
            : MockGoRouterProvider(goRouter: goRouter, child: app),
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

    // Check Again can return a case that now needs action, and its Continue
    // lands above the tile. An export still in flight must keep its outcome
    // across that shift, as the appeal keeps an open in flight.
    testWidgets('keeps an in-flight export when a refresh adds Continue above '
        'it', (tester) async {
      // Tall surface so every control is laid out without scrolling.
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final result = Completer<LogExportResult>();
      when(
        () => bugReportService.exportLogsToFile(
          currentScreen: any(named: 'currentScreen'),
          recentScreens: any(named: 'recentScreens'),
          userPubkey: any(named: 'userPubkey'),
          sharePositionOrigin: any(named: 'sharePositionOrigin'),
        ),
      ).thenAnswer((_) => result.future);
      await pumpReview(
        tester,
        _case(
          SuspectedAgeBand.age13To15,
          MinorReviewResolutionType.parentVideoOrEmail,
          MinorReviewCaseState.submittedForReview,
        ),
        refreshedCase: _case(
          SuspectedAgeBand.age13To15,
          MinorReviewResolutionType.parentVideoOrEmail,
          MinorReviewCaseState.restrictedPendingUserResponse,
        ),
      );
      await tester.tap(find.text(l10n.supportSaveLogs));
      await tester.pump();
      expect(find.text(l10n.minorAccountReviewContinue), findsNothing);

      await tester.tap(find.text(l10n.minorAccountReviewCheckAgain));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.minorAccountReviewContinue), findsOneWidget);

      result.complete(const LogExportResult.noLogs());
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportNoLogsToExport), findsOneWidget);
    });

    // A refresh that fails while the delete sheet is open, as a resume
    // refresh can, swaps the loaded view for the error view. The deletion
    // confirmed after that must still run, not stop on the unmounted view.
    testWidgets('runs a deletion confirmed after a refresh fails', (
      tester,
    ) async {
      when(authService.checkAccountDeletionReadiness).thenAnswer(
        (_) async => AccountDeletionReadiness.requiresReauthentication,
      );
      await pumpReview(
        tester,
        null,
        refreshError: Exception('status unavailable'),
        // The sheet closes itself through GoRouter.
        goRouter: MockGoRouter(),
      );
      await scrollUntilTappable(
        tester,
        find.text(l10n.nostrSettingsDeleteAccount),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text(l10n.nostrSettingsDeleteAccount));
      await tester.pumpAndSettle();

      ProviderScope.containerOf(
        tester.element(find.byType(MinorAccountReviewScreen)),
      ).invalidate(currentMinorAccountReviewStatusProvider);
      await tester.pumpAndSettle();
      expect(find.text(l10n.minorAccountReviewErrorTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          DivineButton,
          l10n.deleteAccountDeleteAllContentButton,
        ),
      );
      await tester.pumpAndSettle();

      verify(authService.checkAccountDeletionReadiness).called(1);
      expect(find.text(l10n.deleteAccountReauthRequired), findsOneWidget);
    });
  });

  group('renders', () {
    // The row sits on the adaptive page, where the fixed VineTheme.error red
    // holds only 3.45:1 in light mode. The palette token is #8C1D18 there.
    testWidgets('Delete Account takes its red from the palette on light', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpReview(tester, null, theme: VineTheme.lightTheme);

      final color = tester
          .widget<Text>(find.text(l10n.nostrSettingsDeleteAccount))
          .style
          ?.color;
      expect(color, VineTheme.lightColors.onErrorContainer);
      expect(color, isNot(VineTheme.error));
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
