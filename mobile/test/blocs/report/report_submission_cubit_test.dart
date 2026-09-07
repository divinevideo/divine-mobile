// ABOUTME: Unit tests for ReportSubmissionCubit, the report sheet's
// ABOUTME: submission state machine across the kind-1984 and DM channels.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/report/report_submission_cubit.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockDmRepository extends Mock implements DmRepository {}

const _moderationPubkey =
    '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

/// A 64-hex blob hash, so `moderationDmTags` resolves it rather than dropping
/// it as malformed.
const _blobHash =
    'b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2';

void main() {
  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  group(ReportTarget, () {
    ReportTarget targetWith({String? userPubkey}) => ReportTarget(
      eventId: 'event_id',
      authorPubkey: 'author_pubkey',
      userPubkey: userPubkey,
      sha256: _blobHash,
      videoUrl: 'https://blossom.example/$_blobHash',
      moderationKindLabel: 'Content Report',
      moderationEventLabel: 'Event',
    );

    test('carries a video blob hash on a content report', () {
      final target = targetWith();

      expect(target.moderationSha256, equals(_blobHash));
      expect(target.moderationVideoUrl, isNotNull);
    });

    test('withholds the blob hash from a user report', () {
      // The constructor allows a video and a userPubkey together, and
      // userPubkey is what routes to reportUser. Passing the hash regardless
      // would have the backend file an account-level report against that one
      // video.
      final target = targetWith(userPubkey: 'reported_user_pubkey');

      expect(target.moderationSha256, isNull);
      expect(target.moderationVideoUrl, isNull);
    });
  });

  group(ReportSubmissionCubit, () {
    late _MockContentReportingService reportingService;
    late _MockDmRepository dmRepository;

    void stubReportContent(
      _MockContentReportingService service, {
      ReportDelivery delivery = ReportDelivery.reached,
      bool success = true,
      String error = 'rejected',
    }) {
      when(
        () => service.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => success
            ? ReportResult.createSuccess('id', delivery: delivery)
            : ReportResult.failure(error),
      );
    }

    void stubEnqueueSend(EnqueueSendResult result) {
      when(
        () => dmRepository.enqueueSend(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((_) async => result);
    }

    void stubRecoverFullSend(NIP17SendResult result) {
      when(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer((_) async => result);
    }

    NIP17SendResult dmSuccess() => NIP17SendResult.success(
      rumorEventId: 'rumor_id',
      messageEventId: 'dm_event_id',
      recipientPubkey: _moderationPubkey,
    );

    setUp(() {
      reportingService = _MockContentReportingService();
      dmRepository = _MockDmRepository();

      stubReportContent(reportingService);
      // Default: the DM enqueues durably and its background drive delivers.
      stubEnqueueSend(const EnqueueSendResult.enqueued('rumor_id'));
      stubRecoverFullSend(dmSuccess());
    });

    ReportSubmissionCubit buildCubit({
      ContentReportingServiceResolver? resolveReportingService,
      ModerationDmTransportResolver? resolveTransport,
    }) => ReportSubmissionCubit(
      resolveContentReportingService:
          resolveReportingService ?? () async => reportingService,
      resolveModerationDmTransport:
          resolveTransport ??
          () => (repository: dmRepository, pubkey: _moderationPubkey),
      target: const ReportTarget(
        eventId: 'event_id',
        authorPubkey: 'author_pubkey',
        moderationKindLabel: 'Content Report',
        moderationEventLabel: 'Event',
      ),
    );

    Future<void> submit(ReportSubmissionCubit cubit) => cubit.submit(
      reason: ContentFilterReason.spam,
      reasonTitle: 'Spam',
      details: 'Spam',
    );

    void verifyEnqueueSendCalled(int times) {
      verify(
        () => dmRepository.enqueueSend(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(times);
    }

    test('confirms as submitted and records the DM delivered once its '
        'background drive lands', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      // The confirmation is unconditional and shown as soon as the report is
      // durably enqueued — before the DM publishes.
      expect(cubit.state.status, ReportSubmissionStatus.submitted);

      // The DM publish is driven in the background; let it settle.
      await pumpEventQueue();
      expect(cubit.state.moderationDm.outcome, ModerationDmOutcome.delivered);
      verifyEnqueueSendCalled(1);
    });

    test(
      'confirms unconditionally even if a channel could not be reached',
      () async {
        // A legacy no-queue report can still return localOnly; the confirmation
        // no longer gates on delivery, so it is shown regardless.
        stubReportContent(reportingService, delivery: ReportDelivery.localOnly);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await submit(cubit);

        expect(cubit.state.status, ReportSubmissionStatus.submitted);
      },
    );

    test('a refused self-report is silent — confirmation shown, nothing '
        'enqueued (#8352)', () async {
      stubReportContent(reportingService, delivery: ReportDelivery.refused);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();

      // Silent success — a refusal must NOT hand off to the moderation DM, or
      // a self-naming report would still leave the device privately (#8352).
      expect(cubit.state.status, ReportSubmissionStatus.submitted);
      verifyNever(
        () => dmRepository.enqueueSend(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
        ),
      );
    });

    test('reports failure status when the report itself is rejected', () async {
      stubReportContent(reportingService, success: false);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);

      // #3589: the service's prose is logged, never emitted. The status is the
      // whole contract the UI reads.
      expect(cubit.state.status, ReportSubmissionStatus.failure);
    });

    test(
      'a moderation-side preflight failure does not sink the report',
      () async {
        // The transport is resolved inside the dispatch precisely so this stays
        // a DM-only failure. Resolving it when the sheet opened would let the
        // moderation label service take down a report the kind-1984 channel
        // carried fine.
        final cubit = buildCubit(
          resolveTransport: () => throw StateError('moderation unavailable'),
        );
        addTearDown(cubit.close);

        await submit(cubit);
        await pumpEventQueue();

        expect(cubit.state.status, ReportSubmissionStatus.submitted);
        verifyNever(
          () => dmRepository.enqueueSend(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            additionalTags: any(named: 'additionalTags'),
          ),
        );
      },
    );

    test('resolves the reporting service for each submit', () async {
      final nextReportingService = _MockContentReportingService();
      stubReportContent(nextReportingService);

      final services = <ContentReportingService>[
        reportingService,
        nextReportingService,
      ];
      final cubit = buildCubit(
        resolveReportingService: () async => services.removeAt(0),
      );
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();
      await submit(cubit);
      await pumpEventQueue();

      verify(
        () => reportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
      verify(
        () => nextReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });

    test('does not re-enqueue a blocked moderation DM on resubmit', () async {
      stubEnqueueSend(const EnqueueSendResult.blocked('policy blocked'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();
      await submit(cubit);
      await pumpEventQueue();

      expect(cubit.state.moderationDm.outcome, ModerationDmOutcome.blocked);
      verifyEnqueueSendCalled(1);
      verifyNever(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      );
    });

    test(
      'does not re-enqueue an oversized moderation DM on resubmit',
      () async {
        stubEnqueueSend(const EnqueueSendResult.tooLong('too large'));
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await submit(cubit);
        await pumpEventQueue();
        await submit(cubit);
        await pumpEventQueue();

        expect(cubit.state.moderationDm.outcome, ModerationDmOutcome.tooLong);
        verifyEnqueueSendCalled(1);
        verifyNever(
          () => dmRepository.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        );
      },
    );

    test(
      're-drives the parked row rather than enqueuing a second DM (#6610)',
      () async {
        stubEnqueueSend(const EnqueueSendResult.enqueued('parked_rumor_id'));
        // The background drive does not land, so the row stays parked.
        stubRecoverFullSend(
          const NIP17SendResult.failure(
            'no relays',
            retryablePending: true,
            queuedRumorId: 'parked_rumor_id',
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await submit(cubit);
        await pumpEventQueue();
        expect(
          cubit.state.moderationDm.queuedRumorId,
          equals('parked_rumor_id'),
        );

        // The same reason again coalesces onto the parked row rather than
        // stacking a second one for the sweep to deliver (#6610).
        await submit(cubit);
        await pumpEventQueue();

        verifyEnqueueSendCalled(1);
        verify(
          () => dmRepository.recoverFullSend(
            rumorId: 'parked_rumor_id',
            resetRetryBudget: true,
          ),
        ).called(2);
      },
    );

    test('replaces the parked row when the reason moved', () async {
      stubEnqueueSend(const EnqueueSendResult.enqueued('parked_rumor_id'));
      stubRecoverFullSend(
        const NIP17SendResult.failure(
          'no relays',
          retryablePending: true,
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => dmRepository.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();

      // A parked rumor's tags are frozen at build time and replayed verbatim,
      // so re-driving after the user changed their mind would ship the
      // superseded NIP-32 label while the kind-1984 republish carries the new
      // one. Cancel and enqueue a correct one instead.
      await cubit.submit(
        reason: ContentFilterReason.harassment,
        reasonTitle: 'Harassment',
        details: 'Harassment',
      );
      await pumpEventQueue();

      verify(
        () => dmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
      ).called(1);
      // Two enqueues: the original, then a fresh one after the stale row was
      // cancelled — never a re-drive of the stale row.
      verifyEnqueueSendCalled(2);
    });

    test('stops sending once a parked row becomes unreachable (#6610)', () async {
      stubEnqueueSend(const EnqueueSendResult.enqueued('parked_rumor_id'));
      // The background drive cannot resolve the row. recoverFullSend is async,
      // so an ArgumentError arrives as a rejected future, not a sync throw.
      when(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer((_) async => throw ArgumentError('no such outgoing send'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();
      expect(
        cubit.state.moderationDm.outcome,
        ModerationDmOutcome.unverifiable,
      );

      // Unverifiable is terminal: a resubmit must not mint the #6610 duplicate.
      await submit(cubit);
      await pumpEventQueue();
      verifyEnqueueSendCalled(1);
    });

    test('does not enqueue the DM twice for an unchanged resubmit', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await pumpEventQueue();
      await submit(cubit);
      await pumpEventQueue();

      // The kind-1984 republishes deliberately; the DM is the report itself,
      // so a second copy is a second ticket to triage (#6610). Once the first
      // DM is delivered, a plain resubmit sends no second copy.
      verify(
        () => reportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
      verifyEnqueueSendCalled(1);
    });
  });
}
