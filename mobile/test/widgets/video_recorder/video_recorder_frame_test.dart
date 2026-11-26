// ABOUTME: Tests for VideoRecorderFrame, which narrows the recorder to the
// ABOUTME: 9:16 frame it records on large screens and spans the window on phones

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/large_screen_orientation_provider.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_frame.dart';

const _contentKey = Key('content');
const _bottomBarKey = Key('bottomBar');

void main() {
  group(VideoRecorderFrame, () {
    Future<void> pumpFrame(
      WidgetTester tester, {
      required Size window,
      bool largeScreenLayout = true,
      FakeViewPadding padding = FakeViewPadding.zero,
      double aspectRatio = 9 / 16,
      double bottomBarHeight = 96,
      Widget content = const SizedBox.expand(key: _contentKey),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = window;
      tester.view.padding = padding;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(largeScreenLayout),
            ignoresOrientationLockOnLargeScreensProvider.overrideWithValue(
              false,
            ),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery.fromView(
              view: tester.view,
              child: AdaptiveLayoutScope(
                child: VideoRecorderFrame(
                  aspectRatio: aspectRatio,
                  content: content,
                  bottomBar: SizedBox(
                    key: _bottomBarKey,
                    height: bottomBarHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Rect contentRect(WidgetTester tester) =>
        tester.getRect(find.byKey(_contentKey));

    Rect bottomBarRect(WidgetTester tester) =>
        tester.getRect(find.byKey(_bottomBarKey));

    group('renders', () {
      testWidgets('spans the window on a phone', (tester) async {
        await pumpFrame(
          tester,
          window: const Size(390, 844),
          padding: const FakeViewPadding(top: 47, bottom: 34),
        );

        expect(contentRect(tester), const Rect.fromLTWH(0, 0, 390, 748));
        expect(bottomBarRect(tester), const Rect.fromLTWH(0, 748, 390, 96));
      });

      testWidgets('narrows to the 9:16 preview on a large screen', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          window: const Size(834, 1194),
          padding: const FakeViewPadding(top: 24, bottom: 20),
        );

        final content = contentRect(tester);
        // The preview is what is left below the top inset.
        expect(content.width / (content.height - 24), closeTo(9 / 16, 1e-9));
        expect(content.center.dx, closeTo(834 / 2, 1e-9));
        expect(content.top, 0);
        expect(
          bottomBarRect(tester),
          Rect.fromLTWH(content.left, content.bottom, content.width, 96),
        );
      });

      testWidgets('narrows to the 9:16 preview in a landscape window', (
        tester,
      ) async {
        await pumpFrame(tester, window: const Size(1280, 800));

        final content = contentRect(tester);
        expect(content.width, closeTo((800 - 96) * 9 / 16, 1e-9));
        expect(content.center.dx, closeTo(640, 1e-9));
        expect(bottomBarRect(tester).width, content.width);
      });

      testWidgets('widens to the largest square for a square preview', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          window: const Size(1280, 800),
          aspectRatio: 1,
        );

        final content = contentRect(tester);
        expect(content.width, closeTo(800 - 96, 1e-9));
        expect(content.center.dx, closeTo(640, 1e-9));
      });

      testWidgets('spans a window narrower than the square preview', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          window: const Size(834, 1194),
          aspectRatio: 1,
        );

        expect(contentRect(tester).width, 834);
      });

      testWidgets(
        'narrows to the 9:16 preview on the desktop without the '
        'large-screen layouts',
        (tester) async {
          await pumpFrame(
            tester,
            window: const Size(1440, 900),
            largeScreenLayout: false,
          );

          expect(
            contentRect(tester).width,
            closeTo((900 - 96) * 9 / 16, 1e-9),
          );
        },
        variant: TargetPlatformVariant.desktop(),
      );

      testWidgets('spans the window of a large screen without the '
          'large-screen layouts', (tester) async {
        await pumpFrame(
          tester,
          window: const Size(834, 1194),
          largeScreenLayout: false,
        );

        expect(contentRect(tester).width, 834);
        expect(bottomBarRect(tester).width, 834);
      });

      testWidgets('keeps the frame clear of a side inset, which its '
          'children then do not inset again', (tester) async {
        late EdgeInsets contentPadding;
        await pumpFrame(
          tester,
          window: const Size(1280, 800),
          padding: const FakeViewPadding(left: 48),
          content: Builder(
            key: _contentKey,
            builder: (context) {
              contentPadding = MediaQuery.paddingOf(context);
              return const SizedBox.expand();
            },
          ),
        );

        expect(contentRect(tester).center.dx, closeTo(48 + 1232 / 2, 1e-9));
        expect(contentPadding.left, 0);
      });
    });

    group('updates', () {
      testWidgets('widens along with the preview when it turns square', (
        tester,
      ) async {
        await pumpFrame(tester, window: const Size(1280, 800));

        await pumpFrame(
          tester,
          window: const Size(1280, 800),
          aspectRatio: 1,
        );
        await tester.pump(recorderAspectRatioTransition ~/ 2);
        final halfway = contentRect(tester).width;
        await tester.pumpAndSettle();

        expect(halfway, greaterThan((800 - 96) * 9 / 16));
        expect(halfway, lessThan(800 - 96));
        expect(contentRect(tester).width, closeTo(800 - 96, 1e-9));
      });

      testWidgets('narrows further when the bottom bar grows', (tester) async {
        await pumpFrame(tester, window: const Size(1280, 800));
        expect(contentRect(tester).width, closeTo((800 - 96) * 9 / 16, 1e-9));

        await pumpFrame(
          tester,
          window: const Size(1280, 800),
          bottomBarHeight: 140,
        );

        expect(
          contentRect(tester).width,
          closeTo((800 - 140) * 9 / 16, 1e-9),
        );
        expect(bottomBarRect(tester).width, contentRect(tester).width);
      });

      testWidgets('keeps its content when the window grows into the frame', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          window: const Size(390, 844),
          content: const _StatefulContent(key: _contentKey),
        );
        final phoneState = tester.state(find.byKey(_contentKey));

        await pumpFrame(
          tester,
          window: const Size(834, 1194),
          content: const _StatefulContent(key: _contentKey),
        );

        expect(contentRect(tester).width, lessThan(834));
        expect(tester.state(find.byKey(_contentKey)), same(phoneState));
      });
    });
  });
}

/// Stands in for the camera preview, whose state a remount would lose.
class _StatefulContent extends StatefulWidget {
  const _StatefulContent({super.key});

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _StatefulContentState extends State<_StatefulContent> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
