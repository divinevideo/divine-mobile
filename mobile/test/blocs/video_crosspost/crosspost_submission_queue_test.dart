import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_crosspost/crosspost_submission_queue.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

void main() {
  group(CrosspostSubmissionQueue, () {
    const eventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const connection = CrosspostingConnection(
      id: 'connection-1',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
    );
    const queuedJob = CrosspostJob(
      id: 'job-1',
      platform: 'instagram',
      status: CrosspostJobStatus.queued,
    );
    late _MockCrosspostingApiClient client;
    late CrosspostSubmissionQueue queue;

    setUp(() {
      client = _MockCrosspostingApiClient();
      queue = CrosspostSubmissionQueue(
        repository: CrosspostingRepository(client),
      );
    });

    tearDown(() => queue.close());

    group('submit', () {
      test(
        'retries an unindexed source and tracks the job in the background',
        () {
          fakeAsync((clock) {
            var attempts = 0;
            when(
              () => client.createCrossposts(
                eventId: eventId,
                platforms: ['instagram'],
              ),
            ).thenAnswer((_) async {
              attempts++;
              if (attempts == 1) {
                throw const CrosspostingApiException(
                  'Not indexed',
                  statusCode: 404,
                  code: 'not_found',
                );
              }
              return [queuedJob];
            });
            when(
              () => client.createCrossposts(
                eventId: eventId,
                platforms: ['instagram'],
                allowUserInteraction: false,
              ),
            ).thenAnswer((_) async {
              attempts++;
              return [queuedJob];
            });
            when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
              (_) async => const [
                CrosspostJob(
                  id: 'job-1',
                  platform: 'instagram',
                  status: CrosspostJobStatus.posted,
                ),
              ],
            );
            VideoCrosspostState? result;
            unawaited(
              queue
                  .submit(eventId: eventId, connections: [connection])
                  .then((value) => result = value),
            );
            clock.flushMicrotasks();
            expect(attempts, 1);
            expect(result, isNull);
            clock.elapse(const Duration(seconds: 2));
            clock.flushMicrotasks();
            expect(attempts, 2);
            verify(
              () => client.createCrossposts(
                eventId: eventId,
                platforms: ['instagram'],
                allowUserInteraction: false,
              ),
            ).called(1);
            expect(result, isNull);
            clock.elapse(const Duration(seconds: 3));
            clock.flushMicrotasks();
            expect(result?.jobs.single.status, CrosspostJobStatus.posted);
            expect(clock.pendingTimers, isEmpty);
          });
        },
      );

      test('ignores jobs from other submissions of the same video', () {
        fakeAsync((clock) {
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenAnswer((_) async => [queuedJob]);
          when(() => client.getCrossposts(eventId: eventId)).thenAnswer(
            (_) async => const [
              CrosspostJob(
                id: 'old-failure',
                platform: 'tiktok',
                status: CrosspostJobStatus.failed,
              ),
              CrosspostJob(
                id: 'other-pending',
                platform: 'youtube',
                status: CrosspostJobStatus.queued,
              ),
              CrosspostJob(
                id: 'job-1',
                platform: 'instagram',
                status: CrosspostJobStatus.posted,
              ),
            ],
          );
          final updates = <VideoCrosspostState>[];
          unawaited(
            queue.submit(
              eventId: eventId,
              connections: [connection],
              onUpdate: updates.add,
            ),
          );
          clock.flushMicrotasks();
          clock.elapse(const Duration(seconds: 3));
          clock.flushMicrotasks();
          expect(
            updates.expand((state) => state.jobs).map((job) => job.id),
            everyElement('job-1'),
          );
          expect(updates.last.jobs.single.status, CrosspostJobStatus.posted);
          expect(updates.last.status, VideoCrosspostStatus.finished);
          expect(clock.pendingTimers, isEmpty);
        });
      });

      test('recovers a source retry after a silent remote signature fails', () {
        fakeAsync((clock) {
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenThrow(
            const CrosspostingApiException(
              'Not indexed',
              statusCode: 404,
              code: 'not_found',
            ),
          );
          var retries = 0;
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
              allowUserInteraction: false,
            ),
          ).thenAnswer((_) async {
            if (retries++ == 0) {
              throw const CrosspostingPassiveSigningUnavailable(
                retryable: true,
              );
            }
            return const [
              CrosspostJob(
                id: 'posted',
                platform: 'instagram',
                status: CrosspostJobStatus.posted,
              ),
            ];
          });
          final updates = <VideoCrosspostState>[];
          unawaited(
            queue.submit(
              eventId: eventId,
              connections: [connection],
              onUpdate: updates.add,
            ),
          );
          clock.flushMicrotasks();
          clock.elapse(const Duration(seconds: 4));
          expect(retries, 2);
          expect(updates.last.jobs.single.status, CrosspostJobStatus.posted);
          expect(
            updates.map((state) => state.status),
            isNot(contains(VideoCrosspostStatus.submitFailed)),
          );
        });
      });

      test('returns mapped failure for the background notification', () async {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenThrow(
          const CrosspostingApiException(
            'Not connected',
            statusCode: 409,
            code: 'not_connected',
          ),
        );

        final result = await queue.submit(
          eventId: eventId,
          connections: [connection],
        );

        expect(result?.status, VideoCrosspostStatus.submitFailed);
        expect(result?.submitError, VideoCrosspostSubmitError.notConnected);
      });
    });

    group('logging', () {
      List<String> warnings() => [
        for (final entry in LogCaptureService().getRecentLogs(
          minLevel: LogLevel.warning,
        ))
          entry.message,
      ];

      setUp(() => LogCaptureService().clearAllLogs());

      test('records a failed job with its event, platform and error', () async {
        when(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        ).thenAnswer(
          (_) async => const [
            CrosspostJob(
              id: 'job-1',
              platform: 'instagram',
              status: CrosspostJobStatus.failed,
              errorCode: 'not_eligible',
            ),
          ],
        );

        await queue.submit(eventId: eventId, connections: [connection]);

        expect(
          warnings(),
          contains(
            allOf(
              contains(eventId),
              contains('instagram failed (not_eligible) job job-1'),
            ),
          ),
        );
      });

      test('records the jobs left unmonitored without a signature', () {
        fakeAsync((clock) {
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenAnswer((_) async => [queuedJob]);
          when(
            () => client.getCrossposts(eventId: eventId),
          ).thenThrow(const CrosspostingPassiveSigningUnavailable());
          unawaited(queue.submit(eventId: eventId, connections: [connection]));
          clock.flushMicrotasks();
          clock.elapse(const Duration(seconds: 3));
          clock.flushMicrotasks();

          expect(
            warnings(),
            contains(
              allOf(
                contains(eventId),
                contains('without a background signature'),
                contains('instagram queued job job-1'),
              ),
            ),
          );
          expect(clock.pendingTimers, isEmpty);
        });
      });

      test('records a submission the account change cancelled', () {
        fakeAsync((clock) {
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenAnswer(
            (_) async => throw const CrosspostingApiException(
              'Not indexed',
              statusCode: 404,
              code: 'not_found',
            ),
          );
          unawaited(queue.submit(eventId: eventId, connections: [connection]));
          clock.flushMicrotasks();
          unawaited(queue.close());
          clock.flushMicrotasks();

          expect(
            LogCaptureService().getRecentLogs().map((entry) => entry.message),
            contains(
              allOf(
                contains(eventId),
                contains('cancelled before it finished'),
              ),
            ),
          );
        });
      });
    });

    group('close', () {
      test('cancels the old account retry timer and suppresses its result', () {
        fakeAsync((clock) {
          var attempts = 0;
          when(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
          ).thenAnswer((_) async {
            attempts++;
            throw const CrosspostingApiException(
              'Not indexed',
              statusCode: 404,
              code: 'not_found',
            );
          });
          var completed = false;
          VideoCrosspostState? result;
          unawaited(
            queue.submit(eventId: eventId, connections: [connection]).then((
              value,
            ) {
              result = value;
              completed = true;
            }),
          );
          clock.flushMicrotasks();
          expect(clock.pendingTimers, hasLength(1));
          unawaited(queue.close());
          clock.flushMicrotasks();
          clock.elapse(const Duration(minutes: 1));

          expect(attempts, 1);
          expect(completed, isTrue);
          expect(result, isNull);
          expect(clock.pendingTimers, isEmpty);
        });
      });

      test('does not submit after the account owner is disposed', () async {
        await queue.close();
        final result = await queue.submit(
          eventId: eventId,
          connections: [connection],
        );
        expect(result, isNull);
        verifyNever(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
        );
      });
    });
  });
}
