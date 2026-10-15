import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/sound_requests/sound_request_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('interactions', () {
    test(
      'account snapshots survive recreation without leaking between owners',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = SoundRequestPreferencesStore(prefs);
        final snapshot = SoundRequestSnapshot(
          audioByVideo: {'video': 'a' * 64},
        );
        await store.write('owner', snapshot);
        expect(
          await SoundRequestPreferencesStore(prefs).read('owner'),
          snapshot,
        );
        expect(await store.read('other'), const SoundRequestSnapshot());
      },
    );
  });
  group('interactions', () {
    test(
      'malformed persisted state throws and remains available for recovery',
      () async {
        SharedPreferences.setMockInitialValues({
          'sound_requests_v1_owner': 'broken',
        });
        final prefs = await SharedPreferences.getInstance();
        await expectLater(
          SoundRequestPreferencesStore(prefs).read('owner'),
          throwsFormatException,
        );
        expect(prefs.getString('sound_requests_v1_owner'), 'broken');
      },
    );
  });
}
