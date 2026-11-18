// ABOUTME: Tests that the feed publishes its comments panel only in wide
// ABOUTME: landscape windows, and closes it when the window gets too narrow

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/screens/comments/comments_panel_scope.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_feed_item/feed_comments_panel.dart';

import '../../helpers/test_helpers.dart';

const _landscape = Size(1194, 834);

/// The feed beside the panel (`FeedCommentsPanelHost` keys its slot).
const ValueKey<String> _feedKey = ValueKey('feed');
const _portrait = Size(834, 1194);

void main() {
  group(FeedCommentsPanelHost, () {
    late BuildContext feedContext;

    const panelKey = Key('panel');

    Future<void> pumpHost(
      WidgetTester tester, {
      required Size window,
      bool enabled = true,
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
              data: MediaQueryData(
                size: window,
                disableAnimations: reduceMotion,
              ),
              child: AdaptiveLayoutScope(
                child: FeedCommentsPanelHost(
                  // The comments themselves need the whole app around them.
                  panelBuilder: (_, _) => const SizedBox.expand(key: panelKey),
                  child: Builder(
                    builder: (context) {
                      feedContext = context;
                      return const SizedBox.expand();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('publishes the panel in wide landscape', (tester) async {
        await pumpHost(tester, window: _landscape);

        expect(CommentsPanelScope.maybeOf(feedContext), isNotNull);
      });

      testWidgets('leaves comments to the sheet in portrait', (tester) async {
        await pumpHost(tester, window: _portrait);

        expect(CommentsPanelScope.maybeOf(feedContext), isNull);
      });

      testWidgets('leaves comments to the sheet with the flag off', (
        tester,
      ) async {
        await pumpHost(tester, window: _landscape, enabled: false);

        expect(CommentsPanelScope.maybeOf(feedContext), isNull);
      });
    });

    group('slide', () {
      CommentsPanelRequest request() => CommentsPanelRequest(
        video: TestHelpers.createVideoEvent(id: 'b' * 64),
      );

      double panelWidth(WidgetTester tester) =>
          tester.getSize(find.byKey(panelKey)).width;
      double visibleWidth(WidgetTester tester) =>
          _landscape.width - tester.getSize(find.byKey(_feedKey)).width;

      testWidgets('slides the panel in from the edge', (tester) async {
        await pumpHost(tester, window: _landscape);
        unawaited(CommentsPanelScope.maybeOf(feedContext)!.open(request()));
        // One frame mounts the panel and starts the slide, the next runs it.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Part of the way in, laid out at its full width the whole time.
        expect(visibleWidth(tester), greaterThan(0));
        expect(visibleWidth(tester), lessThan(panelWidth(tester)));

        await tester.pumpAndSettle();

        expect(visibleWidth(tester), equals(panelWidth(tester)));
      });

      testWidgets('slides the panel out before removing it', (tester) async {
        await pumpHost(tester, window: _landscape);
        final cubit = CommentsPanelScope.maybeOf(feedContext)!;
        unawaited(cubit.open(request()));
        await tester.pumpAndSettle();

        cubit.dismiss();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(panelKey), findsOneWidget);
        expect(visibleWidth(tester), greaterThan(0));

        await tester.pumpAndSettle();

        expect(find.byKey(panelKey), findsNothing);
        expect(visibleWidth(tester), equals(0));
      });

      testWidgets('shows the panel at once with reduced motion', (
        tester,
      ) async {
        await pumpHost(tester, window: _landscape, reduceMotion: true);
        unawaited(CommentsPanelScope.maybeOf(feedContext)!.open(request()));
        await tester.pump();
        await tester.pump();

        expect(visibleWidth(tester), equals(panelWidth(tester)));
      });
    });

    group('interactions', () {
      testWidgets('closes the panel when the window turns portrait', (
        tester,
      ) async {
        await pumpHost(tester, window: _landscape);
        final cubit = CommentsPanelScope.maybeOf(feedContext)!;
        var closed = false;
        unawaited(
          cubit
              .open(
                CommentsPanelRequest(
                  video: TestHelpers.createVideoEvent(id: 'a' * 64),
                ),
              )
              .then((_) => closed = true),
        );

        // Rotated before the panel built: it never has to render here.
        await pumpHost(tester, window: _portrait);
        await tester.pump();

        expect(cubit.state, isNull);
        expect(closed, isTrue);
        expect(CommentsPanelScope.maybeOf(feedContext), isNull);
      });
    });
  });
}
