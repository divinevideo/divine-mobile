// ABOUTME: Tests for FeedLoadingModerationCubit.
// ABOUTME: Covers deferred moderation check, timer cancellation, and error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

void main() {
  // Valid 64-char hex sha256.
  const sha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  // URL whose host ends with divine.video and whose path encodes sha256.
  const divineUrl =
      'https://cdn.divine.video/'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      '.mp4';

  const blockedStatus = VideoModerationStatus(
    moderated: true,
    blocked: true,
    quarantined: false,
    ageRestricted: false,
    needsReview: false,
    aiGenerated: false,
  );

  const notBlockedStatus = VideoModerationStatus(
    moderated: false,
    blocked: false,
    quarantined: false,
    ageRestricted: false,
    needsReview: false,
    aiGenerated: false,
  );

  late _MockVideoModerationStatusService mockService;

  setUp(() {
    mockService = _MockVideoModerationStatusService();
  });

  FeedLoadingModerationCubit buildCubit({
    String? explicitSha256,
    String? videoUrl,
  }) {
    return FeedLoadingModerationCubit(
      service: mockService,
      explicitSha256: explicitSha256,
      videoUrl: videoUrl,
    );
  }

  group(FeedLoadingModerationCubit, () {
    group('initial state', () {
      test('is loading and not restricted', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(cubit.state, const FeedLoadingModerationState());
        expect(cubit.state.isRestricted, isFalse);
      });
    });

    group('start', () {
      test('is a no-op when videoUrl is null', () {
        fakeAsync((fake) {
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.start();
          fake.elapse(const Duration(seconds: 5));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          verifyNever(() => mockService.fetchStatus(any()));
          fake.flushMicrotasks();
        });
      });

      test('is a no-op when videoUrl host is not a divine host', () {
        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: 'https://example.com/video.mp4');
          addTearDown(cubit.close);
          cubit.start();
          fake.elapse(const Duration(seconds: 5));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          verifyNever(() => mockService.fetchStatus(any()));
          fake.flushMicrotasks();
        });
      });

      test(
        'emits restricted immediately when service returns a blocked status',
        () {
          when(
            () => mockService.fetchStatus(sha256),
          ).thenAnswer((_) async => blockedStatus);

          fakeAsync((fake) {
            final cubit = buildCubit(videoUrl: divineUrl);
            addTearDown(cubit.close);
            cubit.start();
            fake.flushMicrotasks();
            expect(cubit.state.isRestricted, isTrue);
            verify(() => mockService.fetchStatus(sha256)).called(1);
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'emits ageRestricted when service returns age-restricted status',
        () {
          const ageRestricted = VideoModerationStatus(
            moderated: true,
            blocked: false,
            quarantined: false,
            ageRestricted: true,
            needsReview: false,
            aiGenerated: false,
          );
          when(
            () => mockService.fetchStatus(sha256),
          ).thenAnswer((_) async => ageRestricted);

          fakeAsync((fake) {
            final cubit = buildCubit(videoUrl: divineUrl);
            addTearDown(cubit.close);
            cubit.start();
            fake.elapse(const Duration(seconds: 2));
            fake.flushMicrotasks();
            expect(cubit.state.isRestricted, isFalse);
            expect(cubit.state.isAgeRestricted, isTrue);
            expect(
              cubit.state.status,
              FeedLoadingModerationStatus.ageRestricted,
            );
            fake.flushMicrotasks();
          });
        },
      );

      test('blocked status wins over age-restricted status', () {
        const blockedAndAgeRestricted = VideoModerationStatus(
          moderated: true,
          blocked: true,
          quarantined: false,
          ageRestricted: true,
          needsReview: false,
          aiGenerated: false,
        );
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => blockedAndAgeRestricted);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          addTearDown(cubit.close);
          cubit.start();
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isTrue);
          expect(cubit.state.isAgeRestricted, isFalse);
          expect(cubit.state.status, FeedLoadingModerationStatus.restricted);
          fake.flushMicrotasks();
        });
      });

      test('stays loading when service returns null', () {
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => null);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          addTearDown(cubit.close);
          cubit.start();
          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          fake.flushMicrotasks();
        });
      });

      test('stays loading when service returns a non-blocked status', () {
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => notBlockedStatus);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          addTearDown(cubit.close);
          cubit.start();
          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          fake.flushMicrotasks();
        });
      });

      test(
        'prefers explicitSha256 over url-derived sha256 when both provided',
        () {
          const explicitSha256 =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          when(
            () => mockService.fetchStatus(explicitSha256),
          ).thenAnswer((_) async => null);

          fakeAsync((fake) {
            final cubit = buildCubit(
              explicitSha256: explicitSha256,
              videoUrl: divineUrl,
            );
            addTearDown(cubit.close);
            cubit.start();
            fake.elapse(const Duration(seconds: 3));
            fake.flushMicrotasks();
            verify(() => mockService.fetchStatus(explicitSha256)).called(1);
            verifyNever(() => mockService.fetchStatus(sha256));
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('error handling', () {
      blocTest<FeedLoadingModerationCubit, FeedLoadingModerationState>(
        'calls addError and stays loading when fetchStatus throws',
        build: () {
          when(
            () => mockService.fetchStatus(any()),
          ).thenThrow(Exception('network error'));
          return FeedLoadingModerationCubit(
            service: mockService,
            explicitSha256: sha256,
            videoUrl: divineUrl,
          );
        },
        act: (cubit) => cubit.start(),
        wait: const Duration(milliseconds: 50),
        errors: () => [isA<Exception>()],
        expect: () => const <FeedLoadingModerationState>[],
      );
    });
  });
}
