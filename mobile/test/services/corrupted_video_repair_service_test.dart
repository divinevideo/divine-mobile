import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

/// Shapes a `queryEventsDetailed` answer a relay actually gave, so an empty
/// [events] list is genuine "this account has no corrupted videos" — the only
/// result the repair may latch on (#8213).
({
  List<Event> events,
  bool timedOut,
  bool noRelays,
  bool anyRelayAnswered,
  List<String> unsettledRelays,
})
_answeredScan(
  List<Event> events,
) => (
  events: events,
  timedOut: false,
  noRelays: false,
  anyRelayAnswered: false,
  unsettledRelays: const <String>[],
);

/// Shapes a scan nothing answered: a fan-out no relay took ([noRelays]), or a
/// relay that refused the REQ with `CLOSED` / a partial fan-out ([timedOut]).
({
  List<Event> events,
  bool timedOut,
  bool noRelays,
  bool anyRelayAnswered,
  List<String> unsettledRelays,
})
_unansweredScan({
  bool noRelays = false,
  bool timedOut = false,
}) => (
  events: const <Event>[],
  timedOut: timedOut,
  noRelays: noRelays,
  anyRelayAnswered: false,
  unsettledRelays: const <String>[],
);

class _FakeEvent extends Fake implements Event {}

const _testPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _blossomBaseUrl = 'https://media.divine.video';
const _testSha256 =
    '9783bc5788da2fc2bab7600521ea923d873ef3379d18da1b865f513f76e1bf6f';

Event _createVideoEvent({
  required String id,
  required List<List<String>> tags,
  String content = '',
  int createdAt = 1000000,
}) {
  final event = Event(
    _testPubkey,
    EventKind.videoVertical,
    tags,
    content,
    createdAt: createdAt,
  );
  event.id = id;
  return event;
}

void main() {
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockVideoEventService mockVideoEventService;
  late SharedPreferences prefs;
  late CorruptedVideoRepairService repairService;
  late List<Event> publishedEvents;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeEvent());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockVideoEventService = _MockVideoEventService();
    publishedEvents = [];

    when(() => mockNostrClient.publicKey).thenReturn(_testPubkey);
    when(() => mockAuthService.isAuthenticated).thenReturn(true);

    repairService = CorruptedVideoRepairService(
      nostrClient: mockNostrClient,
      authService: mockAuthService,
      prefs: prefs,
      blossomBaseUrl: _blossomBaseUrl,
      videoEventService: mockVideoEventService,
    );
  });

  /// Stubs createAndSignEvent to return a signed event, and publishEvent
  /// to capture it.
  void stubSignAndPublishSuccess() {
    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((invocation) async {
      final tags =
          invocation.namedArguments[#tags] as List<List<String>>? ?? [];
      final content = invocation.namedArguments[#content] as String;
      final createdAt = invocation.namedArguments[#createdAt] as int?;
      final event = Event(
        _testPubkey,
        EventKind.videoVertical,
        tags,
        content,
        createdAt: createdAt,
      );
      event.sig = 'a' * 128;
      return event;
    });

    when(() => mockNostrClient.publishEvent(any())).thenAnswer((
      invocation,
    ) async {
      final event = invocation.positionalArguments[0] as Event;
      publishedEvents.add(event);
      return PublishSuccess(event: event);
    });
  }

  group(CorruptedVideoRepairService, () {
    group('repairIfNeeded', () {
      test('skips if already completed', () async {
        await prefs.setBool('corrupted_video_repair_v1_completed', true);

        final result = await repairService.repairIfNeeded();

        expect(result, equals(-1));
      });

      test('repairs event with corrupted iOS local file path', () async {
        final corruptedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_123'],
            [
              'imeta',
              'url /var/mobile/Containers/Data/Application/xxx/cache/video.mp4',
              'm video/mp4',
              'x $_testSha256',
            ],
            ['title', 'My Video'],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([corruptedEvent]));

        stubSignAndPublishSuccess();

        final result = await repairService.repairIfNeeded();

        expect(result, equals(1));
        expect(publishedEvents, hasLength(1));

        final captured = publishedEvents.first;

        // Verify repaired blossom URL
        final imetaTag = captured.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'imeta',
        );
        final urlComponent = imetaTag.firstWhere((c) => c.startsWith('url '));
        expect(urlComponent, equals('url $_blossomBaseUrl/$_testSha256'));

        // Verify d-tag preserved
        final dTag = captured.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'd',
        );
        expect(dTag[1], equals('video_123'));

        // Verify title preserved
        final titleTag = captured.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'title',
        );
        expect(titleTag[1], equals('My Video'));

        // Verify created_at bumped by 1
        expect(captured.createdAt, equals(1000001));

        // Verify completion flag set
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isTrue);
      });

      test('skips events with valid HTTP URLs', () async {
        final validEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_123'],
            [
              'imeta',
              'url https://media.divine.video/$_testSha256',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([validEvent]));

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(publishedEvents, isEmpty);
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isTrue);
      });

      test('skips corrupted event without x hash', () async {
        final corruptedNoHash = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_123'],
            [
              'imeta',
              'url /data/user/0/co.openvine.app/cache/video.mp4',
              'm video/mp4',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([corruptedNoHash]));

        final result = await repairService.repairIfNeeded();

        // Cannot repair without hash
        expect(result, equals(0));
        expect(publishedEvents, isEmpty);
      });

      test('repairs Android local file paths', () async {
        final corruptedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_456'],
            [
              'imeta',
              'url /data/user/0/co.openvine.app/cache/openvine_video_cache/video.mp4',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([corruptedEvent]));

        stubSignAndPublishSuccess();

        final result = await repairService.repairIfNeeded();

        expect(result, equals(1));

        final imetaTag = publishedEvents.first.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'imeta',
        );
        final urlComponent = imetaTag.firstWhere((c) => c.startsWith('url '));
        expect(urlComponent, equals('url $_blossomBaseUrl/$_testSha256'));
      });

      test('does not set completion flag on query failure', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenThrow(Exception('Relay connection failed'));

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isNull);
      });

      test('does not set completion flag when the fan-out reached no relay '
          '(#8213)', () async {
        // A scan nobody answered is not a scan that found nothing. Latching
        // here disables the #2144 repair on this device permanently, because
        // the flag lives in SharedPreferences and nothing re-arms it.
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _unansweredScan(noRelays: true));

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isNull);
      });

      test(
        'does not set completion flag when a relay refused the scan (#8213)',
        () async {
          // divine-funnelcake answers a failed query with
          // `CLOSED "error: could not complete query"`, which surfaces as
          // timedOut only because the scan demands full settlement.
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((_) async => _unansweredScan(timedOut: true));

          final result = await repairService.repairIfNeeded();

          expect(result, equals(0));
          expect(prefs.getBool('corrupted_video_repair_v1_completed'), isNull);
        },
      );

      test('demands full relay settlement, so a refusal cannot arrive as an '
          'ordinary empty scan (#8213)', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan(const []));

        await repairService.repairIfNeeded();

        final demands = verify(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: captureAny(
              named: 'requireAllRelaysSettled',
            ),
          ),
        ).captured;
        expect(demands, isNotEmpty);
        expect(demands, everyElement(isTrue));
      });

      test('an unanswered scan leaves the repair armed for the next launch '
          '(#8213)', () async {
        final corruptedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_123'],
            [
              'imeta',
              'url /var/mobile/Containers/Data/Application/xxx/video.mp4',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );
        var scans = 0;
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async {
          scans++;
          // First launch: nothing answers. Second: the relay is back and
          // serves the corrupted event the repair exists to fix.
          return scans == 1
              ? _unansweredScan(timedOut: true)
              : _answeredScan([corruptedEvent]);
        });
        stubSignAndPublishSuccess();

        expect(await repairService.repairIfNeeded(), equals(0));
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isNull);

        // Under the latching behavior this second run returned -1 without
        // ever querying, and the corrupted event stayed broken forever.
        expect(await repairService.repairIfNeeded(), equals(1));
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isTrue);
      });

      test('skips when not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(publishedEvents, isEmpty);
        expect(
          prefs.getBool('corrupted_video_repair_v1_completed'),
          isNull,
          reason:
              'A pre-restore unauthenticated run must not mark the one-time '
              'repair complete; it has to retry once an identity is available.',
        );
      });

      test('skips when no public key available', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(publishedEvents, isEmpty);
        expect(
          prefs.getBool('corrupted_video_repair_v1_completed'),
          isNull,
          reason:
              'A run without a restored Nostr pubkey must not mark the '
              'one-time repair complete.',
        );
      });

      test('handles signing failure gracefully', () async {
        final corruptedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_789'],
            [
              'imeta',
              'url /var/mobile/Containers/cache/video.mp4',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([corruptedEvent]));

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async => null);

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(publishedEvents, isEmpty);
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isTrue);
      });

      test('handles publish failure gracefully', () async {
        final corruptedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_789'],
            [
              'imeta',
              'url /var/mobile/Containers/cache/video.mp4',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([corruptedEvent]));

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async {
          final event = Event(_testPubkey, EventKind.videoVertical, [], '');
          event.sig = 'a' * 128;
          return event;
        });

        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final result = await repairService.repairIfNeeded();

        expect(result, equals(0));
        expect(prefs.getBool('corrupted_video_repair_v1_completed'), isTrue);
      });

      test('only repairs corrupted URLs, preserves valid ones', () async {
        final mixedEvent = _createVideoEvent(
          id: 'event1',
          tags: [
            ['d', 'video_mixed'],
            [
              'imeta',
              'url /var/mobile/Containers/cache/video.mp4',
              'url https://media.divine.video/existing_valid_url',
              'm video/mp4',
              'x $_testSha256',
            ],
          ],
        );

        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => _answeredScan([mixedEvent]));

        stubSignAndPublishSuccess();

        final result = await repairService.repairIfNeeded();

        expect(result, equals(1));

        final imetaTag = publishedEvents.first.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'imeta',
        );
        final urlComponents = imetaTag
            .where((c) => c.startsWith('url '))
            .toList();

        expect(urlComponents[0], equals('url $_blossomBaseUrl/$_testSha256'));
        expect(
          urlComponents[1],
          equals('url https://media.divine.video/existing_valid_url'),
        );
      });
    });
  });
}
