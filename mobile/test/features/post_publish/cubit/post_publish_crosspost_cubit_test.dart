// ABOUTME: Tests the post-publish crosspost cubit's prompt choice and its
// ABOUTME: CTA exposure and tap analytics.

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/post_publish/cubit/post_publish_crosspost_cubit.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockCrosspostingRepository extends Mock
    implements CrosspostingRepository {}

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

const _instagramConnected = CrosspostingConnection(
  id: 'conn-instagram',
  platform: CrosspostingPlatform.instagram,
  status: CrosspostingConnectionStatus.connected,
);
const _instagramNeedsReauth = CrosspostingConnection(
  id: 'conn-instagram',
  platform: CrosspostingPlatform.instagram,
  status: CrosspostingConnectionStatus.needsReauth,
);
const _tiktokConnected = CrosspostingConnection(
  id: 'conn-tiktok',
  platform: CrosspostingPlatform.tiktok,
  status: CrosspostingConnectionStatus.connected,
);

CrosspostingPlatformSettings _settings({
  CrosspostingPlatform platform = CrosspostingPlatform.instagram,
  CrosspostingConnection? connection,
  CrosspostingMode mode = CrosspostingMode.disabled,
}) => CrosspostingPlatformSettings(
  platform: platform,
  supportsAutomatic: true,
  mode: mode,
  connection: connection,
);

void main() {
  group(PostPublishCrosspostCubit, () {
    late _MockCrosspostingRepository repository;
    late _RecordingSink analytics;

    setUp(() {
      repository = _MockCrosspostingRepository();
      analytics = _RecordingSink();
    });

    PostPublishCrosspostCubit buildCubit() => PostPublishCrosspostCubit(
      repository: repository,
      analytics: analytics,
    );

    test('starts loading', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.prompt, equals(PostPublishCrosspostPrompt.loading));
    });

    group('load', () {
      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'suggests crossposting to connected manual-mode platforms',
        setUp: () => when(() => repository.loadSettings()).thenAnswer(
          (_) async => [
            _settings(
              connection: _instagramConnected,
              mode: CrosspostingMode.manual,
            ),
            _settings(
              platform: CrosspostingPlatform.tiktok,
              connection: _tiktokConnected,
              mode: CrosspostingMode.automatic,
            ),
          ],
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.crosspost,
            platforms: [CrosspostingPlatform.instagram],
            connections: [_instagramConnected],
          ),
        ],
        verify: (_) {
          expect(analytics.events.single.name, equals('crosspost_cta_shown'));
          expect(
            analytics.events.single.parameters,
            equals({'surface': 'post_publish', 'cta': 'crosspost_video'}),
          );
        },
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'offers setup when no platform is connected',
        setUp: () => when(
          () => repository.loadSettings(),
        ).thenAnswer((_) async => [_settings()]),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.setUp,
            platforms: [CrosspostingPlatform.instagram],
          ),
        ],
        verify: (_) => expect(
          analytics.events.single.parameters,
          equals({'surface': 'post_publish', 'cta': 'connect'}),
        ),
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'notes automatic crossposting without a CTA',
        setUp: () => when(() => repository.loadSettings()).thenAnswer(
          (_) async => [
            _settings(
              connection: _instagramConnected,
              mode: CrosspostingMode.automatic,
            ),
          ],
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.automatic,
            platforms: [CrosspostingPlatform.instagram],
          ),
        ],
        verify: (_) => expect(analytics.events, isEmpty),
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'asks to reconnect a platform whose authorization lapsed',
        setUp: () => when(() => repository.loadSettings()).thenAnswer(
          (_) async => [
            _settings(
              connection: _instagramNeedsReauth,
              mode: CrosspostingMode.manual,
            ),
          ],
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.reconnect,
            platforms: [CrosspostingPlatform.instagram],
          ),
        ],
        verify: (_) => expect(
          analytics.events.single.parameters,
          equals({'surface': 'post_publish', 'cta': 'reconnect'}),
        ),
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'prefers suggesting a crosspost over a reconnect elsewhere',
        setUp: () => when(() => repository.loadSettings()).thenAnswer(
          (_) async => [
            _settings(
              connection: _instagramNeedsReauth,
              mode: CrosspostingMode.manual,
            ),
            _settings(
              platform: CrosspostingPlatform.tiktok,
              connection: _tiktokConnected,
              mode: CrosspostingMode.manual,
            ),
          ],
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.crosspost,
            platforms: [CrosspostingPlatform.tiktok],
            connections: [_tiktokConnected],
          ),
        ],
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'stays quiet when the creator switched a connected platform off',
        setUp: () => when(() => repository.loadSettings()).thenAnswer(
          (_) async => [_settings(connection: _instagramConnected)],
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.none,
          ),
        ],
        verify: (_) => expect(analytics.events, isEmpty),
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'stays quiet when no platform is available to connect',
        setUp: () =>
            when(() => repository.loadSettings()).thenAnswer((_) async => []),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.none,
          ),
        ],
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'stays quiet and reports the error when loading fails',
        setUp: () => when(
          () => repository.loadSettings(),
        ).thenThrow(const CrosspostingApiException('offline')),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const PostPublishCrosspostState(
            prompt: PostPublishCrosspostPrompt.none,
          ),
        ],
        errors: () => [isA<CrosspostingApiException>()],
        verify: (_) => expect(analytics.events, isEmpty),
      );

      test('does not log exposure when closed before settings load', () async {
        when(() => repository.loadSettings()).thenAnswer(
          (_) async => [_settings()],
        );
        final cubit = buildCubit();
        final load = cubit.load();
        await cubit.close();
        await load;

        expect(analytics.events, isEmpty);
      });
    });

    group('recordTap', () {
      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'logs a tap on the shown CTA',
        seed: () => const PostPublishCrosspostState(
          prompt: PostPublishCrosspostPrompt.reconnect,
          platforms: [CrosspostingPlatform.instagram],
        ),
        build: buildCubit,
        act: (cubit) => cubit.recordTap(),
        expect: () => const <PostPublishCrosspostState>[],
        verify: (_) {
          expect(analytics.events.single.name, equals('crosspost_cta_tapped'));
          expect(
            analytics.events.single.parameters,
            equals({'surface': 'post_publish', 'cta': 'reconnect'}),
          );
        },
      );

      blocTest<PostPublishCrosspostCubit, PostPublishCrosspostState>(
        'logs nothing while no CTA is shown',
        seed: () => const PostPublishCrosspostState(
          prompt: PostPublishCrosspostPrompt.automatic,
          platforms: [CrosspostingPlatform.instagram],
        ),
        build: buildCubit,
        act: (cubit) => cubit.recordTap(),
        verify: (_) => expect(analytics.events, isEmpty),
      );
    });
  });
}
