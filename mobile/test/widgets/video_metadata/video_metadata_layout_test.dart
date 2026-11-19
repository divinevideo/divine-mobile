// ABOUTME: Tests that the video metadata screens keep the preview above the
// ABOUTME: form on phones and give it a pane beside the form in wide landscape

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_layout.dart';

const _previewKey = Key('preview');
const _sidePreviewKey = Key('side-preview');
const _detailsKey = Key('details');
const _bottomBarKey = Key('bottom-bar');

void main() {
  group(VideoMetadataLayout, () {
    Future<void> pumpLayout(
      WidgetTester tester, {
      required Size window,
      bool largeScreenLayout = true,
      FakeViewPadding padding = FakeViewPadding.zero,
      List<Widget> details = const [SizedBox(key: _detailsKey, height: 300)],
      Widget bottomBar = const SizedBox(
        key: _bottomBarKey,
        width: double.infinity,
        height: 56,
      ),
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(largeScreenLayout),
          ],
          child: MediaQuery.fromView(
            view: tester.view,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AdaptiveLayoutScope(
                child: VideoMetadataLayout(
                  preview: const SizedBox(key: _previewKey, height: 200),
                  sidePreview: (maxSize) =>
                      SizedBox.fromSize(key: _sidePreviewKey, size: maxSize),
                  details: details,
                  bottomBar: bottomBar,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Rect rectOf(WidgetTester tester, Key key) =>
        tester.getRect(find.byKey(key));

    group('renders', () {
      testWidgets('keeps the preview above the details on a phone', (
        tester,
      ) async {
        await pumpLayout(tester, window: const Size(402, 874));

        expect(find.byKey(_sidePreviewKey), findsNothing);
        expect(
          rectOf(tester, _previewKey).bottom,
          lessThanOrEqualTo(rectOf(tester, _detailsKey).top),
        );
        expect(rectOf(tester, _detailsKey).width, equals(402));
      });

      testWidgets(
        'keeps the preview above the details in landscape with the flag off',
        (tester) async {
          await pumpLayout(
            tester,
            window: const Size(951, 669),
            largeScreenLayout: false,
          );

          expect(find.byKey(_sidePreviewKey), findsNothing);
          expect(find.byKey(_previewKey), findsOneWidget);
        },
      );

      testWidgets('puts the preview in a pane beside the details in a wide '
          'landscape window', (tester) async {
        await pumpLayout(tester, window: const Size(1194, 834));

        expect(find.byKey(_previewKey), findsNothing);
        final pane = rectOf(tester, _sidePreviewKey);
        final details = rectOf(tester, _detailsKey);
        const paneWidth = VideoMetadataLayout.maxPreviewPaneWidth;
        const inset = VideoMetadataLayout.previewPaneInset;
        expect(pane.left, equals(inset));
        expect(pane.right, equals(paneWidth - inset));
        expect(details.left, equals(paneWidth));
        expect(details.right, equals(1194));
        expect(
          rectOf(tester, _bottomBarKey).left,
          equals(paneWidth),
        );
      });

      testWidgets('ends at a status bar column', (tester) async {
        await pumpLayout(
          tester,
          window: const Size(951, 669),
          padding: const FakeViewPadding(right: 84, bottom: 34),
        );

        const width = 951 - 84;
        final details = rectOf(tester, _detailsKey);
        expect(
          rectOf(tester, _sidePreviewKey).right,
          equals(
            width * VideoMetadataLayout.previewPaneFraction -
                VideoMetadataLayout.previewPaneInset,
          ),
        );
        expect(details.right, equals(width));
        expect(rectOf(tester, _bottomBarKey).bottom, equals(669 - 34));
      });
    });

    group('interactions', () {
      testWidgets('keeps the form and the bottom bar when rotating between the '
          'two layouts', (tester) async {
        const formKey = Key('form');
        const barKey = Key('bar');
        Future<void> pumpAt(Size window) => pumpLayout(
          tester,
          window: window,
          details: const [_Counter(key: formKey)],
          bottomBar: const _Counter(key: barKey),
        );

        await pumpAt(const Size(1194, 834));
        await tester.tap(find.byKey(formKey));
        await tester.tap(find.byKey(barKey));
        await tester.tap(find.byKey(barKey));
        await tester.pump();
        expect(find.byKey(_sidePreviewKey), findsOneWidget);

        await pumpAt(const Size(834, 1194));

        expect(find.byKey(_previewKey), findsOneWidget);
        expect(
          find.descendant(of: find.byKey(formKey), matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byKey(barKey), matching: find.text('2')),
          findsOneWidget,
        );
      });
    });
  });
}

/// Counts its taps, to tell a kept state from a fresh one.
class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _taps++),
    child: SizedBox(height: 56, child: Center(child: Text('$_taps'))),
  );
}
