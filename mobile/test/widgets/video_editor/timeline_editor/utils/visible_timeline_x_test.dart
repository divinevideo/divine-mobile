import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/visible_timeline_x.dart';

void main() {
  group('visibleTimelineX', () {
    testWidgets('measures against the visible part of the timeline', (
      tester,
    ) async {
      late BuildContext stripContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            // Beside a panel, as the timeline sits beside the preview.
            padding: const EdgeInsets.only(left: 100),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 300,
                height: 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Builder(
                    builder: (context) {
                      stripContext = context;
                      return const SizedBox(width: 1200, height: 50);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final (:x, :width) = visibleTimelineX(stripContext, 390);

      expect(x, equals(290));
      expect(width, equals(300));
    });

    testWidgets('falls back to the screen outside a timeline', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox();
            },
          ),
        ),
      );

      final (:x, :width) = visibleTimelineX(context, 390);

      expect(x, equals(390));
      expect(width, equals(800));
    });
  });
}
