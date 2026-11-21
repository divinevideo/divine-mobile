// ABOUTME: Pins the read a video republish rebuilds from: the newest signed
// ABOUTME: revision at the address once every relay settled, or no answer.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _dTag = 'my-video';

typedef _Read = ({List<Event> events, bool timedOut, bool noRelays});

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group('fetchLatestVideoRevision', () {
    late _MockNostrClient nostr;
    late VideosRepository repository;
    late String privateKey;
    late String pubkey;
    late String address;

    Event signed({
      required int createdAt,
      String dTag = _dTag,
      int kind = 34236,
      String title = 'title',
      String? key,
    }) {
      final signingKey = key ?? privateKey;
      return Event(
        getPublicKey(signingKey),
        kind,
        [
          ['d', dTag],
          ['title', title],
        ],
        '',
        createdAt: createdAt,
      )..sign(signingKey);
    }

    /// Answers only the settled, cache-free read a republish needs; any other
    /// shape of call is unstubbed and fails the test.
    void answer(_Read read) {
      when(
        () => nostr.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
          acceptRelayClosedWhenOthersAnswered: true,
        ),
      ).thenAnswer((_) async => read);
    }

    setUp(() {
      nostr = _MockNostrClient();
      repository = VideosRepository(nostrClient: nostr);
      privateKey = generatePrivateKey();
      pubkey = getPublicKey(privateKey);
      address = '34236:$pubkey:$_dTag';
    });

    test('returns the newest revision once every relay settled', () async {
      final older = signed(createdAt: 1000, title: 'older');
      final newer = signed(createdAt: 2000, title: 'newer');
      answer((events: [older, newer], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          newer.id,
        ),
      );
    });

    test('breaks a created_at tie by the lowest event id', () async {
      final a = signed(createdAt: 2000, title: 'a');
      final b = signed(createdAt: 2000, title: 'b');
      final lowest = a.id.compareTo(b.id) < 0 ? a : b;
      answer((events: [a, b], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          lowest.id,
        ),
      );
    });

    test('asks for exactly the address', () async {
      answer((events: const [], timedOut: false, noRelays: false));

      await repository.fetchLatestVideoRevision(address);

      final filters =
          verify(
                () => nostr.queryEventsDetailed(
                  captureAny(),
                  useCache: false,
                  requireAllRelaysSettled: true,
                  acceptRelayClosedWhenOthersAnswered: true,
                ),
              ).captured.single
              as List<Filter>;
      expect(filters.single.toJson(), {
        'kinds': [34236],
        'authors': [pubkey],
        '#d': [_dTag],
      });
    });

    test('reports unknown when the read timed out, '
        'even with revisions in hand', () async {
      answer((
        events: [signed(createdAt: 1000)],
        timedOut: true,
        noRelays: false,
      ));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(result, isA<LatestVideoRevisionUnknown>());
    });

    test('reports unknown when no relay took the read', () async {
      answer((events: const [], timedOut: false, noRelays: true));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(result, isA<LatestVideoRevisionUnknown>());
    });

    test('reports absent when every relay settled with nothing', () async {
      answer((events: const [], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(result, isA<LatestVideoRevisionAbsent>());
    });

    test('ignores revisions that are not at the address', () async {
      final current = signed(createdAt: 1000, title: 'current');
      answer((
        events: [
          current,
          signed(createdAt: 3000, dTag: 'other-video'),
          signed(createdAt: 3000, kind: 34235),
          signed(createdAt: 3000, key: generatePrivateKey()),
        ],
        timedOut: false,
        noRelays: false,
      ));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          current.id,
        ),
      );
    });

    test('ignores a revision whose signature does not verify', () async {
      final current = signed(createdAt: 1000, title: 'current');
      final forged = signed(createdAt: 3000, title: 'forged')
        ..sig = signed(createdAt: 4000).sig;
      answer((events: [current, forged], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          current.id,
        ),
      );
    });

    test('ignores a revision whose id does not match its content', () async {
      final current = signed(createdAt: 1000, title: 'current');
      final tampered = signed(createdAt: 3000, title: 'tampered')
        ..content = 'changed after signing';
      answer((events: [current, tampered], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(address);

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          current.id,
        ),
      );
    });

    test('reads a Kind 34235 address', () async {
      final normal = signed(createdAt: 1000, kind: 34235);
      answer((events: [normal], timedOut: false, noRelays: false));

      final result = await repository.fetchLatestVideoRevision(
        '34235:$pubkey:$_dTag',
      );

      expect(
        result,
        isA<LatestVideoRevisionFound>().having(
          (r) => r.event.id,
          'event.id',
          normal.id,
        ),
      );
    });

    test('throws $ArgumentError for an address that is not a video', () {
      expect(
        () => repository.fetchLatestVideoRevision('30023:$pubkey:$_dTag'),
        throwsArgumentError,
      );
      expect(
        () => repository.fetchLatestVideoRevision('not-an-address'),
        throwsArgumentError,
      );
      verifyNever(
        () => nostr.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
        ),
      );
    });
  });
}
