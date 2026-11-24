// ABOUTME: Tests whether a viewer may reply to a video with a video: anyone,
// ABOUTME: unless its replies sticker lets only the creator or their follows.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_reply_gate/video_reply_gate_cubit.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

final String _creator = 'a' * 64;
final String _friend = 'b' * 64;
final String _stranger = 'c' * 64;

VideoEvent _video([VideoStickerAudience? audience]) => VideoEvent(
  id: 'd' * 64,
  pubkey: _creator,
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  stickerRegions: [
    if (audience != null)
      VideoStickerRegion(
        kind: VideoStickerKind.replies,
        target: '',
        centerX: 0.5,
        centerY: 0.5,
        width: 0.6,
        height: 0.3,
        label: 'Reply with a video',
        audience: audience,
      ),
  ],
);

void main() {
  group(VideoReplyGateCubit, () {
    late _MockFollowRepository followRepository;

    setUp(() {
      followRepository = _MockFollowRepository();
      when(() => followRepository.getOthersFollowing(_creator)).thenAnswer(
        (_) async => FollowingSnapshot(pubkeys: [_friend], count: 1),
      );
    });

    VideoReplyGateCubit build(VideoEvent video, {String? viewer}) =>
        VideoReplyGateCubit(
          followRepository: followRepository,
          video: video,
          viewer: viewer,
        );

    group('check', () {
      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'lets anyone reply to a video whose replies anyone may give',
        build: () => build(
          _video(VideoStickerAudience.everyone),
          viewer: _stranger,
        ),
        act: (cubit) => cubit.check(),
        expect: () => <VideoReplyGate>[],
        verify: (cubit) {
          expect(cubit.state, equals(VideoReplyGate.allowed));
          expect(VideoReplyGateCubit.isGated(_video()), isFalse);
        },
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'lets someone the creator follows reply',
        build: () => build(
          _video(VideoStickerAudience.following),
          viewer: _friend,
        ),
        act: (cubit) => cubit.check(),
        expect: () => [VideoReplyGate.allowed],
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'keeps anyone else from replying',
        build: () => build(
          _video(VideoStickerAudience.following),
          viewer: _stranger,
        ),
        act: (cubit) => cubit.check(),
        expect: () => [VideoReplyGate.denied],
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'lets only the creator reply when only they may, reading nothing',
        build: () => build(
          _video(VideoStickerAudience.creator),
          viewer: _creator,
        ),
        act: (cubit) => cubit.check(),
        expect: () => <VideoReplyGate>[],
        verify: (cubit) {
          expect(cubit.state, equals(VideoReplyGate.allowed));
          verifyNever(() => followRepository.getOthersFollowing(any()));
        },
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'keeps anyone but the creator from replying when only they may',
        build: () => build(
          _video(VideoStickerAudience.creator),
          viewer: _friend,
        ),
        act: (cubit) => cubit.check(),
        expect: () => [VideoReplyGate.denied],
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'keeps someone signed out from replying',
        build: () => build(_video(VideoStickerAudience.following)),
        act: (cubit) => cubit.check(),
        expect: () => <VideoReplyGate>[],
        verify: (cubit) => expect(cubit.state, equals(VideoReplyGate.denied)),
      );

      blocTest<VideoReplyGateCubit, VideoReplyGate>(
        'keeps the viewer from replying when who the creator follows could '
        'not be read',
        setUp: () => when(
          () => followRepository.getOthersFollowing(_creator),
        ).thenThrow(Exception('timed out')),
        build: () => build(
          _video(VideoStickerAudience.following),
          viewer: _friend,
        ),
        act: (cubit) => cubit.check(),
        expect: () => [VideoReplyGate.denied],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
