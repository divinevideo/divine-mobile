// ABOUTME: Tests for WelcomeBloc
// ABOUTME: Verifies multi-account loading, selection, and auth actions

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockAuthService extends Mock implements AuthService {}

class _CapturingObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

const _testPubkeyHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _testPubkeyHex2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

final _testProfile = UserProfile(
  pubkey: _testPubkeyHex,
  displayName: 'Test User',
  picture: 'https://example.com/avatar.png',
  nip05: 'testuser@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8',
);

final _testProfile2 = UserProfile(
  pubkey: _testPubkeyHex2,
  displayName: 'Second User',
  picture: 'https://example.com/avatar2.png',
  nip05: 'second@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8',
);

final _testKnownAccount = KnownAccount(
  pubkeyHex: _testPubkeyHex,
  authSource: AuthenticationSource.automatic,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 6),
);

final _testKnownAccount2 = KnownAccount(
  pubkeyHex: _testPubkeyHex2,
  authSource: AuthenticationSource.amber,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 3),
);

const _testPreviousAccount = PreviousAccount(
  pubkeyHex: _testPubkeyHex,
  authSource: AuthenticationSource.automatic,
);

const _testPreviousAccount2 = PreviousAccount(
  pubkeyHex: _testPubkeyHex2,
  authSource: AuthenticationSource.amber,
);

void main() {
  late _MockUserProfilesDao mockUserProfilesDao;
  late _MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(AuthenticationSource.none);
  });

  setUp(() {
    mockUserProfilesDao = _MockUserProfilesDao();
    mockAuthService = _MockAuthService();

    when(
      () => mockUserProfilesDao.getProfile(any()),
    ).thenAnswer((_) async => null);
    when(() => mockAuthService.getKnownAccounts()).thenAnswer((_) async => []);
    when(
      () => mockAuthService.getSessionRecoveryAnchorNpub(),
    ).thenAnswer((_) async => null);
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
    when(
      () => mockAuthService.signInForAccount(any(), any()),
    ).thenAnswer((_) async {});
  });

  WelcomeBloc buildBloc() => WelcomeBloc(
    userProfilesDao: mockUserProfilesDao,
    authService: mockAuthService,
  );

  group(WelcomeBloc, () {
    test('initial state is $WelcomeState with initial status', () async {
      final bloc = buildBloc();
      expect(bloc.state, const WelcomeState());
      expect(bloc.state.status, WelcomeStatus.initial);
      await bloc.close();
    });

    group('$WelcomeStarted', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with no returning users when no known accounts',
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits accounts immediately, then hydrates profiles later',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => _testProfile);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          // First: accounts without profiles
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
          // Second: accounts with hydrated profiles
          WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [
              PreviousAccount(
                pubkeyHex: _testPubkeyHex,
                authSource: AuthenticationSource.automatic,
                profile: _testProfile,
              ),
            ],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with account but null profile when not cached',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with account and records addError when profile '
        'lookup throws',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenThrow(Exception('DB error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      test(
        'does not addError after close when _hydrateAccount completes '
        'post-close (regression #4605)',
        () async {
          // Pin the lifecycle race: _hydrateProfiles is dispatched
          // fire-and-forget from _onWelcomeStarted. If the user navigates
          // away before the in-flight getProfile resolves, the bloc closes
          // and an unguarded addError in the catch arm would throw
          // StateError. The guard added in #4605 must suppress the forward.
          final completer = Completer<UserProfile?>();
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) => completer.future);

          final observer = _CapturingObserver();
          final priorObserver = Bloc.observer;
          Bloc.observer = observer;
          addTearDown(() => Bloc.observer = priorObserver);

          final bloc = buildBloc()..add(const WelcomeStarted());
          // Let the handler reach the await on getProfile.
          await pumpEventQueue();

          // Close the bloc while _hydrateAccount is still awaiting.
          await bloc.close();

          // Now fail the in-flight future; the catch arm runs post-close.
          completer.completeError(Exception('DB error'));
          // Drain microtasks queued by the completion.
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test(
        'does not add after close when _hydrateProfiles completes '
        'successfully post-close (regression #4605)',
        () async {
          final completer = Completer<UserProfile?>();
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) => completer.future);

          final observer = _CapturingObserver();
          final priorObserver = Bloc.observer;
          Bloc.observer = observer;
          addTearDown(() => Bloc.observer = priorObserver);

          final bloc = buildBloc()..add(const WelcomeStarted());
          await pumpEventQueue();

          await bloc.close();

          completer.complete(_testProfile);
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with multiple accounts then hydrates profiles',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount, _testKnownAccount2]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => _testProfile);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex2),
          ).thenAnswer((_) async => _testProfile2);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          // First: accounts without profiles
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          ),
          // Second: accounts with hydrated profiles
          WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [
              PreviousAccount(
                pubkeyHex: _testPubkeyHex,
                authSource: AuthenticationSource.automatic,
                profile: _testProfile,
              ),
              PreviousAccount(
                pubkeyHex: _testPubkeyHex2,
                authSource: AuthenticationSource.amber,
                profile: _testProfile2,
              ),
            ],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'keeps an account with a pending deletion receipt selectable',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount, _testKnownAccount2]);
        },
        build: () => WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
          deletionPendingPubkeyHex: _testPubkeyHex,
        ),
        act: (bloc) => bloc.add(
          const WelcomeStarted(initialSelectedPubkeyHex: _testPubkeyHex),
        ),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex,
          ),
        ],
      );
    });

    group('$WelcomeLastUserDismissed', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'clears returning user data',
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeLastUserDismissed()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
      );
    });

    for (final event in <WelcomeEvent>[
      const WelcomeLogBackInRequested(),
      const WelcomeCancelSwitchRequested(),
    ]) {
      blocTest<WelcomeBloc, WelcomeState>(
        '$event preserves typed cleanup failure and a retryable account',
        setUp: () {
          when(() => mockAuthService.signInForAccount(any(), any())).thenThrow(
            const UserDataCleanupException(
              'Could not clear account data safely',
            ),
          );
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(event),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.accountCleanupFailed,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        errors: () => [isA<UserDataCleanupException>()],
        verify: (_) {
          verifyNever(() => mockAuthService.acceptTerms());
        },
      );
    }

    group('$WelcomeLogBackInRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'routes a pending deletion account to recovery without signing in',
        build: () => WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
          deletionPendingPubkeyHex: _testPubkeyHex,
        ),
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.navigatingToAccountDeletionRecovery,
            previousAccounts: [_testPreviousAccount],
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        verify: (_) {
          verifyNever(
            () => mockAuthService.signInForAccount(any(), any()),
          );
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits accepting and calls signInForAccount with selected account',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
        ],
        verify: (_) {
          verify(
            () => mockAuthService.signInForAccount(
              _testPubkeyHex,
              AuthenticationSource.automatic,
            ),
          ).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'signs in with explicitly selected account from multi-account list',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex2,
          ),
        ],
        verify: (_) {
          verify(
            () => mockAuthService.signInForAccount(
              _testPubkeyHex2,
              AuthenticationSource.amber,
            ),
          ).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'does nothing when no accounts exist',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => <WelcomeState>[],
        verify: (_) {
          verifyNever(() => mockAuthService.signInForAccount(any(), any()));
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits error and records addError on signInForAccount failure',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(Exception('Network error'));
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.error,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits error, records addError, then navigates to login options on '
        '$SessionExpiredException',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(SessionExpiredException());
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.sessionExpired,
            previousAccounts: [_testPreviousAccount],
          ),
          const WelcomeState(
            status: WelcomeStatus.navigatingToLoginOptions,
            previousAccounts: [_testPreviousAccount],
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
        errors: () => [isA<SessionExpiredException>()],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'navigates to login options on $AccountRestoreFailedException '
        '(missing keys) instead of looping silently',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(
            const AccountRestoreFailedException(
              _testPubkeyHex,
              AuthState.unauthenticated,
            ),
          );
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.accountRestoreFailed,
            previousAccounts: [_testPreviousAccount],
          ),
          const WelcomeState(
            status: WelcomeStatus.navigatingToLoginOptions,
            previousAccounts: [_testPreviousAccount],
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
        errors: () => [isA<AccountRestoreFailedException>()],
      );
    });

    group('$WelcomeCancelSwitchRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'routes a pending previous account to recovery without signing in',
        build: () => WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
          deletionPendingPubkeyHex: _testPubkeyHex,
        ),
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.navigatingToAccountDeletionRecovery,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => mockAuthService.signInForAccount(any(), any()),
          );
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'restores the previous account regardless of selected account',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex,
          ),
        ],
        verify: (_) {
          verify(
            () => mockAuthService.signInForAccount(
              _testPubkeyHex,
              AuthenticationSource.automatic,
            ),
          ).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'records addError and redirects to login options on '
        '$SessionExpiredException',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(SessionExpiredException());
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.navigatingToLoginOptions,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
        errors: () => [isA<SessionExpiredException>()],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'records addError and redirects to login options on '
        '$AccountRestoreFailedException',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(
            const AccountRestoreFailedException(
              _testPubkeyHex,
              AuthState.unauthenticated,
            ),
          );
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.navigatingToLoginOptions,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
        errors: () => [isA<AccountRestoreFailedException>()],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'records addError and emits error on restore failure',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(Exception('restore failed'));
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.error,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'does nothing when there is no previous account to restore',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeCancelSwitchRequested()),
        expect: () => <WelcomeState>[],
        verify: (_) {
          verifyNever(() => mockAuthService.signInForAccount(any(), any()));
        },
      );
    });

    group('$WelcomeAccountSelected', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits updated selectedPubkeyHex',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
        ),
        act: (bloc) =>
            bloc.add(const WelcomeAccountSelected(pubkeyHex: _testPubkeyHex2)),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
      );
    });

    group('$WelcomeCreateAccountRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls acceptTerms and emits navigating then loaded',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeCreateAccountRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.navigatingToCreateAccount),
          const WelcomeState(status: WelcomeStatus.loaded),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });

    group('$WelcomeLoginOptionsRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls acceptTerms and emits navigating then loaded',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLoginOptionsRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.navigatingToLoginOptions),
          const WelcomeState(status: WelcomeStatus.loaded),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });
  });

  group('$WelcomeState', () {
    test('hasReturningUsers is true when previousAccounts is not empty', () {
      const state = WelcomeState(previousAccounts: [_testPreviousAccount]);
      expect(state.hasReturningUsers, isTrue);
    });

    test('hasReturningUsers is false when previousAccounts is empty', () {
      const state = WelcomeState();
      expect(state.hasReturningUsers, isFalse);
    });

    test('isAccepting is true when status is accepting', () {
      const state = WelcomeState(status: WelcomeStatus.accepting);
      expect(state.isAccepting, isTrue);
    });

    test('selectedAccount returns first when no selection', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
      );
      expect(state.selectedAccount, equals(_testPreviousAccount));
    });

    test('selectedAccount returns matching account', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
        selectedPubkeyHex: _testPubkeyHex2,
      );
      expect(state.selectedAccount, equals(_testPreviousAccount2));
    });

    test('selectedAccount returns first when selection not found', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount],
        selectedPubkeyHex: _testPubkeyHex2,
      );
      expect(state.selectedAccount, equals(_testPreviousAccount));
    });

    test('selectedAccount returns null when no accounts', () {
      const state = WelcomeState();
      expect(state.selectedAccount, isNull);
    });

    test('copyWith clearAccounts removes accounts', () {
      const state = WelcomeState(
        status: WelcomeStatus.loaded,
        previousAccounts: [_testPreviousAccount],
      );
      final cleared = state.copyWith(clearAccounts: true);
      expect(cleared.previousAccounts, isEmpty);
      expect(cleared.status, WelcomeStatus.loaded);
    });

    test('copyWith clearSelectedPubkey removes selection', () {
      const state = WelcomeState(selectedPubkeyHex: _testPubkeyHex);
      final cleared = state.copyWith(clearSelectedPubkey: true);
      expect(cleared.selectedPubkeyHex, isNull);
    });

    test('copyWith clearSigningIn removes signing in state', () {
      const state = WelcomeState(signingInPubkeyHex: _testPubkeyHex);
      final cleared = state.copyWith(clearSigningIn: true);
      expect(cleared.signingInPubkeyHex, isNull);
    });

    test('copyWith clearRecoveryAnchor removes anchor', () {
      const state = WelcomeState(recoveryAnchorPubkeyHex: _testPubkeyHex);
      final cleared = state.copyWith(clearRecoveryAnchor: true);
      expect(cleared.recoveryAnchorPubkeyHex, isNull);
    });

    test('copyWith status resets from error', () {
      const state = WelcomeState(status: WelcomeStatus.error);
      final cleared = state.copyWith(status: WelcomeStatus.loaded);
      expect(cleared.status, equals(WelcomeStatus.loaded));
    });

    test('hasRecoveryAnchor is true when recovery anchor is set', () {
      const state = WelcomeState(recoveryAnchorPubkeyHex: _testPubkeyHex);
      expect(state.hasRecoveryAnchor, isTrue);
    });

    group('hasCrossAccountMismatch', () {
      test('is false when no recovery anchor is set', () {
        const state = WelcomeState(
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
        );
        expect(state.hasCrossAccountMismatch, isFalse);
      });

      test('is false when no accounts are present', () {
        const state = WelcomeState(
          recoveryAnchorPubkeyHex: _testPubkeyHex,
        );
        expect(state.hasCrossAccountMismatch, isFalse);
      });

      test(
        'is false when the selected account matches the recovery anchor',
        () {
          // Anchor IS the selected account — safe default, no banner needed.
          const state = WelcomeState(
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex,
            recoveryAnchorPubkeyHex: _testPubkeyHex,
          );
          expect(state.hasCrossAccountMismatch, isFalse);
        },
      );

      test(
        'is true when the selected account differs from the recovery anchor',
        () {
          // User has switched dropdown to account 2, but anchor is account 1.
          const state = WelcomeState(
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            recoveryAnchorPubkeyHex: _testPubkeyHex,
          );
          expect(state.hasCrossAccountMismatch, isTrue);
        },
      );

      test(
        'is true when selectedPubkeyHex is null (defaults to first account) '
        'and first account differs from anchor',
        () {
          // Anchor points to account 2, but no explicit selection so
          // selectedAccount falls back to previousAccounts.first (account 1).
          const state = WelcomeState(
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            recoveryAnchorPubkeyHex: _testPubkeyHex2,
          );
          expect(state.hasCrossAccountMismatch, isTrue);
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Session recovery anchor — WelcomeBloc._onStarted (#4624)
  // ---------------------------------------------------------------------------

  group('WelcomeStarted with session recovery anchor', () {
    test(
      'pre-selects the anchor account when anchor differs from '
      'most-recently-used first account (cross-account scenario)',
      () async {
        // Simulate the incident: most-recently-used account is account 2
        // (stamped by _redirectRecoveryToRemainingAccount), but the recovery
        // anchor is account 1 (what the user was actually signed into).
        // The bloc should pre-select account 1 so the welcome screen shows
        // the right account by default.

        // _testKnownAccount has pubkey1, _testKnownAccount2 has pubkey2.
        // Arrange the list so account2 is "first" (most recently used).
        final knownAccounts = [_testKnownAccount2, _testKnownAccount];
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenAnswer((_) async => knownAccounts);

        // Anchor points to account 1 (the user's actual active account).
        final anchorNpub = NostrKeyUtils.encodePubKey(_testPubkeyHex);
        when(
          () => mockAuthService.getSessionRecoveryAnchorNpub(),
        ).thenAnswer((_) async => anchorNpub);

        final bloc = WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
        );
        bloc.add(const WelcomeStarted());
        // Wait for _onStarted to complete (accounts load is async).
        await pumpEventQueue();

        final state = bloc.state;
        expect(
          state.selectedPubkeyHex,
          equals(_testPubkeyHex),
          reason:
              'The anchor account should be pre-selected on the welcome '
              'screen even when it is not the most-recently-used account, '
              'preventing the user from unknowingly signing into the wrong '
              'account',
        );
        expect(
          state.recoveryAnchorPubkeyHex,
          equals(_testPubkeyHex),
          reason: 'The recovery anchor pubkey should be stored in state',
        );
        expect(
          state.hasCrossAccountMismatch,
          isFalse,
          reason:
              'hasCrossAccountMismatch should be false because the '
              'pre-selected account matches the anchor (safe default)',
        );

        await bloc.close();
      },
    );

    test(
      'does not set recoveryAnchorPubkeyHex when no anchor is stored '
      '(normal single-account flow)',
      () async {
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenAnswer((_) async => [_testKnownAccount]);
        when(
          () => mockAuthService.getSessionRecoveryAnchorNpub(),
        ).thenAnswer((_) async => null);

        final bloc = WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
        );
        bloc.add(const WelcomeStarted());
        await pumpEventQueue();

        expect(bloc.state.recoveryAnchorPubkeyHex, isNull);
        expect(bloc.state.hasCrossAccountMismatch, isFalse);

        await bloc.close();
      },
    );

    test(
      'event.initialSelectedPubkeyHex takes priority over the recovery anchor '
      'for pre-selection (router deep-link flow)',
      () async {
        // When the router passes initialSelectedPubkeyHex (e.g., from the
        // account-switcher deep link ?selectedPubkey=...), that explicit
        // selection must win over the recovery anchor.
        final knownAccounts = [_testKnownAccount, _testKnownAccount2];
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenAnswer((_) async => knownAccounts);

        final anchorNpub = NostrKeyUtils.encodePubKey(_testPubkeyHex);
        when(
          () => mockAuthService.getSessionRecoveryAnchorNpub(),
        ).thenAnswer((_) async => anchorNpub);

        final bloc = WelcomeBloc(
          userProfilesDao: mockUserProfilesDao,
          authService: mockAuthService,
        );
        // Pass account2 as the router-provided initial selection.
        bloc.add(
          const WelcomeStarted(initialSelectedPubkeyHex: _testPubkeyHex2),
        );
        await pumpEventQueue();

        // Router-provided selection wins over anchor.
        expect(
          bloc.state.selectedPubkeyHex,
          equals(_testPubkeyHex2),
          reason:
              'An explicit initialSelectedPubkeyHex from the router '
              'must take priority over the recovery anchor pre-selection',
        );

        await bloc.close();
      },
    );
  });
}
