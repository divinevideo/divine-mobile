// ABOUTME: Tests for VideoEditorFeedPreviewOverlay: that it frames the feed
// ABOUTME: overlay like the feed and reserves the tallest caption block.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_feed_preview_overlay.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

/// A 6.1" iPhone: 390 x 844 logical pixels at 3x, 34 px home indicator.
const double _devicePixelRatio = 3;
const Size _screenSize = Size(390, 844);
const double _bottomInset = 34;

TimelineOverlayItem _captionCue(String id, String text) => TimelineOverlayItem(
  id: id,
  type: TimelineOverlayType.captions,
  startTime: Duration.zero,
  endTime: const Duration(seconds: 1),
  label: text,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorFeedPreviewOverlay, () {
    late _MockTimelineOverlayBloc timelineOverlayBloc;

    setUp(() {
      timelineOverlayBloc = _MockTimelineOverlayBloc();
      when(
        () => timelineOverlayBloc.state,
      ).thenReturn(const TimelineOverlayState());
    });

    Future<void> pumpOverlay(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = _devicePixelRatio
        ..physicalSize = _screenSize * _devicePixelRatio
        ..viewPadding = const FakeViewPadding(
          bottom: _bottomInset * _devicePixelRatio,
        );
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<TimelineOverlayBloc>.value(
                value: timelineOverlayBloc,
                // The editor canvas: a 9:16 video.
                child: const Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: VideoEditorFeedPreviewOverlay(
                      targetAspectRatio: 9 / 16,
                      isFeedPreviewVisible: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('frame', () {
      testWidgets('is the size the feed gives the video', (tester) async {
        await pumpOverlay(tester);

        final frame = find.descendant(
          of: find.byType(FittedBox),
          matching: find.byType(Stack),
        );

        expect(
          tester.getSize(frame.first),
          equals(
            Size(
              _screenSize.width,
              _screenSize.height - vineBottomNavBarHeight - _bottomInset,
            ),
          ),
        );
      });

      testWidgets('gives the feed overlay no bottom inset, as the feed does', (
        tester,
      ) async {
        await pumpOverlay(tester);

        final overlayContext = tester.element(find.byType(VideoOverlayActions));

        expect(
          MediaQuery.viewPaddingOf(tester.element(find.byType(Scaffold))),
          isNot(EdgeInsets.zero),
        );
        expect(MediaQuery.viewPaddingOf(overlayContext).bottom, isZero);
      });
    });

    group('caption block', () {
      testWidgets('shows a title line', (tester) async {
        await pumpOverlay(tester);

        expect(find.text(l10n.videoMetadataTitleLabel), findsOneWidget);
      });

      testWidgets('shows a description on both of its lines', (tester) async {
        await pumpOverlay(tester);

        expect(
          find.textContaining(
            '${l10n.videoMetadataDescriptionLabel}\n'
            '${l10n.videoEditorFeedPreviewContent}',
            findRichText: true,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows a sound row', (tester) async {
        await pumpOverlay(tester);

        expect(find.byType(AudioAttributionPlaceholder), findsOneWidget);
        expect(
          find.textContaining(l10n.audioAttributionOriginalSound),
          findsOneWidget,
        );
      });

      testWidgets('shows a caption pill when the edit has no captions', (
        tester,
      ) async {
        await pumpOverlay(tester);

        expect(
          find.widgetWithText(CaptionPill, l10n.videoEditorCaptionsLabel),
          findsOneWidget,
        );
      });

      testWidgets('shows the longest of the edit caption cues in the pill', (
        tester,
      ) async {
        when(() => timelineOverlayBloc.state).thenReturn(
          TimelineOverlayState(
            items: [
              _captionCue('a', 'Hi'),
              _captionCue('b', 'Apparently this is not enough legs'),
              _captionCue('c', 'for a corgi race'),
            ],
          ),
        );

        await pumpOverlay(tester);

        expect(
          find.widgetWithText(
            CaptionPill,
            'Apparently this is not enough legs',
          ),
          findsOneWidget,
        );
      });

      testWidgets('keeps the placeholder pill when captions are burned in', (
        tester,
      ) async {
        when(() => timelineOverlayBloc.state).thenReturn(
          TimelineOverlayState(
            items: [_captionCue('a', 'Burned into the video')],
            captionsBurnIn: true,
          ),
        );

        await pumpOverlay(tester);

        expect(
          find.widgetWithText(CaptionPill, l10n.videoEditorCaptionsLabel),
          findsOneWidget,
        );
      });
    });
  });
}
