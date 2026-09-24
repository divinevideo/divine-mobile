import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/list_video_player_mode.dart';

import '../helpers/test_provider_overrides.dart';
import '../test_data/video_test_data.dart';

void main() {
  group(ListVideoPlayerMode, () {
    group('renders', () {
      testWidgets('the unavailable message for an empty list', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: ListVideoPlayerMode(
              videos: const [],
              activeIndex: 0,
              listName: 'Crew',
              onExit: () {},
              unavailableMessage: 'Nothing to play',
            ),
          ),
        );

        expect(find.text('Nothing to play'), findsOneWidget);
        expect(find.byType(PopScope), findsNothing);
      });

      testWidgets('the unavailable message when the index is past the end', (
        tester,
      ) async {
        // The list shrank under the index the grid handed over.
        await tester.pumpWidget(
          testMaterialApp(
            home: ListVideoPlayerMode(
              videos: [createTestVideoEvent()],
              activeIndex: 1,
              listName: 'Crew',
              onExit: () {},
              unavailableMessage: 'Nothing to play',
            ),
          ),
        );

        expect(find.text('Nothing to play'), findsOneWidget);
        expect(find.byType(PopScope), findsNothing);
      });
    });
  });
}
