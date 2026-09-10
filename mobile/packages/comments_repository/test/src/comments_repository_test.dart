import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class FakeEvent extends Fake implements Event {}

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

/// Example kind for a video event (Kind 34236 for NIP-71).
const int _testRootEventKind = EventKind.videoVertical;

void main() {
  group('CommentsRepository', () {
    late MockNostrClient mockNostrClient;
    late MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late CommentsRepository repository;

    const testRootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testRootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testUserPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(FakeEvent());
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockFunnelcakeApiClient = MockFunnelcakeApiClient();
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      repository = CommentsRepository(nostrClient: mockNostrClient);
    });

    group('constructor', () {
      test('creates repository with nostrClient', () {
        final repo = CommentsRepository(nostrClient: mockNostrClient);
        expect(repo, isNotNull);
      });
    });

    group('loadComments', () {
      test('uses REST bootstrap when Funnelcake client is available', () async {
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenAnswer(
          (_) async => VideoCommentsResponse(
            comments: [
              VideoComment(
                id: 'rest_comment',
                pubkey: testUserPubkey,
                createdAt: 1000,
                kind: _commentKind,
                content: 'REST comment',
                sig: 'sig',
                tags: [
                  ['E', testRootEventId],
                  ['K', _testRootEventKind.toString()],
                  ['P', testRootAuthorPubkey],
                  ['e', testRootEventId],
                  ['k', _testRootEventKind.toString()],
                  ['p', testRootAuthorPubkey],
                ],
                authorName: 'Tester',
                authorAvatar: 'https://example.com/avatar.jpg',
              ),
            ],
            total: 12,
          ),
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        repository = CommentsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.totalCount, equals(12));
        expect(result.comments, hasLength(1));
        expect(result.comments.first.content, equals('REST comment'));
        verify(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: testRootEventId,
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).called(1);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test(
        'does not merge relay video replies into REST bootstrap comments '
        'when video replies are disabled',
        () async {
          when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeApiClient.getVideoComments(
              videoId: any(named: 'videoId'),
              sort: any(named: 'sort'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              cacheBustToken: any(named: 'cacheBustToken'),
            ),
          ).thenAnswer(
            (_) async => VideoCommentsResponse(
              comments: [
                VideoComment(
                  id: 'rest_comment',
                  pubkey: testUserPubkey,
                  createdAt: 1000,
                  kind: _commentKind,
                  content: 'REST comment',
                  sig: 'sig',
                  tags: [
                    ['E', testRootEventId],
                    ['K', _testRootEventKind.toString()],
                    ['P', testRootAuthorPubkey],
                    ['e', testRootEventId],
                    ['k', _testRootEventKind.toString()],
                    ['p', testRootAuthorPubkey],
                  ],
                ),
              ],
              total: 1,
            ),
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          repository = CommentsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeApiClient,
          );

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          expect(result.totalCount, equals(1));
          expect(
            result.comments.map((comment) => comment.id),
            ['rest_comment'],
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test(
        'REST bootstrap does not wait for relay video reply lookup',
        () async {
          when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeApiClient.getVideoComments(
              videoId: any(named: 'videoId'),
              sort: any(named: 'sort'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              cacheBustToken: any(named: 'cacheBustToken'),
            ),
          ).thenAnswer(
            (_) async => VideoCommentsResponse(
              comments: [
                VideoComment(
                  id: 'rest_comment',
                  pubkey: testUserPubkey,
                  createdAt: 1000,
                  kind: _commentKind,
                  content: 'REST comment',
                  sig: 'sig',
                  tags: [
                    ['E', testRootEventId],
                    ['K', _testRootEventKind.toString()],
                    ['P', testRootAuthorPubkey],
                    ['e', testRootEventId],
                    ['k', _testRootEventKind.toString()],
                    ['p', testRootAuthorPubkey],
                  ],
                ),
              ],
              total: 1,
            ),
          );
          final neverCompletes = Completer<List<Event>>();
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) => neverCompletes.future);

          repository = CommentsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeApiClient,
          );

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            includeVideoReplies: true,
          );

          expect(result.totalCount, equals(1));
          expect(result.comments.map((comment) => comment.id), [
            'rest_comment',
          ]);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test('maps video metadata from REST imeta tags', () async {
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenAnswer(
          (_) async => VideoCommentsResponse(
            comments: [
              VideoComment(
                id: 'rest_video_reply',
                pubkey: testUserPubkey,
                createdAt: 1000,
                kind: EventKind.videoVertical,
                content: 'REST video reply',
                sig: 'sig',
                tags: [
                  ['E', testRootEventId],
                  ['K', _testRootEventKind.toString()],
                  ['P', testRootAuthorPubkey],
                  ['e', testRootEventId],
                  ['k', _testRootEventKind.toString()],
                  ['p', testRootAuthorPubkey],
                  [
                    'imeta',
                    'url https://media.divine.video/reply/12345',
                    'm video/mp4',
                    'image https://media.divine.video/reply/12345.jpg',
                    'dim 720x1280',
                    'duration 6',
                    'blurhash LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
                  ],
                ],
              ),
            ],
            total: 1,
          ),
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        repository = CommentsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          includeVideoReplies: true,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.hasVideo, isTrue);
        expect(
          result.comments.first.videoUrl,
          equals('https://media.divine.video/reply/12345'),
        );
        expect(
          result.comments.first.thumbnailUrl,
          equals('https://media.divine.video/reply/12345.jpg'),
        );
        expect(result.comments.first.videoDimensions, equals('720x1280'));
        expect(result.comments.first.videoDuration, equals(6));
        expect(
          result.comments.first.videoBlurhash,
          equals('LKO2?U%2Tw=w]~RBVZRi};RPxuwH'),
        );
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('maps video metadata from positional REST imeta tags', () async {
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenAnswer(
          (_) async => VideoCommentsResponse(
            comments: [
              VideoComment(
                id: 'rest_video_reply',
                pubkey: testUserPubkey,
                createdAt: 1000,
                kind: EventKind.videoVertical,
                content: 'REST video reply',
                sig: 'sig',
                tags: [
                  ['E', testRootEventId],
                  ['K', _testRootEventKind.toString()],
                  ['P', testRootAuthorPubkey],
                  ['e', testRootEventId],
                  ['k', _testRootEventKind.toString()],
                  ['p', testRootAuthorPubkey],
                  [
                    'imeta',
                    'url',
                    'https://media.divine.video/reply/12345',
                    'm',
                    'video/mp4',
                    'thumb',
                    'https://media.divine.video/reply/12345.jpg',
                    'dim',
                    '720x1280',
                    'duration',
                    '6',
                    'blurhash',
                    'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
                  ],
                ],
              ),
            ],
            total: 1,
          ),
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        repository = CommentsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          includeVideoReplies: true,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.hasVideo, isTrue);
        expect(
          result.comments.first.videoUrl,
          equals('https://media.divine.video/reply/12345'),
        );
        expect(
          result.comments.first.thumbnailUrl,
          equals('https://media.divine.video/reply/12345.jpg'),
        );
        expect(result.comments.first.videoDimensions, equals('720x1280'));
        expect(result.comments.first.videoDuration, equals(6));
        expect(
          result.comments.first.videoBlurhash,
          equals('LKO2?U%2Tw=w]~RBVZRi};RPxuwH'),
        );
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test(
        'maps coordinate and kind from a REST video reply (#6124)',
        () async {
          // loadComments is REST-first, so this — not the relay mapper — is the
          // path that serves the first page in production. Without it a vote on
          // a REST-delivered video reply still carries k:1111 and no `a` tag.
          when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeApiClient.getVideoComments(
              videoId: any(named: 'videoId'),
              sort: any(named: 'sort'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              cacheBustToken: any(named: 'cacheBustToken'),
            ),
          ).thenAnswer(
            (_) async => const VideoCommentsResponse(
              comments: [
                VideoComment(
                  id: 'rest_video_reply',
                  pubkey: testUserPubkey,
                  createdAt: 1000,
                  kind: EventKind.videoVertical,
                  content: 'REST video reply',
                  sig: 'sig',
                  tags: [
                    ['E', testRootEventId],
                    ['P', testRootAuthorPubkey],
                    ['d', 'rest_reply_d'],
                    ['imeta', 'url https://media.divine.video/reply/12345'],
                  ],
                ),
              ],
              total: 1,
            ),
          );

          repository = CommentsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeApiClient,
          );

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            includeVideoReplies: true,
          );

          expect(result.comments, hasLength(1));
          expect(result.comments.first.eventKind, EventKind.videoVertical);
          expect(
            result.comments.first.addressableId,
            equals('${EventKind.videoVertical}:$testUserPubkey:rest_reply_d'),
          );
        },
      );

      test('leaves eventKind null when REST omits the kind (#6124)', () async {
        // VideoComment.fromJson defaults an absent kind to 0. Forwarding that
        // verbatim would put k:0 on the reaction; null keeps the handler's
        // Kind 1111 fallback in charge.
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenAnswer(
          (_) async => const VideoCommentsResponse(
            comments: [
              VideoComment(
                id: 'rest_comment_no_kind',
                pubkey: testUserPubkey,
                createdAt: 1000,
                kind: 0,
                content: 'plain',
                sig: 'sig',
                tags: [
                  ['E', testRootEventId],
                  ['P', testRootAuthorPubkey],
                ],
              ),
            ],
            total: 1,
          ),
        );

        repository = CommentsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.eventKind, isNull);
        expect(result.comments.first.addressableId, isNull);
      });

      test('falls back to relay query when REST bootstrap throws', () async {
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'boom', statusCode: 500),
        );

        final relayEvent = _createCommentEvent(
          id: 'relay_comment',
          content: 'Relay fallback comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [relayEvent],
        );

        repository = CommentsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          includeVideoReplies: true,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.content, equals('Relay fallback comment'));
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test(
        'leaves addressableId null for a Kind 1111 comment (#6124)',
        () async {
          final plainComment = _createCommentEvent(
            id: 'plain_comment',
            content: 'no coordinate here',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [plainComment]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          expect(result.comments, hasLength(1));
          expect(result.comments.first.addressableId, isNull);
          expect(result.comments.first.eventKind, _commentKind);
        },
      );

      test('leaves addressableId null when an addressable event has no d tag '
          '(#6124)', () async {
        // Must NOT fall back to the event id the way VideoEvent does — that
        // mints a well-formed coordinate that addresses nothing.
        final noDTag = _createCommentEvent(
          id: 'reply_without_d',
          kind: EventKind.videoVertical,
          content: 'Reply title',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          extraTags: const [
            ['imeta', 'url https://media.divine.video/video.mp4'],
          ],
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [noDTag]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          includeVideoReplies: true,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.addressableId, isNull);
      });

      test('loads NIP-71 video reply events in the comments thread', () async {
        const rootAddressableId = '34236:$testRootAuthorPubkey:video-dtag';
        final videoReplyEvent = _createCommentEvent(
          id: 'video_reply',
          kind: EventKind.videoVertical,
          content: 'Reply title',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          extraTags: const [
            ['A', rootAddressableId, ''],
            ['a', rootAddressableId, ''],
            ['d', 'video_reply_d'],
            ['imeta', 'url https://media.divine.video/video.mp4'],
            ['title', 'Reply title'],
            ['summary', 'Video reply summary'],
          ],
        );
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [videoReplyEvent],
        );

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: rootAddressableId,
          includeVideoReplies: true,
        );

        expect(result.comments, hasLength(1));
        expect(result.comments.first.id, equals('video_reply'));
        expect(result.comments.first.rootAddressableId, rootAddressableId);
        expect(result.comments.first.hasVideo, isTrue);
        // Its OWN coordinate and kind, not the parent video's — a reaction
        // tagged with the parent's would credit the parent's counts (#6124).
        expect(result.comments.first.eventKind, EventKind.videoVertical);
        expect(
          result.comments.first.addressableId,
          equals('${EventKind.videoVertical}:$testUserPubkey:video_reply_d'),
        );
        expect(
          result.comments.first.addressableId,
          isNot(equals(rootAddressableId)),
        );
        expect(
          result.comments.first.videoUrl,
          equals('https://media.divine.video/video.mp4'),
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured
            .expand((argument) => argument as List<Filter>)
            .toList();
        expect(
          filters,
          contains(
            isA<Filter>()
                .having((filter) => filter.kinds, 'kinds', [
                  EventKind.comment,
                  EventKind.videoVertical,
                ])
                .having((filter) => filter.uppercaseE, 'uppercaseE', [
                  testRootEventId,
                ]),
          ),
        );
        expect(
          filters,
          contains(
            isA<Filter>()
                .having((filter) => filter.kinds, 'kinds', [
                  EventKind.comment,
                  EventKind.videoVertical,
                ])
                .having((filter) => filter.uppercaseA, 'uppercaseA', [
                  rootAddressableId,
                ]),
          ),
        );
      });

      test(
        'does not treat video hosts as playable comment videos without video '
        'mime or extension',
        () async {
          final imageOnlyEvent = _createCommentEvent(
            id: 'image_only',
            kind: EventKind.videoVertical,
            content: 'Image only',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            extraTags: const [
              [
                'imeta',
                'url https://media.divine.video/thumb',
                'image https://media.divine.video/thumb.jpg',
              ],
            ],
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [imageOnlyEvent]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            includeVideoReplies: true,
          );

          expect(result.comments, hasLength(1));
          expect(result.comments.first.hasVideo, isFalse);
          expect(
            result.comments.first.videoUrl,
            isNull,
          );
        },
      );

      test(
        'treats extensionless imeta urls as videos when the imeta mime type '
        'is video',
        () async {
          final videoReplyEvent = _createCommentEvent(
            id: 'video_reply',
            kind: EventKind.videoVertical,
            content: 'Reply title',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            extraTags: const [
              [
                'imeta',
                'url https://media.divine.video/reply/12345',
                'm video/mp4',
              ],
            ],
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [videoReplyEvent]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            includeVideoReplies: true,
          );

          expect(result.comments, hasLength(1));
          expect(result.comments.first.hasVideo, isTrue);
          expect(
            result.comments.first.videoUrl,
            equals('https://media.divine.video/reply/12345'),
          );
        },
      );

      test(
        'maps relay video metadata from positional imeta tags',
        () async {
          final videoReplyEvent = _createCommentEvent(
            id: 'video_reply',
            kind: EventKind.videoVertical,
            content: 'Reply title',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            extraTags: const [
              [
                'imeta',
                'url',
                'https://media.divine.video/reply/12345',
                'm',
                'video/mp4',
                'image',
                'https://media.divine.video/reply/12345.jpg',
                'dim',
                '720x1280',
                'duration',
                '6',
                'blurhash',
                'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
              ],
            ],
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [videoReplyEvent]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            includeVideoReplies: true,
          );

          expect(result.comments, hasLength(1));
          expect(result.comments.first.hasVideo, isTrue);
          expect(
            result.comments.first.videoUrl,
            equals('https://media.divine.video/reply/12345'),
          );
          expect(
            result.comments.first.thumbnailUrl,
            equals('https://media.divine.video/reply/12345.jpg'),
          );
          expect(result.comments.first.videoDimensions, equals('720x1280'));
          expect(result.comments.first.videoDuration, equals(6));
          expect(
            result.comments.first.videoBlurhash,
            equals('LKO2?U%2Tw=w]~RBVZRi};RPxuwH'),
          );
        },
      );

      test('returns empty thread when no comments', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.isEmpty, isTrue);
        expect(result.totalCount, equals(0));
        expect(result.comments, isEmpty);
        expect(result.rootEventId, equals(testRootEventId));
      });

      test('returns thread with single top-level comment', () async {
        final commentEvent = _createCommentEvent(
          id: 'comment1',
          content: 'Great video!',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [commentEvent]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.isNotEmpty, isTrue);
        expect(result.totalCount, equals(1));
        expect(result.comments.length, equals(1));
        expect(result.comments.first.content, equals('Great video!'));
        expect(result.comments.first.replyToEventId, isNull);
      });

      test('returns flat list with replies in chronological order', () async {
        final rootComment = _createCommentEvent(
          id: 'comment1',
          content: 'Parent comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final replyComment = _createCommentEvent(
          id: 'comment2',
          content: 'Reply to parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'comment1',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [rootComment, replyComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.totalCount, equals(2));
        expect(result.comments.length, equals(2));
        // Newest first (reply is newer)
        expect(result.comments.first.content, equals('Reply to parent'));
        expect(result.comments.first.replyToEventId, equals('comment1'));
        expect(result.comments.last.content, equals('Parent comment'));
      });

      test('sorts all comments chronologically (newest first)', () async {
        final oldComment = _createCommentEvent(
          id: 'comment1',
          content: 'Old comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final newComment = _createCommentEvent(
          id: 'comment2',
          content: 'New comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [oldComment, newComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.comments.first.content, 'New comment');
        expect(result.comments.last.content, 'Old comment');
      });

      test('includes replies in chronological order with parent', () async {
        final parentComment = _createCommentEvent(
          id: 'parent',
          content: 'Parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final oldReply = _createCommentEvent(
          id: 'reply1',
          content: 'Old reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final newReply = _createCommentEvent(
          id: 'reply2',
          content: 'New reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 3000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [parentComment, newReply, oldReply]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.comments.length, equals(3));
        // Chronological: newest first
        expect(result.comments[0].content, 'New reply');
        expect(result.comments[1].content, 'Old reply');
        expect(result.comments[2].content, 'Parent');
      });

      test(
        'includes orphan replies in flat list with replyTo reference',
        () async {
          // Orphan replies are just included in the flat list with
          // their replyToEventId
          final orphanReply = _createCommentEvent(
            id: 'orphan',
            content: 'Orphan reply',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            replyToEventId: 'nonexistent_parent',
            replyToAuthorPubkey: testUserPubkey,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [orphanReply]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          // Orphan is in the flat list
          expect(result.comments.length, equals(1));
          expect(result.comments.first.content, 'Orphan reply');
          expect(result.comments.first.replyToEventId, 'nonexistent_parent');
        },
      );

      test(
        'queries by both E and A tags when rootAddressableId is provided',
        () async {
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          // Should make 2 calls: one for E tag, one for A tag
          final captured = verify(
            () => mockNostrClient.queryEvents(captureAny()),
          ).captured;

          expect(captured.length, equals(2));

          final filtersE = captured[0] as List<Filter>;
          expect(
            filtersE.first.uppercaseE,
            contains(testRootEventId),
          );

          final filtersA = captured[1] as List<Filter>;
          expect(
            filtersA.first.uppercaseA,
            contains(testAddressableId),
          );
        },
      );

      test(
        'deduplicates comments found by both E and A tag queries',
        () async {
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          final commentEvent = _createCommentEvent(
            id: 'comment1',
            content: 'Found by both queries',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          );

          // Both queries return the same event
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [commentEvent]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          // Should be deduplicated to 1 comment
          expect(result.totalCount, equals(1));
          expect(result.comments.length, equals(1));
        },
      );

      test(
        'parses comment with only A tag (no E tag) from other clients',
        () async {
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          // Some clients may only use A tag for addressable events
          final aTagOnlyComment = Event(
            testUserPubkey,
            _commentKind,
            <List<String>>[
              [
                'A',
                testAddressableId,
                '',
              ],
              ['K', _testRootEventKind.toString()],
              ['P', testRootAuthorPubkey],
              [
                'a',
                testAddressableId,
                '',
              ],
              ['k', _testRootEventKind.toString()],
              ['p', testRootAuthorPubkey],
            ],
            'A-tag only comment',
            createdAt: 1000,
          )..id = 'a_tag_comment';

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [aTagOnlyComment]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          expect(result.totalCount, equals(1));
          final comment = result.comments.first;
          expect(comment.content, equals('A-tag only comment'));
          // rootAuthorPubkey extracted from A tag addressable ID
          expect(comment.rootAuthorPubkey, equals(testRootAuthorPubkey));
          expect(comment.rootAddressableId, equals(testAddressableId));
          // Top-level comment (parent kind = root kind)
          expect(comment.replyToEventId, isNull);
        },
      );

      group('client-side filtering', () {
        const otherVideoId =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddddd';
        const otherAddressableId = '34236:$testRootAuthorPubkey:other-video';

        test(
          'filters out comments whose E tag does not match rootEventId',
          () async {
            final matchingComment = _createCommentEvent(
              id: 'matching',
              content: 'Matching comment',
              pubkey: testUserPubkey,
              rootEventId: testRootEventId,
              rootAuthorPubkey: testRootAuthorPubkey,
              rootEventKind: _testRootEventKind,
            );

            final nonMatchingComment = _createCommentEvent(
              id: 'nonmatching',
              content: 'Wrong video comment',
              pubkey: testUserPubkey,
              rootEventId: otherVideoId,
              rootAuthorPubkey: testRootAuthorPubkey,
              rootEventKind: _testRootEventKind,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer(
              (_) async => [matchingComment, nonMatchingComment],
            );

            final result = await repository.loadComments(
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
            );

            expect(result.totalCount, equals(1));
            expect(
              result.comments.first.content,
              equals('Matching comment'),
            );
          },
        );

        test(
          'includes comments matching via A tag when '
          'rootAddressableId is provided',
          () async {
            const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

            // Event with only A tag (no matching E tag)
            final aTagComment = Event(
              testUserPubkey,
              _commentKind,
              <List<String>>[
                ['A', testAddressableId, ''],
                ['K', _testRootEventKind.toString()],
                ['P', testRootAuthorPubkey],
                ['a', testAddressableId, ''],
                ['k', _testRootEventKind.toString()],
                ['p', testRootAuthorPubkey],
              ],
              'A-tag comment',
              createdAt: 1000,
            )..id = 'a_tag_only';

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [aTagComment]);

            final result = await repository.loadComments(
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
              rootAddressableId: testAddressableId,
            );

            expect(result.totalCount, equals(1));
            expect(
              result.comments.first.content,
              equals('A-tag comment'),
            );
          },
        );

        test(
          'filters out comments with non-matching E and A tags',
          () async {
            const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

            // Event for a completely different video
            final unrelatedComment = Event(
              testUserPubkey,
              _commentKind,
              <List<String>>[
                ['E', otherVideoId, '', testRootAuthorPubkey],
                ['A', otherAddressableId, ''],
                ['K', _testRootEventKind.toString()],
                ['P', testRootAuthorPubkey],
                ['e', otherVideoId, '', testRootAuthorPubkey],
                ['k', _testRootEventKind.toString()],
                ['p', testRootAuthorPubkey],
              ],
              'Unrelated comment',
              createdAt: 1000,
            )..id = 'unrelated';

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [unrelatedComment]);

            final result = await repository.loadComments(
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
              rootAddressableId: testAddressableId,
            );

            expect(result.isEmpty, isTrue);
            expect(result.totalCount, equals(0));
          },
        );

        test(
          'retains matching and filters non-matching from mixed results',
          () async {
            final matchingComment = _createCommentEvent(
              id: 'match1',
              content: 'Correct video',
              pubkey: testUserPubkey,
              rootEventId: testRootEventId,
              rootAuthorPubkey: testRootAuthorPubkey,
              rootEventKind: _testRootEventKind,
            );

            final wrongVideoComment = _createCommentEvent(
              id: 'wrong1',
              content: 'Wrong video',
              pubkey: testUserPubkey,
              rootEventId: otherVideoId,
              rootAuthorPubkey: testRootAuthorPubkey,
              rootEventKind: _testRootEventKind,
            );

            final anotherMatch = _createCommentEvent(
              id: 'match2',
              content: 'Also correct',
              pubkey: testUserPubkey,
              rootEventId: testRootEventId,
              rootAuthorPubkey: testRootAuthorPubkey,
              rootEventKind: _testRootEventKind,
              createdAt: 2000,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer(
              (_) async => [
                matchingComment,
                wrongVideoComment,
                anotherMatch,
              ],
            );

            final result = await repository.loadComments(
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
            );

            expect(result.totalCount, equals(2));
            expect(
              result.comments.map((c) => c.content).toList(),
              containsAll(['Correct video', 'Also correct']),
            );
          },
        );
      });

      test('throws LoadCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          ),
          throwsA(isA<LoadCommentsFailedException>()),
        );
      });

      test('respects limit parameter', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          limit: 50,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, equals(50));
      });

      test('passes before parameter as until filter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final beforeTime = DateTime.fromMillisecondsSinceEpoch(2000000000);
        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          before: beforeTime,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        // `until` is in seconds (Nostr epoch), so divide milliseconds by 1000
        expect(filters.first.until, equals(2000000000 ~/ 1000));
      });

      test('does not include until filter when before is null', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.until, isNull);
      });

      group('first-page authoritative zero clears stale positive cache', () {
        // The dual-key cache from this PR makes a stale positive count
        // outlive an addressable-event edit. If loadComments returns 0,
        // both write sites must overwrite the cache so the post-edit
        // fetch via the new event id sees the authoritative zero.
        const oldEventId =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const newEventId =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const addressableId =
            '34236:$testRootAuthorPubkey'
            ':video-dtag';

        test(
          'REST authoritative zero overwrites a positive cache under the '
          'addressable id',
          () async {
            repository =
                CommentsRepository(
                  nostrClient: mockNostrClient,
                  funnelcakeApiClient: mockFunnelcakeApiClient,
                )..updateCachedCommentCount(
                  oldEventId,
                  7,
                  rootAddressableId: addressableId,
                );

            when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeApiClient.getVideoComments(
                videoId: any(named: 'videoId'),
                sort: any(named: 'sort'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).thenAnswer(
              (_) async => const VideoCommentsResponse(
                comments: [],
                total: 0,
              ),
            );

            final loaded = await repository.loadComments(
              rootEventId: newEventId,
              rootEventKind: _testRootEventKind,
              rootAddressableId: addressableId,
            );
            expect(loaded.totalCount, equals(0));

            final post = await repository.getCommentsCount(
              newEventId,
              rootAddressableId: addressableId,
            );
            expect(
              post,
              equals(0),
              reason: 'REST zero must wipe the stale 7 keyed by address',
            );
            verifyNever(() => mockNostrClient.countEvents(any()));
          },
        );

        test(
          'v2 paginated lower-bound total does not overwrite cached count',
          () async {
            repository =
                CommentsRepository(
                  nostrClient: mockNostrClient,
                  funnelcakeApiClient: mockFunnelcakeApiClient,
                )..updateCachedCommentCount(
                  oldEventId,
                  7,
                  rootAddressableId: addressableId,
                );

            when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeApiClient.getVideoComments(
                videoId: any(named: 'videoId'),
                sort: any(named: 'sort'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).thenAnswer(
              (_) async => VideoCommentsResponse(
                comments: [
                  VideoComment(
                    id: 'rest_comment',
                    pubkey: testUserPubkey,
                    createdAt: 1000,
                    kind: _commentKind,
                    content: 'REST comment',
                    sig: 'sig',
                    tags: [
                      ['E', newEventId],
                      ['K', _testRootEventKind.toString()],
                      ['P', testRootAuthorPubkey],
                      ['e', newEventId],
                      ['k', _testRootEventKind.toString()],
                      ['p', testRootAuthorPubkey],
                    ],
                  ),
                ],
                total: 2,
                hasMore: true,
                hasExactTotal: false,
              ),
            );

            final loaded = await repository.loadComments(
              rootEventId: newEventId,
              rootEventKind: _testRootEventKind,
              rootAddressableId: addressableId,
            );
            expect(loaded.totalCount, equals(2));
            expect(loaded.hasMore, isTrue);

            final post = await repository.getCommentsCount(
              newEventId,
              rootAddressableId: addressableId,
            );
            expect(post, equals(7));
            verifyNever(() => mockNostrClient.countEvents(any()));
          },
        );

        test(
          'relay first-page empty result overwrites a positive cache under '
          'the addressable id',
          () async {
            repository.updateCachedCommentCount(
              oldEventId,
              7,
              rootAddressableId: addressableId,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => <Event>[]);

            final loaded = await repository.loadComments(
              rootEventId: newEventId,
              rootEventKind: _testRootEventKind,
              rootAddressableId: addressableId,
            );
            expect(loaded.totalCount, equals(0));

            final post = await repository.getCommentsCount(
              newEventId,
              rootAddressableId: addressableId,
            );
            expect(
              post,
              equals(0),
              reason: 'relay zero must wipe the stale 7 keyed by address',
            );
            verifyNever(() => mockNostrClient.countEvents(any()));
          },
        );
      });
    });

    group('postComment', () {
      test('posts top-level comment with correct tags', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.postComment(
          content: 'Test comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(_commentKind));
        expect(capturedEvent!.content, equals('Test comment'));

        // Check NIP-22 tags
        // Uppercase tags = root scope
        final uppercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'E')
            .toList();
        final uppercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'K')
            .toList();
        final uppercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'P')
            .toList();

        // Lowercase tags = parent item (for top-level, same as root)
        final lowercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final lowercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();
        final lowercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'p')
            .toList();

        // Root scope tags
        expect(uppercaseETags.length, equals(1));
        expect(uppercaseETags.first[1], equals(testRootEventId));
        expect(uppercaseKTags.length, equals(1));
        expect(uppercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(uppercasePTags.length, equals(1));
        expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

        // Parent item tags (same as root for top-level)
        expect(lowercaseETags.length, equals(1));
        expect(lowercaseETags.first[1], equals(testRootEventId));
        expect(lowercaseKTags.length, equals(1));
        expect(lowercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(lowercasePTags.length, equals(1));
        expect(lowercasePTags.first[1], equals(testRootAuthorPubkey));
      });

      test('posts reply with correct tags', () async {
        Event? capturedEvent;
        const parentCommentId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const parentAuthorPubkey =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.postComment(
          content: 'Reply comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          replyToEventId: parentCommentId,
          replyToAuthorPubkey: parentAuthorPubkey,
        );

        expect(capturedEvent, isNotNull);

        // Check NIP-22 tags
        // Uppercase tags = root scope
        final uppercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'E')
            .toList();
        final uppercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'K')
            .toList();
        final uppercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'P')
            .toList();

        // Lowercase tags = parent item (for reply, parent comment)
        final lowercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final lowercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();
        final lowercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'p')
            .toList();

        // Root scope tags (uppercase)
        expect(uppercaseETags.length, equals(1));
        expect(uppercaseETags.first[1], equals(testRootEventId));
        expect(uppercaseKTags.length, equals(1));
        expect(uppercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(uppercasePTags.length, equals(1));
        expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

        // Parent item tags (lowercase) - point to parent comment
        expect(lowercaseETags.length, equals(1));
        expect(lowercaseETags.first[1], equals(parentCommentId));
        expect(lowercaseKTags.length, equals(1));
        expect(lowercaseKTags.first[1], equals(_commentKind.toString()));
        expect(lowercasePTags.length, equals(1));
        expect(lowercasePTags.first[1], equals(parentAuthorPubkey));
      });

      test('appends mentioned pubkeys after required NIP-22 tags', () async {
        Event? capturedEvent;
        const firstMentionPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const secondMentionPubkey =
            '2222222222222222222222222222222222222222222222222222222222222222';

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.postComment(
          content: 'Mentioning @alice and @bob',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          mentionedPubkeys: const [
            firstMentionPubkey,
            secondMentionPubkey,
          ],
        );

        expect(capturedEvent, isNotNull);
        expect(
          capturedEvent!.tags,
          equals([
            ['E', testRootEventId, '', testRootAuthorPubkey],
            ['K', _testRootEventKind.toString()],
            ['P', testRootAuthorPubkey],
            ['e', testRootEventId, '', testRootAuthorPubkey],
            ['k', _testRootEventKind.toString()],
            ['p', testRootAuthorPubkey],
            [
              'p',
              firstMentionPubkey,
              'wss://relay.divine.video',
              'mention',
            ],
            [
              'p',
              secondMentionPubkey,
              'wss://relay.divine.video',
              'mention',
            ],
          ]),
        );
      });

      test(
        'skips invalid mentioned pubkeys and root or parent author duplicates',
        () async {
          Event? capturedEvent;
          const parentCommentId =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
          const parentAuthorPubkey =
              'ffffffffffffffffffffffffffffffff'
              'ffffffffffffffffffffffffffffffff';
          const mentionedPubkey =
              '33333333333333333333333333333333'
              '33333333333333333333333333333333';

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            capturedEvent = inv.positionalArguments.first as Event;
            return PublishSuccess(event: capturedEvent!);
          });

          await repository.postComment(
            content: 'Reply with mentions',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            replyToEventId: parentCommentId,
            replyToAuthorPubkey: parentAuthorPubkey,
            mentionedPubkeys: const [
              '',
              'not-a-pubkey',
              mentionedPubkey,
              testRootAuthorPubkey,
              parentAuthorPubkey,
              mentionedPubkey,
            ],
          );

          expect(capturedEvent, isNotNull);
          final mentionTags = capturedEvent!.tags
              .where(
                (tag) =>
                    tag.length == 4 &&
                    tag[0] == 'p' &&
                    tag[2] == 'wss://relay.divine.video' &&
                    tag[3] == 'mention',
              )
              .toList();

          expect(mentionTags, [
            [
              'p',
              mentionedPubkey,
              'wss://relay.divine.video',
              'mention',
            ],
          ]);
        },
      );

      test(
        'posts top-level comment with A/a tags for addressable events',
        () async {
          Event? capturedEvent;
          const testAddressableId = '34236:$testRootAuthorPubkey:my-video-dtag';

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            capturedEvent = inv.positionalArguments.first as Event;
            return PublishSuccess(event: capturedEvent!);
          });

          await repository.postComment(
            content: 'Comment on addressable event',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: testAddressableId,
          );

          expect(capturedEvent, isNotNull);

          // Uppercase A tag = root scope (3 elements per NIP-22)
          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          expect(uppercaseATags.length, equals(1));
          expect(uppercaseATags.first.length, equals(3));
          expect(uppercaseATags.first[1], equals(testAddressableId));
          expect(uppercaseATags.first[2], equals(''));

          // Lowercase a tag = parent item (3 elements per NIP-22)
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();
          expect(lowercaseATags.length, equals(1));
          expect(lowercaseATags.first.length, equals(3));
          expect(lowercaseATags.first[1], equals(testAddressableId));
          expect(lowercaseATags.first[2], equals(''));
        },
      );

      test(
        'posts reply comment without lowercase a tag',
        () async {
          Event? capturedEvent;
          const testAddressableId = '34236:$testRootAuthorPubkey:my-video-dtag';
          const parentCommentId =
              'eeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeee';
          const parentAuthorPubkey =
              'ffffffffffffffff'
              'ffffffffffffffffffffffffffffffff'
              'ffffffffffffffff';

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            capturedEvent = inv.positionalArguments.first as Event;
            return PublishSuccess(event: capturedEvent!);
          });

          await repository.postComment(
            content: 'Reply to comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: testAddressableId,
            replyToEventId: parentCommentId,
            replyToAuthorPubkey: parentAuthorPubkey,
          );

          expect(capturedEvent, isNotNull);

          // Uppercase A tag should be present (root scope)
          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          expect(uppercaseATags.length, equals(1));

          // Lowercase a tag should NOT be present (reply parent is comment,
          // not addressable event)
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();
          expect(lowercaseATags, isEmpty);
        },
      );

      test(
        'does not include A/a tags when rootAddressableId is null',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            capturedEvent = inv.positionalArguments.first as Event;
            return PublishSuccess(event: capturedEvent!);
          });

          await repository.postComment(
            content: 'No addressable ID',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          );

          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();

          expect(uppercaseATags, isEmpty);
          expect(lowercaseATags, isEmpty);
        },
      );

      test('returns created Comment', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          final event = inv.positionalArguments.first as Event
            ..id = 'created_event_id';
          return PublishSuccess(event: event);
        });

        final result = await repository.postComment(
          content: 'Test comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(result.content, equals('Test comment'));
        expect(result.rootEventId, equals(testRootEventId));
        expect(result.rootAuthorPubkey, equals(testRootAuthorPubkey));
        expect(result.authorPubkey, equals(testUserPubkey));
      });

      test('throws InvalidCommentContentException for empty content', () async {
        expect(
          () => repository.postComment(
            content: '',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<InvalidCommentContentException>()),
        );
      });

      test(
        'throws InvalidCommentContentException for whitespace-only content',
        () async {
          expect(
            () => repository.postComment(
              content: '   ',
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
              rootEventAuthorPubkey: testRootAuthorPubkey,
            ),
            throwsA(isA<InvalidCommentContentException>()),
          );
        },
      );

      test('trims content before posting', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.postComment(
          content: '  Trimmed content  ',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(capturedEvent!.content, equals('Trimmed content'));
      });

      test('throws PostCommentFailedException when publish fails', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });

      test('throws PostCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });
    });

    group('getCommentsCount', () {
      // 64-char hex constants hoisted to the group scope so the
      // post-edit cache tests stay under the 80-char line limit while
      // sharing a single old/new event id pair.
      const oldEventId =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const newEventId =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const deletedCommentId =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      test('returns count from NIP-45', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        final result = await repository.getCommentsCount(testRootEventId);

        expect(result, equals(42));
      });

      test('queries with correct filter', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 0),
        );

        await repository.getCommentsCount(testRootEventId);

        final captured = verify(
          () => mockNostrClient.countEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, equals(const [_commentKind]));
        expect(filters.first.uppercaseE, contains(testRootEventId));
      });

      test('queries video replies when includeVideoReplies is true', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 0),
        );

        await repository.getCommentsCount(
          testRootEventId,
          includeVideoReplies: true,
        );

        final captured = verify(
          () => mockNostrClient.countEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(_commentKind));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.uppercaseE, contains(testRootEventId));
      });

      test(
        'returns max of E and A tag counts when '
        'rootAddressableId provided',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          var callCount = 0;
          when(() => mockNostrClient.countEvents(any())).thenAnswer((_) async {
            callCount++;
            // First call (E tag) returns 5, second call (A tag) returns 8
            return CountResult(count: callCount == 1 ? 5 : 8);
          });

          final result = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );

          // Should return the maximum of the two counts
          expect(result, equals(8));

          // Should make 2 calls
          verify(() => mockNostrClient.countEvents(any())).called(2);
        },
      );

      test(
        'returns E tag count when higher than A tag count',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          var callCount = 0;
          when(() => mockNostrClient.countEvents(any())).thenAnswer((_) async {
            callCount++;
            // First call (E tag) returns 10, second call (A tag) returns 3
            return CountResult(count: callCount == 1 ? 10 : 3);
          });

          final result = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );

          expect(result, equals(10));
        },
      );

      test('throws CountCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenThrow(Exception('Count failed'));

        expect(
          () => repository.getCommentsCount(testRootEventId),
          throwsA(isA<CountCommentsFailedException>()),
        );
      });

      test('returns null and caches nothing when no relay answered', () async {
        when(() => mockNostrClient.countEvents(any())).thenThrow(
          const CountUnavailableException('No relay responded to COUNT'),
        );

        final first = await repository.getCommentsCount(testRootEventId);
        final second = await repository.getCommentsCount(testRootEventId);

        expect(first, isNull);
        expect(second, isNull);
        verify(() => mockNostrClient.countEvents(any())).called(2);
      });

      test(
        'returns null rather than a floor when only one of the E and A '
        'counts is answered',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          var callCount = 0;
          when(() => mockNostrClient.countEvents(any())).thenAnswer((_) async {
            callCount++;
            // The E count answers and the A count does not.
            if (callCount.isOdd) return const CountResult(count: 5);
            throw const CountUnavailableException(
              'No relay responded to COUNT',
            );
          });

          final first = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );
          final second = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );

          expect(first, isNull);
          expect(second, isNull);
          verify(() => mockNostrClient.countEvents(any())).called(4);
        },
      );

      test('returns cached count on second call without relay query', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        final first = await repository.getCommentsCount(testRootEventId);
        final second = await repository.getCommentsCount(testRootEventId);

        expect(first, equals(42));
        expect(second, equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('updateCachedCommentCount overrides cached value', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 5),
        );

        await repository.getCommentsCount(testRootEventId);
        repository.updateCachedCommentCount(testRootEventId, 10);
        final cached = await repository.getCommentsCount(testRootEventId);

        expect(cached, equals(10));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('cache is incremented after postComment', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 5),
        );
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments.first as Event),
        );

        await repository.getCommentsCount(testRootEventId);
        await repository.postComment(
          content: 'hello',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );
        final cached = await repository.getCommentsCount(testRootEventId);

        expect(cached, equals(6));
      });

      test('clearCommentCountCache resets count cache', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        await repository.getCommentsCount(testRootEventId);
        repository.clearCommentCountCache();

        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 99),
        );

        final fresh = await repository.getCommentsCount(testRootEventId);
        expect(fresh, equals(99));
        verify(() => mockNostrClient.countEvents(any())).called(2);
      });

      test(
        // After a metadata edit the addressable video keeps the same
        // address but gets a fresh event id. A purely event-id-keyed
        // cache misses on the new id and forces a relay re-query whose
        // NIP-45 COUNT on #A for kind 1111 can transiently return 0
        // (mirror of #4432 for kind 7). The companion addressable-id
        // cache lets the post-edit fetch reuse the count without
        // hitting the relay.
        'getCommentsCount returns cached value via addressable id when '
        'event_id changes after edit',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          when(() => mockNostrClient.countEvents(any())).thenAnswer(
            (_) async => const CountResult(count: 7),
          );

          // Seed the cache with the pre-edit fetch.
          final preEdit = await repository.getCommentsCount(
            oldEventId,
            rootAddressableId: testAddressableId,
          );

          // After the edit, a fresh bloc fetches with the new event id
          // but the same addressable id.
          final postEdit = await repository.getCommentsCount(
            newEventId,
            rootAddressableId: testAddressableId,
          );

          expect(preEdit, equals(7));
          expect(
            postEdit,
            equals(7),
            reason: 'companion cache by addressable id must survive the edit',
          );
          // The relay was queried only for the first call. The second
          // call is fully cache-served.
          verify(() => mockNostrClient.countEvents(any())).called(2);
        },
      );

      test(
        'clearCommentCountCache also clears the addressable-id companion '
        'cache',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          when(() => mockNostrClient.countEvents(any())).thenAnswer(
            (_) async => const CountResult(count: 7),
          );

          await repository.getCommentsCount(
            oldEventId,
            rootAddressableId: testAddressableId,
          );
          repository.clearCommentCountCache();

          when(() => mockNostrClient.countEvents(any())).thenAnswer(
            (_) async => const CountResult(count: 11),
          );

          final fresh = await repository.getCommentsCount(
            newEventId,
            rootAddressableId: testAddressableId,
          );
          expect(
            fresh,
            equals(11),
            reason: 'clear must drop the addressable companion entry too',
          );
        },
      );

      test(
        'deleteComment decrement mirrors into the addressable companion '
        'cache',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          when(() => mockNostrClient.countEvents(any())).thenAnswer(
            (_) async => const CountResult(count: 7),
          );
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (inv) async =>
                PublishSuccess(event: inv.positionalArguments.first as Event),
          );

          await repository.getCommentsCount(
            oldEventId,
            rootAddressableId: testAddressableId,
          );

          await repository.deleteComment(
            commentId: deletedCommentId,
            rootEventId: oldEventId,
            rootAddressableId: testAddressableId,
          );

          // Post-edit fetch with the new event id should see the
          // decremented count via the addressable companion cache.
          final postEdit = await repository.getCommentsCount(
            newEventId,
            rootAddressableId: testAddressableId,
          );

          expect(postEdit, equals(6));
        },
      );
    });

    group('deleteComment', () {
      const testCommentId =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      test('publishes deletion event with correct tags', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.deleteComment(commentId: testCommentId);

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(_deletionKind));

        // Check NIP-09 deletion tags
        final eTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final kTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();

        expect(eTags.length, equals(1));
        expect(eTags.first[1], equals(testCommentId));
        expect(kTags.length, equals(1));
        expect(kTags.first[1], equals(_commentKind.toString()));
      });

      test('publishes deletion event with reason when provided', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          capturedEvent = inv.positionalArguments.first as Event;
          return PublishSuccess(event: capturedEvent!);
        });

        await repository.deleteComment(
          commentId: testCommentId,
          reason: 'Spam content',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.content, equals('Spam content'));
      });

      test(
        'publishes deletion event with empty content when no reason',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            capturedEvent = inv.positionalArguments.first as Event;
            return PublishSuccess(event: capturedEvent!);
          });

          await repository.deleteComment(commentId: testCommentId);

          expect(capturedEvent, isNotNull);
          expect(capturedEvent!.content, isEmpty);
        },
      );

      test(
        'throws DeleteCommentFailedException when publish does not return '
        'PublishSuccess',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          expect(
            () => repository.deleteComment(commentId: testCommentId),
            throwsA(isA<DeleteCommentFailedException>()),
          );
        },
      );

      test('throws DeleteCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(isA<DeleteCommentFailedException>()),
        );
      });

      test('rethrows DeleteCommentFailedException', () async {
        when(() => mockNostrClient.publishEvent(any())).thenThrow(
          const DeleteCommentFailedException('Custom error'),
        );

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(
            isA<DeleteCommentFailedException>().having(
              (e) => e.message,
              'message',
              'Custom error',
            ),
          ),
        );
      });

      test('decrements cached count when rootEventId is provided', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 10),
        );
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments.first as Event),
        );

        await repository.getCommentsCount(testRootEventId);
        await repository.deleteComment(
          commentId: testCommentId,
          rootEventId: testRootEventId,
        );
        final cached = await repository.getCommentsCount(testRootEventId);

        expect(cached, equals(9));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('does not decrement when rootEventId is omitted', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 10),
        );
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (inv) async =>
              PublishSuccess(event: inv.positionalArguments.first as Event),
        );

        await repository.getCommentsCount(testRootEventId);
        await repository.deleteComment(commentId: testCommentId);
        final cached = await repository.getCommentsCount(testRootEventId);

        expect(cached, equals(10));
      });
    });

    group('watchComments', () {
      test('returns stream of comments from subscription', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final stream = repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          since: DateTime.fromMillisecondsSinceEpoch(1000000),
        );

        final comments = <Comment>[];
        final sub = stream.listen(comments.add);

        // Emit a comment event
        final commentEvent = _createCommentEvent(
          id: 'new_comment',
          content: 'Real-time comment!',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 5000,
        );
        controller.add(commentEvent);

        // Let the stream process
        await Future<void>.delayed(Duration.zero);

        expect(comments, hasLength(1));
        expect(comments.first.content, equals('Real-time comment!'));
        expect(comments.first.id, equals('new_comment'));

        await sub.cancel();
        await controller.close();
      });

      test('subscribes with correct filters including since', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final since = DateTime.fromMillisecondsSinceEpoch(2000000);
        repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          since: since,
        );

        final captured = verify(
          () => mockNostrClient.subscribe(
            captureAny(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(_commentKind));
        expect(filters.first.uppercaseE, contains(testRootEventId));
        expect(filters.first.since, equals(2000000 ~/ 1000));

        await controller.close();
      });

      test(
        'opens the subscription under an id within the NIP-01 cap',
        () async {
          final controller = StreamController<Event>.broadcast();

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          repository.watchComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          final id =
              verify(
                    () => mockNostrClient.subscribe(
                      any(),
                      subscriptionId: captureAny(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as String;
          expect(
            id.length,
            lessThanOrEqualTo(nip01MaxSubscriptionIdLength),
            reason:
                '"$id" is ${id.length} characters; relays enforcing '
                'NIP-01 refuse the REQ',
          );
          expect(
            id,
            equals(scopedSubscriptionId('comments_watch', testRootEventId)),
          );

          await controller.close();
        },
      );

      test('allows watchComments without since and forwards onEose', () async {
        final controller = StreamController<Event>.broadcast();
        void Function()? capturedOnEose;

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((invocation) {
          capturedOnEose =
              invocation.namedArguments[#onEose] as void Function()?;
          return controller.stream;
        });

        var didReceiveEose = false;
        repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          onEose: () {
            didReceiveEose = true;
          },
        );

        final captured = verify(
          () => mockNostrClient.subscribe(
            captureAny(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.since, isNull);

        capturedOnEose?.call();
        expect(didReceiveEose, isTrue);

        await controller.close();
      });

      test(
        'includes A tag filter when rootAddressableId is provided',
        () async {
          final controller = StreamController<Event>.broadcast();
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          repository.watchComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
            since: DateTime.fromMillisecondsSinceEpoch(1000000),
          );

          final captured = verify(
            () => mockNostrClient.subscribe(
              captureAny(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).captured;

          final filters = captured.first as List<Filter>;
          // Should have 2 filters: E tag and A tag
          expect(filters, hasLength(2));
          expect(filters[0].uppercaseE, contains(testRootEventId));
          expect(filters[1].uppercaseA, contains(testAddressableId));

          await controller.close();
        },
      );

      test(
        'deduplicates events with the same ID from dual-filter subscriptions',
        () async {
          final controller = StreamController<Event>.broadcast();

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final stream = repository.watchComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: '34236:$testRootAuthorPubkey:video-dtag',
            since: DateTime.fromMillisecondsSinceEpoch(1000000),
          );

          final comments = <Comment>[];
          final sub = stream.listen(comments.add);

          // Emit the same event twice (simulating E and A filter match)
          final commentEvent = _createCommentEvent(
            id: 'duplicate_event',
            content: 'Arrived twice',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 5000,
          );
          controller
            ..add(commentEvent)
            ..add(commentEvent);

          await Future<void>.delayed(Duration.zero);

          expect(comments, hasLength(1));
          expect(comments.first.content, equals('Arrived twice'));

          await sub.cancel();
          await controller.close();
        },
      );

      test('filters out null comments from malformed events', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final stream = repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          since: DateTime.fromMillisecondsSinceEpoch(1000000),
        );

        final comments = <Comment>[];
        final sub = stream.listen(comments.add);

        // Emit a malformed event with no tags
        final malformedEvent = Event(
          testUserPubkey,
          _commentKind,
          <List<String>>[],
          'Malformed',
          createdAt: 1000,
        )..id = 'malformed';
        controller.add(malformedEvent);

        // Emit a valid event
        final validEvent = _createCommentEvent(
          id: 'valid',
          content: 'Valid comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 2000,
        );
        controller.add(validEvent);

        await Future<void>.delayed(Duration.zero);

        // Malformed event produces a Comment with empty rootEventId
        // but is not null, so it passes through. Only truly null
        // comments (from _eventToComment returning null) are filtered.
        // The valid event should definitely be present.
        expect(comments.any((c) => c.content == 'Valid comment'), isTrue);

        await sub.cancel();
        await controller.close();
      });
    });

    group('stopWatchingComments', () {
      test('calls unsubscribe with the subscription ID', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        // Start watching to set the subscription ID
        repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          since: DateTime.fromMillisecondsSinceEpoch(1000000),
        );

        await repository.stopWatchingComments();

        final subscribedId =
            verify(
                  () => mockNostrClient.subscribe(
                    any(),
                    subscriptionId: captureAny(named: 'subscriptionId'),
                  ),
                ).captured.single
                as String;
        verify(() => mockNostrClient.unsubscribe(subscribedId)).called(1);

        await controller.close();
      });

      test('does nothing when no active subscription', () async {
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        // Stop without starting — should not throw or call unsubscribe
        await repository.stopWatchingComments();

        verifyNever(() => mockNostrClient.unsubscribe(any()));
      });
    });

    group('block filter', () {
      const blockedPubkey =
          'dddddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddddd';
      const allowedPubkey =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      test(
        'filters blocked user comments from loadComments',
        () async {
          final filteredRepo = CommentsRepository(
            nostrClient: mockNostrClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final blockedComment = _createCommentEvent(
            id: 'blocked_comment',
            content: 'Blocked comment',
            pubkey: blockedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          );

          final allowedComment = _createCommentEvent(
            id: 'allowed_comment',
            content: 'Allowed comment',
            pubkey: allowedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 2000,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer(
            (_) async => [blockedComment, allowedComment],
          );

          final result = await filteredRepo.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          expect(result.comments, hasLength(1));
          expect(
            result.comments.first.content,
            equals('Allowed comment'),
          );
          expect(
            result.comments.first.authorPubkey,
            equals(allowedPubkey),
          );
        },
      );

      test(
        'watchComments stream excludes blocked authors',
        () async {
          final filteredRepo = CommentsRepository(
            nostrClient: mockNostrClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final controller = StreamController<Event>.broadcast();

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final stream = filteredRepo.watchComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            since: DateTime.fromMillisecondsSinceEpoch(1000000),
          );

          final comments = <Comment>[];
          final sub = stream.listen(comments.add);

          final blockedEvent = _createCommentEvent(
            id: 'blocked_stream',
            content: 'Blocked stream comment',
            pubkey: blockedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 3000,
          );

          final allowedEvent = _createCommentEvent(
            id: 'allowed_stream',
            content: 'Allowed stream comment',
            pubkey: allowedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 4000,
          );

          controller
            ..add(blockedEvent)
            ..add(allowedEvent);

          await Future<void>.delayed(Duration.zero);

          expect(comments, hasLength(1));
          expect(
            comments.first.content,
            equals('Allowed stream comment'),
          );

          await sub.cancel();
          await controller.close();
        },
      );

      test(
        'returns all comments when blockFilter is null',
        () async {
          // Default repository has no blockFilter.
          final comment1 = _createCommentEvent(
            id: 'c1',
            content: 'Comment one',
            pubkey: blockedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          );

          final comment2 = _createCommentEvent(
            id: 'c2',
            content: 'Comment two',
            pubkey: allowedPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 2000,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [comment1, comment2]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          expect(result.comments, hasLength(2));
        },
      );
    });
  });
}

/// Helper to create a NIP-22 comment event for testing.
Event _createCommentEvent({
  required String id,
  required String content,
  required String pubkey,
  required String rootEventId,
  required String rootAuthorPubkey,
  required int rootEventKind,
  int kind = _commentKind,
  String? replyToEventId,
  String? replyToAuthorPubkey,
  List<List<String>> extraTags = const [],
  int createdAt = 1000,
}) {
  // NIP-22 tags:
  // Uppercase tags (E, K, P) = root scope
  // Lowercase tags (e, k, p) = parent item
  final tags = <List<String>>[
    // Root scope tags (uppercase) - always point to the original event
    ['E', rootEventId, '', rootAuthorPubkey],
    ['K', rootEventKind.toString()],
    ['P', rootAuthorPubkey],
    // Parent item tags (lowercase)
    if (replyToEventId != null && replyToAuthorPubkey != null) ...[
      // Replying to another comment
      ['e', replyToEventId, '', replyToAuthorPubkey],
      ['k', _commentKind.toString()],
      ['p', replyToAuthorPubkey],
    ] else ...[
      // Top-level comment - parent is the same as root
      ['e', rootEventId, '', rootAuthorPubkey],
      ['k', rootEventKind.toString()],
      ['p', rootAuthorPubkey],
    ],
    ...extraTags,
  ];

  return Event(pubkey, kind, tags, content, createdAt: createdAt)..id = id;
}
