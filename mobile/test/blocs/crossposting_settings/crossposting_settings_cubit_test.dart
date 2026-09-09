// ABOUTME: Tests repository-backed crossposting settings orchestration
// ABOUTME: Covers OAuth callbacks, refreshes, duplicate actions, and rollback

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockCrosspostingRepository extends Mock
    implements CrosspostingRepository {}

class _RecordingCrosspostingSettingsCubit extends CrosspostingSettingsCubit {
  _RecordingCrosspostingSettingsCubit({
    required super.repository,
    required super.launchOAuth,
    super.nonceGenerator,
    super.oauthCallbackTimeout,
  });

  final reportedErrors = <Object>[];

  @override
  void onError(Object error, StackTrace stackTrace) {
    reportedErrors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  group(CrosspostingSettingsCubit, () {
    late _MockCrosspostingRepository repository;
    late List<Uri> launchedUrls;
    late Uri? callbackUri;

    const instagramConnection = CrosspostingConnection(
      id: 'instagram-connection',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: 'divine.creator',
    );
    const instagramNeedsReauth = CrosspostingConnection(
      id: 'instagram-stale',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.needsReauth,
      externalAccountName: 'divine.creator',
    );
    const instagramSettings = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.instagram,
      supportsAutomatic: true,
      connection: instagramConnection,
      mode: CrosspostingMode.manual,
    );
    const instagramReauthSettings = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.instagram,
      supportsAutomatic: true,
      connection: instagramNeedsReauth,
      mode: CrosspostingMode.disabled,
    );
    const xSettings = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.x,
      supportsAutomatic: true,
      mode: CrosspostingMode.disabled,
    );
    const initialSettings = [instagramSettings, xSettings];
    final authorizationUrl = Uri.parse('https://provider.example/oauth');

    setUpAll(() {
      registerFallbackValue(CrosspostingPlatform.instagram);
      registerFallbackValue(CrosspostingMode.disabled);
      registerFallbackValue(Uri());
    });

    setUp(() {
      repository = _MockCrosspostingRepository();
      launchedUrls = [];
      callbackUri = Uri.parse(
        'https://divine.video/app/callback'
        '?app_state=test-nonce&connection=connected&platform=instagram',
      );
      when(
        () => repository.loadSettings(),
      ).thenAnswer((_) async => initialSettings);
      when(
        () => repository.startConnection(
          any(),
          returnUrl: any(named: 'returnUrl'),
        ),
      ).thenAnswer(
        (_) async => CrosspostingStart(
          authorizationUrl: authorizationUrl,
          state: 'oauth-state',
        ),
      );
      when(
        () => repository.disconnect(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => repository.setMode(any(), any()),
      ).thenAnswer((_) async {});
    });

    _RecordingCrosspostingSettingsCubit buildCubit({
      Future<Uri?> Function(Uri)? launcher,
      Duration? oauthCallbackTimeout,
    }) {
      return _RecordingCrosspostingSettingsCubit(
        repository: repository,
        nonceGenerator: () => 'test-nonce',
        oauthCallbackTimeout:
            oauthCallbackTimeout ?? const Duration(minutes: 3),
        launchOAuth:
            launcher ??
            (url) async {
              launchedUrls.add(url);
              return callbackUri;
            },
      );
    }

    group('load and refresh', () {
      blocTest<CrosspostingSettingsCubit, CrosspostingSettingsState>(
        'loads settings through the repository',
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<CrosspostingSettingsState>().having(
            (state) => state.status,
            'status',
            CrosspostingSettingsStatus.loading,
          ),
          isA<CrosspostingSettingsState>()
              .having(
                (state) => state.status,
                'status',
                CrosspostingSettingsStatus.loaded,
              )
              .having((state) => state.entries, 'entries', initialSettings),
        ],
        verify: (_) => verify(() => repository.loadSettings()).called(1),
      );

      blocTest<CrosspostingSettingsCubit, CrosspostingSettingsState>(
        'reports an initial load failure',
        build: () {
          when(() => repository.loadSettings()).thenThrow(StateError('down'));
          return buildCubit();
        },
        act: (cubit) => cubit.load(),
        errors: () => [isA<StateError>()],
        verify: (cubit) {
          expect(cubit.state.status, CrosspostingSettingsStatus.failure);
          expect(cubit.state.error, CrosspostingSettingsError.generic);
          expect(cubit.state.pendingAction, isNull);
        },
      );

      blocTest<CrosspostingSettingsCubit, CrosspostingSettingsState>(
        'refreshes loaded settings without entering loading',
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);
          await cubit.refresh();
        },
        verify: (cubit) {
          expect(cubit.state.status, CrosspostingSettingsStatus.loaded);
          expect(cubit.state.entries, const [xSettings]);
          verify(() => repository.loadSettings()).called(2);
        },
      );

      blocTest<CrosspostingSettingsCubit, CrosspostingSettingsState>(
        'retains loaded entries and reports a refresh failure',
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          when(() => repository.loadSettings()).thenThrow(StateError('down'));
          await cubit.refresh();
        },
        errors: () => [isA<StateError>()],
        verify: (cubit) {
          expect(cubit.state.status, CrosspostingSettingsStatus.loaded);
          expect(cubit.state.entries, initialSettings);
          expect(cubit.state.error, CrosspostingSettingsError.generic);
          expect(cubit.state.pendingAction, isNull);
        },
      );

      test(
        'refresh delegates to load before the first successful load',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.refresh();

          expect(cubit.state.status, CrosspostingSettingsStatus.loaded);
          verify(() => repository.loadSettings()).called(1);
        },
      );

      test('refresh is skipped while a user action is pending', () async {
        final disconnectCompleter = Completer<void>();
        when(
          () => repository.disconnect(any(), any()),
        ).thenAnswer((_) => disconnectCompleter.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        final disconnect = cubit.disconnect(CrosspostingPlatform.instagram);
        await cubit.refresh();

        verify(() => repository.loadSettings()).called(1);
        disconnectCompleter.complete();
        await disconnect;
      });

      test('load owns the operation gate before refresh can start', () async {
        final firstLoad = Completer<List<CrosspostingPlatformSettings>>();
        final overlappingLoad = Completer<List<CrosspostingPlatformSettings>>();
        var calls = 0;
        when(() => repository.loadSettings()).thenAnswer((_) {
          calls += 1;
          return calls == 1 ? firstLoad.future : overlappingLoad.future;
        });
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final load = cubit.load();
        final refresh = cubit.refresh();
        firstLoad.complete(const [instagramSettings]);
        overlappingLoad.complete(const [xSettings]);
        await Future.wait([load, refresh]);

        expect(calls, 1);
        expect(cubit.state.entries, const [instagramSettings]);
      });

      test(
        'refresh blocks actions until its repository read completes',
        () async {
          final refreshStarted = Completer<void>();
          final refreshed = Completer<List<CrosspostingPlatformSettings>>();
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();
          when(() => repository.loadSettings()).thenAnswer((_) {
            refreshStarted.complete();
            return refreshed.future;
          });

          final refresh = cubit.refresh();
          await refreshStarted.future;
          expect(
            cubit.state.pendingAction,
            CrosspostingPlatformAction.refreshing,
          );
          await cubit.connect(CrosspostingPlatform.x);

          verifyNever(
            () => repository.startConnection(
              any(),
              returnUrl: any(named: 'returnUrl'),
            ),
          );
          refreshed.complete(const [xSettings]);
          await refresh;
          expect(cubit.state.entries, const [xSettings]);
          expect(cubit.state.pendingAction, isNull);
        },
      );

      test(
        'load blocks connect while its repository read is pending',
        () async {
          final loadStarted = Completer<void>();
          final loaded = Completer<List<CrosspostingPlatformSettings>>();
          when(() => repository.loadSettings()).thenAnswer((_) {
            loadStarted.complete();
            return loaded.future;
          });
          final cubit = buildCubit();
          addTearDown(cubit.close);

          final load = cubit.load();
          await loadStarted.future;
          await cubit.connect(CrosspostingPlatform.instagram);

          verifyNever(
            () => repository.startConnection(
              any(),
              returnUrl: any(named: 'returnUrl'),
            ),
          );
          loaded.complete(initialSettings);
          await load;
        },
      );
    });

    group('connect', () {
      test('default OAuth nonces are random URL-safe values', () {
        final first = generateCrosspostingOAuthNonce();
        final second = generateCrosspostingOAuthNonce();

        expect(first, hasLength(43));
        expect(second, hasLength(43));
        expect(first, isNot(second));
        expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(first), isTrue);
        expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(second), isTrue);
      });

      test(
        'uses the exact universal-link return URL and launches auth',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.connect(CrosspostingPlatform.instagram);

          final captured =
              verify(
                    () => repository.startConnection(
                      CrosspostingPlatform.instagram,
                      returnUrl: captureAny(named: 'returnUrl'),
                    ),
                  ).captured.single
                  as Uri;
          expect(
            captured.toString(),
            'https://divine.video/app/callback?app_state=test-nonce',
          );
          expect(launchedUrls, [authorizationUrl]);
        },
      );

      for (final testCase
          in <
            ({
              String query,
              CrosspostingOAuthOutcome outcome,
            })
          >[
            (
              query: 'connection=connected&platform=instagram',
              outcome: CrosspostingOAuthOutcome.connected,
            ),
            (
              query:
                  'connection=failed&platform=instagram&reason=provider_denied',
              outcome: CrosspostingOAuthOutcome.denied,
            ),
            (
              query: 'connection=failed&platform=instagram&reason=server_error',
              outcome: CrosspostingOAuthOutcome.failed,
            ),
            (
              query: 'connection=failed&platform=instagram',
              outcome: CrosspostingOAuthOutcome.failed,
            ),
          ]) {
        test('refreshes before surfacing ${testCase.outcome.name}', () async {
          final refreshStarted = Completer<void>();
          final refreshed = Completer<List<CrosspostingPlatformSettings>>();
          callbackUri = Uri.parse(
            'https://divine.video/app/callback'
            '?app_state=test-nonce&${testCase.query}',
          );
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) {
            refreshStarted.complete();
            return refreshed.future;
          });
          final cubit = buildCubit();
          addTearDown(cubit.close);

          final connect = cubit.connect(CrosspostingPlatform.instagram);
          await refreshStarted.future;

          expect(
            cubit.state.pendingAction,
            CrosspostingPlatformAction.connecting,
          );
          expect(cubit.state.outcome, isNull);

          refreshed.complete(const [instagramSettings]);
          await connect;

          expect(cubit.state.pendingAction, isNull);
          expect(cubit.state.entries, const [instagramSettings]);
          expect(cubit.state.outcome, testCase.outcome);
          expect(cubit.state.outcomePlatform, CrosspostingPlatform.instagram);
          expect(cubit.state.outcomeAttempt, 1);
        });
      }

      test(
        'cancellation refreshes without surfacing an error or outcome',
        () async {
          callbackUri = null;
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);
          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.connect(CrosspostingPlatform.instagram);

          expect(cubit.state.entries, const [xSettings]);
          expect(cubit.state.pendingAction, isNull);
          expect(cubit.state.error, isNull);
          expect(cubit.state.outcome, isNull);
          verify(() => repository.loadSettings()).called(1);
        },
      );

      final invalidCallbacks = <String, String>{
        'custom scheme': 'divine://divine.video/app/callback?connection=connected&platform=instagram',
        'http scheme': 'http://divine.video/app/callback?connection=connected&platform=instagram',
        'lookalike host': 'https://divine.video.evil.test/app/callback?connection=connected&platform=instagram',
        'subdomain host': 'https://www.divine.video/app/callback?connection=connected&platform=instagram',
        'wrong path': 'https://divine.video/app/callback/extra?connection=connected&platform=instagram',
        'unknown platform': 'https://divine.video/app/callback?connection=connected&platform=bluesky',
        'mismatched supported platform':
            'https://divine.video/app/callback?connection=connected&platform=x',
        'unknown connection': 'https://divine.video/app/callback?connection=pending&platform=instagram',
        'missing connection':
            'https://divine.video/app/callback?platform=instagram',
        'missing platform':
            'https://divine.video/app/callback?connection=connected',
        'duplicate connection': 'https://divine.video/app/callback?connection=connected&connection=failed&platform=instagram',
        'duplicate platform': 'https://divine.video/app/callback?connection=connected&platform=instagram&platform=x',
        'explicit port': 'https://divine.video:8443/app/callback?connection=connected&platform=instagram',
        'user info': 'https://oauth-user@divine.video/app/callback?connection=connected&platform=instagram',
        'fragment': 'https://divine.video/app/callback?connection=connected&platform=instagram#unexpected',
        'duplicate reason': 'https://divine.video/app/callback?connection=failed&platform=instagram&reason=provider_denied&reason=other',
      };

      for (final invalid in invalidCallbacks.entries) {
        test(
          '${invalid.key} is rejected after refreshing server truth',
          () async {
            final invalidUri = Uri.parse(invalid.value);
            callbackUri = invalidUri.replace(
              query:
                  '${invalidUri.query}'
                  '${invalidUri.hasQuery ? '&' : ''}'
                  'app_state=test-nonce',
            );
            when(
              () => repository.loadSettings(),
            ).thenAnswer((_) async => const [xSettings]);
            final cubit = buildCubit();
            addTearDown(cubit.close);
            await cubit.connect(CrosspostingPlatform.instagram);

            expect(cubit.state.entries, const [xSettings]);
            expect(cubit.state.pendingAction, isNull);
            expect(cubit.state.error, CrosspostingSettingsError.generic);
            expect(cubit.state.outcome, isNull);
            expect(cubit.reportedErrors, hasLength(1));
            verify(() => repository.loadSettings()).called(1);
          },
        );
      }

      for (final nonceCase in const {
        'missing nonce': null,
        'mismatched nonce': 'another-attempt',
      }.entries) {
        test(
          '${nonceCase.key} is rejected after refreshing server truth',
          () async {
            callbackUri =
                Uri.parse(
                  'https://divine.video/app/callback',
                ).replace(
                  queryParameters: {
                    if (nonceCase.value != null) 'app_state': nonceCase.value,
                    'connection': 'connected',
                    'platform': 'instagram',
                  },
                );
            when(
              () => repository.loadSettings(),
            ).thenAnswer((_) async => const [xSettings]);
            final cubit = buildCubit();
            addTearDown(cubit.close);

            await cubit.connect(CrosspostingPlatform.instagram);

            expect(cubit.state.entries, const [xSettings]);
            expect(cubit.state.error, CrosspostingSettingsError.generic);
            expect(cubit.state.outcome, isNull);
          },
        );
      }

      test(
        'connect refresh failure clears pending and suppresses outcome',
        () async {
          when(
            () => repository.loadSettings(),
          ).thenThrow(StateError('offline'));
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.connect(CrosspostingPlatform.instagram);

          expect(cubit.state.pendingAction, isNull);
          expect(cubit.state.error, CrosspostingSettingsError.generic);
          expect(cubit.state.outcome, isNull);
          expect(cubit.reportedErrors.single, isA<StateError>());
        },
      );

      test('start failure is reported and does not launch OAuth', () async {
        when(
          () => repository.startConnection(
            any(),
            returnUrl: any(named: 'returnUrl'),
          ),
        ).thenThrow(StateError('offline'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.connect(CrosspostingPlatform.instagram);

        expect(cubit.state.pendingAction, isNull);
        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(launchedUrls, isEmpty);
        expect(cubit.reportedErrors.single, isA<StateError>());
      });

      test('OAuth launcher exception is reported without refreshing', () async {
        final failure = StateError('browser failed');
        final cubit = buildCubit(
          launcher: (_) async => throw failure,
        );
        addTearDown(cubit.close);

        await cubit.connect(CrosspostingPlatform.instagram);

        expect(cubit.state.pendingAction, isNull);
        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(cubit.reportedErrors, [failure]);
        verifyNever(() => repository.loadSettings());
      });

      test(
        'a no-callback OAuth session times out with an explicit error',
        () async {
          // On Android devices where app-link verification fails, the callback
          // URL opens in the browser and the OAuth session never completes.
          // Without a bound the connect flow silently waits forever.
          final cubit = buildCubit(
            oauthCallbackTimeout: const Duration(milliseconds: 50),
            launcher: (_) => Completer<Uri?>().future,
          );
          addTearDown(cubit.close);

          await cubit.connect(CrosspostingPlatform.instagram);
          await Future<void>.delayed(const Duration(milliseconds: 200));

          expect(cubit.state.error, CrosspostingSettingsError.callbackTimeout);
          expect(cubit.state.hasPendingAction, isFalse);
          // The connection may have completed server-side in the browser, so
          // the state refreshes before the error surfaces.
          verify(() => repository.loadSettings()).called(1);
        },
      );

      test(
        'a completed callback within the window reports no timeout error',
        () async {
          // Guards against the timeout firing on healthy sessions.
          final cubit = buildCubit(
            oauthCallbackTimeout: const Duration(seconds: 30),
          );
          addTearDown(cubit.close);

          await cubit.connect(CrosspostingPlatform.instagram);

          expect(cubit.state.error, isNull);
          expect(cubit.state.outcome, CrosspostingOAuthOutcome.connected);
        },
      );

      test('supports reconnecting a needs-reauth connection', () async {
        when(
          () => repository.loadSettings(),
        ).thenAnswer((_) async => const [instagramReauthSettings]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.connect(CrosspostingPlatform.instagram);

        verify(
          () => repository.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: any(named: 'returnUrl'),
          ),
        ).called(1);
      });

      test('suppresses duplicate connects while OAuth is pending', () async {
        final startCompleter = Completer<CrosspostingStart>();
        when(
          () => repository.startConnection(
            any(),
            returnUrl: any(named: 'returnUrl'),
          ),
        ).thenAnswer((_) => startCompleter.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final first = cubit.connect(CrosspostingPlatform.instagram);
        final second = cubit.connect(CrosspostingPlatform.instagram);
        await second;

        verify(
          () => repository.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: any(named: 'returnUrl'),
          ),
        ).called(1);
        startCompleter.complete(
          CrosspostingStart(authorizationUrl: authorizationUrl, state: 'state'),
        );
        await first;
      });

      test('repeated connected callbacks increment outcomeAttempt', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.connect(CrosspostingPlatform.instagram);
        expect(cubit.state.outcomeAttempt, 1);
        await cubit.connect(CrosspostingPlatform.instagram);

        expect(cubit.state.outcome, CrosspostingOAuthOutcome.connected);
        expect(cubit.state.outcomeAttempt, 2);
      });
    });

    group('disconnect', () {
      test(
        'disconnects the selected connection and reloads server truth',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);

          await cubit.disconnect(CrosspostingPlatform.instagram);

          verify(
            () => repository.disconnect(
              CrosspostingPlatform.instagram,
              'instagram-connection',
            ),
          ).called(1);
          expect(cubit.state.entries, const [xSettings]);
          expect(cubit.state.pendingAction, isNull);
        },
      );

      test('disconnects a needs-reauth connection', () async {
        when(
          () => repository.loadSettings(),
        ).thenAnswer((_) async => const [instagramReauthSettings]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.disconnect(CrosspostingPlatform.instagram);

        verify(
          () => repository.disconnect(
            CrosspostingPlatform.instagram,
            'instagram-stale',
          ),
        ).called(1);
      });

      test(
        'does nothing when the platform has no current connection',
        () async {
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();

          await cubit.disconnect(CrosspostingPlatform.x);

          verifyNever(() => repository.disconnect(any(), any()));
        },
      );

      test('suppresses duplicate disconnects while one is pending', () async {
        final completer = Completer<void>();
        when(
          () => repository.disconnect(any(), any()),
        ).thenAnswer((_) => completer.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        final first = cubit.disconnect(CrosspostingPlatform.instagram);
        final second = cubit.disconnect(CrosspostingPlatform.instagram);
        await second;

        verify(() => repository.disconnect(any(), any())).called(1);
        completer.complete();
        await first;
      });

      test('reports disconnect failure and retains loaded entries', () async {
        when(
          () => repository.disconnect(any(), any()),
        ).thenThrow(StateError('offline'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.disconnect(CrosspostingPlatform.instagram);

        expect(cubit.state.entries, initialSettings);
        expect(cubit.state.pendingAction, isNull);
        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(cubit.reportedErrors.single, isA<StateError>());
      });

      test(
        'treats not_connected disconnect as complete and reloads server truth',
        () async {
          when(() => repository.disconnect(any(), any())).thenThrow(
            const CrosspostingApiException(
              'already disconnected',
              statusCode: 400,
              code: 'not_connected',
            ),
          );
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);

          await cubit.disconnect(CrosspostingPlatform.instagram);

          expect(cubit.state.entries, const [xSettings]);
          expect(cubit.state.error, isNull);
          expect(cubit.state.pendingAction, isNull);
          verify(() => repository.loadSettings()).called(2);
        },
      );

      test('reports reload failure after a successful disconnect', () async {
        final reloadFailure = StateError('reload failed');
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        when(() => repository.loadSettings()).thenThrow(reloadFailure);

        await cubit.disconnect(CrosspostingPlatform.instagram);

        verify(
          () => repository.disconnect(
            CrosspostingPlatform.instagram,
            'instagram-connection',
          ),
        ).called(1);
        expect(
          cubit.state.entries,
          const [
            CrosspostingPlatformSettings(
              platform: CrosspostingPlatform.instagram,
              supportsAutomatic: true,
              mode: CrosspostingMode.disabled,
            ),
            xSettings,
          ],
        );
        expect(cubit.state.pendingAction, isNull);
        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(cubit.reportedErrors, [reloadFailure]);
      });
    });

    group('setMode', () {
      test('updates optimistically and keeps the mode on success', () async {
        final completer = Completer<void>();
        when(
          () => repository.setMode(any(), any()),
        ).thenAnswer((_) => completer.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        final save = cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );

        expect(cubit.state.entries.first.mode, CrosspostingMode.automatic);
        expect(
          cubit.state.pendingAction,
          CrosspostingPlatformAction.savingMode,
        );
        completer.complete();
        await save;
        expect(cubit.state.entries.first.mode, CrosspostingMode.automatic);
        expect(cubit.state.pendingAction, isNull);
      });

      test(
        'reloads server truth and maps not_connected to a distinct error',
        () async {
          when(() => repository.setMode(any(), any())).thenThrow(
            const CrosspostingApiException(
              'not connected',
              statusCode: 400,
              code: 'not_connected',
            ),
          );
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();
          when(
            () => repository.loadSettings(),
          ).thenAnswer((_) async => const [xSettings]);
          await cubit.setMode(
            CrosspostingPlatform.instagram,
            CrosspostingMode.automatic,
          );

          expect(cubit.state.entries, const [xSettings]);
          expect(cubit.state.error, CrosspostingSettingsError.notConnected);
          expect(cubit.state.pendingAction, isNull);
          expect(cubit.reportedErrors.single, isA<CrosspostingApiException>());
          verify(() => repository.loadSettings()).called(2);
        },
      );

      test('rolls back and reports a generic save failure', () async {
        when(
          () => repository.setMode(any(), any()),
        ).thenThrow(StateError('offline'));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );

        expect(cubit.state.entries.first.mode, CrosspostingMode.manual);
        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(cubit.state.pendingAction, isNull);
        expect(cubit.reportedErrors.single, isA<StateError>());
      });

      test('suppresses duplicate mode saves while one is pending', () async {
        final completer = Completer<void>();
        when(
          () => repository.setMode(any(), any()),
        ).thenAnswer((_) => completer.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        final first = cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );
        final second = cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.disabled,
        );
        await second;

        verify(() => repository.setMode(any(), any())).called(1);
        expect(cubit.state.entries.first.mode, CrosspostingMode.automatic);
        completer.complete();
        await first;
      });

      test(
        'a pending mutation marks every platform busy and blocks X',
        () async {
          final saveCompleter = Completer<void>();
          when(
            () => repository.setMode(any(), any()),
          ).thenAnswer((_) => saveCompleter.future);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();

          final save = cubit.setMode(
            CrosspostingPlatform.instagram,
            CrosspostingMode.automatic,
          );
          expect(cubit.state.hasPendingAction, isTrue);

          await cubit.connect(CrosspostingPlatform.x);

          verifyNever(
            () => repository.startConnection(
              CrosspostingPlatform.x,
              returnUrl: any(named: 'returnUrl'),
            ),
          );
          saveCompleter.complete();
          await save;
        },
      );

      test('repeated identical failures increment errorAttempt', () async {
        final failure = StateError('offline');
        when(() => repository.setMode(any(), any())).thenThrow(failure);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );
        expect(cubit.state.errorAttempt, 1);
        await cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );

        expect(cubit.state.error, CrosspostingSettingsError.generic);
        expect(cubit.state.errorAttempt, 2);
        expect(cubit.reportedErrors, [failure, failure]);
      });

      test(
        'does nothing when the platform is not in loaded settings',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();

          await cubit.setMode(
            CrosspostingPlatform.youtube,
            CrosspostingMode.manual,
          );

          verifyNever(() => repository.setMode(any(), any()));
        },
      );
    });

    test(
      'acknowledges transient errors and OAuth outcomes independently',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.connect(CrosspostingPlatform.instagram);
        expect(cubit.state.outcome, CrosspostingOAuthOutcome.connected);

        cubit.acknowledgeOutcome();

        expect(cubit.state.outcome, isNull);
        expect(cubit.state.outcomePlatform, isNull);
        expect(cubit.state.outcomeAttempt, 1);

        when(
          () => repository.setMode(any(), any()),
        ).thenThrow(StateError('offline'));
        await cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );
        expect(cubit.state.error, CrosspostingSettingsError.generic);

        cubit.acknowledgeError();

        expect(cubit.state.error, isNull);
        expect(cubit.state.errorAttempt, 1);
      },
    );

    test('state defensively copies its entries list', () {
      final mutable = <CrosspostingPlatformSettings>[instagramSettings];
      final state = CrosspostingSettingsState(entries: mutable);

      mutable.clear();

      expect(state.entries, const [instagramSettings]);
      expect(state.entries.clear, throwsUnsupportedError);
    });

    group('close safety', () {
      test('closing during repository load prevents post-await work', () async {
        final started = Completer<void>();
        final loaded = Completer<List<CrosspostingPlatformSettings>>();
        when(() => repository.loadSettings()).thenAnswer((_) {
          started.complete();
          return loaded.future;
        });
        final cubit = buildCubit();

        final operation = cubit.load();
        await started.future;
        await cubit.close();
        loaded.complete(initialSettings);

        await expectLater(operation, completes);
        expect(cubit.reportedErrors, isEmpty);
      });

      test('closing during connection start prevents OAuth launch', () async {
        final started = Completer<void>();
        final connectionStart = Completer<CrosspostingStart>();
        when(
          () => repository.startConnection(
            any(),
            returnUrl: any(named: 'returnUrl'),
          ),
        ).thenAnswer((_) {
          started.complete();
          return connectionStart.future;
        });
        final cubit = buildCubit();

        final operation = cubit.connect(CrosspostingPlatform.instagram);
        await started.future;
        await cubit.close();
        connectionStart.complete(
          CrosspostingStart(authorizationUrl: authorizationUrl, state: 'state'),
        );

        await expectLater(operation, completes);
        expect(launchedUrls, isEmpty);
        expect(cubit.reportedErrors, isEmpty);
      });

      test('closing during OAuth launch prevents callback handling', () async {
        final launched = Completer<void>();
        final callback = Completer<Uri?>();
        final cubit = buildCubit(
          launcher: (_) {
            launched.complete();
            return callback.future;
          },
        );

        final operation = cubit.connect(CrosspostingPlatform.instagram);
        await launched.future;
        await cubit.close();
        callback.complete(callbackUri);

        await expectLater(operation, completes);
        verifyNever(() => repository.loadSettings());
        expect(cubit.reportedErrors, isEmpty);
      });

      test('closing during connect reload prevents outcome emission', () async {
        final reloadStarted = Completer<void>();
        final reloaded = Completer<List<CrosspostingPlatformSettings>>();
        when(() => repository.loadSettings()).thenAnswer((_) {
          reloadStarted.complete();
          return reloaded.future;
        });
        final cubit = buildCubit();

        final operation = cubit.connect(CrosspostingPlatform.instagram);
        await reloadStarted.future;
        await cubit.close();
        reloaded.complete(initialSettings);

        await expectLater(operation, completes);
        expect(cubit.reportedErrors, isEmpty);
      });

      test('closing during disconnect prevents its reload', () async {
        final disconnectStarted = Completer<void>();
        final disconnected = Completer<void>();
        final cubit = buildCubit();
        await cubit.load();
        when(() => repository.disconnect(any(), any())).thenAnswer((_) {
          disconnectStarted.complete();
          return disconnected.future;
        });

        final operation = cubit.disconnect(CrosspostingPlatform.instagram);
        await disconnectStarted.future;
        await cubit.close();
        disconnected.complete();

        await expectLater(operation, completes);
        verify(() => repository.loadSettings()).called(1);
        expect(cubit.reportedErrors, isEmpty);
      });

      test('closing during mode save prevents post-await emission', () async {
        final saveStarted = Completer<void>();
        final saved = Completer<void>();
        final cubit = buildCubit();
        await cubit.load();
        when(() => repository.setMode(any(), any())).thenAnswer((_) {
          saveStarted.complete();
          return saved.future;
        });

        final operation = cubit.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        );
        await saveStarted.future;
        await cubit.close();
        saved.complete();

        await expectLater(operation, completes);
        expect(cubit.reportedErrors, isEmpty);
      });
    });
  });
}
