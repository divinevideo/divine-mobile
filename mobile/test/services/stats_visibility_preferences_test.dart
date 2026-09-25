// ABOUTME: Unit tests for StatsVisibilityPreferences defaults and persistence.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(StatsVisibilityPreferences, () {
    test('defaults to total loops only on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = StatsVisibilityPreferences(prefs);

      expect(service.showTotalLoops, isTrue);
      expect(service.showVideoLoops, isFalse);
      expect(service.showPublishedDate, isFalse);
    });

    test('reads persisted values', () async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();

      final service = StatsVisibilityPreferences(prefs);

      expect(service.showTotalLoops, isFalse);
      expect(service.showVideoLoops, isTrue);
      expect(service.showPublishedDate, isTrue);
    });

    test('setters persist each key and notify listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = StatsVisibilityPreferences(prefs);
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setShowVideoLoops(true);
      await service.setShowPublishedDate(true);
      await service.setShowTotalLoops(false);

      expect(
        prefs.getBool(StatsVisibilityPreferences.showVideoLoopsKey),
        isTrue,
      );
      expect(
        prefs.getBool(StatsVisibilityPreferences.showPublishedDateKey),
        isTrue,
      );
      expect(
        prefs.getBool(StatsVisibilityPreferences.showTotalLoopsKey),
        isFalse,
      );
      expect(notifications, 3);
    });

    test('does not notify when a value is set to itself', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = StatsVisibilityPreferences(prefs);
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setShowTotalLoops(true);

      expect(notifications, 0);
    });

    test('declares every key device-scoped', () {
      expect(
        StatsVisibilityPreferences.deviceScopedPrefsKeys,
        containsAll(<String>[
          StatsVisibilityPreferences.showTotalLoopsKey,
          StatsVisibilityPreferences.showVideoLoopsKey,
          StatsVisibilityPreferences.showPublishedDateKey,
        ]),
      );
    });
  });
}
