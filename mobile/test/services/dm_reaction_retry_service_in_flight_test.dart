// ABOUTME: Real service/repository/DAO regression for a foreground heartbeat
// ABOUTME: overlapping a group reaction whose original fan-out is still running.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/dm_reaction_retry_service.dart';

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _secondPeer =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _thirdPeer =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _messageId =
    '5555555555555555555555555555555555555555555555555555555555555555';

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group('in-flight group reaction', () {
    for (final originalSucceeds in [false, true]) {
      test(
        'heartbeat waits for the original fan-out that '
        '${originalSucceeds ? 'succeeds' : 'fails'}',
        () async {
          final db = AppDatabase.test(NativeDatabase.memory());
          final dao = DmReactionsDao(db);
          final conversations = ConversationsDao(db);
          final messageService = _MockMessageService();
          final repository = DmReactionsRepository(
            reactionsDao: dao,
            conversationsDao: conversations,
            directMessagesDao: DirectMessagesDao(db),
          )..setCredentials(userPubkey: _owner, messageService: messageService);
          const conversationId = 'group-reaction-heartbeat';
          await conversations.upsertConversation(
            id: conversationId,
            participantPubkeys:
                '["$_owner","$_peer","$_secondPeer","$_thirdPeer"]',
            isGroup: true,
            createdAt: 1700000000,
            ownerPubkey: _owner,
          );

          try {
            fakeAsync((async) {
              final now = async.getClock(DateTime.utc(2026, 10, 7, 12)).now;
              when(
                () => messageService.buildRumor(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  eventKind: any(named: 'eventKind'),
                  additionalTags: any(named: 'additionalTags'),
                  createdAt: any(named: 'createdAt'),
                ),
              ).thenAnswer(
                (invocation) => Event(
                  _owner,
                  invocation.namedArguments[#eventKind] as int,
                  invocation.namedArguments[#additionalTags]
                      as List<List<String>>,
                  invocation.namedArguments[#content] as String,
                  createdAt: now().millisecondsSinceEpoch ~/ 1000,
                ),
              );
              final originalSends = <Completer<NIP17SendResult>>[];
              var sends = 0;
              when(
                () => messageService.sendRumor(
                  rumorEvent: any(named: 'rumorEvent'),
                  recipientPubkey: any(named: 'recipientPubkey'),
                  targetRelays: any(named: 'targetRelays'),
                  awaitRecipientOk: any(named: 'awaitRecipientOk'),
                  selfWrapOnSoftUnconfirmed: any(
                    named: 'selfWrapOnSoftUnconfirmed',
                  ),
                  recipientWrapBuildTimeout: any(
                    named: 'recipientWrapBuildTimeout',
                  ),
                  selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
                ),
              ).thenAnswer((invocation) {
                sends++;
                if (sends <= 3) {
                  final send = Completer<NIP17SendResult>();
                  originalSends.add(send);
                  return send.future;
                }
                return Future.value(
                  NIP17SendResult.success(
                    rumorEventId:
                        (invocation.namedArguments[#rumorEvent] as Event).id,
                    messageEventId: 'confirmed-wrap',
                    recipientPubkey:
                        invocation.namedArguments[#recipientPubkey] as String,
                  ),
                );
              });

              final foreground = StreamController<bool>();
              final service = DmReactionRetryService(
                reactionsRepository: repository,
                appForegroundStream: foreground.stream,
                crashReporting: CrashReportingService(),
                now: now,
              );
              unawaited(service.initialize());
              DmReactionPublishResult? result;
              unawaited(
                repository
                    .publish(
                      conversationId: conversationId,
                      targetMessageId: _messageId,
                      targetMessageAuthor: _peer,
                      emoji: '🔥',
                    )
                    .then((value) => result = value),
              );
              async.flushMicrotasks();
              expect(originalSends, hasLength(1));
              foreground.add(true);
              async.flushMicrotasks();

              for (var index = 0; index < 2; index++) {
                async.elapse(const Duration(seconds: 11));
                originalSends[index].complete(
                  NIP17SendResult.success(
                    rumorEventId: 'original-rumor',
                    messageEventId: 'original-wrap',
                    recipientPubkey: _peer,
                  ),
                );
                async.flushMicrotasks();
              }
              expect(originalSends, hasLength(3));
              async.elapse(
                const Duration(seconds: 8),
              ); // Heartbeat at 30 seconds.
              final sendsAtHeartbeat = sends;
              async.elapse(const Duration(seconds: 3));
              originalSends[2].complete(
                originalSucceeds
                    ? NIP17SendResult.success(
                        rumorEventId: 'original-rumor',
                        messageEventId: 'original-wrap',
                        recipientPubkey: _thirdPeer,
                      )
                    : const NIP17SendResult.failure('relay rejected'),
              );
              async.flushMicrotasks();
              expect(result?.success, originalSucceeds);
              async.elapse(const Duration(seconds: 30));

              DmReactionRow? row;
              unawaited(
                dao
                    .getById(id: result!.rumorId, ownerPubkey: _owner)
                    .then((value) => row = value),
              );
              async.flushMicrotasks();
              expect(row?.publishStatus, 'sent');
              expect(row?.rumorEventJson, isNull);
              expect(sendsAtHeartbeat, 3, reason: 'no overlapping fan-out');
              expect(
                sends,
                originalSucceeds ? 3 : 6,
                reason: 'only a failed original needs a subsequent fan-out',
              );
              unawaited(service.dispose());
              unawaited(foreground.close());
              async.flushMicrotasks();
            });
          } finally {
            await db.close();
          }
        },
      );
    }
  });
}
