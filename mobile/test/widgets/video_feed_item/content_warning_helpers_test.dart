// ABOUTME: Tests for content warning helper functions.
// ABOUTME: Verifies shouldShowContentWarningOverlay, contentWarningOverlayLabels,
// ABOUTME: and humanizeContentLabel behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';

void main() {
  group('shouldShowContentWarningOverlay', () {
    test('returns false when both label lists are empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: [],
        warnLabels: [],
      );

      expect(result, isFalse);
    });

    test('returns false when contentWarningLabels is non-empty '
        'but warnLabels is empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: ['violence'],
        warnLabels: [],
      );

      expect(result, isFalse);
    });

    test('returns true when warnLabels is non-empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: [],
        warnLabels: ['nudity'],
      );

      expect(result, isTrue);
    });

    test('returns true when both lists are non-empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: ['violence'],
        warnLabels: ['nudity'],
      );

      expect(result, isTrue);
    });
  });

  group('contentWarningOverlayLabels', () {
    test('returns warnLabels when non-empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: ['violence'],
        warnLabels: ['nudity', 'drugs'],
      );

      expect(result, equals(['nudity', 'drugs']));
    });

    test('falls back to contentWarningLabels when warnLabels is empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: ['violence', 'graphic-media'],
        warnLabels: [],
      );

      expect(result, equals(['violence', 'graphic-media']));
    });

    test('returns empty list when both are empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: [],
        warnLabels: [],
      );

      expect(result, isEmpty);
    });
  });

  group('humanizeContentLabel', () {
    late BuildContext capturedContext;

    Future<void> pumpWithContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('maps known labels to human-readable strings', (tester) async {
      await pumpWithContext(tester);

      expect(humanizeContentLabel(capturedContext, 'nudity'), equals('Nudity'));
      expect(
        humanizeContentLabel(capturedContext, 'violence'),
        equals('Violence'),
      );
      expect(
        humanizeContentLabel(capturedContext, 'drugs'),
        equals('Drug Use'),
      );
      expect(
        humanizeContentLabel(capturedContext, 'ai-generated'),
        equals('AI-Generated'),
      );
      expect(
        humanizeContentLabel(capturedContext, 'flashing-lights'),
        equals('Flashing Lights'),
      );
    });

    testWidgets('returns generic fallback for unknown labels', (tester) async {
      await pumpWithContext(tester);

      expect(
        humanizeContentLabel(capturedContext, 'unknown-label'),
        equals('Content Warning'),
      );
    });
  });
}
