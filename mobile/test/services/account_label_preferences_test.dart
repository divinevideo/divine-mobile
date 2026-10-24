import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_cubit.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _labelerA =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _labelerB =
    '4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('account label preferences', () {
    test('remote account self-labels update publishing defaults and UI without public event echo', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final port = AccountPreferenceStore(preferences);
      final repository = FakeAccountState(_account);
      await port.bind(repository);
      final auth = _Auth();
      final client = _Client();
      when(() => auth.currentPublicKeyHex).thenReturn(_account);
      final labels = AccountLabelService(
        authService: auth,
        nostrClient: client,
        accountPreferences: port,
      );
      await labels.initialize();
      final cubit = AccountContentLabelsCubit(service: labels)..load();
      repository.receive({'account_content_label': 'nudity'});
      await pumpEventQueue();
      expect(labels.defaultVideoLabels, {ContentLabel.nudity});
      expect(cubit.state.labels, {ContentLabel.nudity});
      expect(repository.localWrites, 0);
      verifyZeroInteractions(client);
      repository.receive({'account_content_label': null});
      await pumpEventQueue();
      expect(labels.defaultVideoLabels, isEmpty);
      await cubit.close();
      labels.dispose();
      port.dispose();
      await repository.close();
    });

    test('trusted labelers merge per pubkey and remote disable/reset applies without echo', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final port = AccountPreferenceStore(preferences);
      final repository = FakeAccountState(_account);
      await port.bind(repository);
      final service = ModerationLabelService(
        nostrClient: _Client(),
        authService: _Auth(),
        sharedPreferences: preferences,
        accountPreferences: port,
        canQueryRelays: () => false,
      );
      await service.ensureLoaded();
      await service.addLabeler(_labelerA);
      expect(repository.values, {'trusted_labeler/$_labelerA': true});
      repository.receive({
        'trusted_labeler/$_labelerB': true,
        'following_moderation_enabled': true,
      });
      await pumpEventQueue();
      expect(service.customLabelers, {_labelerA, _labelerB});
      expect(service.isFollowingModerationEnabled, isTrue);
      expect(repository.localWrites, 1);
      repository.receive({
        'trusted_labeler/$_labelerA': false,
        'following_moderation_enabled': null,
      });
      await pumpEventQueue();
      expect(service.customLabelers, {_labelerB});
      expect(service.isFollowingModerationEnabled, isFalse);
      expect(repository.localWrites, 1);
      service.dispose();
      repository.receive({'trusted_labeler/$_labelerB': null});
      await pumpEventQueue();
      port.dispose();
      await repository.close();
    });
  });
}
