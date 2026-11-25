// ABOUTME: Verifies that a video republish reads its exact video address from
// ABOUTME: Funnelcake first, then falls back to relays without gating on them.

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
