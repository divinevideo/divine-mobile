// ABOUTME: Tests when the feed fills its viewport with a video or shows the
// ABOUTME: whole video, and where its overlay sits when it shows the whole video

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_feed_item/feed_video_fit.dart';

/// Window sizes of the devices the rule is meant for, in points.
const _iPhone17Pro = Size(402, 874);
const _iPhoneSe = Size(375, 667);
const _duoOuter = Size(466, 678);
const _duoInner = Size(669, 951);
const _duoInnerLandscape = Size(951, 669);
const _iPadMini = Size(744, 1133);

/// The feed viewports (window minus the bottom navigation) the frame bounds
/// are laid out in.
const _duoOuterFeed = Size(466, 600);
const _duoInnerFeed = Size(669, 881);

void main() {
  group('feedFillsViewport', () {
    bool fills(Size window, {bool largeScreenLayout = true}) =>
        feedFillsViewport(
          shouldPortraitExpand: true,
          largeScreenLayout: largeScreenLayout,
          window: window,
        );

    test('keeps filling phone windows', () {
      expect(fills(_iPhone17Pro), isTrue);
      expect(fills(_iPhoneSe), isTrue);
    });

    test('fills the folded iPhone Duo, as a phone', () {
      expect(fills(_duoOuter), isTrue);
    });

    test('shows whole videos on the open iPhone Duo and iPads', () {
      expect(fills(_duoInner), isFalse);
      expect(fills(_duoInnerLandscape), isFalse);
      expect(fills(_iPadMini), isFalse);
    });

    test('shows whole videos in a small landscape window', () {
      expect(fills(const Size(560, 400)), isFalse);
    });

    test('fills every window with the flag off', () {
      expect(fills(_duoInner, largeScreenLayout: false), isTrue);
    });

    test('never fills when the caller asks for whole videos', () {
      expect(
        feedFillsViewport(
          shouldPortraitExpand: false,
          largeScreenLayout: true,
          window: _iPhone17Pro,
        ),
        isFalse,
      );
    });
  });

  group(FeedVideoFrameBounds, () {
    Future<double> overlayWidth(
      WidgetTester tester, {
      required Size viewport,
      required bool shouldPortraitExpand,
      bool enabled = true,
      double? aspectRatio = 9 / 16,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const overlayKey = Key('overlay');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(enabled),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(size: viewport),
              child: AdaptiveLayoutScope(
                child: FeedVideoFrameBounds(
                  videoAspectRatio: aspectRatio,
                  shouldPortraitExpand: shouldPortraitExpand,
                  child: const SizedBox.expand(key: overlayKey),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byKey(overlayKey)).width;
    }

    testWidgets('narrows the overlay to the video frame', (tester) async {
      final width = await overlayWidth(
        tester,
        viewport: _duoInnerFeed,
        shouldPortraitExpand: false,
      );

      expect(width, moreOrLessEquals(_duoInnerFeed.height * 9 / 16));
    });

    testWidgets('keeps the overlay at least its minimum width', (
      tester,
    ) async {
      final width = await overlayWidth(
        tester,
        viewport: _duoOuterFeed,
        shouldPortraitExpand: false,
      );

      expect(width, equals(360));
    });

    testWidgets('spans the viewport where the video fills it', (
      tester,
    ) async {
      final width = await overlayWidth(
        tester,
        viewport: _duoInnerFeed,
        shouldPortraitExpand: true,
      );

      expect(width, equals(_duoInnerFeed.width));
    });

    testWidgets('spans the viewport with the flag off', (tester) async {
      final width = await overlayWidth(
        tester,
        viewport: _duoInnerFeed,
        shouldPortraitExpand: false,
        enabled: false,
      );

      expect(width, equals(_duoInnerFeed.width));
    });

    testWidgets('spans the viewport when the video size is unknown', (
      tester,
    ) async {
      final width = await overlayWidth(
        tester,
        viewport: _duoInnerFeed,
        shouldPortraitExpand: false,
        aspectRatio: null,
      );

      expect(width, equals(_duoInnerFeed.width));
    });
  });
}
