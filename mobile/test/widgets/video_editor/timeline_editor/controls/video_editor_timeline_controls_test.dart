// ABOUTME: Widget tests for VideoEditorTimelineControls.
// ABOUTME: Verifies optional buttons and callback invocation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';

void main() {
  group(VideoEditorTimelineControls, () {
    testWidgets('renders done and configured optional controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onDelete: () {},
              onDuplicated: () {},
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Split'), findsNothing);
    });

    testWidgets('triggers button callbacks', (tester) async {
      var doneCount = 0;
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onDelete: () => deleteCount++,
              onDone: () => doneCount++,
            ),
          ),
        ),
      );

      final buttons = find.byType(DivineIconButton);
      expect(buttons, findsNWidgets(2));

      await tester.tap(buttons.first);
      await tester.tap(buttons.last);
      await tester.pump();

      expect(deleteCount, equals(1));
      expect(doneCount, equals(1));
    });

    testWidgets('renders the transform button only when onTransform is set', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onTransform: () {},
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text(l10n.videoEditorTransformLabel), findsOneWidget);
    });

    testWidgets('invokes onTransform when the transform button is tapped', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var transformCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onTransform: () => transformCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorTransformSelectedClipSemanticLabel,
        ),
      );
      await tester.pump();

      expect(transformCount, equals(1));
    });

    testWidgets('keeps Split mounted but inert while isSplitting', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var splitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSplit: () => splitCount++,
              isSplitting: true,
              onDone: () {},
            ),
          ),
        ),
      );

      // Still on screen (disabled, not removed)...
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      // ...but tapping it does nothing.
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSplitSelectedClipSemanticLabel),
      );
      await tester.pump();
      expect(splitCount, equals(0));
    });

    testWidgets('invokes onSplit when not splitting', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var splitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSplit: () => splitCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSplitSelectedClipSemanticLabel),
      );
      await tester.pump();
      expect(splitCount, equals(1));
    });

    testWidgets('keeps Speed mounted but inert while isExtractingAudio', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var speedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSpeed: () => speedCount++,
              isExtractingAudio: true,
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text(l10n.videoEditorSpeedLabel), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSetClipSpeedSemanticLabel),
      );
      await tester.pump();
      expect(speedCount, equals(0));
    });

    testWidgets('invokes onSpeed when not extracting audio', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var speedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSpeed: () => speedCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSetClipSpeedSemanticLabel),
      );
      await tester.pump();
      expect(speedCount, equals(1));
    });

    testWidgets('hides Save when onSaveToLibrary is not provided', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoEditorTimelineControls(onDone: () {})),
        ),
      );

      expect(find.text(l10n.videoEditorSaveClip), findsNothing);
    });

    testWidgets('invokes onSaveToLibrary when idle', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSaveToLibrary: () => saveCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text(l10n.videoEditorSaveClip), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSaveSelectedClip),
      );
      await tester.pump();
      expect(saveCount, equals(1));
    });

    testWidgets('swaps Save for a spinner while saving to the library', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSaveToLibrary: () => saveCount++,
              isSavingToLibrary: true,
              onDone: () {},
            ),
          ),
        ),
      );

      // The label stays put so the control set doesn't reshuffle mid-render,
      // but the button is replaced by the spinner and can't be tapped again.
      expect(find.text(l10n.videoEditorSaveClip), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoEditorSaveSelectedClip),
        findsNothing,
      );
      expect(saveCount, equals(0));

      // The spinner carries no semantics, so the caption has to stop being
      // excluded — otherwise the control disappears from the traversal order
      // for as long as the save runs.
      expect(find.bySemanticsLabel(l10n.videoEditorSaveClip), findsOneWidget);
    });

    testWidgets('does not announce the caption twice when idle', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSaveToLibrary: () {},
              onDone: () {},
            ),
          ),
        ),
      );

      // The button already announces the action, so the caption below it is
      // excluded and only the button's own label reaches a screen reader.
      expect(find.text(l10n.videoEditorSaveClip), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.videoEditorSaveClip), findsNothing);
      expect(
        find.bySemanticsLabel(l10n.videoEditorSaveSelectedClip),
        findsOneWidget,
      );
    });
  });
}
