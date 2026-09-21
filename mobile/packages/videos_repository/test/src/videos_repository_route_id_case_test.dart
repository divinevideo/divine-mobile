// ABOUTME: Pins that an upper-case hex route id reaches REST lowercased.
// ABOUTME: The first-party API is case sensitive, so the original case 404s.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _pubkey =
    'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

// Hex letters in every block, so upper- and lower-case forms differ.
const _eventId =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

Event _videoEvent() => Event.fromJson({
  'id': _eventId,
  'pubkey': _pubkey,
  'created_at': 1765250795,
  'kind': 34236,
  'content': '',
  'sig': 'a' * 128,
  'tags': [
    ['d', 'route-case-fixture'],
    ['imeta', 'url https://cdn.divine.video/fixture.mp4', 'm video/mp4'],
    ['title', 'route id case fixture'],
  ],
});

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group('route id case handling', () {
    late _MockNostrClient nostr;
    late _MockFunnelcakeApiClient funnelcake;

    setUp(() {
      nostr = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      when(() => nostr.queryEvents(any())).thenAnswer((_) async => []);
      when(() => funnelcake.isAvailable).thenReturn(true);
      when(
        () => funnelcake.getVideoEvent(any()),
      ).thenAnswer((_) async => _videoEvent());
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenThrow(const FunnelcakeException('no stats'));
    });

    VideosRepository build() =>
        VideosRepository(nostrClient: nostr, funnelcakeApiClient: funnelcake);

    test('lowercases an upper-case hex id before the REST lookup', () async {
      final upper = _eventId.toUpperCase();
      // Guard the fixture itself: a digits-only id would make this vacuous.
      expect(upper, isNot(equals(_eventId)));

      final result = await build().fetchVideoWithStatsForRouteId(upper);

      final sent = verify(
        () => funnelcake.getVideoEvent(captureAny()),
      ).captured;
      expect(
        sent.single,
        equals(_eventId),
        reason:
            'the REST route is case sensitive, so the original case 404s and '
            'the lookup silently falls through to the relay',
      );
      expect(result, isNotNull);
    });

    test('leaves an already-lowercase hex id untouched', () async {
      await build().fetchVideoWithStatsForRouteId(_eventId);

      final sent = verify(
        () => funnelcake.getVideoEvent(captureAny()),
      ).captured;
      expect(sent.single, equals(_eventId));
    });

    test('still resolves an addressable id by its d tag', () async {
      // An addressable reference carries no event id, so the d tag is the only
      // identifier the REST route can use — preferring the event id must not
      // strand it.
      const dTag = 'route-case-fixture';
      const routeId = '34236:$_pubkey:$dTag';

      await build().fetchVideoWithStatsForRouteId(routeId);

      final sent = verify(
        () => funnelcake.getVideoEvent(captureAny()),
      ).captured;
      expect(sent.single, equals(dTag));
    });
  });
}
