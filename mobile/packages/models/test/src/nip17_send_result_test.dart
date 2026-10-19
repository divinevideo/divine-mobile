// ABOUTME: Tests for NIP17SendResult including the per-wrap status
// ABOUTME: that surfaces partial delivery (recipient delivered but
// ABOUTME: self-wrap dropped) and its durable recovery queue handle.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  const rumorEventId =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const messageEventId =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const recipientPubkey =
      '3333333333333333333333333333333333333333333333333333333333333333';

  group(NIP17SendResult, () {
    group('success factory', () {
      test('defaults selfWrapPublished to true for backward compatibility', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, equals(rumorEventId));
        expect(result.messageEventId, equals(messageEventId));
        expect(result.recipientPubkey, equals(recipientPubkey));
        expect(result.error, isNull);
        expect(result.timestamp, isNotNull);
        expect(
          result.selfWrapPublished,
          isTrue,
          reason:
              'Pre-existing call sites do not pass selfWrapPublished. '
              'The default must keep them in the fully-delivered state '
              'to avoid spurious "partial delivery" UX after the field '
              'was added.',
        );
      });

      test('preserves selfWrapPublished=false when explicitly passed '
          '(NIP17MessageService partial-delivery path)', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
        );

        expect(result.success, isTrue);
        expect(result.selfWrapPublished, isFalse);
      });

      test('carries a surviving queue handle for partial recovery', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
          queuedRumorId: 'queue-handle',
        );

        expect(result.queuedRumorId, equals('queue-handle'));
      });
    });

    group('failure factory', () {
      test('builds a failure result with error and no message ids', () {
        const result = NIP17SendResult.failure('publish to relays failed');

        expect(result.success, isFalse);
        expect(result.error, equals('publish to relays failed'));
        expect(result.rumorEventId, isNull);
        expect(result.messageEventId, isNull);
        expect(result.recipientPubkey, isNull);
        expect(result.timestamp, isNull);
      });

      test('defaults retryablePending and blocked to false', () {
        const result = NIP17SendResult.failure('boom');

        expect(result.retryablePending, isFalse);
        expect(result.blocked, isFalse);
      });

      test('preserves retryablePending=true when explicitly passed — the '
          'soft unconfirmed case reaction callers keep sweep-retryable', () {
        const result = NIP17SendResult.failure(
          'recipient OK unconfirmed',
          retryablePending: true,
        );

        expect(result.success, isFalse);
        expect(result.retryablePending, isTrue);
        expect(
          result.blocked,
          isFalse,
          reason: 'A soft unconfirmed failure is not a policy block.',
        );
      });

      test('success and blocked never report retryablePending', () {
        final success = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );
        const blocked = NIP17SendResult.blocked('policy');

        expect(success.retryablePending, isFalse);
        expect(blocked.retryablePending, isFalse);
      });

      test('carries the queued row id when the send parked one, so a retry '
          'can re-drive that row instead of enqueuing a second', () {
        const result = NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'rumor_abc',
        );

        expect(result.queuedRumorId, equals('rumor_abc'));
      });

      test('defaults queuedRumorId to null — a send that parked no row has '
          'nothing for a caller to coalesce onto', () {
        const result = NIP17SendResult.failure('boom');

        expect(result.queuedRumorId, isNull);
      });

      test('full success and blocked never carry a queuedRumorId', () {
        final success = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );
        const blocked = NIP17SendResult.blocked('policy');

        expect(success.queuedRumorId, isNull);
        expect(blocked.queuedRumorId, isNull);
      });

      test('reports a send that reached no relay, so a retry sweep can '
          'leave it uncounted (#8516)', () {
        const unreached = NIP17SendResult.failure(
          'Reaction not sent: no relay reached',
          reachedNoRelay: true,
        );
        const rejected = NIP17SendResult.failure('rejected by relay');

        expect(unreached.reachedNoRelay, isTrue);
        expect(rejected.reachedNoRelay, isFalse);
      });

      test('success, blocked and tooLong never report reaching no relay', () {
        final success = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );
        const blocked = NIP17SendResult.blocked('policy');
        const tooLong = NIP17SendResult.tooLong('too long');

        expect(success.reachedNoRelay, isFalse);
        expect(blocked.reachedNoRelay, isFalse);
        expect(tooLong.reachedNoRelay, isFalse);
      });
    });

    group('blocked factory', () {
      test('is a non-retryable failure distinct from a transient one', () {
        const result = NIP17SendResult.blocked('policy refused recipient');

        expect(result.success, isFalse);
        expect(result.blocked, isTrue);
        expect(result.retryablePending, isFalse);
        expect(result.error, equals('policy refused recipient'));
      });

      test('leaves selfWrapPublished as null on the failure branch — the '
          'field is meaningful only when success is true (self-wrap is '
          'never attempted when the recipient publish fails)', () {
        const result = NIP17SendResult.failure('publish to relays failed');

        expect(result.success, isFalse);
        // Sealed shape: NIP17SendFailure has no `selfWrapPublished`
        // field; the base getter returns `null`. A failure cannot
        // carry a misleading success-like `true` because the field
        // does not exist on this branch.
        expect(result.selfWrapPublished, isNull);
      });
    });

    group('toString', () {
      test('success path includes selfWrapPublished status', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
        );

        expect(result.toString(), contains('selfWrapPublished: false'));
        expect(result.toString(), startsWith('NIP17SendSuccess('));
      });

      test('failure path omits selfWrapPublished and shows error', () {
        const result = NIP17SendResult.failure('relay timeout');

        expect(result.toString(), startsWith('NIP17SendFailure('));
        expect(result.toString(), contains('error: relay timeout'));
        expect(result.toString(), isNot(contains('selfWrapPublished')));
      });

      test('failure path surfaces blocked and retryablePending so a '
          'regression dropping either from the shape is visible', () {
        const soft = NIP17SendResult.failure(
          'unconfirmed',
          retryablePending: true,
        );
        const blocked = NIP17SendResult.blocked('policy');

        expect(soft.toString(), contains('retryablePending: true'));
        expect(soft.toString(), contains('blocked: false'));
        expect(blocked.toString(), contains('blocked: true'));
        expect(blocked.toString(), contains('retryablePending: false'));
      });

      test('failure path surfaces the parked queue row — a report of "not '
          'delivered" is only actionable alongside the row to re-drive', () {
        const parked = NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'rumor_abc',
        );

        expect(parked.toString(), contains('queuedRumorId: rumor_abc'));
      });
    });

    group('sealed shape', () {
      test('NIP17SendSuccess requires non-null selfWrapPublished at '
          'compile time — pin a runtime example so the test breaks '
          'loudly if someone changes the parameter to a default later', () {
        const result = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
        );

        expect(result.selfWrapPublished, isTrue);
        expect(result.success, isTrue);
        expect(result, isA<NIP17SendResult>());
      });

      test('NIP17SendFailure does not expose selfWrapPublished', () {
        const result = NIP17SendFailure('boom');

        expect(result.selfWrapPublished, isNull);
        expect(result.success, isFalse);
        expect(result.error, equals('boom'));
        expect(result, isA<NIP17SendResult>());
      });

      test('factories produce the matching subclass', () {
        final success = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );
        expect(success, isA<NIP17SendSuccess>());
        expect(success, isNot(isA<NIP17SendFailure>()));

        const failure = NIP17SendResult.failure('boom');
        expect(failure, isA<NIP17SendFailure>());
        expect(failure, isNot(isA<NIP17SendSuccess>()));
      });

      test('exhaustive switch at the use site compiles and discriminates '
          'the variant', () {
        const result = NIP17SendResult.failure('x');
        final label = switch (result) {
          NIP17SendSuccess() => 'ok',
          NIP17SendFailure() => 'err',
        };
        expect(label, equals('err'));
      });

      test('value equality: identical successes are equal', () {
        final timestamp = DateTime(2026, 5, 7);
        final a = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );
        final b = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('value equality: differing selfWrapPublished breaks equality', () {
        final timestamp = DateTime(2026, 5, 7);
        final fully = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );
        final partially = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
          timestamp: timestamp,
        );

        expect(fully, isNot(equals(partially)));
      });

      test('value equality: failures with same error are equal', () {
        expect(
          const NIP17SendFailure('boom'),
          equals(const NIP17SendFailure('boom')),
        );
        expect(
          const NIP17SendFailure('boom').hashCode,
          equals(const NIP17SendFailure('boom').hashCode),
        );
      });

      test('value equality: differing retryablePending breaks equality '
          '(the field participates in == and hashCode)', () {
        const hard = NIP17SendFailure('boom');
        const soft = NIP17SendFailure('boom', retryablePending: true);

        expect(hard, isNot(equals(soft)));
        expect(hard.hashCode, isNot(equals(soft.hashCode)));
      });

      test('value equality: differing reachedNoRelay breaks equality', () {
        const reached = NIP17SendFailure('boom');
        const unreached = NIP17SendFailure('boom', reachedNoRelay: true);

        expect(reached, isNot(equals(unreached)));
        expect(reached.hashCode, isNot(equals(unreached.hashCode)));
        expect(unreached.toString(), contains('reachedNoRelay: true'));
      });

      test('value equality: differing queuedRumorId breaks equality — two '
          'failures parking different rows are not interchangeable', () {
        const unparked = NIP17SendFailure('boom');
        const parked = NIP17SendFailure('boom', queuedRumorId: 'rumor_abc');
        const other = NIP17SendFailure('boom', queuedRumorId: 'rumor_xyz');

        expect(unparked, isNot(equals(parked)));
        expect(unparked.hashCode, isNot(equals(parked.hashCode)));
        expect(parked, isNot(equals(other)));
        expect(parked.hashCode, isNot(equals(other.hashCode)));
      });

      test('value equality: blocked and transient failures with the same '
          'error are never equal (the blocked field participates in ==)', () {
        const transient = NIP17SendFailure('policy');
        const blocked = NIP17SendFailure.blocked('policy');

        expect(transient, isNot(equals(blocked)));
        expect(transient.hashCode, isNot(equals(blocked.hashCode)));
      });

      test('blocked disposition defaults to discard and participates in '
          'value equality', () {
        const discard = NIP17SendFailure.blocked('policy');
        const retain = NIP17SendFailure.blocked(
          'policy',
          disposition: NIP17BlockedSendDisposition.retain,
        );

        expect(
          discard.blockedDisposition,
          NIP17BlockedSendDisposition.discard,
        );
        expect(retain.blockedDisposition, NIP17BlockedSendDisposition.retain);
        expect(discard, isNot(equals(retain)));
        expect(discard.hashCode, isNot(equals(retain.hashCode)));
      });

      test('value equality: success and failure are never equal', () {
        final success = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: DateTime(2026, 5, 7),
        );
        const failure = NIP17SendFailure('boom');

        expect(success, isNot(equals(failure)));
        expect(failure, isNot(equals(success)));
      });
    });

    group('tooLong factory', () {
      test('is a non-retriable failure distinct from blocked', () {
        const result = NIP17SendResult.tooLong('too big');

        expect(result.success, isFalse);
        expect(result.tooLong, isTrue);
        expect(result.blocked, isFalse);
        expect(result.retryablePending, isFalse);
      });

      test('carries no queue row, so the retry sweep cannot re-drive it', () {
        // The size check runs before the enqueue on purpose: a hard-failed row
        // is re-driven by OutgoingDmRetryService.sweep(), and an oversized
        // send fails identically every time (#7331).
        const result = NIP17SendResult.tooLong('too big');

        expect(result.queuedRumorId, isNull);
        expect(result.selfWrapPublished, isNull);
      });

      test('does not equal a blocked failure carrying the same error', () {
        const tooLong = NIP17SendResult.tooLong('same');
        const blocked = NIP17SendResult.blocked('same');

        expect(tooLong, isNot(equals(blocked)));
        expect(blocked, isNot(equals(tooLong)));
      });

      test('does not equal a plain failure carrying the same error', () {
        const tooLong = NIP17SendResult.tooLong('same');
        const plain = NIP17SendResult.failure('same');

        expect(tooLong, isNot(equals(plain)));
      });

      test('toString surfaces tooLong so a report is unambiguous', () {
        const result = NIP17SendResult.tooLong('over the limit');

        expect(result.toString(), contains('tooLong: true'));
      });

      test('blocked, plain failure and success are never tooLong', () {
        final success = NIP17SendResult.success(
          rumorEventId: 'r',
          messageEventId: 'm',
          recipientPubkey: 'p',
        );

        expect(const NIP17SendResult.blocked('x').tooLong, isFalse);
        expect(const NIP17SendResult.failure('x').tooLong, isFalse);
        expect(success.tooLong, isFalse);
      });
    });
  });
}
