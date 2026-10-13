import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/messages/messages_navigation_cubit.dart';
import 'package:openvine/services/messages_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MessagesNavigationCubit, () {
    late MessagesPreferenceService preferences;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = MessagesPreferenceService(
        await SharedPreferences.getInstance(),
      );
    });

    test('starts on Direct and restores Rooms for only its account', () async {
      final first = MessagesNavigationCubit(
        account: 'a' * 64,
        preferences: preferences,
      );
      expect(first.state, MessagesSection.direct);
      await first.select(MessagesSection.rooms);
      await first.close();
      final restored = MessagesNavigationCubit(
        account: 'a' * 64,
        preferences: preferences,
      );
      final other = MessagesNavigationCubit(
        account: 'b' * 64,
        preferences: preferences,
      );
      addTearDown(restored.close);
      addTearDown(other.close);
      expect(restored.state, MessagesSection.rooms);
      expect(other.state, MessagesSection.direct);
    });

    test(
      'explicit Direct selection replaces the saved Rooms preference',
      () async {
        final cubit = MessagesNavigationCubit(
          account: 'a' * 64,
          preferences: preferences,
        );
        addTearDown(cubit.close);
        await cubit.select(MessagesSection.rooms);
        await cubit.select(MessagesSection.direct);
        expect(cubit.state, MessagesSection.direct);
        expect(preferences.roomsSelected('a' * 64), isFalse);
      },
    );

    test('selection after disposal does not change saved state', () async {
      final cubit = MessagesNavigationCubit(
        account: 'a' * 64,
        preferences: preferences,
      );
      await cubit.close();
      await cubit.select(MessagesSection.rooms);
      expect(preferences.roomsSelected('a' * 64), isFalse);
    });
  });
}
