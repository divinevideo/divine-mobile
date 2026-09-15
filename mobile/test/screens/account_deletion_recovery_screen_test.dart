// ABOUTME: Widget tests for the account-deletion recovery Cubit view.
// ABOUTME: Pins localized copy and valid actions for every recovery state.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';

class _MockRecoveryCubit extends MockCubit<AccountDeletionRecoveryState>
    implements AccountDeletionRecoveryCubit {}

const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
  usernameExpiresAt: 1787450400,
);

Widget _app(
  AccountDeletionRecoveryCubit cubit, {
  Stream<AccountDeletionRecoveryState>? states,
}) {
  if (states != null) whenListen(cubit, states);
  final router = GoRouter(
    initialLocation: AccountDeletionRecoveryScreen.path,
    routes: [
      GoRoute(
        path: AccountDeletionRecoveryScreen.path,
        builder: (_, _) => BlocProvider.value(
          value: cubit,
          child: const AccountDeletionRecoveryView(),
        ),
      ),
      GoRoute(
        path: '/home/0',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, _) => const Scaffold(body: Text('Welcome')),
      ),
    ],
  );
  return MaterialApp.router(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  late _MockRecoveryCubit cubit;

  setUp(() {
    cubit = _MockRecoveryCubit();
    when(cubit.cancel).thenAnswer((_) async {});
    when(cubit.retry).thenAnswer((_) async {});
    when(cubit.signOut).thenAnswer((_) async {});
    when(cubit.switchAccount).thenAnswer((_) async => true);
    when(cubit.completeLocalCleanup).thenAnswer((_) async {});
    when(cubit.acknowledgeCompletion).thenAnswer((_) async {});
    when(() => cubit.contentDeletionUnverified).thenReturn(false);
  });

  group('renders and navigation', () {
    testWidgets('recoverable username offers only restore', (tester) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: _recoverable,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionRecoveryTitle), findsOneWidget);
      expect(find.textContaining('reserved for you until'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
      );

      verify(cubit.cancel).called(1);
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionCancelAttempt),
        findsNothing,
      );
    });

    testWidgets('preparing attempt without username offers cancellation', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.preparing,
          ),
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionCancelAttemptBody), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionCancelAttempt),
        findsOneWidget,
      );
    });

    testWidgets('cancelling attempt has no conflicting restore action', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.cancelInFlight,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.preparing,
            operation: AccountDeletionAttemptOperation.cancelling,
            username: 'alice',
          ),
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionCancellingBody), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
        findsNothing,
      );
    });

    testWidgets('paused processing keeps support and account switch actions', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.processing,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.processing,
          ),
          pollingPaused: true,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.widgetWithText(DivineButton, l10n.supportContactSupport),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.authUseAnotherAccount),
        findsOneWidget,
      );
    });

    testWidgets('paused submission confirmation offers recovery actions', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.confirmingSubmission,
          attempt: _recoverable,
          pollingPaused: true,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.widgetWithText(DivineButton, l10n.supportContactSupport),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.authUseAnotherAccount),
        findsOneWidget,
      );
    });

    testWidgets('processing remains non-cancellable', (tester) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.processing,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.processing,
          ),
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionFinishingBody), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUseAnotherAccount),
      );
      await tester.pumpAndSettle();

      verify(cubit.switchAccount).called(1);
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('cleanup failures distinguish keychain from local data', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.cleanupFailed,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.completed,
          ),
          failure: AccountDeletionRecoveryFailure.keychainCleanup,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.deleteAccountKeyDeletionWarning), findsOneWidget);
      expect(
        find.text(l10n.deleteAccountLocalDataDeletionFailed),
        findsNothing,
      );
    });

    testWidgets('terminal failure offers support and sign out', (tester) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.terminalFailure,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.terminalFailure,
            failureMessage: 'Server English must not be shown.',
          ),
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.textContaining('Server English'), findsNothing);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
      );
      verify(cubit.signOut).called(1);
    });

    testWidgets('Keycast terminal failure explains deletion is incomplete', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.terminalFailure,
          attempt: AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.terminalFailure,
            failureCode: 'keycast_deletion_failed',
          ),
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.deleteAccountServerDeletionFailed), findsOneWidget);
      expect(find.text(l10n.accountDeletionTerminalFailureBody), findsNothing);
    });

    testWidgets('fail-closed load error keeps retry and sign out reachable', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.statusLookup,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.minorAccountReviewCheckingStatusTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining(RegExp('delet', caseSensitive: false)),
        findsNothing,
      );
      expect(find.text(l10n.authUnexpectedError), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, l10n.commonRetry),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(DivineButton, l10n.commonRetry));
      verify(cubit.retry).called(1);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
      );
      verify(cubit.signOut).called(1);
    });

    testWidgets('signer failure asks the user to sign in again', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.signerUnavailable,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.authSessionExpired), findsOneWidget);
      expect(find.text(l10n.authUnexpectedError), findsNothing);
      expect(
        find.widgetWithText(DivineButton, l10n.commonRetry),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
        findsOneWidget,
      );
    });

    testWidgets(
      'sign-out failure offers one sign-out retry with generic copy',
      (tester) async {
        when(() => cubit.state).thenReturn(
          const AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.signOutFailed,
          ),
        );
        await tester.pumpWidget(_app(cubit));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.authUnexpectedError), findsOneWidget);
        expect(
          find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(DivineButton, l10n.commonRetry),
          findsNothing,
        );
        await tester.tap(
          find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
        );
        verify(cubit.signOut).called(1);
      },
    );

    testWidgets('fail-closed loading keeps sign out reachable', (tester) async {
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loading,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.minorAccountReviewCheckingStatusTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining(RegExp('delet', caseSensitive: false)),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
      );
      verify(cubit.signOut).called(1);
    });

    testWidgets('resolved state returns to the feed', (tester) async {
      const initial = AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.restorable,
        attempt: _recoverable,
      );
      const resolved = AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.resolved,
      );
      when(() => cubit.state).thenReturn(initial);
      await tester.pumpWidget(_app(cubit, states: Stream.value(resolved)));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('completed deletion remains visible until acknowledged', (
      tester,
    ) async {
      const processing = AccountDeletionAttempt(
        id: 'attempt-id',
        status: AccountDeletionAttemptStatus.processing,
      );
      const initial = AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.processing,
        attempt: processing,
      );
      when(() => cubit.state).thenReturn(initial);
      await tester.pumpWidget(
        _app(
          cubit,
          states: Stream.value(
            const AccountDeletionRecoveryState(
              status: AccountDeletionRecoveryStatus.completed,
              attempt: processing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.deleteAccountSuccess), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.commonClose),
      );
      verify(cubit.acknowledgeCompletion).called(1);
    });

    testWidgets('an unverified content sweep never claims full deletion', (
      tester,
    ) async {
      const processing = AccountDeletionAttempt(
        id: 'attempt-id',
        status: AccountDeletionAttemptStatus.processing,
      );
      when(() => cubit.contentDeletionUnverified).thenReturn(true);
      when(() => cubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.completed,
          attempt: processing,
        ),
      );
      await tester.pumpWidget(_app(cubit));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.deleteAccountSuccessContentUnverified),
        findsOneWidget,
      );
      expect(find.text(l10n.deleteAccountSuccess), findsNothing);
    });
  });
}
