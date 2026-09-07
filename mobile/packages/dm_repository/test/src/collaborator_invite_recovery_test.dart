import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _StubDmRepository extends DmRepository {
  _StubDmRepository({
    required super.nostrClient,
    required super.directMessagesDao,
    required super.conversationsDao,
    required super.outgoingDmsDao,
    required this.onRecoverFullSend,
    super.errorReporter,
  });

  final Future<NIP17SendResult> Function(String rumorId) onRecoverFullSend;

  @override
  Future<NIP17SendResult> recoverFullSend({
    required String rumorId,
    bool resetRetryBudget = false,
  }) {
    return onRecoverFullSend(rumorId);
  }
}

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaboratorA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collaboratorB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _videoAddress = '34236:$_ownerPubkey:video:1';

OutgoingDm _inviteRow({
  required String id,
  required String collaboratorPubkey,
  required OutgoingWrapStatus recipient,
  required OutgoingWrapStatus self,
  DateTime? queuedAt,
  String videoAddress = _videoAddress,
}) {
  final rumor = Event(_ownerPubkey, 14, [
    [CollaboratorInviteTags.pubkey, collaboratorPubkey],
    [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
    [
      CollaboratorInviteTags.address,
      videoAddress,
      'wss://relay.divine.video',
      'root',
    ],
    [CollaboratorInviteTags.pubkey, _ownerPubkey],
    [CollaboratorInviteTags.role, CollaboratorInviteTags.collaboratorRole],
    [CollaboratorInviteTags.title, 'Beach post'],
    [CollaboratorInviteTags.thumbnail, 'https://cdn.divine.video/thumb.jpg'],
  ], 'invite');
  return OutgoingDm(
    id: id,
    conversationId: 'conv:$id',
    recipientPubkey: collaboratorPubkey,
    content: 'invite',
    createdAt: rumor.createdAt,
    rumorEventJson: jsonEncode(rumor.toJson()),
    recipientWrapStatus: recipient,
    selfWrapStatus: self,
    queuedAt: queuedAt ?? DateTime.utc(2026, 5, 22, 13),
    ownerPubkey: _ownerPubkey,
  );
}

OutgoingDm _plainDmRow() {
  final rumor = Event(_ownerPubkey, 14, [
    [CollaboratorInviteTags.pubkey, _collaboratorA],
  ], 'hello');
  return OutgoingDm(
    id: 'plain',
    conversationId: 'conv:plain',
    recipientPubkey: _collaboratorA,
    content: 'hello',
    createdAt: rumor.createdAt,
    rumorEventJson: jsonEncode(rumor.toJson()),
    recipientWrapStatus: OutgoingWrapStatus.failed,
    selfWrapStatus: OutgoingWrapStatus.failed,
    queuedAt: DateTime.utc(2026, 5, 22, 13),
    ownerPubkey: _ownerPubkey,
  );
}

void main() {
  late _MockNostrClient nostrClient;
  late _MockDirectMessagesDao directMessagesDao;
  late _MockConversationsDao conversationsDao;
  late _MockOutgoingDmsDao outgoingDmsDao;
  late _MockNostrSigner signer;
  late NIP17MessageService messageService;
  late Future<NIP17SendResult> Function(String rumorId) recoverFullSendHandler;
  late _StubDmRepository repository;
  late List<({Object error, StackTrace stackTrace, String site})>
  reportedErrors;

  setUp(() {
    nostrClient = _MockNostrClient();
    directMessagesDao = _MockDirectMessagesDao();
    conversationsDao = _MockConversationsDao();
    outgoingDmsDao = _MockOutgoingDmsDao();
    signer = _MockNostrSigner();
    messageService = NIP17MessageService(
      signer: signer,
      senderPublicKey: _ownerPubkey,
      nostrService: nostrClient,
    );
    when(
      () => conversationsDao.getAllConversations(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => const <ConversationRow>[]);
    when(
      () => conversationsDao.getConversation(
        any(),
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => conversationsDao.backfillCurrentUserHasSent(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => conversationsDao.backfillLatestMessagePreviews(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => 0);
    reportedErrors = [];
    recoverFullSendHandler = (rumorId) async => NIP17SendResult.success(
      rumorEventId: rumorId,
      messageEventId: 'wrap:$rumorId',
      recipientPubkey: _collaboratorA,
    );
    repository =
        _StubDmRepository(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          outgoingDmsDao: outgoingDmsDao,
          onRecoverFullSend: (rumorId) => recoverFullSendHandler(rumorId),
          errorReporter: (error, stackTrace, {required site}) {
            reportedErrors.add((
              error: error,
              stackTrace: stackTrace,
              site: site,
            ));
          },
        )..setCredentials(
          userPubkey: _ownerPubkey,
          signer: signer,
          messageService: messageService,
        );
  });

  group('watchPendingCollaboratorInviteGroups', () {
    test(
      'watchPendingCollaboratorInviteGroups emits only unresolved '
      'collaborator invites',
      () async {
        when(() => outgoingDmsDao.watchAllForOwner(_ownerPubkey)).thenAnswer(
          (_) => Stream.value([
            _inviteRow(
              id: 'failed-a',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _inviteRow(
              id: 'pending-b',
              collaboratorPubkey: _collaboratorB,
              recipient: OutgoingWrapStatus.pending,
              self: OutgoingWrapStatus.pending,
            ),
            _inviteRow(
              id: 'self-only',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _plainDmRow(),
          ]),
        );

        final groups = await repository
            .watchPendingCollaboratorInviteGroups()
            .first;

        expect(groups, hasLength(1));
        expect(groups.single.videoAddress, _videoAddress);
        expect(groups.single.inviteCount, 2);
        expect(
          groups.single.collaboratorPubkeys,
          equals({_collaboratorA, _collaboratorB}),
        );
      },
    );
  });

  group('value semantics', () {
    test('pending invite value semantics expose recovery state', () {
      final queuedAt = DateTime.utc(2026, 5, 22, 13);
      final failedInvite = PendingCollaboratorInvite(
        rumorId: 'failed-a',
        collaboratorPubkey: _collaboratorA,
        creatorPubkey: _ownerPubkey,
        videoAddress: _videoAddress,
        recipientWrapStatus: OutgoingWrapStatus.failed,
        selfWrapStatus: OutgoingWrapStatus.failed,
        retryCount: 2,
        queuedAt: queuedAt,
        title: 'Beach post',
        thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
        relayHint: 'wss://relay.divine.video',
        lastError: 'timeout',
      );
      final sentInvite = PendingCollaboratorInvite(
        rumorId: 'sent-a',
        collaboratorPubkey: _collaboratorA,
        creatorPubkey: _ownerPubkey,
        videoAddress: _videoAddress,
        recipientWrapStatus: OutgoingWrapStatus.sent,
        selfWrapStatus: OutgoingWrapStatus.failed,
        retryCount: 2,
        queuedAt: queuedAt,
        title: 'Beach post',
        thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
        relayHint: 'wss://relay.divine.video',
        lastError: 'timeout',
      );

      expect(
        failedInvite,
        equals(
          PendingCollaboratorInvite(
            rumorId: 'failed-a',
            collaboratorPubkey: _collaboratorA,
            creatorPubkey: _ownerPubkey,
            videoAddress: _videoAddress,
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            retryCount: 2,
            queuedAt: queuedAt,
            title: 'Beach post',
            thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
            relayHint: 'wss://relay.divine.video',
            lastError: 'timeout',
          ),
        ),
      );
      expect(failedInvite.requiresRecipientRecovery, isTrue);
      expect(sentInvite.requiresRecipientRecovery, isFalse);
      expect(
        PendingCollaboratorInvite(
          rumorId: 'blocked-a',
          collaboratorPubkey: _collaboratorA,
          creatorPubkey: _ownerPubkey,
          videoAddress: _videoAddress,
          recipientWrapStatus: OutgoingWrapStatus.blocked,
          selfWrapStatus: OutgoingWrapStatus.blocked,
          retryCount: 2,
          queuedAt: queuedAt,
        ).requiresRecipientRecovery,
        isFalse,
      );
    });

    test('pending invite group exposes collaborators and equality', () {
      final inviteA = _toPendingInvite(
        _inviteRow(
          id: 'target-a',
          collaboratorPubkey: _collaboratorA,
          recipient: OutgoingWrapStatus.failed,
          self: OutgoingWrapStatus.failed,
        ),
      );
      final inviteB = _toPendingInvite(
        _inviteRow(
          id: 'target-b',
          collaboratorPubkey: _collaboratorB,
          recipient: OutgoingWrapStatus.pending,
          self: OutgoingWrapStatus.failed,
        ),
      );
      final group = PendingCollaboratorInviteGroup(
        creatorPubkey: _ownerPubkey,
        videoAddress: _videoAddress,
        invites: [inviteA, inviteB],
        title: 'Beach post',
        thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
        relayHint: 'wss://relay.divine.video',
      );

      expect(
        group,
        equals(
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownerPubkey,
            videoAddress: _videoAddress,
            invites: [inviteA, inviteB],
            title: 'Beach post',
            thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
            relayHint: 'wss://relay.divine.video',
          ),
        ),
      );
      expect(group.inviteCount, 2);
      expect(group.collaboratorPubkeys, {_collaboratorA, _collaboratorB});
    });

    test('retry summary exposes aggregate success semantics', () {
      const success = CollaboratorInviteRetrySummary(
        attemptedCount: 2,
        successCount: 2,
        failureCount: 0,
      );
      const failure = CollaboratorInviteRetrySummary(
        attemptedCount: 2,
        successCount: 1,
        failureCount: 1,
      );

      expect(
        success,
        equals(
          const CollaboratorInviteRetrySummary(
            attemptedCount: 2,
            successCount: 2,
            failureCount: 0,
          ),
        ),
      );
      expect(success.allSucceeded, isTrue);
      expect(failure.allSucceeded, isFalse);
    });
  });

  group('parseCollaboratorInviteRumor', () {
    test('parseCollaboratorInviteRumor preserves d-tags containing colons', () {
      final metadata = parseCollaboratorInviteRumor(
        Event(_ownerPubkey, 14, [
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [
            CollaboratorInviteTags.address,
            '34236:$_ownerPubkey:vine:with:colons',
            'wss://relay.divine.video',
            'root',
          ],
          [CollaboratorInviteTags.pubkey, _ownerPubkey],
        ], 'invite'),
      );

      expect(metadata, isNotNull);
      expect(metadata!.videoDTag, 'vine:with:colons');
      expect(metadata.videoAddress, '34236:$_ownerPubkey:vine:with:colons');
    });

    test('parseCollaboratorInviteRumor returns structured metadata', () {
      final metadata = parseCollaboratorInviteRumor(
        Event(_ownerPubkey, 14, [
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [
            CollaboratorInviteTags.address,
            _videoAddress,
            '  wss://relay.divine.video  ',
            'root',
          ],
          [CollaboratorInviteTags.pubkey, _collaboratorA],
          [CollaboratorInviteTags.pubkey, _ownerPubkey],
          [CollaboratorInviteTags.title, '  Beach post  '],
          [
            CollaboratorInviteTags.thumbnail,
            ' https://cdn.divine.video/t.jpg ',
          ],
        ], 'invite'),
      );

      expect(
        metadata,
        equals(
          const CollaboratorInviteRumorMetadata(
            videoAddress: _videoAddress,
            videoKind: 34236,
            creatorPubkey: _ownerPubkey,
            videoDTag: 'video:1',
            role: CollaboratorInviteTags.collaboratorRole,
            relayHint: 'wss://relay.divine.video',
            title: 'Beach post',
            thumbnailUrl: 'https://cdn.divine.video/t.jpg',
          ),
        ),
      );
    });

    test('parseCollaboratorInviteRumor rejects non-invite rumor tags', () {
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, _videoAddress],
        ]),
        isNotNull,
      );
      expect(
        parseCollaboratorInviteRumor(
          Event(_ownerPubkey, 14, const [], 'invite'),
        ),
        isNull,
      );
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
        ]),
        isNull,
      );
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, 'not-an-address'],
        ]),
        isNull,
      );
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, '34236:not-a-pubkey:video:1'],
        ]),
        isNull,
      );
    });

    test('parseCollaboratorInviteRumor rejects mismatched creator pubkey', () {
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, _videoAddress],
          [CollaboratorInviteTags.pubkey, _ownerPubkey],
        ]),
        isNotNull,
      );
      final metadata = parseCollaboratorInviteRumorTags([
        [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
        [CollaboratorInviteTags.address, _videoAddress],
        [CollaboratorInviteTags.pubkey, _collaboratorA],
      ]);

      expect(metadata, isNull);
    });

    test(
      'parseCollaboratorInviteRumor ignores invalid p-tags if creator exists',
      () {
        final metadata = parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, _videoAddress],
          [CollaboratorInviteTags.pubkey, 'not-a-pubkey'],
          [CollaboratorInviteTags.pubkey, _ownerPubkey],
        ]);

        expect(metadata, isNotNull);
      },
    );

    test('parseCollaboratorInviteRumor rejects non-collaborator role', () {
      expect(
        parseCollaboratorInviteRumorTags([
          [
            CollaboratorInviteTags.markerName,
            CollaboratorInviteTags.markerValue,
          ],
          [CollaboratorInviteTags.address, _videoAddress],
          [CollaboratorInviteTags.pubkey, _ownerPubkey],
          [
            CollaboratorInviteTags.role,
            CollaboratorInviteTags.collaboratorRole,
          ],
        ]),
        isNotNull,
      );
      final metadata = parseCollaboratorInviteRumorTags([
        [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
        [CollaboratorInviteTags.address, _videoAddress],
        [CollaboratorInviteTags.pubkey, _ownerPubkey],
        [CollaboratorInviteTags.role, 'Producer'],
      ]);

      expect(metadata, isNull);
    });

    test('parseCollaboratorInviteRumor normalizes empty optional values', () {
      final metadata = parseCollaboratorInviteRumorTags([
        [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
        [CollaboratorInviteTags.address, _videoAddress, '   ', 'root'],
        [CollaboratorInviteTags.pubkey, _ownerPubkey],
        [CollaboratorInviteTags.title, '   '],
        [CollaboratorInviteTags.thumbnail, ''],
      ]);

      expect(metadata, isNotNull);
      expect(metadata!.relayHint, isNull);
      expect(metadata.title, isNull);
      expect(metadata.thumbnailUrl, isNull);
    });
  });

  group('retryPendingCollaboratorInvites', () {
    test(
      'retryPendingCollaboratorInvitesForVideo recovers only matching '
      'unresolved rows',
      () async {
        when(() => outgoingDmsDao.watchAllForOwner(_ownerPubkey)).thenAnswer(
          (_) => Stream.value([
            _inviteRow(
              id: 'target-a',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _inviteRow(
              id: 'target-b',
              collaboratorPubkey: _collaboratorB,
              recipient: OutgoingWrapStatus.pending,
              self: OutgoingWrapStatus.pending,
            ),
            _inviteRow(
              id: 'other-video',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
              videoAddress: '34236:$_ownerPubkey:video-2',
            ),
          ]),
        );

        final recoveredRumorIds = <String>[];
        recoverFullSendHandler = (rumorId) async {
          recoveredRumorIds.add(rumorId);
          return NIP17SendResult.success(
            rumorEventId: rumorId,
            messageEventId: 'wrap:$rumorId',
            recipientPubkey: _collaboratorA,
          );
        };

        final summary = await repository
            .retryPendingCollaboratorInvitesForVideo(
              videoAddress: _videoAddress,
              collaboratorPubkeys: const [_collaboratorA],
            );

        expect(summary.attemptedCount, 1);
        expect(summary.successCount, 1);
        expect(recoveredRumorIds, ['target-a']);
      },
    );

    test('retryPendingCollaboratorInvites reports partial failures', () async {
      recoverFullSendHandler = (rumorId) async {
        if (rumorId == 'target-b') {
          return const NIP17SendResult.failure('relay timeout');
        }
        return NIP17SendResult.success(
          rumorEventId: rumorId,
          messageEventId: 'wrap:$rumorId',
          recipientPubkey: _collaboratorA,
        );
      };

      final summary = await repository.retryPendingCollaboratorInvites([
        _toPendingInvite(
          _inviteRow(
            id: 'target-a',
            collaboratorPubkey: _collaboratorA,
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          ),
        ),
        _toPendingInvite(
          _inviteRow(
            id: 'target-b',
            collaboratorPubkey: _collaboratorB,
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          ),
        ),
      ]);

      expect(summary.attemptedCount, 2);
      expect(summary.successCount, 1);
      expect(summary.failureCount, 1);
    });

    test(
      'retryPendingCollaboratorInvites reports unexpected throws through the '
      'reporter port',
      () async {
        recoverFullSendHandler = (rumorId) async {
          if (rumorId == 'boom') {
            throw StateError('boom');
          }
          return NIP17SendResult.success(
            rumorEventId: rumorId,
            messageEventId: 'wrap:$rumorId',
            recipientPubkey: _collaboratorA,
          );
        };

        final summary = await repository.retryPendingCollaboratorInvites([
          _toPendingInvite(
            _inviteRow(
              id: 'boom',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ),
        ]);

        expect(summary.attemptedCount, 1);
        expect(summary.successCount, 0);
        expect(summary.failureCount, 1);
        expect(reportedErrors, hasLength(1));
        expect(
          reportedErrors.single.site,
          DmRepositoryReportableSites
              .retryPendingCollaboratorInviteUnexpectedThrow,
        );
      },
    );

    test(
      'retryPendingCollaboratorInvites counts a confirmed policy block as '
      'terminal, not a retryable failure',
      () async {
        recoverFullSendHandler = (rumorId) async {
          if (rumorId == 'blocked-b') {
            return const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
            );
          }
          return NIP17SendResult.success(
            rumorEventId: rumorId,
            messageEventId: 'wrap:$rumorId',
            recipientPubkey: _collaboratorA,
          );
        };

        final summary = await repository.retryPendingCollaboratorInvites([
          _toPendingInvite(
            _inviteRow(
              id: 'target-a',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ),
          _toPendingInvite(
            _inviteRow(
              id: 'blocked-b',
              collaboratorPubkey: _collaboratorB,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ),
        ]);

        expect(summary.attemptedCount, 2);
        expect(summary.successCount, 1);
        expect(summary.blockedCount, 1);
        // A terminal block is neither delivered nor retryable, so it must not
        // inflate the "still needs to send" failure count...
        expect(summary.failureCount, 0);
        // ...and it is an expected outcome, not a crash to report.
        expect(reportedErrors, isEmpty);
      },
    );

    test(
      'retryPendingCollaboratorInvites skips a row removed by a concurrent '
      'sweep without reporting it',
      () async {
        recoverFullSendHandler = (rumorId) async {
          if (rumorId == 'raced') {
            throw ArgumentError.value(
              rumorId,
              'rumorId',
              'no queued outgoing DM with this id',
            );
          }
          return NIP17SendResult.success(
            rumorEventId: rumorId,
            messageEventId: 'wrap:$rumorId',
            recipientPubkey: _collaboratorA,
          );
        };

        final summary = await repository.retryPendingCollaboratorInvites([
          _toPendingInvite(
            _inviteRow(
              id: 'target-a',
              collaboratorPubkey: _collaboratorA,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ),
          _toPendingInvite(
            _inviteRow(
              id: 'raced',
              collaboratorPubkey: _collaboratorB,
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ),
        ]);

        expect(summary.attemptedCount, 2);
        expect(summary.successCount, 1);
        // The raced row is terminal for this invite but not a retryable
        // failure, and the expected race must not reach Crashlytics.
        expect(summary.failureCount, 0);
        expect(summary.blockedCount, 0);
        expect(reportedErrors, isEmpty);
      },
    );
  });
}

PendingCollaboratorInvite _toPendingInvite(OutgoingDm row) {
  return PendingCollaboratorInvite(
    rumorId: row.id,
    collaboratorPubkey: row.recipientPubkey,
    creatorPubkey: _ownerPubkey,
    videoAddress: _videoAddress,
    recipientWrapStatus: row.recipientWrapStatus,
    selfWrapStatus: row.selfWrapStatus,
    retryCount: row.retryCount,
    queuedAt: row.queuedAt,
    title: 'Beach post',
    thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
    relayHint: 'wss://relay.divine.video',
  );
}
