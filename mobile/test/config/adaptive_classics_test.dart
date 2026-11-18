import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/adaptive_classics.dart';

void main() {
  group('Adaptive Classics', () {
    test('requires an explicit build flag to enable recommendations', () {
      const enabledInBuild = bool.fromEnvironment('ADAPTIVE_CLASSICS_ENABLED');
      expect(adaptiveClassicsEnabled, enabledInBuild);
    });
  });
}
