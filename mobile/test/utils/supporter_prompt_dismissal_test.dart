import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/supporter_prompt_dismissal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(SupporterPromptDismissalStore, () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<SupporterPromptDismissalStore> storeFor(String pubkey) async =>
        SupporterPromptDismissalStore(
          prefs: await SharedPreferences.getInstance(),
          userIdHex: pubkey,
        );

    test('persists a dismissal', () async {
      final store = await storeFor('account-a');

      await store.dismiss();

      expect((await storeFor('account-a')).isDismissed(), isTrue);
    });

    test('keeps dismissals scoped to one account', () async {
      await (await storeFor('account-a')).dismiss();

      expect((await storeFor('account-b')).isDismissed(), isFalse);
    });

    test('treats missing and malformed values as not dismissed', () async {
      SharedPreferences.setMockInitialValues({
        SupporterPromptDismissalStore.keyFor('malformed'): 'true',
      });

      expect((await storeFor('missing')).isDismissed(), isFalse);
      expect((await storeFor('malformed')).isDismissed(), isFalse);
    });
  });
}
