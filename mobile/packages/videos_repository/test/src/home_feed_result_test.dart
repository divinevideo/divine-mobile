import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group(HomeFeedResult, () {
    VideoEvent createVideo({required String id, int createdAt = 1000}) {
      return VideoEvent(
        id: id,
        pubkey: 'pubkey',
        createdAt: createdAt,
        content: '',
        timestamp: DateTime(2025),
      );
    }

    test('can be instantiated with required fields only', () {
      final result = HomeFeedResult(videos: [createVideo(id: 'v1')]);

      expect(result.videos, hasLength(1));
      expect(result.videoListSources, isEmpty);
      expect(result.listOnlyVideoIds, isEmpty);
      expect(result.consumedItemCount, isNull);
      expect(result.recommendationPageCount, 0);
      expect(result.followingPageCount, 0);
    });

    test('can be instantiated with all fields', () {
      final result = HomeFeedResult(
        videos: [createVideo(id: 'v1')],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
        consumedItemCount: 5,
        nextCursor: 1234,
        paginationCursor: 'o:2',
        hasMore: true,
        recommendationPageCount: 2,
        followingPageCount: 3,
      );

      expect(result.videos, hasLength(1));
      expect(result.videoListSources, hasLength(1));
      expect(result.listOnlyVideoIds, contains('v1'));
      expect(result.consumedItemCount, 5);
      expect(result.nextCursor, 1234);
      expect(result.paginationCursor, 'o:2');
      expect(result.hasMore, isTrue);
      expect(result.recommendationPageCount, 2);
      expect(result.followingPageCount, 3);
    });

    test('empty constructor defaults', () {
      const result = HomeFeedResult(videos: []);

      expect(result.videos, isEmpty);
      expect(result.videoListSources, isEmpty);
      expect(result.listOnlyVideoIds, isEmpty);
    });

    test('supports equality via Equatable', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
      );

      final result2 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
      );

      expect(result1, equals(result2));
    });

    test('inequality when videos differ', () {
      final result1 = HomeFeedResult(videos: [createVideo(id: 'v1')]);
      final result2 = HomeFeedResult(videos: [createVideo(id: 'v2')]);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when videoListSources differ', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
      );

      final result2 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-b'},
        },
      );

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when listOnlyVideoIds differ', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        listOnlyVideoIds: const {'v1'},
      );

      final result2 = HomeFeedResult(videos: [video]);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when consumedItemCount differs', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(videos: [video], consumedItemCount: 1);
      final result2 = HomeFeedResult(videos: [video], consumedItemCount: 2);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when nextCursor differs', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(videos: [video], nextCursor: 1);
      final result2 = HomeFeedResult(videos: [video], nextCursor: 2);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when hasMore differs', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(videos: [video], hasMore: true);
      final result2 = HomeFeedResult(videos: [video], hasMore: false);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when paginationCursor differs', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(videos: [video], paginationCursor: 'o:1');
      final result2 = HomeFeedResult(videos: [video], paginationCursor: 'o:2');

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when traversal counts differ', () {
      final video = createVideo(id: 'v1');
      final result1 = HomeFeedResult(
        videos: [video],
        recommendationPageCount: 1,
      );
      final result2 = HomeFeedResult(
        videos: [video],
        followingPageCount: 1,
      );

      expect(result1, isNot(equals(result2)));
    });

    test('props includes all fields', () {
      final video = createVideo(id: 'v1');
      const sources = {
        'v1': {'list-a'},
      };
      const listOnly = {'v1'};

      final result = HomeFeedResult(
        videos: [video],
        videoListSources: sources,
        listOnlyVideoIds: listOnly,
        consumedItemCount: 7,
        nextCursor: 1234,
        paginationCursor: 'o:2',
        hasMore: true,
        recommendationPageCount: 2,
        followingPageCount: 3,
      );

      expect(result.props, hasLength(9));
      expect(result.props[0], equals([video]));
      expect(result.props[1], equals(sources));
      expect(result.props[2], equals(listOnly));
      expect(result.props[3], 7);
      expect(result.props[4], 1234);
      expect(result.props[5], 'o:2');
      expect(result.props[6], isTrue);
      expect(result.props[7], 2);
      expect(result.props[8], 3);
    });
  });
}
