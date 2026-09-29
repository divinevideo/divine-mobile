import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DivineHostFilterService', () {
    test('defaults to enabled when no preference is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);

      expect(service.showDivineHostedOnly, isTrue);
    });

    test(
      'respects an explicitly disabled preference (opt-in to wider Nostr)',
      () async {
        SharedPreferences.setMockInitialValues({
          'show_divine_hosted_only': false,
        });
        final prefs = await SharedPreferences.getInstance();

        final service = DivineHostFilterService(prefs);

        expect(service.showDivineHostedOnly, isFalse);
      },
    );

    test('persists disabled state across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);
      await service.setShowDivineHostedOnly(false);

      expect(service.showDivineHostedOnly, isFalse);

      final reloaded = DivineHostFilterService(prefs);
      expect(reloaded.showDivineHostedOnly, isFalse);
    });

    test('notifies listeners only when value actually changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);
      var notificationCount = 0;
      service.addListener(() => notificationCount++);

      await service.setShowDivineHostedOnly(false);
      await service.setShowDivineHostedOnly(false);

      expect(notificationCount, 1);
    });

    group('reloadFromStorage', () {
      test('adopts the stored value and notifies once', () async {
        SharedPreferences.setMockInitialValues({
          DivineHostFilterService.showDivineHostedOnlyStorageKey: false,
        });
        final prefs = await SharedPreferences.getInstance();
        final service = DivineHostFilterService(prefs);
        var notificationCount = 0;
        service.addListener(() => notificationCount++);

        await prefs.remove(
          DivineHostFilterService.showDivineHostedOnlyStorageKey,
        );
        service.reloadFromStorage();

        expect(service.showDivineHostedOnly, isTrue);
        expect(notificationCount, 1);
      });

      test('stays silent when the stored value already matches', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = DivineHostFilterService(prefs);
        var notificationCount = 0;
        service.addListener(() => notificationCount++);

        service.reloadFromStorage();

        expect(service.showDivineHostedOnly, isTrue);
        expect(notificationCount, 0);
      });
    });
  });
}
