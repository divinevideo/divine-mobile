import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/chat/concord_store.dart';

void main() {
  group('put / get / clearAccount', () {
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
