import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _FakeEvent extends Fake implements Event {}

const int _commentKind = EventKind.comment;
const int _videoKind = EventKind.videoVertical;

void main() {
  group('CommentsRepository.loadComments, REST paging', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcake;
    late CommentsRepository repository;

    const currentId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const supersededId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const authorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const viewerPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const coordinate = '$_videoKind:$authorPubkey:edited-video';
    final cursor = DateTime.fromMillisecondsSinceEpoch(5000 * 1000);

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      when(() => nostrClient.publicKey).thenReturn(viewerPubkey);
      when(() => funnelcake.isAvailable).thenReturn(true);
      when(
        () => nostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      repository = CommentsRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcake,
      );
    });

    List<List<String>> commentTags(String rootEventId) => [
      ['E', rootEventId, '', authorPubkey],
      ['K', '$_videoKind'],
      ['P', authorPubkey],
      ['e', rootEventId, '', authorPubkey],
      ['k', '$_videoKind'],
      ['p', authorPubkey],
    ];

    VideoComment restComment(
      String id, {
      required String rootEventId,
      required int createdAt,
    }) => VideoComment(
      id: id,
      pubkey: viewerPubkey,
      createdAt: createdAt,
      kind: _commentKind,
      content: 'comment $id',
      sig: 'sig',
      tags: commentTags(rootEventId),
    );

    void stubRestPage(int offset, List<VideoComment> comments) {
      when(
        () => funnelcake.getVideoComments(
          videoId: any(named: 'videoId'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: offset,
          cacheBustToken: any(named: 'cacheBustToken'),
        ),
      ).thenAnswer(
        (_) async => VideoCommentsResponse(
          comments: comments,
          total: offset + comments.length,
          hasMore: false,
        ),
      );
    }

    void verifyRestAsked(int offset) => verify(
      () => funnelcake.getVideoComments(
        videoId: currentId,
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        offset: offset,
        cacheBustToken: any(named: 'cacheBustToken'),
      ),
    ).called(1);

    group('first page, served by REST', () {
      test('reports where the next REST page starts, counting comments the '
          'block filter hides', () async {
        const blockedPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        repository = CommentsRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcake,
          blockFilter: (pubkey, {rootAuthorPubkey}) => pubkey == blockedPubkey,
        );
        stubRestPage(0, [
          restComment('first', rootEventId: currentId, createdAt: 3000),
          VideoComment(
            id: 'hidden',
            pubkey: blockedPubkey,
            createdAt: 2000,
            kind: _commentKind,
            content: 'blocked author',
            sig: 'sig',
            tags: commentTags(currentId),
          ),
          restComment('last', rootEventId: currentId, createdAt: 1000),
        ]);

        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
        );

        expect(thread.comments.map((c) => c.id), ['first', 'last']);
        expect(thread.nextOffset, 3);
      });
    });

    group('with a REST offset and a cursor', () {
      test('reports the position after the page REST served', () async {
        stubRestPage(50, [
          restComment('on_current', rootEventId: currentId, createdAt: 2000),
          restComment(
            'on_superseded',
            rootEventId: supersededId,
            createdAt: 1000,
          ),
        ]);

        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
          offset: 50,
        );

        expect(thread.nextOffset, 52);
      });

      test('asks REST for that page and returns what REST lists, including a '
          'comment scoped to a superseded revision', () async {
        stubRestPage(50, [
          restComment('on_current', rootEventId: currentId, createdAt: 2000),
          restComment(
            'on_superseded',
            rootEventId: supersededId,
            createdAt: 1000,
          ),
        ]);

        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
          offset: 50,
        );

        expect(thread.comments.map((c) => c.id), [
          'on_current',
          'on_superseded',
        ]);
        verifyRestAsked(50);
        verifyNever(() => nostrClient.queryEvents(any()));
      });

      test('leaves the cached comment count alone', () async {
        repository.updateCachedCommentCount(
          currentId,
          8,
          rootAddressableId: coordinate,
        );
        stubRestPage(50, [
          restComment('older', rootEventId: currentId, createdAt: 1000),
        ]);

        await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
          offset: 50,
        );

        final cached = await repository.getCommentsCount(
          currentId,
          rootAddressableId: coordinate,
        );
        expect(cached, 8);
      });

      test('does not add the just-posted comment to a later page', () async {
        when(() => nostrClient.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );
        await repository.postComment(
          content: 'my new comment',
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootEventAuthorPubkey: authorPubkey,
        );
        stubRestPage(50, [
          restComment('older', rootEventId: currentId, createdAt: 1000),
        ]);

        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
          offset: 50,
        );

        expect(thread.comments.map((c) => c.id), ['older']);
        expect(thread.totalCount, 51);
      });

      test('falls back to the relay with the cursor when REST fails', () async {
        when(
          () => funnelcake.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        ).thenThrow(const FunnelcakeException('REST is down'));
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              viewerPubkey,
              _commentKind,
              commentTags(currentId),
              'older comment',
              createdAt: 1000,
            )..id = 'relay_comment',
          ],
        );

        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
          offset: 50,
        );

        expect(thread.comments.map((c) => c.id), ['relay_comment']);
        verifyRestAsked(50);
        final filters = verify(
          () => nostrClient.queryEvents(captureAny()),
        ).captured.expand((argument) => argument as List<Filter>);
        expect(filters.map((f) => f.until), everyElement(5000));
      });
    });

    group('with a cursor and no REST offset', () {
      test('reports no REST position for a page the relay served', () async {
        final thread = await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
        );

        expect(thread.nextOffset, isNull);
      });

      test('asks only the relay, for pages the relay served', () async {
        await repository.loadComments(
          rootEventId: currentId,
          rootEventKind: _videoKind,
          rootAddressableId: coordinate,
          before: cursor,
        );

        verifyNever(
          () => funnelcake.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: any(named: 'cacheBustToken'),
          ),
        );
        verify(() => nostrClient.queryEvents(any())).called(greaterThan(0));
      });
    });
  });
}
