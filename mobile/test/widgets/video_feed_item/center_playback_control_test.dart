import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

void main() {
  group(CenterPlaybackControl, () {
    testWidgets('wraps pill in $BackdropFilter when useBackdropBlur is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: CenterPlaybackControl(
            state: CenterPlaybackControlState.play,
            useBackdropBlur: true,
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('omits $BackdropFilter when useBackdropBlur is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: CenterPlaybackControl(
            state: CenterPlaybackControlState.pause,
            useBackdropBlur: false,
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('blurs by default off the web', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: CenterPlaybackControl(state: CenterPlaybackControlState.play),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
