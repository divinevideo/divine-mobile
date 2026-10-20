// ABOUTME: Reproduction test for the offline-send "no live repaint" bug.
// ABOUTME: Drives ConversationBloc off a REAL OutgoingDmsDao on an in-memory
// ABOUTME: AppDatabase; a pending->failed transition on the same rumor id must
// ABOUTME: re-emit so the per-bubble statusFor flips to failed live.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const recipientPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conversationId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const rumorId =
      '4444444444444444444444444444444444444444444444444444444444444444';

  OutgoingDm pendingRow() => OutgoingDm(
    id: rumorId,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    content: 'sent while offline',
    createdAt: 1700000000,
    rumorEventJson: '{"id":"$rumorId","kind":14,"content":"offline"}',
    recipientWrapStatus: OutgoingWrapStatus.pending,
    selfWrapStatus: OutgoingWrapStatus.pending,
    queuedAt: DateTime.utc(2026, 5),
    ownerPubkey: ownerPubkey,
  );

  late AppDatabase db;
  late OutgoingDmsDao dao;
  late _MockDmRepository repo;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    dao = db.outgoingDmsDao;
    repo = _MockDmRepository();

    when(
      () => repo.markConversationAsRead(any()),
    ).thenAnswer((_) async => true);
    // Opening a conversation arms the one-time history drain.
    when(() => repo.backfillHistoryIfNeeded()).thenAnswer((_) async {});
    // A credentialed repository: the bloc holds its loading state while the
    // owner is unknown (#8187), which is not the scenario under test here.
    when(() => repo.userPubkey).thenReturn(ownerPubkey);
    // Persisted-message stream stays empty and stable; the outgoing queue
    // drives every tick — exactly the open-conversation scenario in the bug.
    when(
      () => repo.watchMessages(any()),
    ).thenAnswer((_) => Stream<List<DmMessage>>.value(const []));
    // Real DAO-backed durable queue stream, scoped to this owner.
    when(() => repo.watchOutgoing(any())).thenAnswer(
      (_) => dao.watchForConversation(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group(ConversationBloc, () {
    // Sanity: the raw DAO stream IS reactive across the transition. This
    // isolates the failure to the bloc/state layer if the bloc test fails.
    test(
      'raw OutgoingDmsDao stream re-emits the failed row (DB layer is reactive)',
      () async {
        final seen = <DmDeliveryStatusProbe>[];
        final sub = dao
            .watchForConversation(
              conversationId: conversationId,
              ownerPubkey: ownerPubkey,
            )
            .listen((rows) {
              final matches = rows.where((r) => r.id == rumorId).toList();
              seen.add(
                DmDeliveryStatusProbe(
                  matches.isEmpty ? null : matches.first.recipientWrapStatus,
                ),
              );
            });

        await dao.enqueue(pendingRow());
        await pumpEventQueue();

        await dao.markRecipientWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'device offline',
        );
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'device offline',
        );
        await pumpEventQueue();
        await sub.cancel();

        expect(
          seen.any((p) => p.status == OutgoingWrapStatus.failed),
          isTrue,
          reason: 'DAO watch stream must emit the failed row',
        );
      },
    );

    test(
      'ConversationBloc live-repaints when the open conversation row goes '
      'pending -> failed (offline hard-fail)',
      () async {
        final bloc = ConversationBloc(
          dmRepository: repo,
          conversationId: conversationId,
        );
        addTearDown(bloc.close);

        // Row is enqueued (pending) before the conversation opens, mirroring
        // sendMessage enqueueing before the signer round-trip.
        await dao.enqueue(pendingRow());

        bloc.add(const ConversationStarted());

        // Wait until the pending bubble is projected into state.
        await bloc.stream
            .firstWhere(
              (s) =>
                  s.status == ConversationStatus.loaded &&
                  s.statusFor(rumorId) == DmDeliveryStatus.pending,
            )
            .timeout(const Duration(seconds: 5));
        expect(bloc.state.statusFor(rumorId), DmDeliveryStatus.pending);

        // The offline classifier hard-fails: DmRepository marks BOTH wraps
        // failed on the durable row (this is _finalizeAfterRecipientFailure).
        await dao.markRecipientWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'device offline',
        );
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'device offline',
        );

        // The live, open conversation MUST repaint the red "Not delivered":
        // statusFor(rumorId) must flip to failed without a fresh read.
        final repainted = await bloc.stream
            .firstWhere(
              (s) => s.statusFor(rumorId) == DmDeliveryStatus.failed,
            )
            .then((_) => true)
            .timeout(const Duration(seconds: 3), onTimeout: () => false);

        expect(
          repainted,
          isTrue,
          reason:
              'Bloc never re-emitted with statusFor(rumorId)==failed. The '
              'watch tick carrying the failed row produced a ConversationState '
              'that compares equal to the pending one (OutgoingDm.== is id-only, '
              'so Equatable treats [pending row] == [failed row]), and Bloc.emit '
              'suppressed it. The red bubble only appears on a fresh read.',
        );
        expect(bloc.state.statusFor(rumorId), DmDeliveryStatus.failed);
      },
    );
  });
}

/// Tiny wrapper so the sanity-check list is readable in failure output.
class DmDeliveryStatusProbe {
  DmDeliveryStatusProbe(this.status);
  final OutgoingWrapStatus? status;
  @override
  String toString() => 'probe(${status?.name ?? 'absent'})';
}
