// ABOUTME: Unit tests for DirectMessagesDao with CRUD, deduplication,
// ABOUTME: conversation-scoped queries, reactive watch streams, and counting.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DirectMessagesDao dao;
  late String tempDbPath;

  const conversationId1 = 'conv_abc123';
  const conversationId2 = 'conv_def456';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'direct_messages_dao_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.directMessagesDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group(DirectMessagesDao, () {
    group('insertMessage', () {
      test('inserts new text message (kind 14)', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello Bob!',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_1'));
        expect(results.first.conversationId, equals(conversationId1));
        expect(results.first.senderPubkey, equals('pubkey_alice'));
        expect(results.first.content, equals('Hello Bob!'));
        expect(results.first.createdAt, equals(1700000000));
        expect(results.first.giftWrapId, equals('gw_1'));
        expect(results.first.messageKind, equals(14));
        expect(results.first.replyToId, isNull);
      });

      test('round-trips decrypted rumor tags JSON', () async {
        final tagsJson = jsonEncode([
          ['divine', 'collab-invite'],
          ['a', '34236:creator:dtag', 'wss://relay.divine.video', 'root'],
        ]);

        await dao.insertMessage(
          id: 'msg_tags',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Fallback invite copy',
          createdAt: 1700000000,
          giftWrapId: 'gw_tags',
          tagsJson: tagsJson,
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.tagsJson, equals(tagsJson));
      });

      test('inserts file message (kind 15) with metadata', () async {
        await dao.insertMessage(
          id: 'msg_file',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'https://example.com/encrypted.bin',
          createdAt: 1700000100,
          giftWrapId: 'gw_file',
          messageKind: 15,
          fileType: 'image/jpeg',
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: 'deadbeef',
          decryptionNonce: 'cafebabe',
          fileHash: 'abc123hash',
          originalFileHash: 'orig123hash',
          fileSize: 204800,
          dimensions: '1920x1080',
          blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          thumbnailUrl: 'https://example.com/thumb.bin',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        final msg = results.first;
        expect(msg.messageKind, equals(15));
        expect(msg.fileType, equals('image/jpeg'));
        expect(msg.encryptionAlgorithm, equals('aes-gcm'));
        expect(msg.decryptionKey, equals('deadbeef'));
        expect(msg.decryptionNonce, equals('cafebabe'));
        expect(msg.fileHash, equals('abc123hash'));
        expect(msg.originalFileHash, equals('orig123hash'));
        expect(msg.fileSize, equals(204800));
        expect(msg.dimensions, equals('1920x1080'));
        expect(msg.blurhash, equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'));
        expect(msg.thumbnailUrl, equals('https://example.com/thumb.bin'));
      });

      test('inserts message with reply', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello!',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Hi Alice!',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
          replyToId: 'msg_1',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        // Newest first
        expect(results[0].replyToId, equals('msg_1'));
      });

      test(
        'ignores duplicate insert with same ID (INSERT OR IGNORE)',
        () async {
          await dao.insertMessage(
            id: 'msg_1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Original',
            createdAt: 1700000000,
            giftWrapId: 'gw_1',
          );

          // Second insert with same id is silently ignored — no update.
          await dao.insertMessage(
            id: 'msg_1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Updated',
            createdAt: 1700000000,
            giftWrapId: 'gw_1_new',
          );

          final results = await dao.getMessagesForConversation(conversationId1);
          expect(results, hasLength(1));
          expect(results.first.content, equals('Original'));
        },
      );

      test(
        'ignores duplicate insert with same gift_wrap_id (C1 fix)',
        () async {
          await dao.insertMessage(
            id: 'msg_1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'First message',
            createdAt: 1700000000,
            giftWrapId: 'gw_shared',
          );

          // Different rumor ID but same gift_wrap_id — silently ignored.
          await dao.insertMessage(
            id: 'msg_2',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Duplicate wrap',
            createdAt: 1700000100,
            giftWrapId: 'gw_shared',
          );

          final results = await dao.getMessagesForConversation(conversationId1);
          expect(results, hasLength(1));
          expect(results.first.id, equals('msg_1'));
        },
      );

      test('persists sendBatchId and reads it back', () async {
        await dao.insertMessage(
          id: 'msg_batch',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Group send copy',
          createdAt: 1700000000,
          giftWrapId: 'gw_batch',
          sendBatchId: 'batch-rt',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.sendBatchId, equals('batch-rt'));
      });

      test('defaults sendBatchId to null when the param is omitted', () async {
        await dao.insertMessage(
          id: 'msg_no_batch',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'One-to-one send',
          createdAt: 1700000000,
          giftWrapId: 'gw_no_batch',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.sendBatchId, isNull);
      });

      test('reports whether insert wrote a row', () async {
        final firstInserted = await dao.insertMessage(
          id: 'msg_insert_result',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Original',
          createdAt: 1700000000,
          giftWrapId: 'gw_insert_result',
        );
        final duplicateInserted = await dao.insertMessage(
          id: 'msg_insert_result',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Ignored duplicate',
          createdAt: 1700000001,
          giftWrapId: 'gw_insert_result_duplicate',
        );
        final duplicateGiftWrapInserted = await dao.insertMessage(
          id: 'msg_insert_result_duplicate_gift_wrap',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Ignored duplicate gift wrap',
          createdAt: 1700000002,
          giftWrapId: 'gw_insert_result',
        );

        expect(firstInserted, isTrue);
        expect(duplicateInserted, isFalse);
        expect(duplicateGiftWrapInserted, isFalse);
        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.content, equals('Original'));
      });
    });

    group('owner-scoped uniqueness', () {
      // A NIP-17 group send seals ONE rumor for every recipient, so two local
      // accounts in the same room receive distinct gift wraps carrying an
      // identical rumor id. Under the previous global primary key the second
      // account's insert was a silent no-op and its copy was lost. #6645.
      const rumorId = 'shared_group_rumor';
      final ownerA = 'a' * 64;
      final ownerB = 'b' * 64;

      test(
        'both local accounts persist their own copy of one group rumor',
        () async {
          final insertedForA = await dao.insertMessage(
            id: rumorId,
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'group hello',
            createdAt: 1700000000,
            giftWrapId: 'wrap_for_a',
            ownerPubkey: ownerA,
          );
          final insertedForB = await dao.insertMessage(
            id: rumorId,
            conversationId: conversationId2,
            senderPubkey: 'pubkey_peer',
            content: 'group hello',
            createdAt: 1700000000,
            giftWrapId: 'wrap_for_b',
            ownerPubkey: ownerB,
          );

          expect(insertedForA, isTrue);
          expect(insertedForB, isTrue);
        },
      );

      test('each account reads only its own copy', () async {
        await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'group hello',
          createdAt: 1700000000,
          giftWrapId: 'wrap_for_a',
          ownerPubkey: ownerA,
        );
        await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId2,
          senderPubkey: 'pubkey_peer',
          content: 'group hello',
          createdAt: 1700000000,
          giftWrapId: 'wrap_for_b',
          ownerPubkey: ownerB,
        );

        final forA = await dao.getMessagesForConversation(
          conversationId1,
          ownerPubkey: ownerA,
        );
        final forB = await dao.getMessagesForConversation(
          conversationId2,
          ownerPubkey: ownerB,
        );

        expect(forA, hasLength(1));
        expect(forB, hasLength(1));
      });

      test('a replay for the SAME owner is still ignored', () async {
        final first = await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'group hello',
          createdAt: 1700000000,
          giftWrapId: 'wrap_for_a',
          ownerPubkey: ownerA,
        );
        final replay = await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'group hello again',
          createdAt: 1700000001,
          giftWrapId: 'wrap_for_a_replay',
          ownerPubkey: ownerA,
        );

        expect(first, isTrue);
        expect(replay, isFalse);
      });

      test(
        'two legacy unowned rows sharing a rumor id still collapse',
        () async {
          // SQLite compares NULLs as distinct inside a unique constraint, so a
          // nullable owner in the key would have let both of these through. The
          // column is NOT NULL with an `''` default precisely to stop that.
          final first = await dao.insertMessage(
            id: rumorId,
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'legacy',
            createdAt: 1700000000,
            giftWrapId: 'wrap_legacy_one',
          );
          final second = await dao.insertMessage(
            id: rumorId,
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'legacy duplicate',
            createdAt: 1700000001,
            giftWrapId: 'wrap_legacy_two',
          );

          expect(first, isTrue);
          expect(second, isFalse);
        },
      );

      test('a legacy unowned row stays readable by a real account', () async {
        // The v12 backfill turns NULL owners into `''`; `_ownedOrLegacy` has to
        // match that sentinel or every migrated row goes invisible.
        await dao.insertMessage(
          id: 'legacy_only',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'written before multi-account support',
          createdAt: 1700000000,
          giftWrapId: 'wrap_legacy_only',
        );

        final visible = await dao.getMessagesForConversation(
          conversationId1,
          ownerPubkey: ownerA,
        );

        expect(visible, hasLength(1));
        expect(visible.first.ownerPubkey, isEmpty);
      });

      test('an owned message shadows its legacy copy', () async {
        await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'legacy copy',
          createdAt: 1700000000,
          giftWrapId: 'wrap_legacy',
        );
        await dao.insertMessage(
          id: rumorId,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'owned copy',
          createdAt: 1700000001,
          giftWrapId: 'wrap_owned',
          ownerPubkey: ownerA,
        );

        final single = await dao.getMessageById(rumorId, ownerPubkey: ownerA);
        final listed = await dao.getMessagesForConversation(
          conversationId1,
          ownerPubkey: ownerA,
        );

        expect(single!.content, 'owned copy');
        expect(listed.map((row) => row.content), ['owned copy']);
      });
    });

    group('getMessagesForConversation', () {
      test(
        'returns messages sorted by createdAt desc (newest first)',
        () async {
          await dao.insertMessage(
            id: 'msg_old',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'First message',
            createdAt: 1700000000,
            giftWrapId: 'gw_old',
          );
          await dao.insertMessage(
            id: 'msg_new',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_bob',
            content: 'Latest message',
            createdAt: 1700000200,
            giftWrapId: 'gw_new',
          );
          await dao.insertMessage(
            id: 'msg_mid',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Middle message',
            createdAt: 1700000100,
            giftWrapId: 'gw_mid',
          );

          final results = await dao.getMessagesForConversation(conversationId1);
          expect(results, hasLength(3));
          expect(results[0].id, equals('msg_new'));
          expect(results[1].id, equals('msg_mid'));
          expect(results[2].id, equals('msg_old'));
        },
      );

      test(
        'uses id desc as a stable tie-breaker for equal timestamps',
        () async {
          await dao.insertMessage(
            id: 'msg_same_a',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'First same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_same_a',
          );
          await dao.insertMessage(
            id: 'msg_same_c',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_bob',
            content: 'Latest same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_same_c',
          );
          await dao.insertMessage(
            id: 'msg_same_b',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Middle same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_same_b',
          );

          final results = await dao.getMessagesForConversation(conversationId1);

          expect(results.map((message) => message.id), [
            'msg_same_c',
            'msg_same_b',
            'msg_same_a',
          ]);
        },
      );

      test('respects limit and offset parameters', () async {
        for (var i = 0; i < 5; i++) {
          await dao.insertMessage(
            id: 'msg_$i',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Message $i',
            createdAt: 1700000000 + i * 100,
            giftWrapId: 'gw_$i',
          );
        }

        final results = await dao.getMessagesForConversation(
          conversationId1,
          limit: 2,
          offset: 1,
        );
        expect(results, hasLength(2));
        // Newest first, skip 1 => msg_3, msg_2
        expect(results[0].id, equals('msg_3'));
        expect(results[1].id, equals('msg_2'));
      });

      test('does not return messages from other conversations', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Conv 1 message',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_bob',
          content: 'Conv 2 message',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_1'));
      });

      test('returns empty list for non-existent conversation', () async {
        final results = await dao.getMessagesForConversation('nonexistent');
        expect(results, isEmpty);
      });
    });

    group('watchMessagesForConversation', () {
      test('emits initial list sorted by createdAt desc', () async {
        await dao.insertMessage(
          id: 'msg_old',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Old',
          createdAt: 1700000000,
          giftWrapId: 'gw_old',
        );
        await dao.insertMessage(
          id: 'msg_new',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'New',
          createdAt: 1700000100,
          giftWrapId: 'gw_new',
        );

        final stream = dao.watchMessagesForConversation(conversationId1);
        final results = await stream.first;

        expect(results, hasLength(2));
        expect(results[0].id, equals('msg_new'));
        expect(results[1].id, equals('msg_old'));
      });

      test(
        'uses id desc as a stable tie-breaker for equal timestamps',
        () async {
          await dao.insertMessage(
            id: 'msg_same_a',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'First same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_watch_same_a',
          );
          await dao.insertMessage(
            id: 'msg_same_c',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_bob',
            content: 'Latest same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_watch_same_c',
          );
          await dao.insertMessage(
            id: 'msg_same_b',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Middle same-time message',
            createdAt: 1700000200,
            giftWrapId: 'gw_watch_same_b',
          );

          final stream = dao.watchMessagesForConversation(conversationId1);
          final results = await stream.first;

          expect(results.map((message) => message.id), [
            'msg_same_c',
            'msg_same_b',
            'msg_same_a',
          ]);
        },
      );

      test('respects limit parameter', () async {
        for (var i = 0; i < 3; i++) {
          await dao.insertMessage(
            id: 'msg_$i',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Message $i',
            createdAt: 1700000000 + i * 100,
            giftWrapId: 'gw_$i',
          );
        }

        final stream = dao.watchMessagesForConversation(
          conversationId1,
          limit: 2,
        );
        final results = await stream.first;

        expect(results, hasLength(2));
      });

      test('emits empty list for non-existent conversation', () async {
        final stream = dao.watchMessagesForConversation('nonexistent');
        final results = await stream.first;
        expect(results, isEmpty);
      });
    });

    group('message-deletion durability', () {
      Future<void> insertOwnMessage() => dao.insertMessage(
        id: 'msg_del',
        conversationId: conversationId1,
        senderPubkey: 'pubkey_alice',
        content: 'Regrettable',
        createdAt: 1700000000,
        giftWrapId: 'gw_del',
        ownerPubkey: 'pubkey_alice',
      );

      group('markMessageDeletionPending', () {
        test('hides the row and stores the rumor in one write', () async {
          await insertOwnMessage();

          final updated = await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          expect(updated, isTrue);
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.isDeleted, isTrue);
          expect(row.deletionRumorJson, equals('{"kind":5}'));
          expect(row.deletionPublishStatus, equals('deletion_pending'));
        });

        test('drops the bubble from the live conversation', () async {
          await insertOwnMessage();

          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          final live = await dao.getMessagesForConversation(conversationId1);
          expect(live, isEmpty);
        });

        test('keeps an own pending retraction visible to its owner', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          final live = await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: 'pubkey_alice',
          );

          expect(live.single.id, 'msg_del');
        });

        test(
          'does not expose an uncertain retraction to another owner',
          () async {
            await insertOwnMessage();
            await dao.markMessageDeletionPending(
              'msg_del',
              deletionRumorJson: '{"kind":5}',
              ownerPubkey: 'pubkey_alice',
            );

            final live = await dao.getMessagesForConversation(
              conversationId1,
              ownerPubkey: 'pubkey_bob',
            );

            expect(live, isEmpty);
          },
        );

        test('reports false for an unknown rumor id', () async {
          final updated = await dao.markMessageDeletionPending(
            'msg_missing',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          expect(updated, isFalse);
        });

        test("leaves another account's message untouched", () async {
          await insertOwnMessage();

          final updated = await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_bob',
          );

          expect(updated, isFalse);
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.isDeleted, isFalse);
          expect(row.deletionRumorJson, isNull);
        });
      });

      group('getRetryableOwnMessageDeletions', () {
        test('lists pending own deletions oldest first', () async {
          await dao.insertMessage(
            id: 'msg_new',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Newer',
            createdAt: 1700000200,
            giftWrapId: 'gw_new',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.insertMessage(
            id: 'msg_old',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Older',
            createdAt: 1700000100,
            giftWrapId: 'gw_old',
            ownerPubkey: 'pubkey_alice',
          );
          for (final id in ['msg_new', 'msg_old']) {
            await dao.markMessageDeletionPending(
              id,
              deletionRumorJson: '{"id":"$id"}',
              ownerPubkey: 'pubkey_alice',
            );
          }

          final pending = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(
            pending.map((r) => r.id),
            orderedEquals(['msg_old', 'msg_new']),
          );
        });

        test('excludes settled deletions', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeletionSent(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );

          final pending = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(pending, isEmpty);
        });

        test('re-hides a row that a confirmed retraction settles', () async {
          // A restored blocked row is visible AND holds a rumor, which is
          // exactly what `retryMessageDeletion` accepts. If that replay ever
          // confirms, the message must not stay on screen — the inverse of
          // the #8165 lie this branch exists to fix.
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          await dao.markMessageDeletionSent(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );

          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.isDeleted, isTrue);
        });

        test('excludes a blocked deletion', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          final pending = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(pending, isEmpty);
        });

        test("never re-publishes a peer's deletion applied locally", () async {
          await dao.insertMessage(
            id: 'msg_peer',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_bob',
            content: 'From Bob',
            createdAt: 1700000000,
            giftWrapId: 'gw_peer',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeleted('msg_peer', ownerPubkey: 'pubkey_alice');

          final pending = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(pending, isEmpty);
        });
      });

      group('markMessageDeletionSent', () {
        test('clears the stored rumor once a relay confirms', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          final settled = await dao.markMessageDeletionSent(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );

          expect(settled, isTrue);
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.deletionPublishStatus, equals('deletion_sent'));
          // Delivered: nothing left to replay. Unlike the blocked path (#8226).
          expect(row.deletionRumorJson, isNull);
          expect(row.isDeleted, isTrue);
        });
      });

      group('markMessageDeletionBlocked', () {
        test('settles as blocked rather than as sent', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          final settled = await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          expect(settled, isTrue);
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.deletionPublishStatus, equals('deletion_blocked'));
        });

        test(
          'retains the rumor so a lifted block can still replay it',
          () async {
            // #8226: a block is the one terminal state an outside change can
            // lift, and this payload is the only thing a replay could send.
            const rumor = '{"kind":5,"tags":[["e","msg_del"],["k","14"]]}';
            await insertOwnMessage();
            await dao.markMessageDeletionPending(
              'msg_del',
              deletionRumorJson: rumor,
              ownerPubkey: 'pubkey_alice',
            );

            await dao.markMessageDeletionBlocked(
              'msg_del',
              restoreToThread: true,
              ownerPubkey: 'pubkey_alice',
            );

            final row = await dao.getMessageById(
              'msg_del',
              ownerPubkey: 'pubkey_alice',
            );
            expect(row!.deletionRumorJson, equals(rumor));
          },
        );

        test('the retained rumor stays off the retry worklist', () async {
          // Retention must not resurrect the send: the sweep additionally
          // requires deletion_pending, so a blocked row is excluded on
          // status alone.
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          final pending = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(pending, isEmpty);
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.deletionRumorJson, isNotNull);
        });

        // The test above can no longer fail on the status predicate alone:
        // #8201 restores a blocked row to `is_deleted = false`, so the sweep
        // excludes it twice over and dropping either predicate leaves the
        // suite green. Rows blocked before #8201 shipped are still on disk in
        // the old shape — hidden, with a rumor — and for those the status is
        // the only thing keeping them off the worklist.
        test(
          'a row blocked before the restore stays off the worklist',
          () async {
            await insertOwnMessage();
            await dao.markMessageDeletionPending(
              'msg_del',
              deletionRumorJson: '{"kind":5}',
              ownerPubkey: 'pubkey_alice',
            );
            // Settle the status without the restore, reproducing the pre-#8201
            // on-disk shape rather than what the DAO writes today.
            await database.customStatement(
              'UPDATE direct_messages SET deletion_publish_status = ? '
              'WHERE id = ?',
              [DirectMessagesDao.deletionBlocked, 'msg_del'],
            );

            final pending = await dao.getRetryableOwnMessageDeletions(
              ownerPubkey: 'pubkey_alice',
            );

            expect(pending, isEmpty);
            final row = await dao.getMessageById(
              'msg_del',
              ownerPubkey: 'pubkey_alice',
            );
            expect(row!.isDeleted, isTrue);
            expect(row.deletionRumorJson, isNotNull);
          },
        );

        // The retraction did not happen, so continuing to hide the message
        // repeats the #8165 lie in a new place. Un-hiding also restores the
        // only row the user can act on to try again.
        test('restores the message to the thread', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.isDeleted, isFalse);
        });

        // A mixed outcome — some recipients accepted, the rest blocked — is
        // recorded blocked too, but must NOT come back: the message really is
        // retracted for the recipients that accepted, so un-hiding it would
        // claim it "is still there" for a thread that mostly dropped it
        // (#8201).
        test('keeps a partially delivered retraction hidden', () async {
          await insertOwnMessage();
          await dao.markMessageDeletionPending(
            'msg_del',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: false,
            ownerPubkey: 'pubkey_alice',
          );

          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          expect(row!.isDeleted, isTrue);
          expect(row.deletionPublishStatus, equals('deletion_blocked'));
          // The payload survives either way — it is the retraction's identity,
          // not what makes the row recoverable.
          expect(row.deletionRumorJson, isNotNull);
        });
      });

      group('markMessageDeletionUnconfirmed (#10012)', () {
        const rumor = '{"kind":5,"tags":[["e","msg_del"],["k","14"]]}';

        Future<void> markPending() => dao.markMessageDeletionPending(
          'msg_del',
          deletionRumorJson: rumor,
          ownerPubkey: 'pubkey_alice',
        );

        Future<bool> markUnconfirmed({String ownerPubkey = 'pubkey_alice'}) =>
            dao.markMessageDeletionUnconfirmed(
              'msg_del',
              ownerPubkey: ownerPubkey,
            );

        Future<DirectMessageRow> row() async => (await dao.getMessageById(
          'msg_del',
          ownerPubkey: 'pubkey_alice',
        ))!;

        test('records a pending retraction whose retries ran out', () async {
          await insertOwnMessage();
          await markPending();
          await dao.recordHeldDeletionWrap(
            'msg_del',
            recipientPubkey: 'pubkey_bob',
            wrapEventId: 'gw_held',
            ownerPubkey: 'pubkey_alice',
          );
          final heldBefore = (await row()).heldDeletionWraps;
          expect(heldBefore, isNotNull);

          expect(await markUnconfirmed(), isTrue);

          final unconfirmed = await row();
          expect(
            unconfirmed.deletionPublishStatus,
            equals(DirectMessagesDao.deletionUnconfirmed),
          );
          expect(unconfirmed.deletionRumorJson, equals(rumor));
          expect(unconfirmed.heldDeletionWraps, equals(heldBefore));
          expect(unconfirmed.isDeleted, isTrue);
        });

        test("keeps the bubble in its sender's thread", () async {
          await insertOwnMessage();
          await markPending();
          await markUnconfirmed();

          final live = await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: 'pubkey_alice',
          );
          final watched = await dao
              .watchMessagesForConversation(
                conversationId1,
                ownerPubkey: 'pubkey_alice',
              )
              .first;

          expect(live.map((m) => m.id), equals(['msg_del']));
          expect(watched.map((m) => m.id), equals(['msg_del']));
          expect(
            await dao.isRetracted('msg_del', ownerPubkey: 'pubkey_alice'),
            isFalse,
          );
        });

        test('stays on the retry worklist', () async {
          await insertOwnMessage();
          await markPending();
          await markUnconfirmed();

          final retryable = await dao.getRetryableOwnMessageDeletions(
            ownerPubkey: 'pubkey_alice',
          );

          expect(retryable.map((r) => r.id), equals(['msg_del']));
        });

        test('never overwrites a confirmed retraction', () async {
          await insertOwnMessage();
          await markPending();
          await dao.markMessageDeletionSent(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );

          expect(await markUnconfirmed(), isFalse);

          expect(
            (await row()).deletionPublishStatus,
            equals('deletion_sent'),
          );
        });

        test('never overwrites a blocked retraction', () async {
          await insertOwnMessage();
          await markPending();
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          expect(await markUnconfirmed(), isFalse);

          expect(
            (await row()).deletionPublishStatus,
            equals(DirectMessagesDao.deletionBlocked),
          );
        });

        test("leaves another account's retraction untouched", () async {
          await insertOwnMessage();
          await markPending();

          expect(await markUnconfirmed(ownerPubkey: 'pubkey_bob'), isFalse);

          expect(
            (await row()).deletionPublishStatus,
            equals(DirectMessagesDao.deletionPending),
          );
        });

        test(
          'a retry moving it back to pending keeps its held wraps',
          () async {
            await insertOwnMessage();
            await markPending();
            await dao.recordHeldDeletionWrap(
              'msg_del',
              recipientPubkey: 'pubkey_bob',
              wrapEventId: 'gw_held',
              ownerPubkey: 'pubkey_alice',
            );
            await markUnconfirmed();
            final heldBefore = (await row()).heldDeletionWraps;
            expect(heldBefore, isNotNull);

            await markPending();

            final retried = await row();
            expect(
              retried.deletionPublishStatus,
              equals(DirectMessagesDao.deletionPending),
            );
            expect(retried.heldDeletionWraps, equals(heldBefore));
          },
        );
      });

      group('held deletion wraps (#10012)', () {
        const recipient = 'pubkey_bob';
        const otherRecipient = 'pubkey_carol';

        Future<bool> recordWrap({
          String to = recipient,
          String wrap = 'gw_held',
          String ownerPubkey = 'pubkey_alice',
        }) => dao.recordHeldDeletionWrap(
          'msg_del',
          recipientPubkey: to,
          wrapEventId: wrap,
          ownerPubkey: ownerPubkey,
        );

        Future<void> markPending({String rumor = '{"kind":5}'}) =>
            dao.markMessageDeletionPending(
              'msg_del',
              deletionRumorJson: rumor,
              ownerPubkey: 'pubkey_alice',
            );

        Future<bool> recordDelivered(
          Map<String, String> wraps, {
          String ownerPubkey = 'pubkey_alice',
        }) => dao.recordDeliveredDeletionWraps(
          'msg_del',
          wraps: wraps,
          ownerPubkey: ownerPubkey,
        );

        /// A record's entry for a recipient the fallback pool holds [wrap]
        /// for.
        Map<String, Object> held(String wrap) => {
          'wrap': wrap,
          'delivered': false,
        };

        /// A record's entry for a recipient who has the retraction through
        /// [wrap].
        Map<String, Object> delivered(String wrap) => {
          'wrap': wrap,
          'delivered': true,
        };

        Future<Map<String, dynamic>?> heldWraps() async {
          final row = await dao.getMessageById(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );
          final json = row!.heldDeletionWraps;
          return json == null ? null : jsonDecode(json) as Map<String, dynamic>;
        }

        test('records the wrap held for each recipient', () async {
          await insertOwnMessage();
          await markPending();

          expect(await recordWrap(), isTrue);
          expect(await recordWrap(to: otherRecipient, wrap: 'gw_c'), isTrue);

          expect(await heldWraps(), {
            recipient: held('gw_held'),
            otherRecipient: held('gw_c'),
          });
        });

        test('records each recipient a retraction reached', () async {
          await insertOwnMessage();
          await markPending();
          await recordWrap();

          expect(await recordDelivered({otherRecipient: 'gw_c'}), isTrue);

          expect(await heldWraps(), {
            recipient: held('gw_held'),
            otherRecipient: delivered('gw_c'),
          });
        });

        test(
          'records no recipient on a message with no pending retraction',
          () async {
            await insertOwnMessage();

            expect(await recordDelivered({recipient: 'gw_b'}), isFalse);

            expect(await heldWraps(), isNull);
          },
        );

        test(
          'records nothing on a message with no pending retraction',
          () async {
            await insertOwnMessage();

            expect(await recordWrap(), isFalse);

            expect(await heldWraps(), isNull);
          },
        );

        test("records nothing on another account's message", () async {
          await insertOwnMessage();
          await markPending();

          expect(await recordWrap(ownerPubkey: 'pubkey_bob'), isFalse);

          expect(await heldWraps(), isNull);
        });

        test('records nothing on a blocked retraction', () async {
          await insertOwnMessage();
          await markPending();
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          expect(await recordWrap(), isFalse);

          expect(await heldWraps(), isNull);
        });

        test('go when the retraction is confirmed', () async {
          await insertOwnMessage();
          await markPending();
          await recordWrap();

          await dao.markMessageDeletionSent(
            'msg_del',
            ownerPubkey: 'pubkey_alice',
          );

          expect(await heldWraps(), isNull);
          expect(await recordWrap(), isFalse);
        });

        test('stay, with the kind-5, when the retraction is blocked', () async {
          await insertOwnMessage();
          await markPending();
          await recordWrap();

          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          expect(await heldWraps(), {recipient: held('gw_held')});
        });

        test('stay when a retry records the same kind-5 again', () async {
          await insertOwnMessage();
          await markPending();
          await recordWrap();
          await recordDelivered({otherRecipient: 'gw_c'});
          await dao.markMessageDeletionBlocked(
            'msg_del',
            restoreToThread: true,
            ownerPubkey: 'pubkey_alice',
          );

          await markPending();

          expect(await heldWraps(), {
            recipient: held('gw_held'),
            otherRecipient: delivered('gw_c'),
          });
        });

        test('go when a different kind-5 replaces it', () async {
          await insertOwnMessage();
          await markPending();
          await recordWrap();

          await markPending(rumor: '{"kind":5,"created_at":2}');

          expect(await heldWraps(), isNull);
        });
      });
    });

    group('isRetracted', () {
      Future<void> insertMessage({required String sender}) => dao.insertMessage(
        id: 'msg_retracted',
        conversationId: conversationId1,
        senderPubkey: sender,
        content: 'https://media.example/blob',
        createdAt: 1700000000,
        giftWrapId: 'gw_retracted',
        messageKind: 15,
        ownerPubkey: 'pubkey_alice',
      );

      test('is true once the sender retracted it', () async {
        await insertMessage(sender: 'pubkey_bob');
        await dao.markMessageDeleted(
          'msg_retracted',
          ownerPubkey: 'pubkey_alice',
        );

        expect(
          await dao.isRetracted('msg_retracted', ownerPubkey: 'pubkey_alice'),
          isTrue,
        );
      });

      test(
        'is false for your own message while its retraction is undelivered, '
        'as the thread still shows it',
        () async {
          await insertMessage(sender: 'pubkey_alice');
          await dao.markMessageDeletionPending(
            'msg_retracted',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );

          expect(
            await dao.isRetracted(
              'msg_retracted',
              ownerPubkey: 'pubkey_alice',
            ),
            isFalse,
          );
        },
      );

      test(
        'is true for your own message once its retraction is delivered',
        () async {
          await insertMessage(sender: 'pubkey_alice');
          await dao.markMessageDeletionPending(
            'msg_retracted',
            deletionRumorJson: '{"kind":5}',
            ownerPubkey: 'pubkey_alice',
          );
          await dao.markMessageDeletionSent(
            'msg_retracted',
            ownerPubkey: 'pubkey_alice',
          );

          expect(
            await dao.isRetracted('msg_retracted', ownerPubkey: 'pubkey_alice'),
            isTrue,
          );
        },
      );

      test(
        'agrees with the thread for your own message deleted with no '
        'delivery status',
        () async {
          await insertMessage(sender: 'pubkey_alice');
          await dao.markMessageDeleted(
            'msg_retracted',
            ownerPubkey: 'pubkey_alice',
          );

          expect(
            await dao.getMessagesForConversation(
              conversationId1,
              ownerPubkey: 'pubkey_alice',
            ),
            isEmpty,
          );
          expect(
            await dao.isRetracted(
              'msg_retracted',
              ownerPubkey: 'pubkey_alice',
            ),
            isTrue,
          );
        },
      );

      test('is false for a message still shown', () async {
        await insertMessage(sender: 'pubkey_bob');

        expect(
          await dao.isRetracted('msg_retracted', ownerPubkey: 'pubkey_alice'),
          isFalse,
        );
      });

      test('is false when there is no row', () async {
        expect(
          await dao.isRetracted('msg_retracted', ownerPubkey: 'pubkey_alice'),
          isFalse,
        );
      });
    });

    group('getAllMessagesForConversationIncludingDeleted', () {
      test('returns soft-deleted rows the rendering read hides', () async {
        await dao.insertMessage(
          id: 'live',
          conversationId: conversationId1,
          senderPubkey: 'sender',
          content: 'live',
          createdAt: 1700000001,
          giftWrapId: 'gw_live',
          ownerPubkey: 'owner',
        );
        await dao.insertMessage(
          id: 'gone',
          conversationId: conversationId1,
          senderPubkey: 'sender',
          content: 'gone',
          createdAt: 1700000002,
          giftWrapId: 'gw_gone',
          ownerPubkey: 'owner',
        );
        await dao.markMessageDeleted('gone', ownerPubkey: 'owner');

        expect(
          (await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: 'owner',
          )).map((m) => m.id),
          equals(['live']),
        );
        expect(
          (await dao.getAllMessagesForConversationIncludingDeleted(
            conversationId1,
            ownerPubkey: 'owner',
          )).map((m) => m.id),
          equals(['live', 'gone']),
          reason: 'oldest first, and the soft-deleted row is included',
        );
      });

      test('stays inside the owner scope', () async {
        await dao.insertMessage(
          id: 'mine',
          conversationId: conversationId1,
          senderPubkey: 'sender',
          content: 'mine',
          createdAt: 1700000001,
          giftWrapId: 'gw_mine',
          ownerPubkey: 'owner',
        );
        await dao.insertMessage(
          id: 'theirs',
          conversationId: conversationId1,
          senderPubkey: 'sender',
          content: 'theirs',
          createdAt: 1700000002,
          giftWrapId: 'gw_theirs',
          ownerPubkey: 'other',
        );

        expect(
          (await dao.getAllMessagesForConversationIncludingDeleted(
            conversationId1,
            ownerPubkey: 'owner',
          )).map((m) => m.id),
          equals(['mine']),
        );
      });
    });

    group('reassignMessages', () {
      test('moves only the named ids and leaves the rest behind', () async {
        for (final id in ['a', 'b', 'c']) {
          await dao.insertMessage(
            id: id,
            conversationId: conversationId1,
            senderPubkey: 'sender',
            content: id,
            createdAt: 1700000001,
            giftWrapId: 'gw_$id',
            ownerPubkey: 'owner',
          );
        }

        final moved = await dao.reassignMessages(
          messageIds: ['a', 'c'],
          toConversationId: conversationId2,
          ownerPubkey: 'owner',
        );

        expect(moved, equals(2));
        expect(
          (await dao.getMessagesForConversation(
            conversationId2,
            ownerPubkey: 'owner',
          )).map((m) => m.id).toSet(),
          equals({'a', 'c'}),
        );
        expect(
          (await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: 'owner',
          )).map((m) => m.id).toSet(),
          equals({'b'}),
        );
      });

      test("will not move another owner's row", () async {
        await dao.insertMessage(
          id: 'theirs',
          conversationId: conversationId1,
          senderPubkey: 'sender',
          content: 'theirs',
          createdAt: 1700000001,
          giftWrapId: 'gw_theirs',
          ownerPubkey: 'other',
        );

        expect(
          await dao.reassignMessages(
            messageIds: ['theirs'],
            toConversationId: conversationId2,
            ownerPubkey: 'owner',
          ),
          equals(0),
        );
      });

      test('is a no-op for an empty id list', () async {
        expect(
          await dao.reassignMessages(
            messageIds: const [],
            toConversationId: conversationId2,
            ownerPubkey: 'owner',
          ),
          equals(0),
        );
      });
    });

    group('groupRepliesMissingTheirTarget', () {
      const owner = 'owner_pubkey';
      const groupId = 'conv_group';

      Future<void> conversation(
        String id, {
        required bool isGroup,
        bool currentUserHasSent = false,
        String ownerPubkey = owner,
      }) => database.conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: '[]',
        isGroup: isGroup,
        createdAt: 1700000000,
        currentUserHasSent: currentUserHasSent,
        ownerPubkey: ownerPubkey,
      );

      Future<void> message(
        String id, {
        required String conversationId,
        String? replyToId,
        String ownerPubkey = owner,
      }) => dao.insertMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: 'pubkey_alice',
        content: id,
        createdAt: 1700000000,
        giftWrapId: 'gw_$id',
        replyToId: replyToId,
        ownerPubkey: ownerPubkey,
      );

      test('maps a missing target to the groups holding a reply to '
          'it', () async {
        await conversation(groupId, isGroup: true);
        await conversation('conv_group_2', isGroup: true);
        await message('reply', conversationId: groupId, replyToId: 'absent');
        await message(
          'reply_2',
          conversationId: 'conv_group_2',
          replyToId: 'absent',
        );

        expect(
          await dao.groupRepliesMissingTheirTarget(ownerPubkey: owner),
          equals({
            'absent': {groupId, 'conv_group_2'},
          }),
        );
      });

      test('leaves out a reply whose target is stored', () async {
        await conversation(groupId, isGroup: true);
        await conversation(conversationId1, isGroup: false);
        await message('target', conversationId: conversationId1);
        await message('reply', conversationId: groupId, replyToId: 'target');

        expect(
          await dao.groupRepliesMissingTheirTarget(ownerPubkey: owner),
          isEmpty,
        );
      });

      test('leaves out a reply in a one-to-one', () async {
        await conversation(conversationId1, isGroup: false);
        await message(
          'reply',
          conversationId: conversationId1,
          replyToId: 'absent',
        );

        expect(
          await dao.groupRepliesMissingTheirTarget(ownerPubkey: owner),
          isEmpty,
        );
      });

      test('leaves out a group the account has written in', () async {
        await conversation(groupId, isGroup: true, currentUserHasSent: true);
        await message('reply', conversationId: groupId, replyToId: 'absent');

        expect(
          await dao.groupRepliesMissingTheirTarget(ownerPubkey: owner),
          isEmpty,
        );
      });

      test('reads only the given account', () async {
        await conversation(groupId, isGroup: true, ownerPubkey: 'other');
        await message(
          'reply',
          conversationId: groupId,
          replyToId: 'absent',
          ownerPubkey: 'other',
        );

        expect(
          await dao.groupRepliesMissingTheirTarget(ownerPubkey: owner),
          isEmpty,
        );
      });
    });

    group('hasGiftWrap', () {
      test('returns true when gift wrap ID exists', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello!',
          createdAt: 1700000000,
          giftWrapId: 'gw_unique_123',
        );

        final exists = await dao.hasGiftWrap('gw_unique_123');
        expect(exists, isTrue);
      });

      test('returns false when gift wrap ID does not exist', () async {
        final exists = await dao.hasGiftWrap('gw_nonexistent');
        expect(exists, isFalse);
      });

      test('returns false when table is empty', () async {
        final exists = await dao.hasGiftWrap('gw_any');
        expect(exists, isFalse);
      });
    });

    group('giftWrapIdsPresent', () {
      test('returns only the subset of ids that have a message row', () async {
        await dao.insertMessage(
          id: 'msg_present',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello!',
          createdAt: 1700000000,
          giftWrapId: 'gw_present',
        );

        final present = await dao.giftWrapIdsPresent({
          'gw_present',
          'gw_absent',
        });
        expect(present, equals({'gw_present'}));
      });

      test('returns an empty set for empty input', () async {
        await dao.insertMessage(
          id: 'msg_x',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hi',
          createdAt: 1700000000,
          giftWrapId: 'gw_x',
        );

        expect(await dao.giftWrapIdsPresent(const <String>{}), isEmpty);
      });
    });

    group('hasMatchingMessage', () {
      test(
        'matches cross-protocol duplicates within the default 5s window',
        () async {
          // A NIP-04 arrival: the receive path writes the wire event id into
          // BOTH columns, which is what marks the row as the twin a NIP-17
          // rumor may collapse onto.
          await dao.insertMessage(
            id: 'ev_nip04_original',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'Retryable message',
            createdAt: 1700000000,
            giftWrapId: 'ev_nip04_original',
            ownerPubkey: 'pubkey_owner',
          );

          final duplicate = await dao.hasMatchingMessage(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'Retryable message',
            createdAt: 1700000004,
            ownerPubkey: 'pubkey_owner',
            counterpart: DmDedupCounterpart.nip04Copy,
          );

          expect(duplicate, isTrue);
        },
      );

      test(
        'does not match repeated identical content after the default window',
        () async {
          await dao.insertMessage(
            id: 'msg_first_ok',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'ok',
            createdAt: 1700000000,
            giftWrapId: 'gw_first_ok',
            ownerPubkey: 'pubkey_owner',
          );

          // Counterpart matches the stored row's shape, so the window is the
          // only thing that can reject it — keeping this a window test.
          final duplicate = await dao.hasMatchingMessage(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'ok',
            createdAt: 1700000030,
            ownerPubkey: 'pubkey_owner',
            counterpart: DmDedupCounterpart.nip17Copy,
          );

          expect(duplicate, isFalse);
        },
      );

      test('dedups a re-wrapped rumor but not a re-minted retry outside the '
          'matching window', () async {
        const conversationId = 'receiver_side_convo';
        const senderPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const recipientPubkey =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const text = 'reel reply probe';
        final reelMessageId = 'r' * 64;

        // A manual retry is minted only after the sender's OK-confirm budget
        // expires, so it is outside the ±5s content match used for
        // cross-protocol duplicate detection.
        const firstCreatedAt = 1786700000;
        const retryCreatedAt = firstCreatedAt + 13;

        Future<bool> ingest({
          required String rumorId,
          required String giftWrapId,
          required int createdAt,
        }) => dao.insertMessage(
          id: rumorId,
          conversationId: conversationId,
          senderPubkey: senderPubkey,
          content: text,
          createdAt: createdAt,
          giftWrapId: giftWrapId,
          replyToId: reelMessageId,
          ownerPubkey: recipientPubkey,
        );

        // Correct retry: one kind-14 rumor, re-wrapped. The wrap id changes,
        // but the stable receiver key is the rumor id, so only one row inserts.
        expect(
          await ingest(
            rumorId: 'a' * 64,
            giftWrapId: 'w' * 64,
            createdAt: firstCreatedAt,
          ),
          isTrue,
        );
        expect(
          await ingest(
            rumorId: 'a' * 64,
            giftWrapId: 'x' * 64,
            createdAt: firstCreatedAt,
          ),
          isFalse,
          reason: 'a re-wrapped replay of the same rumor must not insert again',
        );

        var rendered = await dao.getMessagesForConversation(conversationId);
        expect(rendered, hasLength(1));

        expect(
          await dao.hasMatchingMessage(
            conversationId: conversationId,
            senderPubkey: senderPubkey,
            content: text,
            createdAt: retryCreatedAt,
            ownerPubkey: recipientPubkey,
            counterpart: DmDedupCounterpart.nip17Copy,
          ),
          isFalse,
          reason: '13s apart is outside the ±5s window',
        );
        expect(
          await dao.hasMatchingMessage(
            conversationId: conversationId,
            senderPubkey: senderPubkey,
            content: text,
            createdAt: firstCreatedAt + 4,
            ownerPubkey: recipientPubkey,
            counterpart: DmDedupCounterpart.nip17Copy,
          ),
          isTrue,
          reason:
              'positive control: an arriving NIP-04 copy still collapses onto '
              'its stored NIP-17 twin inside 5s',
        );
        expect(
          await dao.hasMatchingMessage(
            conversationId: conversationId,
            senderPubkey: senderPubkey,
            content: text,
            createdAt: firstCreatedAt + 4,
            ownerPubkey: recipientPubkey,
            counterpart: DmDedupCounterpart.nip04Copy,
          ),
          isFalse,
          reason:
              '#7324: an arriving NIP-17 rumor must NOT collapse onto a row '
              'that also arrived over NIP-17 — that is a genuine repeat',
        );

        // The bug: a fresh retry mints a second rumor id. Nothing collapses it.
        expect(
          await ingest(
            rumorId: 'b' * 64,
            giftWrapId: 'y' * 64,
            createdAt: retryCreatedAt,
          ),
          isTrue,
        );

        rendered = await dao.getMessagesForConversation(conversationId);
        expect(
          rendered,
          hasLength(2),
          reason: 'two rumor ids for one message render as two bubbles',
        );
        expect(rendered.map((m) => m.content).toSet(), {text});
      });

      test('a NIP-04 event does not collapse onto another NIP-04 row (#7324, '
          'mirrored onto the legacy protocol)', () async {
        await dao.insertMessage(
          id: 'ev_nip04_first',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'ok',
          createdAt: 1700000000,
          giftWrapId: 'ev_nip04_first',
          ownerPubkey: 'pubkey_owner',
        );

        expect(
          await dao.hasMatchingMessage(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'ok',
            createdAt: 1700000002,
            ownerPubkey: 'pubkey_owner',
            counterpart: DmDedupCounterpart.nip17Copy,
          ),
          isFalse,
          reason: 'a second kind-4 two seconds later is a genuine repeat',
        );
      });

      test('unconstrained matches either arrival shape', () async {
        await dao.insertMessage(
          id: 'rumor_nip17',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_owner',
          content: 'ok',
          createdAt: 1700000000,
          giftWrapId: 'wrap_nip17',
          ownerPubkey: 'pubkey_owner',
        );
        await dao.insertMessage(
          id: 'ev_nip04',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_owner',
          content: 'ok',
          createdAt: 1700000000,
          giftWrapId: 'ev_nip04',
          ownerPubkey: 'pubkey_owner',
        );

        for (final conversationId in [conversationId1, conversationId2]) {
          expect(
            await dao.hasMatchingMessage(
              conversationId: conversationId,
              senderPubkey: 'pubkey_owner',
              content: 'ok',
              createdAt: 1700000002,
              ownerPubkey: 'pubkey_owner',
              counterpart: DmDedupCounterpart.unconstrained,
            ),
            isTrue,
            reason: 'the self-send paths opt out of the arrival filter',
          );
        }
      });
    });

    group('claimCrossProtocolTwin', () {
      Future<void> insertNip04(String id, {int at = 1700000000}) =>
          dao.insertMessage(
            id: id,
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'same text',
            createdAt: at,
            giftWrapId: id,
            ownerPubkey: 'pubkey_owner',
          );

      Future<bool> claimNip04Twin({int at = 1700000000}) =>
          dao.claimCrossProtocolTwin(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'same text',
            createdAt: at,
            counterpart: DmDedupCounterpart.nip04Copy,
            ownerPubkey: 'pubkey_owner',
          );

      test('claims a stored NIP-04 twin exactly once', () async {
        // The dual-send twin is 1:1, so the second same-text rumor inside the
        // window is a genuine repeat and must survive. Before #8211 both were
        // suppressed and three sent messages showed as one bubble.
        await insertNip04('ev_nip04');

        expect(await claimNip04Twin(at: 1700000001), isTrue);
        expect(await claimNip04Twin(at: 1700000003), isFalse);
      });

      test('marks the claimed row so it is spent', () async {
        await insertNip04('ev_nip04');
        await claimNip04Twin();

        final row = await dao.getMessageById('ev_nip04');
        expect(row!.twinCollapsed, isTrue);
      });

      test('leaves an unclaimed sibling available', () async {
        // Two dual-sends of the same text mean two twins, so two rumors may
        // be collapsed — and only two.
        await insertNip04('ev_nip04_a');
        await insertNip04('ev_nip04_b', at: 1700000002);

        expect(await claimNip04Twin(at: 1700000001), isTrue);
        expect(await claimNip04Twin(at: 1700000002), isTrue);
        expect(await claimNip04Twin(at: 1700000003), isFalse);
      });

      test('ignores a row that arrived over the same protocol', () async {
        // A NIP-17 row (distinct id/gift_wrap_id) is a genuine earlier
        // message to another NIP-17 rumor, never its twin (#7324).
        await dao.insertMessage(
          id: 'rumor_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'same text',
          createdAt: 1700000000,
          giftWrapId: 'wrap_1',
          ownerPubkey: 'pubkey_owner',
        );

        expect(await claimNip04Twin(at: 1700000001), isFalse);
      });

      test('claims a NIP-17 twin from the NIP-04 side', () async {
        await dao.insertMessage(
          id: 'rumor_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'same text',
          createdAt: 1700000000,
          giftWrapId: 'wrap_1',
          ownerPubkey: 'pubkey_owner',
        );

        Future<bool> claimNip17Twin() => dao.claimCrossProtocolTwin(
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'same text',
          createdAt: 1700000001,
          counterpart: DmDedupCounterpart.nip17Copy,
          ownerPubkey: 'pubkey_owner',
        );

        expect(await claimNip17Twin(), isTrue);
        expect(await claimNip17Twin(), isFalse);
      });

      test('does not claim outside the window', () async {
        await insertNip04('ev_nip04');

        expect(await claimNip04Twin(at: 1700000006), isFalse);
      });

      test("does not claim another account's row", () async {
        await insertNip04('ev_nip04');

        final claimed = await dao.claimCrossProtocolTwin(
          conversationId: conversationId1,
          senderPubkey: 'pubkey_peer',
          content: 'same text',
          createdAt: 1700000001,
          counterpart: DmDedupCounterpart.nip04Copy,
          ownerPubkey: 'pubkey_other_owner',
        );

        expect(claimed, isFalse);
      });

      test('claiming one owner does not spend another owner copy', () async {
        for (final (owner, wrap) in [
          ('pubkey_owner_a', 'wrap_owner_a'),
          ('pubkey_owner_b', 'wrap_owner_b'),
        ]) {
          await dao.insertMessage(
            id: 'shared_rumor',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'same text',
            createdAt: 1700000000,
            giftWrapId: wrap,
            ownerPubkey: owner,
          );
        }

        expect(
          await dao.claimCrossProtocolTwin(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'same text',
            createdAt: 1700000001,
            counterpart: DmDedupCounterpart.nip17Copy,
            ownerPubkey: 'pubkey_owner_a',
          ),
          isTrue,
        );

        final ownerA = await dao.getMessageById(
          'shared_rumor',
          ownerPubkey: 'pubkey_owner_a',
        );
        final ownerB = await dao.getMessageById(
          'shared_rumor',
          ownerPubkey: 'pubkey_owner_b',
        );
        expect(ownerA!.twinCollapsed, isTrue);
        expect(ownerB!.twinCollapsed, isFalse);
      });

      test('still claims a soft-deleted twin', () async {
        // Deliberate: the deleted row is the twin, and letting its kind-4
        // counterpart insert would resurrect a message the user deleted as a
        // fresh, permanently undeletable bubble — a kind 5 names the rumor id,
        // never the twin's (#8211).
        await insertNip04('ev_nip04');
        await dao.markMessageDeleted('ev_nip04', ownerPubkey: 'pubkey_owner');

        expect(await claimNip04Twin(at: 1700000001), isTrue);
      });

      test('rejects unconstrained, which cannot identify a twin', () async {
        await insertNip04('ev_nip04');

        expect(
          () => dao.claimCrossProtocolTwin(
            conversationId: conversationId1,
            senderPubkey: 'pubkey_peer',
            content: 'same text',
            createdAt: 1700000001,
            counterpart: DmDedupCounterpart.unconstrained,
            ownerPubkey: 'pubkey_owner',
          ),
          throwsArgumentError,
        );
      });
    });

    group('hasMessageWithSendBatchId', () {
      const owner = 'pubkey_owner_a';

      test(
        'distinguishes two same-text sends by batch id — the exact '
        'collision the ±5s hasMatchingMessage window could not tell apart',
        () async {
          // Same content, same second, same owner: hasMatchingMessage would
          // treat the second send as a duplicate of the first and drop it.
          // The durable batch id is what keeps them distinct.
          await dao.insertMessage(
            id: 'msg_b1',
            conversationId: conversationId1,
            senderPubkey: owner,
            content: 'ok',
            createdAt: 1700000000,
            giftWrapId: 'gw_b1',
            ownerPubkey: owner,
            sendBatchId: 'batch-1',
          );
          await dao.insertMessage(
            id: 'msg_b2',
            conversationId: conversationId1,
            senderPubkey: owner,
            content: 'ok',
            createdAt: 1700000002,
            giftWrapId: 'gw_b2',
            ownerPubkey: owner,
            sendBatchId: 'batch-2',
          );

          expect(
            await dao.hasMessageWithSendBatchId(
              batchId: 'batch-1',
              ownerPubkey: owner,
            ),
            isTrue,
          );
          expect(
            await dao.hasMessageWithSendBatchId(
              batchId: 'batch-2',
              ownerPubkey: owner,
            ),
            isTrue,
          );
          expect(
            await dao.hasMessageWithSendBatchId(
              batchId: 'missing',
              ownerPubkey: owner,
            ),
            isFalse,
          );
        },
      );

      test('is scoped by strict owner equality', () async {
        const ownerA = 'pubkey_owner_a';
        const ownerB = 'pubkey_owner_b';

        await dao.insertMessage(
          id: 'msg_x',
          conversationId: conversationId1,
          senderPubkey: ownerA,
          content: 'owned by A',
          createdAt: 1700000000,
          giftWrapId: 'gw_x',
          ownerPubkey: ownerA,
          sendBatchId: 'batch-x',
        );

        expect(
          await dao.hasMessageWithSendBatchId(
            batchId: 'batch-x',
            ownerPubkey: ownerA,
          ),
          isTrue,
        );
        expect(
          await dao.hasMessageWithSendBatchId(
            batchId: 'batch-x',
            ownerPubkey: ownerB,
          ),
          isFalse,
        );
      });
    });

    group('deleteConversationMessages', () {
      test('deletes all messages in a conversation', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );
        await dao.insertMessage(
          id: 'msg_3',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_alice',
          content: 'Other conv',
          createdAt: 1700000200,
          giftWrapId: 'gw_3',
        );

        final deleted = await dao.deleteConversationMessages(conversationId1);

        expect(deleted, equals(2));
        final conv1Msgs = await dao.getMessagesForConversation(conversationId1);
        expect(conv1Msgs, isEmpty);
        final conv2Msgs = await dao.getMessagesForConversation(conversationId2);
        expect(conv2Msgs, hasLength(1));
      });

      test('returns 0 when conversation has no messages', () async {
        final deleted = await dao.deleteConversationMessages('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('deleteMessage', () {
      test('deletes single message by ID', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );

        final deleted = await dao.deleteMessage('msg_1');

        expect(deleted, equals(1));
        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_2'));
      });

      test('returns 0 for non-existent message', () async {
        final deleted = await dao.deleteMessage('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('countMessages', () {
      test('returns count of messages in a conversation', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );
        await dao.insertMessage(
          id: 'msg_3',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_alice',
          content: 'Other conv',
          createdAt: 1700000200,
          giftWrapId: 'gw_3',
        );

        final count = await dao.countMessages(conversationId1);
        expect(count, equals(2));
      });

      test('returns 0 for conversation with no messages', () async {
        final count = await dao.countMessages('nonexistent');
        expect(count, equals(0));
      });
    });

    group('account-switch cleanup', () {
      const userA = 'pubkey_cleanup_a';
      const userB = 'pubkey_cleanup_b';

      Future<void> insert(String id, String? ownerPubkey) {
        return dao.insertMessage(
          id: id,
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: id,
          createdAt: 1700000001,
          giftWrapId: 'gw_$id',
          ownerPubkey: ownerPubkey,
        );
      }

      test('deletes the leaving account and ambiguous owners', () async {
        await insert('msg_a', userA);
        await insert('msg_b', userB);
        await insert('msg_null', null);
        await insert('msg_empty', '');

        expect(await dao.clearForAccountSwitch(userA), equals(3));
        expect(await dao.countMessages(conversationId1), equals(1));
        expect(
          await dao.countMessages(conversationId1, ownerPubkey: userB),
          equals(1),
        );
      });

      test('exact-owner deletion preserves ambiguous rows', () async {
        await insert('msg_a', userA);
        await insert('msg_b', userB);
        await insert('msg_empty', '');

        expect(await dao.deleteAllForOwner(userA), equals(1));
        expect(await dao.countMessages(conversationId1), equals(2));
      });

      test('unknown owner cleanup deletes only ambiguous rows', () async {
        await insert('msg_a', userA);
        await insert('msg_b', userB);
        await insert('msg_null', null);
        await insert('msg_empty', '');

        expect(await dao.clearUnowned(), equals(2));
        expect(await dao.countMessages(conversationId1), equals(2));
      });
    });

    group('ownerPubkey scoping', () {
      const userA = 'pubkey_user_a';
      const userB = 'pubkey_user_b';

      test(
        'queries scoped by ownerPubkey only return that user messages',
        () async {
          await dao.insertMessage(
            id: 'msg_a1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'For user A',
            createdAt: 1700000001,
            giftWrapId: 'gw_a1',
            ownerPubkey: userA,
          );
          await dao.insertMessage(
            id: 'msg_b1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'For user B',
            createdAt: 1700000002,
            giftWrapId: 'gw_b1',
            ownerPubkey: userB,
          );

          final userAMessages = await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: userA,
          );
          final userBMessages = await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: userB,
          );

          expect(userAMessages, hasLength(1));
          expect(userAMessages.first.content, equals('For user A'));
          expect(userBMessages, hasLength(1));
          expect(userBMessages.first.content, equals('For user B'));
        },
      );

      test(
        'legacy messages (NULL ownerPubkey) are visible to scoped queries',
        () async {
          await dao.insertMessage(
            id: 'msg_legacy',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Legacy message',
            createdAt: 1700000001,
            giftWrapId: 'gw_legacy',
          );
          await dao.insertMessage(
            id: 'msg_a1',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'User A message',
            createdAt: 1700000002,
            giftWrapId: 'gw_a1',
            ownerPubkey: userA,
          );

          final userAMessages = await dao.getMessagesForConversation(
            conversationId1,
            ownerPubkey: userA,
          );

          expect(userAMessages, hasLength(2));
        },
      );

      test('account-switch cleanup preserves another user messages', () async {
        await dao.insertMessage(
          id: 'msg_a1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'User A msg',
          createdAt: 1700000001,
          giftWrapId: 'gw_a1',
          ownerPubkey: userA,
        );
        await dao.insertMessage(
          id: 'msg_b1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'User B msg',
          createdAt: 1700000002,
          giftWrapId: 'gw_b1',
          ownerPubkey: userB,
        );

        final deleted = await dao.clearForAccountSwitch(userA);

        expect(deleted, equals(1));
        final remaining = await dao.getMessagesForConversation(
          conversationId1,
          ownerPubkey: userB,
        );
        expect(remaining, hasLength(1));
        expect(remaining.first.content, equals('User B msg'));
      });

      test('countMessages respects ownerPubkey', () async {
        await dao.insertMessage(
          id: 'msg_a1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'A',
          createdAt: 1700000001,
          giftWrapId: 'gw_a1',
          ownerPubkey: userA,
        );
        await dao.insertMessage(
          id: 'msg_b1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'B',
          createdAt: 1700000002,
          giftWrapId: 'gw_b1',
          ownerPubkey: userB,
        );

        final countA = await dao.countMessages(
          conversationId1,
          ownerPubkey: userA,
        );
        final countB = await dao.countMessages(
          conversationId1,
          ownerPubkey: userB,
        );

        expect(countA, equals(1));
        expect(countB, equals(1));
      });
    });
  });
}
