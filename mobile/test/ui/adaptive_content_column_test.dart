// ABOUTME: Tests readable-width constraints and scrolling in viewport margins.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/ui/adaptive_content_column.dart';

import '../helpers/large_screen_layout.dart';

const _contentKey = ValueKey<String>('content');
const _content = SizedBox(key: _contentKey, width: double.infinity, height: 80);

void main() {
  final content = find.byKey(_contentKey);

  group(AdaptiveContentColumn, () {
    testWidgets('uses the full width of a phone window', (tester) async {
      setTestWindowSize(tester, 390);
      await tester.pumpWidget(
        largeScreenLayoutApp(
          enabled: true,
          home: const AdaptiveContentColumn(
            width: AdaptiveContentWidth.form,
            child: _content,
          ),
        ),
      );

      expect(tester.getRect(content), const Rect.fromLTWH(0, 0, 390, 80));
    });

    for (final (name, width, expected) in [
      ('form', AdaptiveContentWidth.form, 440.0),
      ('list', AdaptiveContentWidth.list, 600.0),
      ('reading', AdaptiveContentWidth.reading, 720.0),
    ]) {
      testWidgets('centers the $name width at the top of a wide window', (
        tester,
      ) async {
        setTestWindowSize(tester, 1440);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: true,
            home: AdaptiveContentColumn(width: width, child: _content),
          ),
        );

        expect(
          tester.getRect(content),
          Rect.fromLTWH((1440 - expected) / 2, 0, expected, 80),
        );
      });
    }

    testWidgets('leaves content uncapped with the layouts off', (tester) async {
      setTestWindowSize(tester, 1440);
      await tester.pumpWidget(
        largeScreenLayoutApp(
          enabled: false,
          home: const AdaptiveContentColumn(
            width: AdaptiveContentWidth.list,
            child: _content,
          ),
        ),
      );

      expect(tester.getRect(content), const Rect.fromLTWH(0, 0, 1440, 900));
    });

    testWidgets('keeps an opted-in custom width with the layouts off', (
      tester,
    ) async {
      setTestWindowSize(tester, 1440);
      await tester.pumpWidget(
        largeScreenLayoutApp(
          enabled: false,
          home: const AdaptiveContentColumn(
            width: AdaptiveContentWidth.custom(640),
            capWithoutLargeLayout: true,
            child: _content,
          ),
        ),
      );

      expect(tester.getRect(content), const Rect.fromLTWH(400, 0, 640, 80));
    });

    testWidgets('centers in the parent area beside side navigation', (
      tester,
    ) async {
      setTestWindowSize(tester, 1440);
      await tester.pumpWidget(
        largeScreenLayoutApp(
          enabled: true,
          home: const Padding(
            padding: EdgeInsets.only(left: 200),
            child: AdaptiveContentColumn(
              width: AdaptiveContentWidth.list,
              child: _content,
            ),
          ),
        ),
      );

      expect(tester.getRect(content), const Rect.fromLTWH(520, 0, 600, 80));
    });
  });

  group(SliverAdaptiveContentColumn, () {
    testWidgets('scrolls from the empty margin of a full-width viewport', (
      tester,
    ) async {
      setTestWindowSize(tester, 1440);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        largeScreenLayoutApp(
          enabled: true,
          home: CustomScrollView(
            controller: controller,
            slivers: const [
              SliverAdaptiveContentColumn(
                width: AdaptiveContentWidth.list,
                sliver: SliverToBoxAdapter(
                  child: SizedBox(key: _contentKey, height: 2000),
                ),
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getRect(find.byType(CustomScrollView)),
        const Rect.fromLTWH(0, 0, 1440, 900),
      );
      expect(tester.getRect(content), const Rect.fromLTWH(420, 0, 600, 2000));
      expect(controller.offset, 0);

      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(32, 200),
          scrollDelta: Offset(0, 240),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 240);
    });

    for (final (optIn, expected) in [(false, 1440.0), (true, 600.0)]) {
      testWidgets('with the layouts off, opt-in $optIn sets the width', (
        tester,
      ) async {
        setTestWindowSize(tester, 1440);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: false,
            home: CustomScrollView(
              slivers: [
                SliverAdaptiveContentColumn(
                  width: AdaptiveContentWidth.list,
                  capWithoutLargeLayout: optIn,
                  sliver: const SliverToBoxAdapter(child: _content),
                ),
              ],
            ),
          ),
        );

        expect(
          tester.getRect(content),
          Rect.fromLTWH((1440 - expected) / 2, 0, expected, 80),
        );
      });
    }
  });
}
