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
                  details: const [SizedBox(key: _detailsKey, height: 300)],
                  bottomBar: const SizedBox(
                    key: _bottomBarKey,
                    width: double.infinity,
                    height: 56,
                  ),
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
  });
}
