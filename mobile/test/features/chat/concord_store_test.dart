import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/chat/concord_store.dart';

void main() {
  group('put / get / clearAccount', () {
    test('a failed batch cannot leave an orphaned ciphertext record', () async {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftConcordStore(
        dao: db.concordStoreDao,
        account: 'a' * 64,
        scope: 'relay/general',
      );
      await store.put('existing', 'keep');
      await db.customStatement('''
        CREATE TRIGGER reject_batch_record BEFORE INSERT ON concord_store_entries
        WHEN NEW.key = 'reject'
        BEGIN SELECT RAISE(ABORT, 'batch test'); END;
      ''');
      await expectLater(
        store.writeBatch(
          {'first': 'ciphertext', 'reject': 'value'},
          remove: ['existing'],
        ),
        throwsA(isA<Exception>()),
      );
      expect(await store.get('first'), isNull);
      expect(await store.get('existing'), 'keep');
    });
    test(
      'store captures the account and room and survives adapter recreation',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        DriftConcordStore store(String account, String scope) =>
            DriftConcordStore(
              dao: db.concordStoreDao,
              account: account,
              scope: scope,
            );
        await store('a' * 64, 'relay/general').put('sealed', 'ciphertext');
        expect(
          await store('a' * 64, 'relay/general').get('sealed'),
          'ciphertext',
        );
        expect(await store('b' * 64, 'relay/general').get('sealed'), isNull);
        expect(
          await store('a' * 64, 'relay/introductions').get('sealed'),
          isNull,
        );
        await store('a' * 64, 'relay/general').remove('sealed');
        expect(await store('a' * 64, 'relay/general').get('sealed'), isNull);
        await store('b' * 64, 'relay/general').put('sealed', 'other');
        await store('a' * 64, 'relay/general').clearAccount();
        expect(await store('b' * 64, 'relay/general').get('sealed'), 'other');
      },
    );
  });
}
