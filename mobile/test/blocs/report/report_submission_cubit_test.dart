// ABOUTME: Report acceptance, immutable snapshots, and duplicate-submit guards.
// ABOUTME: Network delivery is owned by the durable queue after this cubit closes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/report/report_submission_cubit.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';

class _Service extends Mock implements ContentReportingService {}

void main() {
  late _Service service;
  const target = ReportTarget(
    eventId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    authorPubkey:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    moderationKindLabel: 'Content Report',
    moderationEventLabel: 'Event',
    sourceRelay: 'wss://source.example',
    sha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  );
  setUpAll(() => registerFallbackValue(ContentFilterReason.spam));
  setUp(() {
    service = _Service();
    when(
      () => service.reportContent(
        eventId: any(named: 'eventId'),
        authorPubkey: any(named: 'authorPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        sourceRelay: any(named: 'sourceRelay'),
        moderationContent: any(named: 'moderationContent'),
        moderationTags: any(named: 'moderationTags'),
      ),
    ).thenAnswer(
      (_) async =>
          ReportResult.createSuccess('report', delivery: ReportDelivery.queued),
    );
  });
  ReportSubmissionCubit build({ReportTarget reportTarget = target}) =>
      ReportSubmissionCubit(
        resolveContentReportingService: () async => service,
        target: reportTarget,
      );
  Future<void> submit(ReportSubmissionCubit cubit) => cubit.submit(
    reason: ContentFilterReason.aiGenerated,
    reasonTitle: 'AI-generated',
    details: 'My report',
  );

  group('submit', () {
    test(
      'accepts queued delivery with the same snapshot for every channel',
      () async {
        final cubit = build();
        addTearDown(cubit.close);
        await submit(cubit);
        expect(cubit.state.status, ReportSubmissionStatus.submitted);
        final args = verify(
          () => service.reportContent(
            eventId: target.eventId,
            authorPubkey: target.authorPubkey,
            reason: ContentFilterReason.aiGenerated,
            details: 'My report',
            sourceRelay: target.sourceRelay,
            moderationContent: captureAny(named: 'moderationContent'),
            moderationTags: captureAny(named: 'moderationTags'),
          ),
        ).captured;
        expect(
          args.whereType<String>().single,
          contains('Reason: AI-generated'),
        );
        expect(
          args.whereType<String>().single,
          contains('Event: ${target.eventId}'),
        );
        expect(args.whereType<String>().single, contains('Details: My report'));
        expect(
          args.whereType<List>().single,
          contains(equals(['sha256', target.sha256])),
        );
        expect(
          args.whereType<List>().single,
          contains(equals(['l', 'NS-aiGenerated', 'social.nos.ontology'])),
        );
      },
    );

    test(
      'coalesces rapid taps and cannot resubmit an accepted report',
      () async {
        final pending = Completer<ReportResult>();
        var calls = 0;
        when(
          () => service.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer((_) {
          calls++;
          return pending.future;
        });
        final cubit = build();
        addTearDown(cubit.close);
        final first = submit(cubit);
        await submit(cubit);
        expect(cubit.state.status, ReportSubmissionStatus.submitting);
        pending.complete(
          ReportResult.createSuccess('report', delivery: ReportDelivery.queued),
        );
        await first;
        await submit(cubit);
        expect(calls, 1);
        expect(cubit.state.status, ReportSubmissionStatus.submitted);
      },
    );

    test(
      'a failed disk write keeps submit available for a corrected retry',
      () async {
        var calls = 0;
        when(
          () => service.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer(
          (_) async => calls++ == 0
              ? ReportResult.failure('disk full')
              : ReportResult.createSuccess(
                  'report',
                  delivery: ReportDelivery.queued,
                ),
        );
        final cubit = build();
        addTearDown(cubit.close);
        await submit(cubit);
        expect(cubit.state.status, ReportSubmissionStatus.failure);
        await submit(cubit);
        expect(cubit.state.status, ReportSubmissionStatus.submitted);
        expect(calls, 2);
      },
    );

    test(
      'closing while enqueue finishes does not cancel the accepted intent',
      () async {
        final pending = Completer<ReportResult>();
        when(
          () => service.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer((_) => pending.future);
        final cubit = build();
        final submission = submit(cubit);
        await cubit.close();
        pending.complete(
          ReportResult.createSuccess('report', delivery: ReportDelivery.queued),
        );
        await expectLater(submission, completes);
      },
    );

    test(
      'user reports retain user labels and never inherit a video hash',
      () async {
        when(
          () => service.reportUser(
            userPubkey: any(named: 'userPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer(
          (_) async => ReportResult.createSuccess(
            'report',
            delivery: ReportDelivery.queued,
          ),
        );
        final cubit = build(
          reportTarget: ReportTarget(
            eventId: 'user_${target.authorPubkey}',
            authorPubkey: target.authorPubkey,
            userPubkey: target.authorPubkey,
            sha256: target.sha256,
            moderationKindLabel: 'User Report',
            moderationEventLabel: 'User Pubkey',
          ),
        );
        addTearDown(cubit.close);
        await submit(cubit);
        final args = verify(
          () => service.reportUser(
            userPubkey: target.authorPubkey,
            reason: ContentFilterReason.aiGenerated,
            details: 'My report',
            moderationContent: captureAny(named: 'moderationContent'),
            moderationTags: captureAny(named: 'moderationTags'),
          ),
        ).captured;
        expect(args.whereType<String>().single, startsWith('User Report'));
        expect(
          args.whereType<List>().single.where(
            (tag) => (tag as List).first == 'sha256',
          ),
          isEmpty,
        );
      },
    );
  });
}
