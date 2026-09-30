// ABOUTME: Tests for SubtitleVisibility provider.
// ABOUTME: Verifies default-on and persisted global subtitle visibility.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group(SubtitleVisibility, () {
    test('defaults to captions enabled when no preference is stored', () {
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isTrue);
    });

    test('restores a stored disabled preference on initialization', () async {
      await prefs.setBool('subtitle_visibility_enabled', false);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
    });

    test('toggle persists disabling captions globally', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
      expect(prefs.getBool('subtitle_visibility_enabled'), isFalse);
    });

    test('toggle persists enabling captions globally', () async {
      await prefs.setBool('subtitle_visibility_enabled', false);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isTrue);
      expect(prefs.getBool('subtitle_visibility_enabled'), isTrue);
    });
  });
}
