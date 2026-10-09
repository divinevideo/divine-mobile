// ABOUTME: Tests for OAuthSessionCoordinator — single-flight dedup, timeout
// ABOUTME: slot release, expired-session guard, and detach behavior.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/auth/oauth_session_coordinator.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockKeycastRpc extends Mock implements KeycastRpc {}

KeycastSession _session({String? userPubkey, String accessToken = 'token'}) =>
    KeycastSession(
      bunkerUrl: 'bunker://test',
      accessToken: accessToken,
      expiresAt: DateTime(2999),
      userPubkey: userPubkey,
    );

void main() {
  const oauthTimeout = Duration(milliseconds: 200);
  const expiredTimeout = Duration(milliseconds: 200);

  group(OAuthSessionCoordinator, () {
    late _MockKeycastOAuth oauthClient;
    late bool hasExpired;
    late String? pubkeyFallback;
    late KeycastRpc? currentSigner;
    late int rejections;

    setUp(() {
      oauthClient = _MockKeycastOAuth();
      hasExpired = true;
      pubkeyFallback = 'fallback_pubkey';
      currentSigner = _MockKeycastRpc();
      rejections = 0;
    });

    OAuthSessionCoordinator build({bool nullClient = false}) =>
        OAuthSessionCoordinator(
          oauthClient: nullClient ? null : oauthClient,
          oauthRefreshTimeout: oauthTimeout,
          expiredSessionRefreshTimeout: expiredTimeout,
          currentPubkeyFallback: () => pubkeyFallback,
          hasExpiredSession: () => hasExpired,
          currentRpcSigner: () => currentSigner,
          onRefreshRejected: () => rejections++,
        );

    group('refreshSession', () {
      test(
        'returns the refreshed session',
        () async {
          final session = _session(userPubkey: 'owner');
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) async => session);

          final result = await build().refreshSession(
            expectedOwnerPubkey: 'owner',
          );

          expect(result, same(session));
          verify(
            () => oauthClient.refreshSession(userPubkey: 'owner'),
          ).called(1);
        },
      );

      test(
        'falls back to currentPubkeyFallback when no owner is passed',
        () async {
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) async => _session());

          await build().refreshSession();

          verify(
            () => oauthClient.refreshSession(userPubkey: 'fallback_pubkey'),
          ).called(1);
        },
      );

      test('returns null when the '
          'refreshed session has no RPC access', () async {
        // No accessToken -> hasRpcAccess is false.
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenAnswer(
          (_) async => const KeycastSession(bunkerUrl: 'bunker://x'),
        );

        final result = await build().refreshSession();

        expect(result, isNull);
      });

      test('returns null (never throws) when the client throws', () async {
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenThrow(Exception('network down'));

        final result = await build().refreshSession();

        expect(result, isNull);
      });

      test('rethrows OAuthNetworkException from the client', () async {
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenThrow(OAuthNetworkException('offline'));

        await expectLater(
          build().refreshSession(),
          throwsA(isA<OAuthNetworkException>()),
        );
      });

      test('returns null when no OAuth client is configured', () async {
        final result = await build(nullClient: true).refreshSession();

        expect(result, isNull);
      });

      test(
        'deduplicates concurrent callers into a single client call',
        () async {
          final gate = Completer<KeycastSession?>();
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) => gate.future);

          final coordinator = build();
          final a = coordinator.refreshSession();
          final b = coordinator.refreshSession();

          gate.complete(_session());
          await Future.wait([a, b]);

          verify(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'applies owner checks for callers that join an in-flight refresh',
        () async {
          final gate = Completer<KeycastSession?>();
          when(oauthClient.getSession).thenAnswer((_) async => null);
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) => gate.future);

          final coordinator = build();
          final first = coordinator.refreshSession();
          final second = coordinator.refreshSession(
            expectedOwnerPubkey: 'current-owner',
            storedSessionReader: () async =>
                _session(userPubkey: 'current-owner'),
          );

          gate.complete(_session(userPubkey: 'previous-owner'));

          expect(await first, isNotNull);
          expect(await second, isNull);
          verify(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'refuses a mismatched stored owner for callers that join an in-flight '
        'refresh',
        () async {
          when(oauthClient.getSession).thenAnswer((_) async => null);
          final gate = Completer<KeycastSession?>();
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) => gate.future);

          final coordinator = build();
          final first = coordinator.refreshSession();

          final joined = await coordinator
              .refreshSession(
                expectedOwnerPubkey: 'current-owner',
                storedSessionReader: () async =>
                    _session(userPubkey: 'previous-owner'),
              )
              .timeout(
                const Duration(milliseconds: 20),
                onTimeout: () => _session(userPubkey: 'timed-out'),
              );

          expect(joined, isNull);
          gate.complete(_session());
          expect(await first, isNotNull);
          verify(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
      );

      test('applies caller timeout when joining an in-flight refresh', () {
        fakeAsync((async) {
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) => Completer<KeycastSession?>().future);

          final coordinator = build();
          coordinator.refreshSession().ignore();

          Object? joinedError;
          var joinedDone = false;
          unawaited(
            coordinator
                .refreshSession(timeout: const Duration(milliseconds: 50))
                .then(
                  (_) {
                    joinedDone = true;
                    return null;
                  },
                  onError: (Object error) {
                    joinedError = error;
                    joinedDone = true;
                    return null;
                  },
                ),
          );

          async.elapse(const Duration(milliseconds: 51));

          expect(joinedDone, isTrue);
          expect(joinedError, isA<OAuthNetworkException>());
          verify(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        });
      });

      test('releases the slot after a hung request times out so the next '
          'call starts a fresh refresh', () {
        fakeAsync((async) {
          var calls = 0;
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) {
            calls++;
            return Completer<KeycastSession?>().future; // never completes
          });

          final coordinator = build();

          Object? firstError;
          var firstDone = false;
          unawaited(
            coordinator.refreshSession().then(
              (_) {
                firstDone = true;
              },
              onError: (Object error) {
                firstError = error;
                firstDone = true;
              },
            ),
          );

          async.elapse(oauthTimeout + const Duration(milliseconds: 1));
          expect(firstDone, isTrue);
          expect(firstError, isA<OAuthNetworkException>());
          expect(calls, equals(1));

          // Slot released: a fresh call issues a new client request.
          coordinator.refreshSession().ignore();
          async.flushMicrotasks();
          expect(calls, equals(2));
        });
      });
    });

    group('refreshExpiredSession', () {
      test(
        'returns false without running the attempt when not expired',
        () async {
          hasExpired = false;
          var attemptRan = false;
          final result = await build().refreshExpiredSession(
            attempt: () async {
              attemptRan = true;
              return true;
            },
          );

          expect(result, isFalse);
          expect(attemptRan, isFalse);
        },
      );

      test(
        'returns false without running the attempt when no client',
        () async {
          var attemptRan = false;
          final result = await build(nullClient: true).refreshExpiredSession(
            attempt: () async {
              attemptRan = true;
              return true;
            },
          );

          expect(result, isFalse);
          expect(attemptRan, isFalse);
        },
      );

      test('runs the attempt and returns its result when expired', () async {
        final result = await build().refreshExpiredSession(
          attempt: () async => true,
        );

        expect(result, isTrue);
      });

      test('deduplicates concurrent expired-session refreshes', () async {
        final gate = Completer<bool>();
        var attemptCalls = 0;

        final coordinator = build();
        final a = coordinator.refreshExpiredSession(
          attempt: () {
            attemptCalls++;
            return gate.future;
          },
        );
        final b = coordinator.refreshExpiredSession(attempt: () async => true);

        gate.complete(true);
        final results = await Future.wait([a, b]);

        expect(results, equals([true, true]));
        expect(attemptCalls, equals(1));
      });

      test('times out a hung attempt as failed and releases the slot', () {
        fakeAsync((async) {
          final coordinator = build();
          var secondAttemptRan = false;

          bool? firstResult;
          Object? firstError;
          unawaited(
            coordinator
                .refreshExpiredSession(
                  attempt: () => Completer<bool>().future, // hangs
                )
                .then(
                  (result) {
                    firstResult = result;
                  },
                  onError: (Object error) {
                    firstError = error;
                  },
                ),
          );

          async.elapse(expiredTimeout + const Duration(milliseconds: 1));
          expect(firstError, isNull);
          expect(firstResult, isFalse);

          coordinator
              .refreshExpiredSession(
                attempt: () async {
                  secondAttemptRan = true;
                  return true;
                },
              )
              .ignore();
          async.flushMicrotasks();
          expect(secondAttemptRan, isTrue);
        });
      });
    });

    group('refreshAccessToken', () {
      void stubRefresh(Future<KeycastSession?> Function() answer) => when(
        () => oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
      ).thenAnswer((_) => answer());

      test('returns the access token of a successful refresh', () async {
        stubRefresh(() async => _session(accessToken: 'fresh-token'));

        final token = await build().refreshAccessToken();

        expect(token, equals('fresh-token'));
        expect(rejections, isZero);
      });

      test('reports a rejection when Keycast refuses the refresh', () async {
        // KeycastOAuth.refreshSession returns null without throwing when
        // there is no refresh token left or Keycast refused it (and deleted
        // it). Nothing can recover the session after that (#9943).
        stubRefresh(() async => null);

        final token = await build().refreshAccessToken();

        expect(token, isNull);
        expect(rejections, equals(1));
      });

      test('reports a rejection when the refreshed session has no RPC '
          'access', () async {
        stubRefresh(() async => const KeycastSession(bunkerUrl: 'bunker://x'));

        final token = await build().refreshAccessToken();

        expect(token, isNull);
        expect(rejections, equals(1));
      });

      test('does not report a rejection when Keycast is unreachable', () async {
        // Network errors, timeouts and 5xx keep the refresh token for a later
        // retry. Treating them as a rejection would prompt every user to sign
        // in again during a Keycast outage.
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenThrow(OAuthNetworkException('Refresh request failed: HTTP 503'));

        final token = await build().refreshAccessToken();

        expect(token, isNull);
        expect(rejections, isZero);
      });

      test('does not report a rejection when the refresh times out', () {
        fakeAsync((async) {
          stubRefresh(() => Completer<KeycastSession?>().future);
          String? token = 'unset';

          unawaited(
            build().refreshAccessToken().then((value) => token = value),
          );
          async.elapse(oauthTimeout * 2);

          expect(token, isNull);
          expect(rejections, isZero);
        });
      });

      test('does not report a rejection when the refresh fails '
          'unexpectedly', () async {
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenThrow(Exception('unexpected'));

        final token = await build().refreshAccessToken();

        expect(token, isNull);
        expect(rejections, isZero);
      });

      test('reports a rejection to each caller that joined the in-flight '
          'refresh', () async {
        final gate = Completer<KeycastSession?>();
        stubRefresh(() => gate.future);

        final coordinator = build();
        final first = coordinator.refreshAccessToken();
        final joined = coordinator.refreshAccessToken();
        gate.complete(null);
        await Future.wait([first, joined]);

        verify(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).called(1);
        expect(rejections, equals(2));
      });

      test('ignores a rejection that lands after sign-out and a new sign-in '
          'to the same account', () async {
        // KeycastOAuth returns the same null when sign-out cleared storage
        // while the request was in flight. The account is unchanged, but the
        // session is new, so that stale result must not mark it expired.
        final gate = Completer<KeycastSession?>();
        stubRefresh(() => gate.future);

        final pending = build().refreshAccessToken();
        currentSigner = null;
        currentSigner = _MockKeycastRpc();
        gate.complete(null);

        expect(await pending, isNull);
        expect(rejections, isZero);
      });

      test('ignores a rejection that lands after sign-out', () async {
        final gate = Completer<KeycastSession?>();
        stubRefresh(() => gate.future);

        final pending = build().refreshAccessToken();
        currentSigner = null;
        gate.complete(null);

        expect(await pending, isNull);
        expect(rejections, isZero);
      });

      test('ignores a rejection for a caller with no live signer', () async {
        currentSigner = null;
        stubRefresh(() async => null);

        expect(await build().refreshAccessToken(), isNull);
        expect(rejections, isZero);
      });
    });

    group('detach', () {
      test(
        'clears the in-flight OAuth refresh so the next call starts fresh',
        () async {
          final firstGate = Completer<KeycastSession?>();
          var calls = 0;
          when(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).thenAnswer((_) {
            calls++;
            return calls == 1 ? firstGate.future : Future.value(_session());
          });

          final coordinator = build();
          final first = coordinator.refreshSession();

          coordinator.detach();

          // A post-detach call must not join the detached in-flight future.
          final second = await coordinator.refreshSession();
          expect(second, isNotNull);
          expect(calls, equals(2));

          firstGate.complete(null);
          await first;
        },
      );

      test("a detached future's late completion does not clobber a newer "
          'in-flight slot', () async {
        final gates = [
          Completer<KeycastSession?>(),
          Completer<KeycastSession?>(),
        ];
        var calls = 0;
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenAnswer((_) => gates[calls++].future);

        final coordinator = build();
        final first = coordinator.refreshSession(); // slot = refresh1
        coordinator.detach(); // slot = null
        final second = coordinator.refreshSession(); // slot = refresh2 (hung)
        expect(calls, equals(2));

        // The detached refresh1 completes AFTER refresh2 took the slot.
        gates[0].complete(null);
        await first;

        // refresh1's whenComplete must NOT null refresh2's slot (identical
        // guard is false), so a third call JOINS refresh2 instead of
        // issuing a new client request.
        final third = coordinator.refreshSession();
        expect(calls, equals(2));

        gates[1].complete(_session());
        await Future.wait([second, third]);
      });

      test('clears the in-flight expired-session refresh', () async {
        final coordinator = build();
        final attemptGate = Completer<bool>();
        var attemptCalls = 0;

        final first = coordinator.refreshExpiredSession(
          attempt: () {
            attemptCalls++;
            return attemptGate.future;
          },
        );

        coordinator.detach();

        // A post-detach expired-session refresh must start a fresh attempt
        // rather than joining the detached one — so its attempt runs too.
        final second = await coordinator.refreshExpiredSession(
          attempt: () async {
            attemptCalls++;
            return true;
          },
        );
        expect(second, isTrue);
        expect(attemptCalls, equals(2));

        attemptGate.complete(false);
        await first;
      });
    });

    test(
      'a nested refreshExpiredSession whose attempt re-enters refreshSession '
      'dedups the two slots independently',
      () async {
        when(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).thenAnswer((_) async => _session());

        final coordinator = build();
        var innerRefreshResults = 0;

        // Mirrors the facade wiring: the outer attempt re-enters the inner
        // single-flight (as _tryRefreshOAuthSession does via refreshSession).
        Future<bool> attempt() async {
          final session = await coordinator.refreshSession();
          if (session != null) innerRefreshResults++;
          return session != null;
        }

        final results = await Future.wait([
          coordinator.refreshExpiredSession(attempt: attempt),
          coordinator.refreshExpiredSession(attempt: attempt),
        ]);

        // Outer slot dedups both callers into one attempt; that single attempt
        // acquires the inner slot exactly once.
        expect(results, equals([true, true]));
        expect(innerRefreshResults, equals(1));
        verify(
          () =>
              oauthClient.refreshSession(userPubkey: any(named: 'userPubkey')),
        ).called(1);
      },
    );
    group('accessTokenForOwner', () {
      test('returns an active token only for its bound owner', () async {
        when(oauthClient.getSession).thenAnswer(
          (_) async => _session(userPubkey: 'owner', accessToken: 'active'),
        );
        final coordinator = build();

        expect(
          await coordinator.accessTokenForOwner(
            expectedOwnerPubkey: 'owner',
            storedSessionReader: () async => null,
          ),
          'active',
        );
        expect(
          await coordinator.accessTokenForOwner(
            expectedOwnerPubkey: 'other',
            storedSessionReader: () async => null,
          ),
          isNull,
        );
        verifyNever(
          () => oauthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        );
      });

      test('refuses to refresh an expired session for another owner', () async {
        when(oauthClient.getSession).thenAnswer((_) async => null);
        final coordinator = build();

        final token = await coordinator.accessTokenForOwner(
          expectedOwnerPubkey: 'current-owner',
          storedSessionReader: () async =>
              _session(userPubkey: 'previous-owner'),
        );

        expect(token, isNull);
        verifyNever(
          () => oauthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        );
      });

      test(
        'concurrent expired-session reads share one bound refresh',
        () async {
          when(oauthClient.getSession).thenAnswer((_) async => null);
          final refresh = Completer<KeycastSession?>();
          when(
            () => oauthClient.refreshSession(userPubkey: 'owner'),
          ).thenAnswer((_) => refresh.future);
          final coordinator = build();

          final first = coordinator.accessTokenForOwner(
            expectedOwnerPubkey: 'owner',
            storedSessionReader: () async => _session(userPubkey: 'owner'),
          );
          final second = coordinator.accessTokenForOwner(
            expectedOwnerPubkey: 'owner',
            storedSessionReader: () async => _session(userPubkey: 'owner'),
          );
          refresh.complete(
            _session(userPubkey: 'owner', accessToken: 'refreshed'),
          );

          expect(await Future.wait([first, second]), [
            'refreshed',
            'refreshed',
          ]);
          verify(
            () => oauthClient.refreshSession(userPubkey: 'owner'),
          ).called(1);
        },
      );
    });
  });
}
