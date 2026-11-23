// ABOUTME: Verifies that a video republish reads its exact video address with
// ABOUTME: the canonical settled read and preserves all three outcomes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _dTag = 'my:video';

void main() {
  group('fetchLatestVideoRevision', () {
    late _MockNostrClient nostr;
    late VideosRepository repository;
    late String privateKey;
    late String pubkey;

    Future<CurrentVersionRead> read(int kind) =>
        nostr.readCurrentVersion(kind: kind, pubkey: pubkey, dTag: _dTag);

    setUp(() {
      nostr = _MockNostrClient();
      repository = VideosRepository(nostrClient: nostr);
      privateKey = generatePrivateKey();
      pubkey = getPublicKey(privateKey);
    });

    for (final kind in [34235, 34236]) {
      test(
        'returns the signed revision at the exact Kind $kind address',
        () async {
          final current = Event(
            pubkey,
            kind,
            [
              ['d', _dTag],
            ],
            '',
            createdAt: 1000,
          )..sign(privateKey);
          when(() => read(kind)).thenAnswer(
            (_) async => CurrentVersionFound(current),
          );

          final result = await repository.fetchLatestVideoRevision(
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
          verify(() => read(kind)).called(1);
          verifyNoMoreInteractions(nostr);
        },
      );
    }

    test(
      'reports absent when every relay settled without a revision',
      () async {
        when(() => read(34236)).thenAnswer(
          (_) async => const CurrentVersionAbsent(),
        );

        final result = await repository.fetchLatestVideoRevision(
          '34236:$pubkey:$_dTag',
        );

        expect(result, isA<LatestVideoRevisionAbsent>());
      },
    );

    for (final noRelay in [false, true]) {
      test('reports unknown on a failed read (noRelay: $noRelay)', () async {
        when(() => read(34236)).thenAnswer(
          (_) async => CurrentVersionFailed(noRelay: noRelay),
        );

        final result = await repository.fetchLatestVideoRevision(
          '34236:$pubkey:$_dTag',
        );

        expect(result, isA<LatestVideoRevisionUnknown>());
      });
    }

    test('throws $ArgumentError for an address that is not a video', () async {
      await expectLater(
        repository.fetchLatestVideoRevision('30023:$pubkey:$_dTag'),
        throwsArgumentError,
      );
      await expectLater(
        repository.fetchLatestVideoRevision('not-an-address'),
        throwsArgumentError,
      );
      verifyZeroInteractions(nostr);
    });
  });
}
