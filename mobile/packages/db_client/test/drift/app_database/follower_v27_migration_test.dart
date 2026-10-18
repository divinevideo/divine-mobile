import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  group('follower v27 migration', () {
    final owner = 'a' * 64;
    final otherOwner = 'b' * 64;
    final conversation = 'c' * 64;
    final message = 'd' * 64;
    final follower = 'e' * 64;
    late SchemaVerifier verifier;

    setUp(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('canonical v25 retains account dismissals and sound jobs', () async {
      final schema = await verifier.schemaAt(25);
      for (final account in [owner, otherOwner]) {
        schema.rawDatabase.execute(
          'INSERT INTO conversations (id, participant_pubkeys, created_at, '
          'last_message_timestamp, owner_pubkey, is_read, is_dismissed) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            conversation,
            jsonEncode([account, follower]),
            100,
            100,
            account,
            1,
            1,
          ],
        );
        schema.rawDatabase.execute(
          'INSERT INTO conversation_dismissals (conversation_id, owner_pubkey, '
          'boundary_timestamp, known_message_ids) VALUES (?, ?, ?, ?)',
          [
            conversation,
            account,
            100,
            jsonEncode([message]),
          ],
        );
        schema.rawDatabase.execute(
          'INSERT INTO sound_request_states '
          '(owner_pubkey, section, record_key, value) VALUES (?, ?, ?, ?)',
          [account, 'jobs', 'pending', 'queued workflow'],
        );
      }
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 27);

      for (final account in [owner, otherOwner]) {
        final sound = await db.soundRequestStateDao.readAccount(account);
        expect(sound.single.value, 'queued workflow');
        await db.directMessagesDao.clearForAccountSwitch(account);
        await db.conversationsDao.clearForAccountSwitch(account);
        await db.directMessagesDao.insertMessage(
          id: message,
          conversationId: conversation,
          senderPubkey: follower,
          content: 'Replayed message',
          createdAt: 100,
          giftWrapId: 'f' * 64,
          ownerPubkey: account,
        );
        await db.conversationsDao.upsertConversation(
          id: conversation,
          participantPubkeys: jsonEncode([account, follower]),
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 100,
          ownerPubkey: account,
          isRead: false,
        );
        final restored = await db.conversationsDao.getConversation(
          conversation,
          ownerPubkey: account,
        );
        expect(restored!.isDismissed, isTrue);
        expect(restored.isRead, isTrue);
      }
      await db.myFollowersDao.upsertAll(
        ownerPubkey: owner,
        followers: [(pubkey: follower, followedAt: 90)],
        seenAt: 100,
      );
      expect(await db.myFollowersDao.followersOf(owner), [
        (pubkey: follower, followedAt: 90),
      ]);
      expect(await db.myFollowersDao.followersOf(otherOwner), isEmpty);
    });

    test('canonical v26 retains read state, replay ids and queued work', () async {
      final schema = await verifier.schemaAt(26);
      for (final account in [owner, otherOwner]) {
        schema.rawDatabase.execute(
          'INSERT INTO conversations (id, participant_pubkeys, created_at, '
          'last_message_timestamp, last_message_created_at, retained_message_ids, '
          'owner_pubkey, is_read, is_dismissed, last_read_timestamp) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            conversation,
            jsonEncode([account, follower]),
            100,
            110,
            120,
            jsonEncode([message]),
            account,
            1,
            1,
            120,
          ],
        );
        schema.rawDatabase.execute(
          'INSERT INTO conversation_dismissals (conversation_id, owner_pubkey, '
          'boundary_timestamp, known_message_ids) VALUES (?, ?, ?, ?)',
          [
            conversation,
            account,
            110,
            jsonEncode([message]),
          ],
        );
        schema.rawDatabase.execute(
          'INSERT INTO sound_request_states '
          '(owner_pubkey, section, record_key, value) VALUES (?, ?, ?, ?)',
          [account, 'jobs', 'pending', 'queued workflow'],
        );
      }
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 27);
      for (final account in [owner, otherOwner]) {
        final row = (await db.conversationsDao.getConversation(
          conversation,
          ownerPubkey: account,
        ))!;
        expect(row.lastMessageTimestamp, 110);
        expect(row.lastMessageCreatedAt, 120);
        expect(row.retainedMessageIds, jsonEncode([message]));
        expect(row.lastReadTimestamp, 120);
        expect(row.isRead, isTrue);
        expect(row.isDismissed, isTrue);
        expect(
          (await db.soundRequestStateDao.readAccount(account)).single.value,
          'queued workflow',
        );
        final marker = await db
            .customSelect(
              'SELECT boundary_timestamp, known_message_ids '
              'FROM conversation_dismissals WHERE owner_pubkey = ?',
              variables: [Variable<String>(account)],
            )
            .getSingle();
        expect(marker.read<int>('boundary_timestamp'), 110);
        expect(marker.read<String>('known_message_ids'), jsonEncode([message]));
      }
      await db.myFollowersDao.upsertAll(
        ownerPubkey: owner,
        followers: [(pubkey: follower, followedAt: 90)],
        seenAt: 100,
      );
      expect(await db.myFollowersDao.followersOf(owner), [
        (pubkey: follower, followedAt: 90),
      ]);
      expect(await db.myFollowersDao.followersOf(otherOwner), isEmpty);
    });

    for (final version in [25, 26]) {
      test(
        'ranking preview v$version retains followers and gains landed storage',
        () async {
          // Ranking v25 preceded dismissal; ranking v26 preceded retained chats.
          // Reproduce each preview without modifying canonical snapshots.
          final schema = await verifier.schemaAt(version);
          if (version == 25) {
            schema.rawDatabase.execute('DROP TABLE conversation_dismissals');
            schema.rawDatabase.execute(
              'ALTER TABLE conversations DROP COLUMN is_dismissed',
            );
          } else {
            schema.rawDatabase.execute(
              'ALTER TABLE conversations DROP COLUMN last_message_created_at',
            );
            schema.rawDatabase.execute(
              'ALTER TABLE conversations DROP COLUMN retained_message_ids',
            );
          }
          schema.rawDatabase.execute(
            'CREATE TABLE my_followers (owner_pubkey TEXT NOT NULL, '
            'follower_pubkey TEXT NOT NULL, followed_at INTEGER NULL, '
            'last_seen_at INTEGER NOT NULL, '
            'PRIMARY KEY (owner_pubkey, follower_pubkey))',
          );
          for (final account in [owner, otherOwner]) {
            schema.rawDatabase.execute(
              'INSERT INTO my_followers '
              '(owner_pubkey, follower_pubkey, followed_at, last_seen_at) '
              'VALUES (?, ?, ?, ?)',
              [account, follower, if (account == owner) 90 else null, 100],
            );
          }
          schema.rawDatabase.execute(
            'INSERT INTO sound_request_states '
            '(owner_pubkey, section, record_key, value) VALUES (?, ?, ?, ?)',
            [owner, 'jobs', 'pending', 'queued workflow'],
          );
          schema.rawDatabase.execute(
            'INSERT INTO conversations (id, participant_pubkeys, created_at, '
            'last_message_timestamp, owner_pubkey) VALUES (?, ?, ?, ?, ?)',
            [
              conversation,
              jsonEncode([owner, follower]),
              100,
              100,
              owner,
            ],
          );

          final db = AppDatabase(schema.newConnection());
          addTearDown(db.close);
          await verifier.migrateAndValidate(db, 27);

          expect(await db.myFollowersDao.followersOf(owner), [
            (pubkey: follower, followedAt: 90),
          ]);
          expect(await db.myFollowersDao.followersOf(otherOwner), [
            (pubkey: follower, followedAt: null),
          ]);
          final saved = await db
              .customSelect('SELECT * FROM my_followers')
              .get();
          expect(saved.map((row) => row.read<int>('last_seen_at')), [100, 100]);
          expect(
            (await db.soundRequestStateDao.readAccount(owner)).single.value,
            'queued workflow',
          );
          expect(
            (await db.conversationsDao.getConversation(
              conversation,
              ownerPubkey: owner,
            ))!.isDismissed,
            isFalse,
          );
          final migrated = (await db.conversationsDao.getConversation(
            conversation,
            ownerPubkey: owner,
          ))!;
          expect(migrated.lastMessageCreatedAt, isNull);
          expect(migrated.retainedMessageIds, isNull);
          await db.conversationsDao.setDismissed(
            conversation,
            ownerPubkey: owner,
            dismissed: true,
          );
          await db.conversationsDao.clearForAccountSwitch(owner);
          await db.conversationsDao.upsertConversation(
            id: conversation,
            participantPubkeys: jsonEncode([owner, follower]),
            isGroup: false,
            createdAt: 100,
            lastMessageTimestamp: 100,
            ownerPubkey: owner,
          );
          expect(
            (await db.conversationsDao.getConversation(
              conversation,
              ownerPubkey: owner,
            ))!.isDismissed,
            isTrue,
          );
        },
      );
    }
  });
}
