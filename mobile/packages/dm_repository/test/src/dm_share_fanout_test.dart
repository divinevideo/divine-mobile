// ABOUTME: Shared videos persist independent one-to-one rumors as one batch.
// ABOUTME: Exercises SQLite rollback, policy refusals and session boundaries.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:dm_repository/src/dm_shared_video_citation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage, NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _Client extends Mock implements NostrClient {}

class _Queue extends OutgoingDmsDao {
  _Queue(super.attachedDatabase);

  int commits = 0;
  void Function()? afterFirstInsert;
  Future<void> Function()? afterCommit;

  @override
  Future<void> enqueueAll(
    List<OutgoingDm> rows, {
    required bool Function() isCurrent,
  }) async {
    var checks = 0;
    await super.enqueueAll(
      rows,
      isCurrent: () {
        if (++checks == 2) afterFirstInsert?.call();
        return isCurrent();
      },
    );
    commits++;
    await afterCommit?.call();
  }
}

void main() {
  final owner = 'aa' * 32;
  final peers = [
    for (final byte in ['bb', 'cc', 'dd']) byte * 32,
  ];
  final signer = LocalNostrSigner('01' * 32);
  late AppDatabase db;
  late _Queue queue;
  late DmRepository repo;
  late _Client client;

  DmRepository build({
    OutgoingDmsDao? dao,
    DmSendPolicy? policy,
    bool Function(String)? isHidden,
    OfflineProbe? isOffline,
  }) {
    client = _Client();
    when(() => client.connectedRelayCount).thenReturn(0);
    when(() => client.configuredRelayCount).thenReturn(0);
    return DmRepository(
      nostrClient: client,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: owner,
        nostrService: client,
        sendPolicy: policy,
        isOffline: isOffline,
      ),
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: dao,
      isShareRecipientHidden: isHidden,
      signer: signer,
      userPubkey: owner,
      environment: 'staging',
    );
  }

  void switchAccount() {
    final nextOwner = 'ee' * 32;
    repo.setCredentials(
      userPubkey: nextOwner,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: nextOwner,
        nostrService: client,
      ),
    );
  }

  Future<Map<String, ShareEnqueueOutcome>> share(
    List<String> recipients, {
    String content = 'See https://divine.video/video',
  }) => repo.enqueueSharedVideoBatch(
    recipientPubkeys: recipients,
    baseContent: content,
    videoAuthorPubkey: owner,
    videoKind: 34236,
    videoDTag: 'shared-video',
  );

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    queue = _Queue(db);
    repo = build(dao: queue);
  });

  tearDown(() async {
    await repo.stopListening();
    await db.close();
  });

  group('enqueueSharedVideoBatch', () {
    test(
      'deduplicates and stores three distinct rumors in one commit',
      () async {
        // Ending the session on commit models the app closing at the handoff:
        // no original transport can take these rows from the recovery sweep.
        queue.afterCommit = repo.stopListening;
        final result = await share([
          ' ${peers.first.toUpperCase()} ',
          ...peers,
        ]);
        expect(queue.commits, 1);
        expect(result.keys, peers);
        final rows = await queue.getStillPendingForOwner(owner);
        expect(rows.map((row) => row.id).toSet(), hasLength(3));
        for (final row in rows) {
          final queued = result[row.recipientPubkey]! as ShareEnqueueQueued;
          expect(queued.rumorId, row.id);
          expect(queued.conversationId, row.conversationId);
          expect(row.environment, 'staging');
          expect(row.content, contains('nostr:naddr'));
          final wire = jsonDecode(row.rumorEventJson) as Map<String, dynamic>;
          expect(wire['tags'], contains(contains('q')));
        }
      },
    );

    test('a share rechecks block and mute eligibility after restart', () async {
      repo = build(dao: queue, isHidden: (recipient) => recipient == peers[1]);
      queue.afterCommit = repo.stopListening;
      final outcomes = await share(peers.take(2).toList());
      expect(outcomes[peers[1]], isA<ShareEnqueueBlocked>());
      final queued = outcomes[peers.first]! as ShareEnqueueQueued;
      expect((await queue.getById(queued.rumorId))!.isVideoShare, isTrue);
      final reopened = build(dao: queue, isHidden: (_) => true);
      addTearDown(reopened.stopListening);
      final result = await reopened.recoverFullSend(rumorId: queued.rumorId);
      expect(result.blocked, isTrue);
      expect(
        (await queue.getById(queued.rumorId))!.recipientWrapStatus,
        OutgoingWrapStatus.blocked,
      );
    });

    test('refusals produce no rows and retain other queued outcomes', () async {
      repo = build(
        dao: queue,
        policy: (p) async => p == peers.last
            ? DmSendPolicyDecision.terminallyBlockedRetain
            : DmSendPolicyDecision.allowed,
      );
      queue.afterCommit = repo.stopListening;
      final result = await share([peers.first, peers.last, owner]);
      expect(result[peers.first], isA<ShareEnqueueQueued>());
      expect(result[peers.last], isA<ShareEnqueueBlocked>());
      expect(result[owner], isA<ShareEnqueueRefused>());
      expect(
        (await queue.getAllForOwner(owner)).single.recipientPubkey,
        peers.first,
      );
    });

    test(
      'delivery waits for the batch and does not hold local confirmation',
      () async {
        final committed = Completer<void>();
        final releaseCommit = Completer<void>();
        final releaseTransport = Completer<bool>();
        final transportStarted = Completer<void>();
        queue.afterCommit = () async {
          committed.complete();
          await releaseCommit.future;
        };
        repo = build(
          dao: queue,
          isOffline: () {
            if (!transportStarted.isCompleted) transportStarted.complete();
            return releaseTransport.future;
          },
        );
        final pending = share(peers);
        await committed.future;
        expect(transportStarted.isCompleted, isFalse);
        releaseCommit.complete();
        final result = await pending;
        await transportStarted.future;
        expect(await queue.getStillPendingForOwner(owner), hasLength(3));
        final attempts = [
          for (final outcome in result.values.whereType<ShareEnqueueQueued>())
            repo.recoverFullSend(rumorId: outcome.rumorId),
        ];
        releaseTransport.complete(true);
        for (final attempt in attempts) {
          expect((await attempt).reachedNoRelay, isTrue);
        }
      },
    );

    test('oversized content parks no intent', () async {
      final result = await share(peers, content: 'a' * maxDmRumorBytes);
      expect(result.values, everyElement(isA<ShareEnqueueTooLong>()));
      expect(queue.commits, 0);
    });

    test('missing outbox refuses to start delivery', () async {
      repo = build();
      await expectLater(share(peers), throwsStateError);
    });

    test('throw during preparation leaves zero rows', () async {
      repo = build(
        dao: queue,
        policy: (p) async {
          if (p == peers.last) throw StateError('policy unavailable');
          return DmSendPolicyDecision.allowed;
        },
      );
      await expectLater(share(peers), throwsStateError);
      expect(queue.commits, 0);
      expect(await queue.getAllForOwner(owner), isEmpty);
    });

    test('session change during policy evaluation abandons all rows', () async {
      final checking = Completer<void>();
      final release = Completer<void>();
      repo = build(
        dao: queue,
        policy: (p) async {
          if (p == peers.last) {
            checking.complete();
            await release.future;
          }
          return DmSendPolicyDecision.allowed;
        },
      );
      final pending = share(peers);
      await checking.future;
      switchAccount();
      release.complete();
      await expectLater(pending, throwsA(isA<ShareSessionEndedException>()));
      expect(queue.commits, 0);
      expect(await queue.getAllForOwner(owner), isEmpty);
    });

    test('session change during transaction rolls back every row', () async {
      queue.afterFirstInsert = switchAccount;
      await expectLater(
        share(peers),
        throwsA(isA<ShareSessionEndedException>()),
      );
      expect(queue.commits, 0);
      expect(await queue.getAllForOwner(owner), isEmpty);
    });
  });

  group('recoverFullSend share classification', () {
    // A point on the curve, so a send that is not refused builds its gift
    // wrap and stops at the offline probe instead of failing earlier.
    final recipient = peers.last;
    final citation = DmSharedVideoCitation.build(
      videoKind: 34236,
      authorPubkey: owner,
      relayHint: 'wss://relay.example.com',
      dTag: 'shared-video',
    )!;

    Future<String> parkUnflagged({
      String? replyToId,
      List<List<String>> extraTags = const [],
    }) async {
      final queued = await repo.enqueueSend(
        recipientPubkey: recipient,
        content: 'See https://divine.video/video\n${citation.nostrUri}',
        replyToId: replyToId,
        additionalTags: [citation.qTag, ...extraTags],
      );
      final id = queued.queuedRumorId!;
      expect((await queue.getById(id))!.isVideoShare, isFalse);
      return id;
    }

    Future<NIP17SendResult> recoverWhileHidden(String rumorId) {
      final reopened = build(
        dao: queue,
        isHidden: (_) => true,
        isOffline: () async => true,
      );
      addTearDown(reopened.stopListening);
      return reopened.recoverFullSend(rumorId: rumorId);
    }

    test('a share-sheet row queued before the flag is rechecked', () async {
      final id = await parkUnflagged();

      final result = await recoverWhileHidden(id);

      expect(result.blocked, isTrue);
      expect(
        (await queue.getById(id))!.recipientWrapStatus,
        OutgoingWrapStatus.blocked,
      );
    });

    test('a reel reply citing the video is not refused', () async {
      final id = await parkUnflagged(replyToId: 'e' * 64);

      final result = await recoverWhileHidden(id);

      expect(result.blocked, isFalse);
      expect(result.reachedNoRelay, isTrue);
      expect(
        (await queue.getById(id))!.recipientWrapStatus,
        isNot(OutgoingWrapStatus.blocked),
      );
    });

    test('a question answer citing the video is not refused', () async {
      final id = await parkUnflagged(
        extraTags: [
          [DmMessage.questionTagName, 'Where was this filmed?'],
        ],
      );

      final result = await recoverWhileHidden(id);

      expect(result.blocked, isFalse);
      expect(result.reachedNoRelay, isTrue);
    });
  });
}
