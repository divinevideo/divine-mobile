// ABOUTME: Widget tests for the horizontal row of video content actions.
// ABOUTME: Covers labels, taps, pending state and the optional heading.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group('VideoActionRow', () {
    testWidgets('renders every action label', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.bookmarkSimple,
                label: 'First',
                onTap: () {},
              ),
              VideoActionRowItem(
                icon: DivineIconName.trash,
                label: 'Second',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('calls onTap when an action is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.trash,
                label: 'Tap me',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(taps, equals(1));
    });

    testWidgets('shows a spinner and ignores taps while pending', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.trash,
                label: 'Busy',
                onTap: () => taps++,
                isPending: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Busy'));
      await tester.pump();

      expect(taps, equals(0));
    });

    testWidgets('ignores taps on a disabled action without a spinner', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.pencilSimpleLine,
                label: 'Held',
                onTap: () => taps++,
                isDisabled: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Held'));
      await tester.pump();

      expect(taps, equals(0));
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'a locked row ignores taps on every action and keeps the pending one '
      'spinning',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          testMaterialApp(
            home: VideoActionRow(
              isLocked: true,
              actions: [
                VideoActionRowItem(
                  icon: DivineIconName.trash,
                  label: 'Deleting',
                  onTap: () => taps++,
                  isPending: true,
                ),
                VideoActionRowItem(
                  icon: DivineIconName.bookmarkSimple,
                  label: 'Save',
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.tap(find.text('Deleting'));
        await tester.pump();

        expect(taps, equals(0));
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('renders the title when one is given', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            title: 'Heading',
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.trash,
                label: 'Only',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Heading'), findsOneWidget);
    });

    testWidgets('renders no heading without a title', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: VideoActionRow(
            actions: [
              VideoActionRowItem(
                icon: DivineIconName.trash,
                label: 'Only',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Only'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
