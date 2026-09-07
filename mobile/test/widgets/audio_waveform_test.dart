// ABOUTME: Tests for AudioWaveform widget
// ABOUTME: Validates visual elements, progress display, and animation behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/audio_waveform.dart';

void main() {
  group('AudioWaveform', () {
    testWidgets('stops its playback loop when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AudioWaveform(isPlaying: true),
            ),
          ),
        ),
      );

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('renders with default parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform()),
        ),
      );

      expect(find.byType(AudioWaveform), findsOneWidget);
      // CustomPaint exists within the waveform
      expect(
        find.descendant(
          of: find.byType(AudioWaveform),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays position text when duration is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform()),
        ),
      );

      expect(find.text('--:-- / --:--'), findsOneWidget);
    });

    testWidgets('displays correct position text with duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              position: Duration(seconds: 3),
            ),
          ),
        ),
      );

      expect(find.text('0:03 / 0:06'), findsOneWidget);
    });

    testWidgets('displays position text with minutes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(minutes: 2, seconds: 30),
              position: Duration(minutes: 1, seconds: 15),
            ),
          ),
        ),
      );

      expect(find.text('1:15 / 2:30'), findsOneWidget);
    });

    testWidgets('formats seconds with leading zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 10),
              position: Duration(seconds: 5),
            ),
          ),
        ),
      );

      expect(find.text('0:05 / 0:10'), findsOneWidget);
    });

    testWidgets('respects custom height', (WidgetTester tester) async {
      const customHeight = 60.0;
      // Total height = waveform height + spacing (8) + text height (16)
      const expectedTotalHeight = customHeight + 8 + 16;

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              height: customHeight,
              duration: Duration(seconds: 6),
            ),
          ),
        ),
      );

      // Verify the waveform area has the correct height
      final waveformSizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(AudioWaveform),
              matching: find.byType(SizedBox),
            )
            .first,
      );

      expect(waveformSizedBox.height, customHeight);

      // Verify total container height
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AudioWaveform),
          matching: find.byType(Container),
        ),
      );

      final constraints = container.constraints;
      expect(constraints?.maxHeight, expectedTotalHeight);
    });

    testWidgets('applies custom color to waveform', (
      WidgetTester tester,
    ) async {
      const customColor = Colors.red;

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              color: customColor,
              duration: Duration(seconds: 6),
            ),
          ),
        ),
      );

      // Widget renders without error with custom color
      expect(find.byType(AudioWaveform), findsOneWidget);
    });

    testWidgets('applies background color', (WidgetTester tester) async {
      const bgColor = Colors.black54;

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              backgroundColor: bgColor,
              duration: Duration(seconds: 6),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AudioWaveform),
          matching: find.byType(Container),
        ),
      );

      expect(container.color, bgColor);
    });

    testWidgets('handles isPlaying state change', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform(duration: Duration(seconds: 6))),
        ),
      );

      expect(find.byType(AudioWaveform), findsOneWidget);

      // Change to playing state
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              isPlaying: true,
            ),
          ),
        ),
      );

      // Pump some frames to allow animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AudioWaveform), findsOneWidget);
    });

    testWidgets('handles position update', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              position: Duration(seconds: 1),
            ),
          ),
        ),
      );

      expect(find.text('0:01 / 0:06'), findsOneWidget);

      // Update position
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              position: Duration(seconds: 4),
            ),
          ),
        ),
      );

      expect(find.text('0:04 / 0:06'), findsOneWidget);
    });

    testWidgets('clamps progress when position exceeds duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              position: Duration(seconds: 10), // Exceeds duration
            ),
          ),
        ),
      );

      // Widget should still render without error
      expect(find.byType(AudioWaveform), findsOneWidget);
      expect(find.text('0:10 / 0:06'), findsOneWidget);
    });

    testWidgets('handles zero duration gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration.zero,
              position: Duration(seconds: 3),
            ),
          ),
        ),
      );

      // Widget should render without error (progress will be 0.0)
      expect(find.byType(AudioWaveform), findsOneWidget);
    });

    testWidgets('has Semantics wrapper with correct properties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              position: Duration(seconds: 3),
            ),
          ),
        ),
      );

      // Verify Semantics widget exists as a wrapper
      expect(
        find.descendant(
          of: find.byType(AudioWaveform),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has Semantics wrapper for loading state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform()),
        ),
      );

      // Verify Semantics widget exists
      expect(
        find.descendant(
          of: find.byType(AudioWaveform),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('respects custom bar count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(duration: Duration(seconds: 6), barCount: 20),
          ),
        ),
      );

      // Widget renders without error with custom bar count
      expect(find.byType(AudioWaveform), findsOneWidget);
    });

    testWidgets('bar count change triggers regeneration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform(duration: Duration(seconds: 6))),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(duration: Duration(seconds: 6), barCount: 40),
          ),
        ),
      );

      // Widget renders without error after bar count change
      expect(find.byType(AudioWaveform), findsOneWidget);
    });

    testWidgets('animation stops when disposed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioWaveform(
              duration: Duration(seconds: 6),
              isPlaying: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Dispose by removing from tree
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      // No exceptions should occur
      expect(find.byType(AudioWaveform), findsNothing);
    });

    testWidgets('uses dark mode colors by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform(duration: Duration(seconds: 6))),
        ),
      );

      // Find the position text and verify it uses white color
      final textWidget = tester.widget<Text>(find.text('0:00 / 0:06'));

      expect(textWidget.style?.color, Colors.white);
    });

    testWidgets('position text is grey when duration is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AudioWaveform()),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('--:-- / --:--'));

      expect(textWidget.style?.color, VineTheme.lightText);
    });
  });
}
