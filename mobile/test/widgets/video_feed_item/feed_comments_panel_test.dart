// ABOUTME: Tests that the feed publishes its comments panel only in wide
// ABOUTME: landscape windows, and hides it while the window is too narrow

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
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
      Widget panel = const SizedBox.expand(key: panelKey),
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
          child: Localizations(
            locale: const Locale('en'),
            delegates: appLocalizationsDelegates,
            child: MediaQuery(
              data: MediaQueryData(
                size: window,
                disableAnimations: reduceMotion,
              ),
              child: AdaptiveLayoutScope(
                child: FeedCommentsPanelHost(
                  // The comments themselves need the whole app around them.
                  panelBuilder: (_, _) => panel,
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
      testWidgets('hides the panel while the window is not wide landscape, '
          'and shows it again with its state', (tester) async {
        Future<void> pumpAt(Size window) => pumpHost(
          tester,
          window: window,
          panel: const _Counter(key: panelKey),
        );
        await pumpAt(_landscape);
        final cubit = CommentsPanelScope.maybeOf(feedContext)!;
        unawaited(
          cubit.open(
            CommentsPanelRequest(
              video: TestHelpers.createVideoEvent(id: 'a' * 64),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(panelKey));
        await tester.pump();

        // A portrait camera opened over the feed turns a tablet to portrait.
        await pumpAt(_portrait);
        await tester.pumpAndSettle();

        expect(find.byKey(panelKey), findsNothing);
        expect(CommentsPanelScope.maybeOf(feedContext), isNull);
        expect(tester.getSize(find.byKey(_feedKey)).width, _portrait.width);
        expect(cubit.state, isNotNull);

        await pumpAt(_landscape);
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: find.byKey(panelKey), matching: find.text('1')),
          findsOneWidget,
        );
      });
    });

    group('semantics', () {
      testWidgets('tells a screen reader the panel opened', (tester) async {
        await pumpHost(tester, window: _landscape);
        unawaited(
          CommentsPanelScope.maybeOf(feedContext)!.open(
            CommentsPanelRequest(
              video: TestHelpers.createVideoEvent(id: 'c' * 64),
              initialCommentCount: 3,
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeAnnouncements().map((a) => a.message),
          [lookupAppLocalizations(const Locale('en')).commentsHeaderCount(3)],
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
    child: Center(child: Text('$_taps')),
  );
}
