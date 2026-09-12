// ABOUTME: Guards the bundled-font preload in flutter_test_config.dart.
// ABOUTME: Without it, layout assertions silently measure fallback glyphs.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// No asset provides this family, so it measures as the engine fallback —
/// which is exactly what an un-preloaded bundled face also measures as.
const _unregisteredFamily = 'DivineNoSuchFontFamily';

const _sample = 'Divine typography metrics 0123456789';

double _widthOf(String? fontFamily) {
  final painter = TextPainter(
    text: TextSpan(
      text: _sample,
      style: TextStyle(fontSize: 14, fontFamily: fontFamily),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  group('bundled font preload', () {
    // google_fonts registers faces asynchronously, so before #8485 whichever
    // test a shard's ordering seed ran first measured fallback glyphs while
    // later tests measured the real face. Any face that still measures as the
    // fallback here means testExecutable stopped awaiting its load.
    testWidgets('every VineTheme face is registered before the first test', (
      tester,
    ) async {
      final fallbackWidth = _widthOf(_unregisteredFamily);

      final faces = <String, String?>{
        'Inter w400': VineTheme.bodyMediumFont().fontFamily,
        'Inter w600': VineTheme.labelLargeFont().fontFamily,
        'BricolageGrotesque w700': VineTheme.headlineMediumFont().fontFamily,
        'BricolageGrotesque w800': VineTheme.titleLargeFont().fontFamily,
        'ChivoMono w300': VineTheme.codeFont().fontFamily,
      };

      for (final MapEntry(key: face, value: family) in faces.entries) {
        expect(
          _widthOf(family),
          isNot(fallbackWidth),
          reason:
              '$face ($family) measured as the fallback font, so the '
              'preload in flutter_test_config.dart did not await it.',
        );
      }
    }, skip: kIsWeb);
  });
}
