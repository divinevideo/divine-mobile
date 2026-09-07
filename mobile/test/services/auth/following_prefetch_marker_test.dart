// ABOUTME: Tests auth-time following prefetch completion markers.
// ABOUTME: Keeps fetch state separate from authoritative following-list data.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth/following_prefetch_marker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('following prefetch marker', () {
    test('records completion for only the requested account', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await markFollowingPrefetchComplete(prefs, 'account-pubkey');

      expect(hasFollowingPrefetchMarker(prefs, 'account-pubkey'), isTrue);
      expect(hasFollowingPrefetchMarker(prefs, 'other-pubkey'), isFalse);
    });
  });
}
