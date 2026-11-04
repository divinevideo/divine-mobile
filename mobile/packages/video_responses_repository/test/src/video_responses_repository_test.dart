// ABOUTME: Tests reading a video's video replies and the answers to its Add
// ABOUTME: yours, from Funnelcake or the relays, and its creator's curation.

import 'dart:async';

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
  String? pubkey,
  String marker = 'mention',
}) => _video(
  id: id,
  createdAt: createdAt,
  pubkey: pubkey ?? _hex(1000 + id),
  dTag: 'answer-$id',
  tags: [
    ['a', chain ?? _rootAddress, _relay, marker],
    ['t', hashtag],
  ],
);

/// The tag of an Add yours sticker naming [chain] as its first video, or
/// none when it is the first.
List<String> _addYoursSticker({
  String chain = '',
  String hashtag = 'desksetup',
}) => VideoStickerRegion(
  kind: VideoStickerKind.prompt,
  target: chain,
  centerX: 0.5,
  centerY: 0.5,
  width: 0.6,
  height: 0.3,
  label: 'Show your desk\n$hashtag',
).toTag();

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

VideoStats _stats(
  String id, {
  List<List<String>> eventTags = const [],
  int createdAtMs = 1000000,
}) => VideoStats(
  id: id,
  pubkey: _viewer,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
  kind: 34236,
  dTag: 'stats-$id',
  eventTags: eventTags,
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
  late List<
    ({int kind, String content, List<List<String>> tags, int? createdAt})
  >
  signed;
  late Event? signedEvent;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_rootVideo());
    registerFallbackValue(VideoResponseType.replies);
  });

  setUp(() {
    nostrClient = _MockNostrClient();
    when(() => nostrClient.publicKey).thenReturn(_creator);
    when(() => nostrClient.isDisposed).thenReturn(false);
    funnelcake = _MockFunnelcakeApiClient();
    signed = [];
    signedEvent = _curationEvent(createdAt: 9000);
  });

  VideoResponsesRepository repository({bool withFunnelcake = false}) =>
      VideoResponsesRepository(
        nostrClient: nostrClient,
        signEvent:
            ({
              required kind,
              required content,
              required tags,
              createdAt,
            }) async {
              signed.add((
                kind: kind,
                content: content,
                tags: tags,
                createdAt: createdAt,
              ));
              return signedEvent;
            },
        funnelcakeApiClient: withFunnelcake ? funnelcake : null,
      );

  void relayAnswers(
    List<Event> events, {
    bool capped = false,
    QueryEnd endedBy = QueryEnd.complete,
  }) {
    when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => events);
    when(() => nostrClient.readEvents(any())).thenAnswer(
      (_) async => QueryResult(
        events: events,
        endedBy: endedBy,
        possiblyCapped: capped,
      ),
    );
  }

  void curationAnswers(
    List<Event> events, {
    bool timedOut = false,
    bool noRelays = false,
  }) =>
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );

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
                  () => nostrClient.readEvents(captureAny()),
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
                  () => nostrClient.readEvents(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters, hasLength(1));
      });

      test('takes the count and the latest from Funnelcake, asking by the '
          "video's event id", () async {
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
          // Not the d tag: any account can publish a video with the same one,
          // and the server resolves a d tag to the newest video carrying it.
          // The event id names this video alone, and the server derives its
          // address from it, so replies to any of its versions still count.
          () => funnelcake.getVideoResponses(
            videoId: _rootId,
            type: VideoResponseType.replies,
            limit: 3,
          ),
        ).called(1);
        verifyNever(() => nostrClient.readEvents(any()));
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

      test('counts replies only as a floor when a relay may have stopped at '
          'its limit', () async {
        relayAnswers([_reply(201, createdAt: 1000)], capped: true);

        final responses = await repository().fetchReplies(
          videoId: _rootId,
          videoAddress: _rootAddress,
        );

        expect(responses.totalIsAtLeast, isTrue);
      });

      test('counts exactly when no relay stopped at its limit', () async {
        // Two filters' answers together can reach the read's limit without
        // either relay stopping at it.
        relayAnswers([
          for (var i = 0; i < VideoResponsesRepository.maxResponsesRead; i++)
            _reply(1000 + i, createdAt: 1000 + i),
        ]);

        final responses = await repository().fetchReplies(
          videoId: _rootId,
          videoAddress: _rootAddress,
        );

        expect(responses.totalIsAtLeast, isFalse);
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
                      () => nostrClient.readEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.a, equals([_rootAddress]));
        expect(filter.t, equals(['desksetup']));
      });

      test('counts each person once, by their newest answer', () async {
        relayAnswers([
          _answer(301, createdAt: 1000, pubkey: _creator),
          _answer(302, createdAt: 2000, pubkey: _creator),
          _answer(303, createdAt: 1500),
        ]);

        final responses = await repository().fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.total, equals(2));
        expect(
          responses.videos.map((v) => v.id),
          equals([_hex(302), _hex(303)]),
        );
      });

      test(
        "picks each person's answer after the viewer's filter",
        () async {
          relayAnswers([
            _answer(301, createdAt: 1000, pubkey: _creator),
            _answer(302, createdAt: 2000, pubkey: _creator),
            _answer(303, createdAt: 1500),
          ]);

          // The viewer's filters leave out the creator's newest answer.
          final responses = await repository().fetchJoined(
            chainRoot: _rootAddress,
            hashtag: 'desksetup',
            filter: (answers) => [
              for (final answer in answers)
                if (answer.id != _hex(302)) answer,
            ],
          );

          expect(responses.total, equals(2));
          expect(
            responses.videos.map((v) => v.id),
            equals([_hex(303), _hex(301)]),
          );
        },
      );

      test('leaves out an `a` tag not marked as a mention', () async {
        relayAnswers([
          _answer(301, createdAt: 1000),
          // A plain reply naming the first video, with the hashtag.
          _answer(302, createdAt: 2000, marker: ''),
          _answer(303, createdAt: 3000, marker: clipSourceCreditTagMarker),
        ]);

        final responses = await repository().fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.videos.map((v) => v.id), equals([_hex(301)]));
      });

      test('counts only a floor when a relay may have stopped at its '
          'limit', () async {
        // A relay that stops below the read's limit still says it may have.
        relayAnswers([
          _answer(301, createdAt: 1000),
          _answer(302, createdAt: 2000),
        ], capped: true);

        final responses = await repository().fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.totalIsAtLeast, isTrue);
        expect(responses.total, equals(2));
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

      test("drops Funnelcake's answers that do not join the chain", () async {
        when(() => funnelcake.isAvailable).thenReturn(true);
        when(
          () => funnelcake.getVideoResponses(
            videoId: any(named: 'videoId'),
            type: any(named: 'type'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => VideoResponsesResponse(
            videos: [
              _stats(
                _hex(301),
                eventTags: [
                  ['a', _rootAddress, _relay, 'mention'],
                  ['t', 'desksetup'],
                ],
              ),
              // Another author's video with the same d tag.
              _stats(
                _hex(302),
                eventTags: [
                  ['a', '34236:$_viewer:root-d', _relay, 'mention'],
                  ['t', 'desksetup'],
                ],
              ),
              // A clip taken from the first video.
              _stats(
                _hex(303),
                eventTags: [
                  ['a', _rootAddress, _relay, clipSourceCreditTagMarker],
                  ['t', 'desksetup'],
                ],
              ),
              // A second answer by the author of the first, counted once.
              _stats(
                _hex(304),
                eventTags: [
                  ['a', _rootAddress, _relay, 'mention'],
                  ['t', 'desksetup'],
                ],
              ),
            ],
            total: 9,
          ),
        );

        final responses = await repository(withFunnelcake: true).fetchJoined(
          chainRoot: _rootAddress,
          hashtag: 'desksetup',
        );

        expect(responses.videos, hasLength(1));
        expect(responses.total, equals(6));
      });

      test(
        "picks each person's Funnelcake answer after the viewer's filter",
        () async {
          when(() => funnelcake.isAvailable).thenReturn(true);
          List<List<String>> joins() => [
            ['a', _rootAddress, _relay, 'mention'],
            ['t', 'desksetup'],
          ];
          when(
            () => funnelcake.getVideoResponses(
              videoId: any(named: 'videoId'),
              type: any(named: 'type'),
              hashtag: any(named: 'hashtag'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => VideoResponsesResponse(
              videos: [
                _stats(_hex(301), eventTags: joins()),
                _stats(_hex(302), eventTags: joins(), createdAtMs: 2000000),
              ],
              total: 2,
            ),
          );

          // The viewer's filters leave out the person's newest answer.
          final responses = await repository(withFunnelcake: true).fetchJoined(
            chainRoot: _rootAddress,
            hashtag: 'desksetup',
            filter: (answers) => [
              for (final answer in answers)
                if (answer.id != _hex(302)) answer,
            ],
          );

          expect(responses.videos.map((v) => v.id), equals([_hex(301)]));
        },
      );
    });

    group('chainStart', () {
      Event first({List<List<String>> tags = const []}) => _video(
        id: 100,
        createdAt: 500,
        pubkey: _creator,
        dTag: 'root-d',
        tags: tags,
      );

      Future<AddYoursChainStart> chainStart(String chainRoot) =>
          repository().chainStart(chainRoot, hashtag: 'desksetup');

      test(
        'starts it for a video with its own Add yours and the hashtag',
        () async {
          relayAnswers([
            first(tags: [_addYoursSticker()]),
          ], endedBy: QueryEnd.settledEarly);

          // Read starting it, so a relay that stayed silent changes nothing.
          expect(await chainStart(_rootAddress), AddYoursChainStart.starts);
          final filter =
              (verify(
                        () => nostrClient.readEvents(captureAny()),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.authors, equals([_creator]));
          expect(filter.d, equals(['root-d']));
        },
      );

      test(
        'does not start it for a video whose Add yours answers another',
        () async {
          relayAnswers([
            first(
              tags: [_addYoursSticker(chain: '34236:$_viewer:other-d')],
            ),
          ]);

          expect(
            await chainStart(_rootAddress),
            AddYoursChainStart.doesNotStart,
          );
        },
      );

      test('does not start it for another hashtag, or no Add yours', () async {
        relayAnswers([
          first(tags: [_addYoursSticker(hashtag: 'other')]),
        ]);
        expect(
          await chainStart(_rootAddress),
          AddYoursChainStart.doesNotStart,
        );

        relayAnswers([first()]);
        expect(
          await chainStart(_rootAddress),
          AddYoursChainStart.doesNotStart,
        );
      });

      test(
        'does not start it when the video is not found or not an address',
        () async {
          relayAnswers([]);

          expect(
            await chainStart(_rootAddress),
            AddYoursChainStart.doesNotStart,
          );
          expect(await chainStart(_rootId), AddYoursChainStart.doesNotStart);
        },
      );

      test(
        'is unconfirmed when a relay did not answer in full and the video '
        'was not read starting it',
        () async {
          for (final endedBy in [
            QueryEnd.settledEarly,
            QueryEnd.relayClosed,
            QueryEnd.socketDropped,
            QueryEnd.deadline,
          ]) {
            relayAnswers([], endedBy: endedBy);
            expect(
              await chainStart(_rootAddress),
              AddYoursChainStart.unconfirmed,
              reason: '$endedBy',
            );
          }

          relayAnswers([first()], endedBy: QueryEnd.settledEarly);
          expect(
            await chainStart(_rootAddress),
            AddYoursChainStart.unconfirmed,
          );
        },
      );

      test('throws when no relay could be asked', () async {
        relayAnswers([], endedBy: QueryEnd.noRelay);

        await expectLater(
          chainStart(_rootAddress),
          throwsA(
            isA<AddYoursChainUnavailableException>().having(
              (error) => error.toString(),
              'toString',
              'AddYoursChainUnavailableException: No relay could be asked',
            ),
          ),
        );
      });
    });

    group('fetchReply', () {
      test('reads a reply by its address', () async {
        relayAnswers([_reply(202, createdAt: 3000, byAddress: true)]);

        final reply = await repository().fetchReply(
          '34236:$_viewer:reply-202',
          videoId: _rootId,
          videoAddress: _rootAddress,
        );

        expect(reply?.id, equals(_hex(202)));
        final filter =
            (verify(
                      () => nostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.authors, equals([_viewer]));
        expect(filter.d, equals(['reply-202']));
      });

      test('reads a reply by its event id', () async {
        relayAnswers([_reply(201, createdAt: 1000)]);

        final reply = await repository().fetchReply(
          _hex(201),
          videoId: _rootId,
        );

        expect(reply?.id, equals(_hex(201)));
        final filter =
            (verify(
                      () => nostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.ids, equals([_hex(201)]));
      });

      test('reads none for a video replying to another video', () async {
        relayAnswers([
          _video(
            id: 203,
            createdAt: 4000,
            tags: [
              ['E', _hex(999), ''],
            ],
          ),
        ]);

        final reply = await repository().fetchReply(
          _hex(203),
          videoId: _rootId,
          videoAddress: _rootAddress,
        );

        expect(reply, isNull);
      });

      test('reads none when the relays have no such reply', () async {
        relayAnswers([]);

        final reply = await repository().fetchReply(
          _hex(201),
          videoId: _rootId,
        );

        expect(reply, isNull);
      });
    });

    group('fetchCuration', () {
      test("reads the creator's latest pins and hides", () async {
        curationAnswers([
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
                      () => nostrClient.queryEventsDetailed(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.authors, equals([_creator]));
        expect(filter.d, equals(['divine:replies:$_rootAddress']));
      });

      test('reads none when the creator curated nothing', () async {
        curationAnswers(const []);

        expect(
          await repository().fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _rootAddress,
          ),
          equals(const RepliesCuration()),
        );
      });
      test('fails when the read timed out and found nothing', () async {
        curationAnswers(const [], timedOut: true);

        // Read as "nothing curated", the creator's next pin would publish a
        // curation without the replies they hid.
        await expectLater(
          repository().fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _rootAddress,
          ),
          throwsA(isA<RepliesCurationUnavailableException>()),
        );
      });

      test('fails when no relay could be asked', () async {
        curationAnswers(const [], noRelays: true);

        await expectLater(
          repository().fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _rootAddress,
          ),
          throwsA(
            isA<RepliesCurationUnavailableException>().having(
              (e) => e.toString(),
              'toString',
              equals(
                'RepliesCurationUnavailableException: No relay could be asked',
              ),
            ),
          ),
        );
      });

      test('keeps what it found when the read timed out', () async {
        curationAnswers([
          _curationEvent(
            createdAt: 1000,
            tags: [
              ['e', _hex(201), '', 'hidden'],
            ],
          ),
        ], timedOut: true);

        expect(
          await repository().fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _rootAddress,
          ),
          equals(RepliesCuration(hiddenIds: {_hex(201)})),
        );
      });
    });

    group('saveCuration', () {
      setUp(() => curationAnswers(const []));
      test(
        'reconciles remote hidden replies and preserves the complete source',
        () async {
          final remote = Event.fromJson({
            ..._curationEvent(createdAt: 1000).toJson(),
            'tags': [
              ['d', RepliesCuration.dTagFor(_rootAddress)],
              ['a', _rootAddress],
              ['e', _hex(201), 'wss://relay.example', 'hidden', 'extra'],
              ['e', _hex(202), 'wss://relay.example', 'pinned'],
              ['alt', 'Keep me'],
              ['e', _hex(205), '', 'foreign-marker'],
            ],
            'content': 'opaque-private-content',
          });
          curationAnswers([remote]);
          when(
            () => nostrClient.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _outcome(accepted: true));

          final reconciled = await repository().saveCuration(
            RepliesCuration(hiddenIds: {_hex(203)}),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
          );

          expect(
            reconciled,
            RepliesCuration(
              pinnedId: _hex(202),
              hiddenIds: {_hex(201), _hex(203)},
            ),
          );
          expect(signed.single.content, 'opaque-private-content');
          expect(signed.single.tags, [
            ['d', RepliesCuration.dTagFor(_rootAddress)],
            ['a', _rootAddress],
            ['e', _hex(201), 'wss://relay.example', 'hidden', 'extra'],
            ['e', _hex(202), 'wss://relay.example', 'pinned'],
            ['alt', 'Keep me'],
            ['e', _hex(205), '', 'foreign-marker'],
            ['e', _hex(203), '', 'hidden'],
          ]);
        },
      );

      for (final noRelays in [false, true]) {
        test(
          'refuses an incomplete nonempty read (noRelays: $noRelays)',
          () async {
            curationAnswers(
              [
                _curationEvent(
                  createdAt: 1000,
                  tags: [
                    ['e', _hex(201), '', 'hidden'],
                  ],
                ),
              ],
              noRelays: noRelays,
              timedOut: !noRelays,
            );
            when(
              () => nostrClient.publishEventAwaitOk(any()),
            ).thenAnswer((_) async => _outcome(accepted: true));

            await expectLater(
              repository().saveCuration(
                RepliesCuration(hiddenIds: {_hex(203)}),
                videoAddress: _rootAddress,
                previous: const RepliesCuration(),
              ),
              throwsA(isA<RepliesCurationUnavailableException>()),
            );
            expect(signed, isEmpty);
            verifyNever(() => nostrClient.publishEventAwaitOk(any()));
          },
        );
      }

      test(
        'waits for every relay and excludes cached curation events',
        () async {
          curationAnswers(const []);
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer(
            (_) async => (
              events: [
                _curationEvent(
                  createdAt: 1000,
                  tags: [
                    ['e', _hex(201), '', 'hidden'],
                  ],
                ),
              ],
              timedOut: false,
              noRelays: false,
            ),
          );
          when(
            () => nostrClient.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _outcome(accepted: true));

          await repository().saveCuration(
            RepliesCuration(pinnedId: _hex(202)),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
          );

          expect(
            signed.single.tags,
            anyElement(equals(['e', _hex(201), '', 'hidden'])),
          );
        },
      );

      test(
        'serializes the relay read through publication for concurrent edits',
        () async {
          curationAnswers(const []);
          final publishing = Completer<void>();
          final release = Completer<void>();
          final published = <Event>[];
          when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
            call,
          ) async {
            published.add(call.positionalArguments.single as Event);
            if (published.length == 1) {
              publishing.complete();
              await release.future;
            }
            return _outcome(accepted: true);
          });
          final responses = VideoResponsesRepository(
            nostrClient: nostrClient,
            signEvent:
                ({
                  required kind,
                  required content,
                  required tags,
                  createdAt,
                }) async =>
                    Event(_creator, kind, tags, content, createdAt: createdAt),
          );
          final first = responses.saveCuration(
            RepliesCuration(hiddenIds: {_hex(201)}),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
          );
          await publishing.future;
          final second = responses.saveCuration(
            RepliesCuration(hiddenIds: {_hex(202)}),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
          );
          await Future<void>.delayed(Duration.zero);
          final overlapped = published.length > 1;
          release.complete();
          await Future.wait([first, second]);

          expect(overlapped, isFalse);
          expect(RepliesCuration.fromEvent(published.last)?.hiddenIds, {
            _hex(201),
            _hex(202),
          });
        },
      );

      test(
        'shows only the requested reply while keeping remote hidden replies',
        () async {
          curationAnswers([
            _curationEvent(
              createdAt: 1000,
              tags: [
                ['e', _hex(201), 'wss://relay.example', 'hidden'],
                ['e', _hex(202), 'wss://other.example', 'hidden'],
              ],
            ),
          ]);
          when(
            () => nostrClient.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _outcome(accepted: true));

          final reconciled = await repository().saveCuration(
            const RepliesCuration(),
            videoAddress: _rootAddress,
            previous: RepliesCuration(hiddenIds: {_hex(201)}),
          );

          expect(reconciled.hiddenIds, {_hex(202)});
          expect(signed.single.tags, [
            ['d', RepliesCuration.dTagFor(_rootAddress)],
            ['e', _hex(202), 'wss://other.example', 'hidden'],
          ]);
        },
      );

      test('refuses a signature belonging to a different account', () async {
        signedEvent = _curationEvent(createdAt: 1000, pubkey: _viewer);

        await expectLater(
          repository().saveCuration(
            RepliesCuration(hiddenIds: {_hex(201)}),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
          ),
          throwsA(isA<RepliesCurationException>()),
        );

        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test(
        'refuses an account switch while the latest curation is loading',
        () async {
          var currentOwner = _creator;
          when(() => nostrClient.publicKey).thenAnswer((_) => currentOwner);
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer((_) async {
            currentOwner = _viewer;
            return (events: <Event>[], timedOut: false, noRelays: false);
          });

          await expectLater(
            repository().saveCuration(
              RepliesCuration(hiddenIds: {_hex(201)}),
              videoAddress: _rootAddress,
              previous: const RepliesCuration(),
            ),
            throwsA(isA<RepliesCurationException>()),
          );

          expect(signed, isEmpty);
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('signs and publishes the curation', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: true));

        await repository().saveCuration(
          RepliesCuration(pinnedId: _hex(202)),
          videoAddress: _rootAddress,
          previous: const RepliesCuration(),
        );

        expect(signed.single.kind, equals(RepliesCuration.kind));
        expect(
          signed.single.tags,
          anyElement(equals(['e', _hex(202), '', 'pinned'])),
        );
        verify(() => nostrClient.publishEventAwaitOk(signedEvent!)).called(1);
      });

      test('signs after the curation it read, even one ahead of now', () async {
        final ahead = NostrTimestamp.now(driftTolerance: 0) + 1000;
        curationAnswers([_curationEvent(createdAt: ahead)]);
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: true));
        final responses = repository();
        await responses.fetchCuration(
          creatorPubkey: _creator,
          videoAddress: _rootAddress,
        );
        signedEvent = _curationEvent(createdAt: ahead + 1);

        await responses.saveCuration(
          const RepliesCuration(),
          videoAddress: _rootAddress,
          previous: const RepliesCuration(),
        );

        expect(signed.single.createdAt, equals(ahead + 1));
      });

      test('signs a second curation after the first', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: true));
        final responses = repository();
        signedEvent = _curationEvent(
          createdAt: NostrTimestamp.now(driftTolerance: 0) + 1000,
        );
        await responses.saveCuration(
          RepliesCuration(pinnedId: _hex(202)),
          videoAddress: _rootAddress,
          previous: const RepliesCuration(),
        );

        await responses.saveCuration(
          const RepliesCuration(),
          videoAddress: _rootAddress,
          previous: const RepliesCuration(),
        );

        expect(signed.last.createdAt, equals(signedEvent!.createdAt + 1));
      });

      test('throws when it cannot be signed', () async {
        signedEvent = null;

        await expectLater(
          repository().saveCuration(
            const RepliesCuration(),
            videoAddress: _rootAddress,
            previous: const RepliesCuration(),
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
            previous: const RepliesCuration(),
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

    test('keeps a reply hidden and pinned after its author edits it', () {
      final hidden = VideoEvent.fromNostrEvent(_reply(201, createdAt: 900));
      final pinned = VideoEvent.fromNostrEvent(_reply(202, createdAt: 800));
      final curation = const RepliesCuration()
          .hidden(RepliesCuration.keyOf(hidden))
          .pinned(RepliesCuration.keyOf(pinned));
      // An edit republishes the addressable reply under a new event id.
      final edited = [
        VideoEvent.fromNostrEvent(
          _video(id: 301, createdAt: 1200, dTag: 'reply-201'),
        ),
        VideoEvent.fromNostrEvent(
          _video(id: 302, createdAt: 1100, dTag: 'reply-202'),
        ),
        VideoEvent.fromNostrEvent(_reply(203, createdAt: 1000)),
      ];

      expect(
        curation.apply(edited).map((v) => v.id),
        equals([_hex(302), _hex(203)]),
      );
    });

    test('reads pins and hides by address, and drops broken addresses', () {
      final pinned = '34236:$_viewer:reply-201';
      final hidden = '34236:$_viewer:reply-202';
      expect(
        RepliesCuration.fromEvent(
          _curationEvent(
            createdAt: 1,
            tags: [
              ['a', _rootAddress],
              ['a', pinned, '', 'pinned'],
              ['a', hidden, '', 'hidden'],
              ['a', '34236:nope:reply-203', '', 'hidden'],
              ['a', '34236:$_viewer:', '', 'hidden'],
            ],
          ),
        ),
        equals(RepliesCuration(pinnedId: pinned, hiddenIds: {hidden})),
      );
    });

    test('publishes an addressable reply by its address', () {
      final pinned = '34236:$_viewer:reply-201';
      expect(
        RepliesCuration(
          pinnedId: pinned,
          hiddenIds: {_hex(202)},
        ).toTags(_rootAddress),
        equals([
          ['d', 'divine:replies:$_rootAddress'],
          ['a', _rootAddress],
          ['a', pinned, '', 'pinned'],
          ['e', _hex(202), '', 'hidden'],
        ]),
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
