import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web bootstrap and bundled font configuration', () {
    test('web/flutter_bootstrap.js serves CanvasKit from same origin', () {
      final contents = File('web/flutter_bootstrap.js').readAsStringSync();

      expect(contents, contains('{{flutter_js}}'));
      expect(contents, contains('{{flutter_build_config}}'));
      expect(contents, contains("canvasKitBaseUrl: 'canvaskit/'"));
    });

    test('pubspec.yaml registers bundled ChivoMono font asset', () {
      final contents = File('pubspec.yaml').readAsStringSync();

      expect(contents, contains('family: ChivoMono'));
      expect(contents, contains('assets/fonts/ChivoMono-Light.ttf'));
    });
  });
}
