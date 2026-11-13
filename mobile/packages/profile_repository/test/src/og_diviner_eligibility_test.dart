import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, Object?> _user({
  String pubkey = _pubkey,
  bool eligible = true,
  bool published = true,
  bool vanished = false,
}) => {
  'pubkey': pubkey,
  'is_og_diviner': eligible,
  'has_vanish_request': vanished,
  'profile': published
      ? {
          'name': 'Synthetic creator',
          'profile_updated': '2026-11-01T00:00:00Z',
        }
      : null,
};

http.Response _response(Object body) => http.Response(jsonEncode(body), 200);

({
  ProfileRepository repository,
  AppDatabase database,
  List<http.Request> requests,
  ProfileApiCache apiCache,
})
_fixture(FutureOr<http.Response> Function(http.Request) respond) {
  final database = AppDatabase.test(NativeDatabase.memory());
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return respond(request);
  });
  final api = FunnelcakeApiClient(
    baseUrl: 'https://profiles.example.test',
    httpClient: client,
    retryBaseDelay: Duration.zero,
  );
  final apiCache = ProfileApiCache(client: api);
  addTearDown(database.close);
  addTearDown(client.close);
  return (
    repository: ProfileRepository(
      nostrClient: _MockNostrClient(),
      userProfilesDao: database.userProfilesDao,
      httpClient: client,
      funnelcakeApiClient: api,
      profileApiCache: apiCache,
    ),
    database: database,
    requests: requests,
    apiCache: apiCache,
  );
}

void main() {
  group('ProfileRepository OG Diviner eligibility', () {
    test(
      'shares answers across read-only and signing profile handles',
      () async {
        final fixture = _fixture((_) => _response(_user()));
        final otherHandle = ProfileRepository(
          nostrClient: _MockNostrClient(),
          userProfilesDao: fixture.database.userProfilesDao,
          httpClient: MockClient(
            (_) async => throw StateError('Unexpected HTTP'),
          ),
          profileApiCache: fixture.apiCache,
        );
        await otherHandle.getUserProfileFromApi(pubkey: _pubkey);

        expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
        expect(fixture.requests, hasLength(1));
      },
    );

    test(
      'a different environment does not inherit a positive answer',
      () async {
        final first = _fixture((_) => _response(_user()));
        final second = _fixture((_) => _response(_user(eligible: false)));

        expect(await first.repository.isOgDiviner(_pubkey), isTrue);
        expect(await second.repository.isOgDiviner(_pubkey), isFalse);
        expect(first.requests, hasLength(1));
        expect(second.requests, hasLength(1));
      },
    );

    test('reuses a completed single profile response', () async {
      final fixture = _fixture((_) => _response(_user()));

      expect(
        await fixture.repository.getUserProfileFromApi(pubkey: _pubkey),
        isA<UserProfileFound>(),
      );
      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(fixture.requests, hasLength(1));
      expect(fixture.requests.single.method, 'GET');
      expect(fixture.requests.single.url.path, '/api/users/$_pubkey');
    });

    test('hydrates eligibility for every bulk profile', () async {
      final fixture = _fixture(
        (_) => _response({
          'users': [_user(), _user(pubkey: _otherPubkey, eligible: false)],
        }),
      );

      await fixture.repository.getBulkProfilesFromApi([_pubkey, _otherPubkey]);

      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(await fixture.repository.isOgDiviner(_otherPubkey), isFalse);
      expect(fixture.requests, hasLength(1));
      expect(fixture.requests.single.method, 'POST');
      expect(fixture.requests.single.url.path, '/api/users/bulk');
    });

    test('shares an in-flight single profile request with the badge', () async {
      final response = Completer<http.Response>();
      final fixture = _fixture((_) => response.future);

      final profile = fixture.repository.getUserProfileFromApi(pubkey: _pubkey);
      final badge = fixture.repository.isOgDiviner(_pubkey);
      response.complete(_response(_user()));

      expect(await profile, isA<UserProfileFound>());
      expect(await badge, isTrue);
      expect(fixture.requests, hasLength(1));
    });

    test('shares an in-flight bulk request without an extra GET', () async {
      final response = Completer<http.Response>();
      final fixture = _fixture((_) => response.future);

      final profiles = fixture.repository.getBulkProfilesFromApi([
        _pubkey,
        _otherPubkey,
      ]);
      final badge = fixture.repository.isOgDiviner(_pubkey);
      response.complete(
        _response({
          'users': [_user(), _user(pubkey: _otherPubkey)],
        }),
      );

      expect((await profiles)!.profiles, hasLength(2));
      expect(await badge, isTrue);
      expect(fixture.requests, hasLength(1));
      expect(fixture.requests.single.method, 'POST');
    });

    test('allows an eligible account without a published profile', () async {
      final fixture = _fixture((_) => _response(_user(published: false)));

      expect(
        await fixture.repository.getUserProfileFromApi(pubkey: _pubkey),
        isA<UserProfileNotPublished>(),
      );
      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(fixture.requests, hasLength(1));
    });

    test('suppresses a vanished account even with a true wire flag', () async {
      final fixture = _fixture(
        (_) => _response(_user(published: false, vanished: true)),
      );

      expect(await fixture.repository.isOgDiviner(_pubkey), isFalse);
      expect(await fixture.repository.isOgDiviner(_pubkey), isFalse);
      expect(fixture.requests, hasLength(1));
    });

    test('an absent eligibility field quietly returns false', () async {
      final user = _user()..remove('is_og_diviner');
      final fixture = _fixture((_) => _response(user));

      expect(await fixture.repository.isOgDiviner(_pubkey), isFalse);
      expect(fixture.requests, hasLength(1));
    });

    test('a failed lookup can recover on the next request', () async {
      var fail = true;
      final fixture = _fixture(
        (_) => fail ? http.Response('bad request', 400) : _response(_user()),
      );

      await expectLater(
        fixture.repository.isOgDiviner(_pubkey),
        throwsA(isA<FunnelcakeException>()),
      );
      fail = false;

      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(fixture.requests, hasLength(2));
    });

    test('empty and whitespace-only keys never request a profile', () async {
      final fixture = _fixture((_) => throw StateError('Unexpected HTTP'));

      expect(await fixture.repository.isOgDiviner(''), isFalse);
      expect(await fixture.repository.isOgDiviner('   '), isFalse);
      expect(fixture.requests, isEmpty);
    });

    test(
      'bulk failure has no unhandled per-user errors without waiters',
      () async {
        var fail = true;
        final fixture = _fixture(
          (_) => fail ? http.Response('bad request', 400) : _response(_user()),
        );

        await expectLater(
          fixture.repository.getBulkProfilesFromApi([_pubkey, _otherPubkey]),
          throwsA(isA<FunnelcakeException>()),
        );
        await pumpEventQueue();
        fail = false;

        expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
        expect(fixture.requests, hasLength(2));
      },
    );

    test('a newer single response replaces prior true with false', () async {
      var eligible = true;
      final fixture = _fixture((_) => _response(_user(eligible: eligible)));

      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      eligible = false;
      await fixture.repository.getUserProfileFromApi(pubkey: _pubkey);

      expect(await fixture.repository.isOgDiviner(_pubkey), isFalse);
      expect(fixture.requests, hasLength(2));
    });

    test('a newer bulk response replaces prior true with false', () async {
      final fixture = _fixture(
        (request) => request.method == 'GET'
            ? _response(_user())
            : _response({
                'users': [_user(eligible: false)],
              }),
      );

      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      await fixture.repository.getBulkProfilesFromApi([_pubkey]);

      expect(await fixture.repository.isOgDiviner(_pubkey), isFalse);
      expect(fixture.requests, hasLength(2));
    });

    test('fetchFreshProfile persists profile and reuses eligibility', () async {
      final fixture = _fixture((_) => _response(_user()));

      final profile = await fixture.repository.fetchFreshProfile(
        pubkey: _pubkey,
      );

      expect(profile?.name, 'Synthetic creator');
      final cached = await fixture.database.userProfilesDao.getProfile(_pubkey);
      expect(cached?.name, 'Synthetic creator');
      expect(cached!.rawData.containsKey('is_og_diviner'), isFalse);
      expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
      expect(fixture.requests, hasLength(1));
    });

    test(
      'fetchBatchProfiles persists profiles and reuses eligibility',
      () async {
        final fixture = _fixture(
          (_) => _response({
            'users': [_user()],
          }),
        );

        final profiles = await fixture.repository.fetchBatchProfiles(
          pubkeys: [_pubkey],
        );

        expect(profiles[_pubkey]?.name, 'Synthetic creator');
        final cached = await fixture.database.userProfilesDao.getProfile(
          _pubkey,
        );
        expect(cached?.name, 'Synthetic creator');
        expect(await fixture.repository.isOgDiviner(_pubkey), isTrue);
        expect(fixture.requests, hasLength(1));
        expect(fixture.requests.single.method, 'POST');
      },
    );
  });
}
