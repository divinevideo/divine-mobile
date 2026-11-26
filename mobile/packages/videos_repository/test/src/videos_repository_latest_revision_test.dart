// ABOUTME: Verifies that a video republish reads its exact video address from
// ABOUTME: Funnelcake first, then falls back to relays without gating on them.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _dTag = 'my:video';

void main() {
  group('fetchLatestVideoRevision', () {
    late _MockNostrClient nostr;
    late _MockFunnelcakeApiClient funnelcake;
    late String privateKey;
    late String pubkey;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      nostr = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      privateKey = generatePrivateKey();
      pubkey = getPublicKey(privateKey);
    });

    Event revision({
      int kind = 34236,
      String? author,
      String dTag = _dTag,
      int createdAt = 1000,
      String content = '',
      String? signingKey,
    }) => Event(
      author ?? pubkey,
      kind,
      [
        ['d', dTag],
      ],
      content,
      createdAt: createdAt,
    )..sign(signingKey ?? privateKey);

    Future<QueryResult> readRelays() =>
        nostr.readEvents(any(), useCache: any(named: 'useCache'));

    void stubRelays(
      List<Event> events, {
      QueryEnd endedBy = QueryEnd.complete,
    }) {
      when(readRelays).thenAnswer(
        (_) async => QueryResult(events: events, endedBy: endedBy),
      );
    }

    void stubFunnelcake(Future<Event?> Function() answer) {
      when(() => funnelcake.isAvailable).thenReturn(true);
      when(() => funnelcake.getVideoEvent(any())).thenAnswer((_) => answer());
    }

    VideosRepository withFunnelcake() =>
        VideosRepository(nostrClient: nostr, funnelcakeApiClient: funnelcake);

    test('throws $ArgumentError for an address that is not a video', () async {
      final repository = withFunnelcake();
      await expectLater(
        repository.fetchLatestVideoRevision('30023:$pubkey:$_dTag'),
        throwsArgumentError,
      );
      await expectLater(
        repository.fetchLatestVideoRevision('not-an-address'),
        throwsArgumentError,
      );
      verifyZeroInteractions(nostr);
      verifyZeroInteractions(funnelcake);
    });

    group('from Funnelcake', () {
      for (final kind in [34235, 34236]) {
        test(
          'returns its signed Kind $kind revision without asking the relays',
          () async {
            final current = revision(kind: kind);
            stubFunnelcake(() async => current);

            final result = await withFunnelcake().fetchLatestVideoRevision(
              '$kind:$pubkey:$_dTag',
            );

            expect(
              result,
              isA<LatestVideoRevisionFound>().having(
                (r) => r.event,
                'event',
                same(current),
              ),
            );
            verify(() => funnelcake.getVideoEvent(_dTag)).called(1);
            verifyZeroInteractions(nostr);
          },
        );
      }

      group('falls back to the relays when its answer', () {
        late Event onRelay;

        setUp(() {
          onRelay = revision(content: 'relay copy');
          stubRelays([onRelay]);
        });

        Future<void> expectRelayRevision() async {
          final result = await withFunnelcake().fetchLatestVideoRevision(
            '34236:$pubkey:$_dTag',
          );

          expect(
            result,
            isA<LatestVideoRevisionFound>().having(
              (r) => r.event,
              'event',
              same(onRelay),
            ),
          );
          verify(readRelays).called(1);
        }

        test('is by another author', () async {
          final otherKey = generatePrivateKey();
          stubFunnelcake(
            () async => revision(
              author: getPublicKey(otherKey),
              signingKey: otherKey,
              createdAt: 2000,
            ),
          );
          await expectRelayRevision();
        });

        test('is another kind', () async {
          stubFunnelcake(() async => revision(kind: 34235, createdAt: 2000));
          await expectRelayRevision();
        });

        test('is at another d tag', () async {
          stubFunnelcake(
            () async => revision(dTag: 'other', createdAt: 2000),
          );
          await expectRelayRevision();
        });

        test('has a signature by another key', () async {
          stubFunnelcake(
            () async =>
                revision(createdAt: 2000, signingKey: generatePrivateKey()),
          );
          await expectRelayRevision();
        });

        test('has an id that does not match its content', () async {
          final tampered = revision(createdAt: 2000);
          stubFunnelcake(
            () async => Event.fromJson({
              ...tampered.toJson(),
              'content': 'altered',
            }),
          );
          await expectRelayRevision();
        });

        test('is empty', () async {
          stubFunnelcake(() async => null);
          await expectRelayRevision();
        });

        test('is an error', () async {
          stubFunnelcake(
            () async => throw const FunnelcakeException('unavailable'),
          );
          await expectRelayRevision();
        });
      });

      group('when it does not answer', () {
        late Event onRelay;

        setUp(() {
          onRelay = revision(content: 'relay copy');
          stubRelays([onRelay]);
          // A request that never completes, as a hung API leaves it.
          stubFunnelcake(() => Completer<Event?>().future);
        });

        test('waits up to three seconds before asking the relays', () {
          fakeAsync((async) {
            LatestVideoRevision? result;
            unawaited(
              withFunnelcake()
                  .fetchLatestVideoRevision('34236:$pubkey:$_dTag')
                  .then((value) => result = value),
            );

            async.elapse(const Duration(milliseconds: 2999));
            expect(result, isNull);
            verifyNever(readRelays);

            async.elapse(const Duration(milliseconds: 1));
            expect(
              result,
              isA<LatestVideoRevisionFound>().having(
                (r) => r.event,
                'event',
                same(onRelay),
              ),
            );
            verify(readRelays).called(1);
          });
        });

        test('reports unknown, not absent, when no relay completes', () {
          stubRelays([], endedBy: QueryEnd.settledEarly);
          fakeAsync((async) {
            LatestVideoRevision? result;
            unawaited(
              withFunnelcake()
                  .fetchLatestVideoRevision('34236:$pubkey:$_dTag')
                  .then((value) => result = value),
            );

            async.elapse(const Duration(seconds: 3));
            expect(result, isA<LatestVideoRevisionUnknown>());
          });
        });
      });

      group('given the revision the caller opened as a floor', () {
        late Event opened;

        setUp(() {
          opened = revision(content: 'opened');
        });

        Future<LatestVideoRevision> fetch({VideoRevisionFloor? floor}) =>
            withFunnelcake().fetchLatestVideoRevision(
              '34236:$pubkey:$_dTag',
              notOlderThan:
                  floor ?? (createdAt: opened.createdAt, id: opened.id),
            );

        Matcher found(Event event) => isA<LatestVideoRevisionFound>().having(
          (r) => r.event,
          'event',
          same(event),
        );

        test('returns its revision without asking the relays when it is the '
            'opened one', () async {
          stubFunnelcake(() async => opened);

          expect(await fetch(), found(opened));
          verifyZeroInteractions(nostr);
        });

        test('returns its revision without asking the relays when it is '
            'newer', () async {
          final newer = revision(content: 'newer', createdAt: 1001);
          stubFunnelcake(() async => newer);

          expect(await fetch(), found(newer));
          verifyZeroInteractions(nostr);
        });

        group('asks the relays when its revision predates the floor', () {
          late Event stale;

          setUp(() {
            stale = revision(content: 'stale', createdAt: 999);
            stubFunnelcake(() async => stale);
          });

          test('and returns the opened revision a relay holds', () async {
            stubRelays([opened]);

            expect(await fetch(), found(opened));
            verify(readRelays).called(1);
          });

          test('and returns a newer revision a relay holds', () async {
            final newer = revision(content: 'newer', createdAt: 1002);
            stubRelays([opened, newer]);

            expect(await fetch(), found(newer));
          });

          // The caller compares it with the floor and falls back to the copy
          // it holds; reporting absent would read as a deletion.
          for (final endedBy in [QueryEnd.complete, QueryEnd.settledEarly]) {
            test('and returns its revision when no relay returns one, the '
                'read ending by ${endedBy.name}', () async {
              stubRelays([], endedBy: endedBy);

              expect(await fetch(), found(stale));
            });
          }

          test('and returns its revision over an older relay one', () async {
            stubRelays([revision(content: 'oldest', createdAt: 998)]);

            expect(await fetch(), found(stale));
          });

          test('by the lowest id at an equal created_at', () async {
            final newer = revision(content: 'newer', createdAt: 1001);
            stubRelays([newer]);
            final tied = revision(content: 'tied');
            stubFunnelcake(() async => tied);
            // An id below every hex id puts the tied revision after it.
            final floorId = '0' * 64;

            expect(
              await fetch(floor: (createdAt: 1000, id: floorId)),
              found(newer),
            );
            verify(readRelays).called(1);
          });
        });

        test('logs that its revision predates the floor', () async {
          final stale = revision(content: 'stale for log', createdAt: 999);
          stubFunnelcake(() async => stale);
          stubRelays([revision(content: 'older for log', createdAt: 998)]);

          await fetch();

          final messages = LogCaptureService()
              .getRecentLogs()
              .map((entry) => entry.message)
              .where((message) => message.contains(stale.id));
          expect(
            messages,
            allOf(
              contains(contains('predates ${opened.id}')),
              contains(
                allOf(
                  contains('no relay returned a newer one'),
                  contains('relay revisions: 1'),
                ),
              ),
            ),
          );
        });
      });

      test(
        'lets a programming error surface instead of asking the relays',
        () async {
          stubFunnelcake(() async => throw StateError('bug'));
          stubRelays([revision()]);

          await expectLater(
            withFunnelcake().fetchLatestVideoRevision('34236:$pubkey:$_dTag'),
            throwsStateError,
          );
          verifyNever(readRelays);
        },
      );

      test('is not asked when it is not available', () async {
        when(() => funnelcake.isAvailable).thenReturn(false);
        final onRelay = revision();
        stubRelays([onRelay]);

        final result = await withFunnelcake().fetchLatestVideoRevision(
          '34236:$pubkey:$_dTag',
        );

        expect(
          result,
          isA<LatestVideoRevisionFound>().having(
            (r) => r.event,
            'event',
            same(onRelay),
          ),
        );
        verifyNever(() => funnelcake.getVideoEvent(any()));
      });

      group('logs', () {
        /// Captured entries whose message names [eventId], a value unique to
        /// the test that logged it.
        List<LogEntry> logsNaming(String eventId) => LogCaptureService()
            .getRecentLogs()
            .where((entry) => entry.message.contains(eventId))
            .toList();

        Future<void> fetch() => withFunnelcake().fetchLatestVideoRevision(
          '34236:$pubkey:$_dTag',
        );

        test('which source the revision came from', () async {
          final fromApi = revision(content: 'from Funnelcake');
          stubFunnelcake(() async => fromApi);
          await fetch();

          final onRelay = revision(content: 'from a relay');
          stubFunnelcake(() async => null);
          stubRelays([onRelay], endedBy: QueryEnd.settledEarly);
          await fetch();

          expect(
            logsNaming(fromApi.id).single.message,
            contains('from Funnelcake'),
          );
          expect(
            logsNaming(onRelay.id).single.message,
            allOf(contains('from the relays'), contains('settledEarly')),
          );
        });

        test('a revision at the address that fails its checks as a '
            'warning', () async {
          final tampered = Event.fromJson({
            ...revision().toJson(),
            'content': 'changed after signing',
          });
          stubFunnelcake(() async => tampered);
          stubRelays([revision(content: 'relay copy')]);

          await fetch();

          final entry = logsNaming(tampered.id).single;
          expect(entry.level, LogLevel.warning);
          expect(entry.message, contains(pubkeyForLogs(pubkey)));
        });

        test("another author's video at the d tag without a warning", () async {
          final otherKey = generatePrivateKey();
          final theirs = revision(
            author: getPublicKey(otherKey),
            signingKey: otherKey,
          );
          stubFunnelcake(() async => theirs);
          stubRelays([revision(content: 'relay copy')]);

          await fetch();

          expect(logsNaming(theirs.id).single.level, LogLevel.info);
        });

        test('a failed request with its error and stack trace', () async {
          final marker = 'unavailable ${generatePrivateKey()}';
          stubFunnelcake(() async => throw FunnelcakeException(marker));
          stubRelays([revision(content: 'relay copy')]);

          await fetch();

          final entry = LogCaptureService().getRecentLogs().singleWhere(
            (entry) => entry.error?.contains(marker) ?? false,
          );
          expect(entry.level, LogLevel.warning);
          expect(entry.stackTrace, isNotNull);
        });

        group('which source settled a read that found no revision', () {
          String noRevisionMessage() => LogCaptureService()
              .getRecentLogs()
              .singleWhere(
                (entry) =>
                    entry.message.startsWith('No revision of 34236:$pubkey:'),
              )
              .message;

          test('as absent after a 404', () async {
            stubFunnelcake(() async => null);
            stubRelays([], endedBy: QueryEnd.settledEarly);

            await fetch();

            expect(
              noRevisionMessage(),
              allOf(
                contains('so it is absent'),
                contains('Funnelcake answered that it holds none'),
                contains('ended by settledEarly'),
              ),
            );
          });

          test('as unknown after a failed request', () async {
            stubFunnelcake(
              () async => throw const FunnelcakeException('unavailable'),
            );
            stubRelays([], endedBy: QueryEnd.settledEarly);

            await fetch();

            expect(
              noRevisionMessage(),
              allOf(
                contains('so it is unknown'),
                contains('Funnelcake gave none'),
              ),
            );
          });
        });
      });

      group('when no relay returns a revision and the relay read did not '
          'complete', () {
        Future<LatestVideoRevision> fetch() =>
            withFunnelcake().fetchLatestVideoRevision('34236:$pubkey:$_dTag');

        // Funnelcake hides deleted videos, so its 404 is how a deletion
        // reads. Building on a held copy then would bring the video back.
        for (final endedBy in [
          QueryEnd.settledEarly,
          QueryEnd.deadline,
          QueryEnd.relayClosed,
          QueryEnd.socketDropped,
          QueryEnd.noRelay,
        ]) {
          test('reports absent after a 404 when the read ended by '
              '${endedBy.name}', () async {
            stubFunnelcake(() async => null);
            stubRelays([], endedBy: endedBy);

            expect(await fetch(), isA<LatestVideoRevisionAbsent>());
          });
        }

        test('reports unknown when Funnelcake failed', () async {
          stubFunnelcake(
            () async => throw const FunnelcakeException('unavailable'),
          );
          stubRelays([], endedBy: QueryEnd.settledEarly);

          expect(await fetch(), isA<LatestVideoRevisionUnknown>());
        });

        test('reports unknown when Funnelcake returned no revision at the '
            'address', () async {
          final otherKey = generatePrivateKey();
          stubFunnelcake(
            () async => revision(
              author: getPublicKey(otherKey),
              signingKey: otherKey,
            ),
          );
          stubRelays([], endedBy: QueryEnd.settledEarly);

          expect(await fetch(), isA<LatestVideoRevisionUnknown>());
        });
      });
    });

    group('from the relays', () {
      late VideosRepository repository;

      setUp(() {
        repository = VideosRepository(nostrClient: nostr);
      });

      Future<LatestVideoRevision> fetch() =>
          repository.fetchLatestVideoRevision('34236:$pubkey:$_dTag');

      test('reads the exact address without the cache or a gate', () async {
        stubRelays([]);

        await fetch();

        // Mocktail matches named arguments by their key set, so this verify
        // also fails if the read passes requireAllRelaysSettled (the gate).
        final captured = verify(
          () => nostr.readEvents(
            captureAny(),
            useCache: captureAny(named: 'useCache'),
          ),
        ).captured;
        final filters = captured[0] as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.single.kinds, [34236]);
        expect(filters.single.authors, [pubkey]);
        expect(filters.single.d, [_dTag]);
        expect(captured[1], isFalse);
      });

      // Relays answer in arrival order, so each rule is checked with the
      // winner arriving first and last.
      for (final winnerFirst in [true, false]) {
        final order = winnerFirst ? 'first' : 'last';

        test('returns the newest revision any relay returned, arriving '
            '$order', () async {
          final older = revision(content: 'older');
          final newer = revision(createdAt: 2000, content: 'newer');
          stubRelays(
            winnerFirst ? [newer, older] : [older, newer],
            endedBy: QueryEnd.deadline,
          );

          expect(
            await fetch(),
            isA<LatestVideoRevisionFound>().having(
              (r) => r.event,
              'event',
              same(newer),
            ),
          );
        });

        test('breaks a created_at tie by the lowest id, arriving '
            '$order', () async {
          final first = revision(content: 'first');
          final second = revision(content: 'second');
          final lowest = first.id.compareTo(second.id) < 0 ? first : second;
          final highest = identical(lowest, first) ? second : first;
          stubRelays(winnerFirst ? [lowest, highest] : [highest, lowest]);

          expect(
            await fetch(),
            isA<LatestVideoRevisionFound>().having(
              (r) => r.event,
              'event',
              same(lowest),
            ),
          );
        });
      }

      test('ignores revisions at other addresses or without a valid '
          'signature', () async {
        final otherKey = generatePrivateKey();
        final atAddress = revision();
        final unsigned = Event(
          pubkey,
          34236,
          [
            ['d', _dTag],
          ],
          'unsigned',
          createdAt: 3000,
        );
        stubRelays([
          revision(dTag: 'other', createdAt: 3000),
          revision(kind: 34235, createdAt: 3000),
          revision(
            author: getPublicKey(otherKey),
            signingKey: otherKey,
            createdAt: 3000,
          ),
          unsigned,
          atAddress,
        ]);

        expect(
          await fetch(),
          isA<LatestVideoRevisionFound>().having(
            (r) => r.event,
            'event',
            same(atAddress),
          ),
        );
      });

      test('reports absent when the read completed without one', () async {
        stubRelays([revision(dTag: 'other')]);

        expect(await fetch(), isA<LatestVideoRevisionAbsent>());
      });

      for (final endedBy in [QueryEnd.deadline, QueryEnd.noRelay]) {
        test(
          'reports unknown when the read ended by ${endedBy.name} '
          'without one',
          () async {
            stubRelays([], endedBy: endedBy);

            expect(await fetch(), isA<LatestVideoRevisionUnknown>());
          },
        );
      }
    });
  });
}
