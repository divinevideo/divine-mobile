// ABOUTME: Verifies durable, account-isolated Messages navigation preferences.
// ABOUTME: Recreating the service must restore only the selected account's view.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/messages_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MessagesPreferenceService, () {
    test(
      'restores each account independently after service recreation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = MessagesPreferenceService(prefs);
        final first = 'a' * 64;
        final second = 'b' * 64;
        expect(service.roomsSelected(first), isFalse);
        await service.selectRooms(first, selected: true);
        final restored = MessagesPreferenceService(prefs);
        expect(restored.roomsSelected(first), isTrue);
        expect(restored.roomsSelected(second), isFalse);
        await restored.selectRooms(second, selected: true);
        await restored.selectRooms(first, selected: false);
        expect(restored.roomsSelected(first), isFalse);
        expect(restored.roomsSelected(second), isTrue);
      },
    );
  });
}
