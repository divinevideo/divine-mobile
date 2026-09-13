// ABOUTME: Tests broken-video persistence, owner scoping, and expiry cleanup.
// ABOUTME: Keeps tracker behavior separate from VideoEventService integration.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(BrokenVideoTracker, () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists marks independently for each owner', () async {
      final anonymous = BrokenVideoTracker();
      final signedIn = BrokenVideoTracker(ownerPubkey: 'a' * 64);
      await anonymous.initialize();
      await signedIn.initialize();

      await anonymous.markVideoBroken('anonymous-video', '404');
      await signedIn.markVideoBroken('signed-in-video', '404');

      final reloadedAnonymous = BrokenVideoTracker();
      final reloadedSignedIn = BrokenVideoTracker(ownerPubkey: 'a' * 64);
      await reloadedAnonymous.initialize();
      await reloadedSignedIn.initialize();
      expect(reloadedAnonymous.brokenVideoIds, ['anonymous-video']);
      expect(reloadedSignedIn.brokenVideoIds, ['signed-in-video']);
    });

    test('unmark and clear persist across tracker instances', () async {
      final tracker = BrokenVideoTracker();
      await tracker.initialize();
      await tracker.markVideoBroken('first', '404');
      await tracker.markVideoBroken('second', '404');

      await tracker.unmarkVideoBroken('first');
      expect(tracker.isVideoBroken('first'), isFalse);
      expect(tracker.brokenVideoCount, 1);

      await tracker.clearAll();
      final reloaded = BrokenVideoTracker();
      await reloaded.initialize();
      expect(reloaded.brokenVideoIds, isEmpty);
    });

    test('initialize drops expired and legacy unscoped entries', () async {
      final expired = DateTime.now().subtract(const Duration(days: 8));
      final current = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'broken_video_urls_anonymous': jsonEncode(['expired', 'current']),
        'broken_video_timestamps_anonymous': jsonEncode({
          'expired': expired.millisecondsSinceEpoch,
          'current': current.millisecondsSinceEpoch,
        }),
        'broken_video_urls': jsonEncode(['legacy']),
        'broken_video_timestamps': jsonEncode({
          'legacy': current.millisecondsSinceEpoch,
        }),
      });

      final tracker = BrokenVideoTracker();
      await tracker.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(tracker.brokenVideoIds, ['current']);
      expect(prefs.containsKey('broken_video_urls'), isFalse);
      expect(prefs.containsKey('broken_video_timestamps'), isFalse);
    });
  });
}
