// ABOUTME: Keeps the feed's standalone creator and video loop units consistent.
// ABOUTME: Pins the locales whose two labels previously used different terms.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('video overlay loop terminology', () {
    for (final language in ['am', 'bg', 'id', 'ko', 'ms', 'vi']) {
      test('uses the same loop unit in $language for either count', () {
        final l10n = lookupAppLocalizations(Locale(language));
        for (final count in [1, 42]) {
          final compactCount = '$count';
          final videoUnit = l10n
              .videoFeedLoopCountLine(compactCount, count)
              .replaceAll(compactCount, '')
              .trim();
          expect(videoUnit, isNotEmpty);
          expect(
            l10n.videoOverlayTotalLoops(compactCount, count),
            contains(videoUnit),
          );
        }
      });
    }
  });
}
