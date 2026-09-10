// ABOUTME: Tests for VideoClipThumbnailCard widget
// ABOUTME: Verifies selection overlay, duration badge, and disabled state

import 'dart:ui' show SemanticsAction;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoClipThumbnailCard, () {
    DivineVideoClip createClip({
      String id = 'clip-1',
      Duration duration = const Duration(seconds: 5),
      String? libraryTitle,
      bool stopMotion = false,
      int stopMotionFrameCount = 1,
    }) {
      return DivineVideoClip(
        id: id,
        video: stopMotion ? null : EditorVideo.file('/path/to/clip.mp4'),
        stopMotionFrames: stopMotion
            ? [
                for (var i = 0; i < stopMotionFrameCount; i++)
                  StopMotionClipFrame(
                    path: '/frames/f$i.jpg',
                    duration: const Duration(milliseconds: 83),
                  ),
              ]
            : null,
        libraryTitle: libraryTitle,
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    Widget buildWidget({
      DivineVideoClip? clip,
      int selectionIndex = -1,
      bool disabled = false,
      bool showArchivedBadge = false,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoClipThumbnailCard(
            clip: clip ?? createClip(),
            selectionIndex: selectionIndex,
            disabled: disabled,
            showArchivedBadge: showArchivedBadge,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('duration badge', (tester) async {
        await tester.pumpWidget(
          buildWidget(clip: createClip(duration: const Duration(seconds: 3))),
        );

        expect(find.text('3.00'), findsOneWidget);
      });

      testWidgets('library title when present', (tester) async {
        await tester.pumpWidget(
          buildWidget(clip: createClip(libraryTitle: 'Rooftop loop')),
        );

        expect(find.text('Rooftop loop'), findsOneWidget);
      });

      testWidgets('stop-motion badge for a stop-motion clip', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            clip: createClip(stopMotion: true, stopMotionFrameCount: 4),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.imagesSquare,
          ),
          findsOneWidget,
        );
      });

      testWidgets('stop-motion badge shows the still count', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            clip: createClip(stopMotion: true, stopMotionFrameCount: 10),
          ),
        );

        expect(find.text('10'), findsOneWidget);
      });

      testWidgets('no duration badge for a stop-motion clip', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            clip: createClip(
              stopMotion: true,
              duration: const Duration(seconds: 3),
            ),
          ),
        );

        // A stop-motion recording reads as an image: no seconds badge.
        expect(find.text('3.00'), findsNothing);
      });

      testWidgets('archived badge only when the card is told to mark it', (
        tester,
      ) async {
        Finder archivedBadge() => find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.stackSimple,
        );

        await tester.pumpWidget(buildWidget());
        expect(archivedBadge(), findsNothing);

        await tester.pumpWidget(buildWidget(showArchivedBadge: true));
        expect(archivedBadge(), findsOneWidget);
      });

      testWidgets('archived and stop-motion badges sit side by side', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            clip: createClip(stopMotion: true, stopMotionFrameCount: 4),
            showArchivedBadge: true,
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.imagesSquare,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.stackSimple,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('no stop-motion badge for a normal video clip', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.imagesSquare,
          ),
          findsNothing,
        );
      });

      testWidgets('selection index when selected', (tester) async {
        await tester.pumpWidget(buildWidget(selectionIndex: 2));

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('no selection index text when not selected', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Selection overlay exists but without the number
        expect(find.text('1'), findsNothing);
      });

      testWidgets('reduced opacity when disabled', (tester) async {
        await tester.pumpWidget(buildWidget(disabled: true));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(0.4));
      });

      testWidgets('full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildWidget());

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(1.0));
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

        await tester.tap(find.byType(VideoClipThumbnailCard));
        expect(tapped, isTrue);
      });

      testWidgets('does not call onTap when disabled', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildWidget(disabled: true, onTap: () => tapped = true),
        );

        await tester.tap(find.byType(VideoClipThumbnailCard));
        expect(tapped, isFalse);
      });
    });

    group('accessibility', () {
      testWidgets('has correct semantics when not selected', (tester) async {
        await tester.pumpWidget(buildWidget());
        final l10n = lookupAppLocalizations(const Locale('en'));

        final semantics = tester.getSemantics(
          find.byType(VideoClipThumbnailCard),
        );

        expect(
          semantics.label,
          equals(l10n.videoClipSemanticLabel('5.00')),
        );
        expect(
          semantics.value,
          equals(l10n.videoClipSemanticValueNotSelected),
        );
        expect(
          semantics.hint,
          equals(l10n.videoClipSemanticHintSelect),
        );
        final semanticsData = semantics.getSemanticsData();
        expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
        expect(find.bySemanticsLabel('5.00'), findsNothing);
      });

      testWidgets('announces that a badged clip is archived', (tester) async {
        await tester.pumpWidget(buildWidget(showArchivedBadge: true));
        final l10n = lookupAppLocalizations(const Locale('en'));

        final semantics = tester.getSemantics(
          find.byType(VideoClipThumbnailCard),
        );

        expect(
          semantics.label,
          equals(
            l10n.videoClipArchivedSemanticLabel(
              l10n.videoClipSemanticLabel('5.00'),
            ),
          ),
        );
      });

      testWidgets('announces the selection position when selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectionIndex: 3));
        final l10n = lookupAppLocalizations(const Locale('en'));

        final semantics = tester.getSemantics(
          find.byType(VideoClipThumbnailCard),
        );
        expect(
          semantics.value,
          equals(l10n.videoClipSemanticValueSelectedAtPosition(3)),
        );
        // The badge's digits must not merge into the card label as a bare
        // number the way the duration badge used to.
        expect(
          semantics.label,
          equals(l10n.videoClipSemanticLabel('5.00')),
        );
      });

      testWidgets('describes a stop-motion clip by its still count', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            clip: createClip(
              stopMotion: true,
              stopMotionFrameCount: 4,
              duration: const Duration(seconds: 3),
            ),
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));

        final semantics = tester.getSemantics(
          find.byType(VideoClipThumbnailCard),
        );

        expect(
          semantics.label,
          equals(
            l10n.videoClipStopMotionSemanticLabel(
              l10n.videoEditorStopMotionFramesCount(4),
            ),
          ),
        );
        // The duration badge is hidden for stop-motion because the number is
        // misleading; the announcement must withhold it too.
        expect(semantics.label, isNot(contains('3.00')));
        // And the badge must not add a second, non-actionable node inside the
        // card's button. The shape this replaced carried the frame count in
        // `value`, not `label`, so assert on the node count rather than
        // looking the old label up.
        expect(semantics.childrenCount, isZero);
      });
    });
  });
}
