// ABOUTME: Tests for preference providers publishing service changes to state
// ABOUTME: Covers language-version propagation and subscription disposal cleanup

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLanguagePreferenceService extends LanguagePreferenceService {
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }
}

void main() {
  group('languagePreferenceVersionProvider', () {
    late _RecordingLanguagePreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      service = _RecordingLanguagePreferenceService();
      await service.initialize();
    });

    test('publishes every service notification as a new version', () async {
      final container = ProviderContainer(
        overrides: [
          languagePreferenceServiceProvider.overrideWithValue(service),
        ],
      );

      final versions = <int>[];
      container.listen(
        languagePreferenceVersionProvider,
        (_, next) => versions.add(next),
      );

      expect(container.read(languagePreferenceVersionProvider), 0);
      expect(service.addListenerCalls, 1);

      await service.setContentLanguage('es');
      await pumpEventQueue();
      expect(container.read(languagePreferenceVersionProvider), 1);

      // The service notifies on every call, including a repeat of the same
      // language, and the provider turns each notification into a new version.
      await service.setContentLanguage('es');
      await pumpEventQueue();
      expect(container.read(languagePreferenceVersionProvider), 2);
      expect(versions, [1, 2]);
      expect(
        service.addListenerCalls,
        1,
        reason: 'a notification must not rebuild the provider subscription',
      );

      // Kept alive: its subscription is released when the container closes.
      container.dispose();
      expect(service.removeListenerCalls, 1);
    });
  });
}
