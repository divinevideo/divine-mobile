import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

void main() {
  group(VideoCrosspostCubit, () {
    late _MockCrosspostingApiClient client;

    const eventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        'bbbbbbbbbbbbbbbbbbbbbbbb';

    const instagramConnection = CrosspostingConnection(
      id: 'conn-1',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: 'divine.creator',
    );
    const disconnectedTiktok = CrosspostingConnection(
      id: 'conn-2',
      platform: CrosspostingPlatform.tiktok,
      status: CrosspostingConnectionStatus.needsReauth,
    );

    const queuedJob = CrosspostJob(
      id: 'job-1',
      platform: 'instagram',
      status: CrosspostJobStatus.queued,
    );
    const postedJob = CrosspostJob(
      id: 'job-1',
      platform: 'instagram',
      status: CrosspostJobStatus.posted,
      externalPostUrl: 'https://www.instagram.com/reel/abc/',
    );

    setUp(() {
      client = _MockCrosspostingApiClient();
    });

    VideoCrosspostCubit buildCubit({
      List<CrosspostingConnection>? initialConnections,
      Duration pollInterval = const Duration(milliseconds: 10),
      Duration pollTimeout = const Duration(milliseconds: 100),
    }) {
      return VideoCrosspostCubit(
        client: client,
        eventId: eventId,
        initialConnections: initialConnections,
        pollInterval: pollInterval,
        pollTimeout: pollTimeout,
      );
    }

    test('seeds ready state with connected platforms preselected when '
        'given initial connections', () {
      final cubit = buildCubit(
        initialConnections: [instagramConnection, disconnectedTiktok],
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, equals(VideoCrosspostStatus.ready));
      expect(cubit.state.connectedPlatforms, equals(['instagram']));
      expect(cubit.state.selectedPlatforms, equals({'instagram'}));
    });

    group('loadConnections', () {
      blocTest<VideoCrosspostCubit, VideoCrosspostState>(
        'emits ready with connections and preselects connected platforms',
        build: () {
          when(
            () => client.getConnections(),
          ).thenAnswer((_) async => [instagramConnection, disconnectedTiktok]);
          return buildCubit();
        },
        act: (cubit) => cubit.loadConnections(),
        expect: () => [
          const VideoCrosspostState(
            status: VideoCrosspostStatus.loadingConnections,
          ),
          const VideoCrosspostState(
            status: VideoCrosspostStatus.ready,
            connections: [instagramConnection, disconnectedTiktok],
            selectedPlatforms: {'instagram'},
          ),
        ],
      );

      blocTest<VideoCrosspostCubit, VideoCrosspostState>(
        'emits connectionsFailed when the client throws',
        build: () {
          when(
            () => client.getConnections(),
          ).thenThrow(const CrosspostingApiException('boom', statusCode: 500));
          return buildCubit();
        },
        act: (cubit) => cubit.loadConnections(),
        expect: () => [
          const VideoCrosspostState(
            status: VideoCrosspostStatus.loadingConnections,
          ),
          const VideoCrosspostState(
            status: VideoCrosspostStatus.connectionsFailed,
          ),
        ],
        errors: () => [isA<CrosspostingApiException>()],
      );
    });

    group('togglePlatform', () {
      test('toggles selection while ready and ignores toggles in other '
          'states', () {
        final cubit = buildCubit(initialConnections: [instagramConnection]);
        addTearDown(cubit.close);

        cubit.togglePlatform('instagram');
        expect(cubit.state.selectedPlatforms, isEmpty);

        cubit.togglePlatform('instagram');
        expect(cubit.state.selectedPlatforms, equals({'instagram'}));
      });
    });

    group('submit', () {
      test('emits finished immediately when jobs come back '
          'terminal', () async {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenAnswer((_) async => [postedJob]);

        final cubit = buildCubit(initialConnections: [instagramConnection]);
        addTearDown(cubit.close);

        await cubit.submit();

        expect(cubit.state.status, equals(VideoCrosspostStatus.finished));
        expect(cubit.state.jobs, equals([postedJob]));
        verifyNever(() => client.getCrossposts(eventId: eventId));
      });

      test('polls until jobs reach a terminal state', () {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenAnswer((_) async => [queuedJob]);
        var polls = 0;
        when(() => client.getCrossposts(eventId: eventId)).thenAnswer((
          _,
        ) async {
          polls += 1;
          return polls < 2 ? [queuedJob] : [postedJob];
        });

        fakeAsync((fake) {
          final cubit = buildCubit(initialConnections: [instagramConnection]);

          unawaited(cubit.submit());
          fake.flushMicrotasks();
          expect(cubit.state.status, equals(VideoCrosspostStatus.polling));

          fake
            ..elapse(const Duration(milliseconds: 20))
            ..flushMicrotasks();

          expect(cubit.state.status, equals(VideoCrosspostStatus.finished));
          expect(
            cubit.state.jobs.single.externalPostUrl,
            equals('https://www.instagram.com/reel/abc/'),
          );
          expect(cubit.state.pollTimedOut, isFalse);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      test('gives up with pollTimedOut when jobs stay pending past the '
          'timeout', () {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenAnswer((_) async => [queuedJob]);
        when(
          () => client.getCrossposts(eventId: eventId),
        ).thenAnswer((_) async => [queuedJob]);

        fakeAsync((fake) {
          final cubit = buildCubit(
            initialConnections: [instagramConnection],
            pollTimeout: const Duration(milliseconds: 30),
          );

          unawaited(cubit.submit());
          fake
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 50))
            ..flushMicrotasks();

          expect(cubit.state.status, equals(VideoCrosspostStatus.finished));
          expect(cubit.state.pollTimedOut, isTrue);
          expect(cubit.state.hasPendingJobs, isTrue);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      test('keeps polling through a transient poll failure', () {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenAnswer((_) async => [queuedJob]);
        var polls = 0;
        when(() => client.getCrossposts(eventId: eventId)).thenAnswer((
          _,
        ) async {
          polls += 1;
          if (polls == 1) {
            throw const CrosspostingApiException('flaky', statusCode: 502);
          }
          return [postedJob];
        });

        fakeAsync((fake) {
          final cubit = buildCubit(initialConnections: [instagramConnection]);

          unawaited(cubit.submit());
          fake
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 20))
            ..flushMicrotasks();

          expect(cubit.state.status, equals(VideoCrosspostStatus.finished));
          expect(cubit.state.pollTimedOut, isFalse);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      for (final (code, expected) in [
        ('not_owner', VideoCrosspostSubmitError.notOwner),
        ('not_eligible', VideoCrosspostSubmitError.notEligible),
        ('not_connected', VideoCrosspostSubmitError.notConnected),
        ('unauthorized', VideoCrosspostSubmitError.unauthorized),
        (null, VideoCrosspostSubmitError.network),
      ]) {
        test('maps $code submit failure to $expected', () async {
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenThrow(
            CrosspostingApiException('nope', statusCode: 403, code: code),
          );

          final cubit = buildCubit(initialConnections: [instagramConnection]);
          addTearDown(cubit.close);

          await cubit.submit();

          expect(cubit.state.status, equals(VideoCrosspostStatus.submitFailed));
          expect(cubit.state.submitError, equals(expected));
        });
      }

      test('does nothing when no platform is selected', () async {
        final cubit = buildCubit(initialConnections: [disconnectedTiktok]);
        addTearDown(cubit.close);

        await cubit.submit();

        expect(cubit.state.status, equals(VideoCrosspostStatus.ready));
        verifyNever(
          () => client.createCrossposts(
            eventId: any(named: 'eventId'),
            platforms: any(named: 'platforms'),
          ),
        );
      });
    });

    test('close cancels polling so no further client calls fire', () async {
      when(
        () =>
            client.createCrossposts(eventId: eventId, platforms: ['instagram']),
      ).thenAnswer((_) async => [queuedJob]);
      when(
        () => client.getCrossposts(eventId: eventId),
      ).thenAnswer((_) async => [queuedJob]);

      final cubit = buildCubit(
        initialConnections: [instagramConnection],
        pollInterval: const Duration(milliseconds: 50),
      );
      await cubit.submit();
      await cubit.close();

      await Future<void>.delayed(const Duration(milliseconds: 150));

      verifyNever(() => client.getCrossposts(eventId: eventId));
    });
  });
}
