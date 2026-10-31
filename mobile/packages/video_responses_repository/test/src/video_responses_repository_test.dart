// ABOUTME: Tests reading a video's video replies and the answers to its Add
// ABOUTME: yours, from Funnelcake or the relays, and its creator's curation.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _creator = _hex(1);
final String _viewer = _hex(2);
final String _rootId = _hex(100);
final String _rootAddress = '34236:$_creator:root-d';
const _relay = 'wss://relay.divine.video';

Event _video({
  required int id,
  required int createdAt,
  String? pubkey,
  String dTag = 'video-d',
  List<List<String>> tags = const [],
  int kind = 34236,
}) => Event.fromJson({
  'id': _hex(id),
  'pubkey': pubkey ?? _viewer,
  'created_at': createdAt,
  'kind': kind,
  'tags': [
    ['d', dTag],
    ['imeta', 'url https://cdn.example/$id.mp4', 'm video/mp4'],
    ...tags,
  ],
  'content': '',
  'sig': '',
});

Event _rootVideo() =>
    _video(id: 100, createdAt: 500, pubkey: _creator, dTag: 'root-d');

Event _reply(int id, {required int createdAt, bool byAddress = false}) =>
    _video(
      id: id,
      createdAt: createdAt,
      dTag: 'reply-$id',
      tags: [
        if (byAddress)
          ['A', _rootAddress, '']
        else
          ['E', _rootId, '', _creator],
        ['K', '34236'],
      ],
    );

Event _answer(
  int id, {
  required int createdAt,
  String? chain,
  String hashtag = 'desksetup',
}) => _video(
  id: id,
  createdAt: createdAt,
  dTag: 'answer-$id',
  tags: [
    ['a', chain ?? _rootAddress, _relay, 'mention'],
    ['t', hashtag],
  ],
);

Event _curationEvent({
  required int createdAt,
  List<List<String>> tags = const [],
  String? pubkey,
  int kind = RepliesCuration.kind,
}) => Event.fromJson({
  'id': _hex(createdAt),
  'pubkey': pubkey ?? _creator,
  'created_at': createdAt,
  'kind': kind,
  'tags': [
    ['d', RepliesCuration.dTagFor(_rootAddress)],
    ...tags,
  ],
  'content': '',
  'sig': '',
});

PublishOutcome _outcome({required bool accepted}) => PublishOutcome(
  eventId: _hex(5),
  acceptedBy: accepted ? const [_relay] : const [],
  rejectedBy: accepted ? const {} : const {_relay: 'blocked: kind'},
  noResponseFrom: const [],
);

VideoStats _stats(String id) => VideoStats(
  id: id,
  pubkey: _viewer,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000000),
  kind: 34236,
  dTag: 'stats-$id',
  title: '',
  thumbnail: '',
  videoUrl: 'https://cdn.example/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);

void main() {
  late _MockNostrClient nostrClient;
  late _MockFunnelcakeApiClient funnelcake;
  late List<({int kind, List<List<String>> tags})> signed;
  late Event? signedEvent;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_rootVideo());
    registerFallbackValue(VideoResponseType.replies);
  });

  setUp(() {
    nostrClient = _MockNostrClient();
    funnelcake = _MockFunnelcakeApiClient();
    signed = [];
    signedEvent = _curationEvent(createdAt: 9000);
  });

  VideoResponsesRepository repository({bool withFunnelcake = false}) =>
      VideoResponsesRepository(
        nostrClient: nostrClient,
        signEvent: ({required kind, required content, required tags}) async {
          signed.add((kind: kind, tags: tags));
          return signedEvent;
        },
        funnelcakeApiClient: withFunnelcake ? funnelcake : null,
      );

  void relayAnswers(List<Event> events) => when(
    () => nostrClient.queryEvents(any()),
  ).thenAnswer((_) async => events);

  group(VideoResponsesRepository, () {
    group('fetchReplies', () {
      test('reads the replies from the relays, the newest first', () async {
        relayAnswers([
          _reply(201, createdAt: 1000),
          _reply(202, createdAt: 3000, byAddress: true),
          _reply(201, createdAt: 1000),
          // Not a reply to this video.
          _video(
            id: 203,
            createdAt: 4000,
            tags: [
              ['E', _hex(999), ''],
            ],
          ),
        ]);

        final responses = await repository().fetchReplies(
          videoId: _rootId,
          videoAddress: _rootAddress,
          limit: 1,
        );

        expect(responses.total, equals(2));
        expect(responses.videos.map((v) => v.id), equals([_hex(202)]));
        final filters =
            verify(
                  () => nostrClient.queryEvents(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters.map((f) => f.uppercaseE), anyElement(equals([_rootId])));
        expect(
          filters.map((f) => f.uppercaseA),
          anyElement(equals([_rootAddress])),
        );
      });

      test('asks by event id alone for a video with no address', () async {
        relayAnswers([_reply(201, createdAt: 1000)]);
        final responses = await repository().fetchReplies(videoId: _rootId);

        expect(responses.total, equals(1));
        final filters =
            verify(
                  () => nostrClient.queryEvents(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters, hasLength(1));
      });

      test('takes the count and the latest from Funnelcake', () async {
        when(() => funnelcake.isAvailable).thenReturn(true);
        when(
          () => funnelcake.getVideoResponses(
            videoId: any(named: 'videoId'),
            type: any(named: 'type'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async =>
              VideoResponsesResponse(videos: [_stats('abc')], total: 42),
        );

        final responses = await repository(
          withFunnelcake: true,
        ).fetchReplies(videoId: _rootId, videoAddress: _rootAddress, limit: 3);

        expect(responses.total, equals(42));
        expect(responses.videos.single.id, equals('abc'));
        verify(
          () => funnelcake.getVideoResponses(
            videoId: 'root-d',
            type: VideoResponseType.replies,
            limit: 3,
          ),
        ).called(1);
        verifyNever(() => nostrClient.queryEvents(any()));
      });

      test('reads the relays when Funnelcake does not answer', () async {
        when(() => funnelcake.isAvailable).thenReturn(true);
        when(
          () => funnelcake.getVideoResponses(
            videoId: any(named: 'videoId'),
            type: any(named: 'type'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          FunnelcakeNotFoundException(resource: 'Video responses'),
        );
        relayAnswers([_reply(201, createdAt: 1000)]);

        final responses = await repository(
          withFunnelcake: true,
        ).fetchReplies(videoId: _rootId, videoAddress: _rootAddress);

        expect(responses.total, equals(1));
      });

      test('reads the relays while Funnelcake is not configured', () async {
        when(() => funnelcake.isAvailable).thenReturn(false);
        relayAnswers(const []);

        final responses = await repository(
          withFunnelcake: true,
        ).fetchReplies(videoId: _rootId, videoAddress: _rootAddress);

        expect(responses, equals(const VideoResponses()));
        verifyNever(
          () => funnelcake.getVideoResponses(
            videoId: any(named: 'videoId'),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        );
      });
    });

    group('fetchJoined', () {
      test('reads the answers that name the chain and its hashtag', () async {
        relayAnswers([
          _answer(301, createdAt: 1000),
          _answer(302, createdAt: 2000),
          // Inspired by the same video for its sound, without the hashtag.
          _answer(303, createdAt: 3000, hashtag: 'other'),
          // Another chain.
          _answer(304, createdAt: 4000, chain: '34236:$_creator:other-d'),
          // The first video itself.
          _video(
            id: 100,
            createdAt: 500,
            pubkey: _creator,
            dTag: 'root-d',
            tags: [
              ['a', _rootAddress, _relay, 'mention'],
              ['t', 'desksetup'],
            ],
          ),
        ]);

        final responses = await repository().fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.total, equals(2));
        expect(
          responses.videos.map((v) => v.id),
          equals([_hex(302), _hex(301)]),
        );
        final filter =
            (verify(
                      () => nostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.a, equals([_rootAddress]));
        expect(filter.t, equals(['desksetup']));
      });

      test('asks Funnelcake by the first video and the hashtag', () async {
        when(() => funnelcake.isAvailable).thenReturn(true);
        when(
          () => funnelcake.getVideoResponses(
            videoId: any(named: 'videoId'),
            type: any(named: 'type'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => const VideoResponsesResponse(videos: [], total: 7),
        );

        final responses = await repository(withFunnelcake: true).fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.total, equals(7));
        verify(
          () => funnelcake.getVideoResponses(
            videoId: 'root-d',
            type: VideoResponseType.joined,
            hashtag: 'desksetup',
          ),
        ).called(1);
      });
    });

    group('fetchCuration', () {
      test("reads the creator's latest pins and hides", () async {
        relayAnswers([
          _curationEvent(
            createdAt: 1000,
            tags: [
              ['e', _hex(201), '', 'pinned'],
            ],
          ),
          _curationEvent(
            createdAt: 2000,
            tags: [
              ['e', _hex(202), '', 'pinned'],
              ['e', _hex(203), '', 'hidden'],
            ],
          ),
          // Someone else's cannot curate the creator's replies.
          _curationEvent(
            createdAt: 3000,
            pubkey: _viewer,
            tags: [
              ['e', _hex(204), '', 'pinned'],
            ],
          ),
        ]);

        final curation = await repository().fetchCuration(
          creatorPubkey: _creator,
          videoAddress: _rootAddress,
        );

        expect(
          curation,
          equals(RepliesCuration(pinnedId: _hex(202), hiddenIds: {_hex(203)})),
        );
        final filter =
            (verify(
                      () => nostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.authors, equals([_creator]));
        expect(filter.d, equals(['divine:replies:$_rootAddress']));
      });

      test('reads none when the creator curated nothing', () async {
        relayAnswers(const []);

        expect(
          await repository().fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _rootAddress,
          ),
          equals(const RepliesCuration()),
        );
      });
    });

    group('saveCuration', () {
      test('signs and publishes the curation', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: true));

        await repository().saveCuration(
          RepliesCuration(pinnedId: _hex(202)),
          videoAddress: _rootAddress,
        );

        expect(signed.single.kind, equals(RepliesCuration.kind));
        expect(
          signed.single.tags,
          anyElement(equals(['e', _hex(202), '', 'pinned'])),
        );
        verify(() => nostrClient.publishEventAwaitOk(signedEvent!)).called(1);
      });

      test('throws when it cannot be signed', () async {
        signedEvent = null;

        await expectLater(
          repository().saveCuration(
            const RepliesCuration(),
            videoAddress: _rootAddress,
          ),
          throwsA(isA<RepliesCurationException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('throws when no relay takes it', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: false));

        await expectLater(
          repository().saveCuration(
            const RepliesCuration(),
            videoAddress: _rootAddress,
          ),
          throwsA(
            isA<RepliesCurationException>()
                .having((e) => e.outcome?.failed, 'failed', isTrue)
                .having(
                  (e) => e.toString(),
                  'toString',
                  startsWith('RepliesCurationException:'),
                ),
          ),
        );
      });
    });
  });

  group(RepliesCuration, () {
    test('reads only its own kind and d tag', () {
      expect(
        RepliesCuration.fromEvent(_curationEvent(createdAt: 1, kind: 1)),
        isNull,
      );
      expect(
        RepliesCuration.fromEvent(
          Event.fromJson({
            ..._curationEvent(createdAt: 1).toJson(),
            'tags': [
              ['d', 'other'],
            ],
          }),
        ),
        isNull,
      );
    });

    test('drops a pinned reply it also hides, and broken ids', () {
      expect(
        RepliesCuration.fromEvent(
          _curationEvent(
            createdAt: 1,
            tags: [
              ['e', _hex(201), '', 'pinned'],
              ['e', _hex(201), '', 'hidden'],
              ['e', 'nope', '', 'hidden'],
              ['e', _hex(202), ''],
              ['e', _hex(203), '', 'other'],
            ],
          ),
        ),
        equals(RepliesCuration(hiddenIds: {_hex(201)})),
      );
    });

    test('pins, hides and shows a reply again', () {
      final curation = const RepliesCuration()
          .pinned(_hex(201))
          .hidden(_hex(202));

      expect(curation.pinnedId, equals(_hex(201)));
      expect(curation.hidden(_hex(201)).pinnedId, isNull);
      expect(curation.shown(_hex(202)).hiddenIds, isEmpty);
      expect(curation.pinned(_hex(202)).hiddenIds, isEmpty);
    });

    test('puts the pinned reply first and leaves the hidden ones out', () {
      final replies = [
        for (final id in [201, 202, 203])
          VideoEvent.fromNostrEvent(_reply(id, createdAt: 1000 - id)),
      ];

      expect(
        RepliesCuration(
          pinnedId: _hex(203),
          hiddenIds: {_hex(202)},
        ).apply(replies).map((v) => v.id),
        equals([_hex(203), _hex(201)]),
      );
      expect(
        RepliesCuration(pinnedId: _hex(201)).apply(replies),
        equals(replies),
      );
    });

    test('publishes its pins and hides for the video', () {
      expect(
        RepliesCuration(
          pinnedId: _hex(201),
          hiddenIds: {_hex(202)},
        ).toTags(_rootAddress),
        equals([
          ['d', 'divine:replies:$_rootAddress'],
          ['a', _rootAddress],
          ['e', _hex(201), '', 'pinned'],
          ['e', _hex(202), '', 'hidden'],
        ]),
      );
    });
  });
}
