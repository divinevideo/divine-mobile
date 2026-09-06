import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('main() ErrorWidget.builder wiring', () {
    test('startOpenVineApp receives buildGlobalErrorWidget', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(
        source,
        contains(RegExp(r'errorWidgetBuilder:\s*buildGlobalErrorWidget')),
        reason:
            'main() must pass buildGlobalErrorWidget into startOpenVineApp. '
            'The widget tests install that builder themselves, so they stay '
            'green if this wiring is removed — which is how the branded '
            'surface stayed unreachable for seven months (#8647).',
      );
      expect(
        source,
        isNot(contains('startupErrorWidgetBuilder')),
        reason: 'the deleted minimal startup surface must not return',
      );
    });
  });
}
