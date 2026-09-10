// ABOUTME: Widget tests for SubtitleCueTimeline — the ruler and filmstrip
// ABOUTME: that scrub the preview from under a fixed playhead.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_cue_timeline.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_timeline_thumbnails.dart';

void main() {
  group(SubtitleCueTimeline, () {
    late List<Duration> scrubs;
    late ValueNotifier<Duration> playbackPosition;
    late ValueNotifier<List<TimelineFrame>> thumbnails;

    setUp(() {
      scrubs = [];
      playbackPosition = ValueNotifier(Duration.zero);
      thumbnails = ValueNotifier(const []);
    });

    tearDown(() {
      playbackPosition.dispose();
      thumbnails.dispose();
    });

    Widget pump({int totalDurationMs = 8000}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: SubtitleCueTimeline(
            totalDuration: Duration(milliseconds: totalDurationMs),
            playbackPosition: playbackPosition,
            thumbnails: thumbnails,
            onScrubbed: scrubs.add,
          ),
        ),
      ),
    );

    /// Pixels one second of video occupies at the default zoom.
    const pixelsPerSecond = TimelineConstants.pixelsPerSecond;

    testWidgets('lays the video out along the ruler', (tester) async {
      await tester.pumpWidget(pump());

      expect(
        tester.getSize(find.byType(SubtitleTimelineThumbnails)).width,
        8 * pixelsPerSecond,
      );
    });

    testWidgets('scrubbing reports the position under the playhead', (
      tester,
    ) async {
      await tester.pumpWidget(pump());

      await tester.drag(
        find.byType(SubtitleCueTimeline),
        const Offset(-2 * pixelsPerSecond, 0),
      );
      await tester.pumpAndSettle();

      expect(scrubs, isNotEmpty);
      expect(scrubs.last.inMilliseconds, closeTo(2000, 120));
    });

    testWidgets('playback moves the film under the playhead', (tester) async {
      await tester.pumpWidget(pump());
      final scrollable = find.byType(Scrollable).first;
      expect(tester.widget<Scrollable>(scrollable).controller!.offset, 0);

      playbackPosition.value = const Duration(seconds: 3);
      await tester.pump();

      expect(
        tester.widget<Scrollable>(scrollable).controller!.offset,
        closeTo(3 * pixelsPerSecond, 1),
      );
    });

    testWidgets('following playback does not echo back as a scrub', (
      tester,
    ) async {
      await tester.pumpWidget(pump());

      playbackPosition.value = const Duration(seconds: 3);
      await tester.pumpAndSettle();

      expect(
        scrubs,
        isEmpty,
        reason: 'a scroll the player caused must not seek the player again',
      );
    });
  });
}
