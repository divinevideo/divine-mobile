import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/feed_tuning/feed_tuning_swipe_overlay.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<List<FeedTuningDirection>> pumpOverlay(WidgetTester tester) async {
    final tuned = <FeedTuningDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: const SizedBox(width: 300, height: 500),
            ),
          ),
        ),
      ),
    );
    return tuned;
  }

  group(FeedTuningSwipeOverlay, () {
    testWidgets('swiping right past the threshold tunes "more"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
    });

    testWidgets('swiping left past the threshold tunes "less"', (tester) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
    });

    testWidgets('a short swipe below the threshold does not tune', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
    });

    testWidgets('trackpad swipe right past the threshold tunes "more"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(FeedTuningSwipeOverlay))),
      );

      await tester.sendEventToBinding(pointer.scroll(const Offset(-200, 0)));
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
    });

    testWidgets('trackpad swipe left past the threshold tunes "less"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(FeedTuningSwipeOverlay))),
      );

      await tester.sendEventToBinding(pointer.scroll(const Offset(200, 0)));
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
    });

    testWidgets('trackpad pan right past the threshold tunes "more"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.trackpadFling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(200, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
    });

    testWidgets('trackpad pan left past the threshold tunes "less"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.trackpadFling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
    });

    testWidgets('shows the directional indicator during a drag', (
      tester,
    ) async {
      await pumpOverlay(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FeedTuningSwipeOverlay)),
      );
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(find.text(l10n.feedTuningMoreLabel), findsOneWidget);
      expect(find.text(l10n.feedTuningLessLabel), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('exposes more/less as custom semantic actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOverlay(tester);

      final moreId = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.feedTuningMoreLabel),
      );
      final lessId = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.feedTuningLessLabel),
      );
      final node = tester.getSemantics(find.byType(FeedTuningSwipeOverlay));

      expect(
        node.getSemanticsData().customSemanticsActionIds,
        containsAll(<int>[moreId, lessId]),
      );
      handle.dispose();
    });
  });

  group('platform back gesture', () {
    testWidgets('iOS back swipe pops without tuning', (tester) async {
      final tuned = await pumpPushedOverlay(tester);

      await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('iOS center swipe still tunes more on pushed route', (
      tester,
    ) async {
      final tuned = await pumpPushedOverlay(tester);

      await tester.dragFrom(const Offset(200, 300), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
      expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);
    });

    testWidgets('iOS RTL back swipe pops without tuning', (tester) async {
      final tuned = await pumpPushedOverlay(
        tester,
        textDirection: TextDirection.rtl,
      );

      await tester.dragFrom(const Offset(795, 300), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('iOS root-route edge swipe can still tune', (tester) async {
      final tuned = await pumpFullscreenRootOverlay(tester);

      await tester.dragFrom(const Offset(5, 300), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
    });

    testWidgets('macOS pushed route edge swipe pops without tuning', (
      tester,
    ) async {
      final tuned = await pumpPushedOverlay(
        tester,
        platform: TargetPlatform.macOS,
      );

      await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Android pushed route edge swipe can still tune', (
      tester,
    ) async {
      final tuned = await pumpPushedOverlay(
        tester,
        platform: TargetPlatform.android,
      );

      await tester.dragFrom(const Offset(5, 300), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
      expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);
    });
  });

  group('gesture arena vs. vertical paging', () {
    testWidgets('horizontal swipe tunes WITHOUT changing the page', (
      tester,
    ) async {
      final tuned = <FeedTuningDirection>[];
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                children: const [
                  SizedBox.expand(child: Center(child: Text('page-0'))),
                  SizedBox.expand(child: Center(child: Text('page-1'))),
                  SizedBox.expand(child: Center(child: Text('page-2'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.fling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
      expect(controller.page, 0); // vertical pager untouched
    });

    testWidgets('vertical swipe pages WITHOUT tuning', (tester) async {
      final tuned = <FeedTuningDirection>[];
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                children: const [
                  SizedBox.expand(child: Center(child: Text('page-0'))),
                  SizedBox.expand(child: Center(child: Text('page-1'))),
                  SizedBox.expand(child: Center(child: Text('page-2'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.fling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(0, -600),
        1500,
      );
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(controller.page, greaterThan(0)); // vertical pager advanced
    });

    testWidgets('vertical swipe with sideways drift still pages', (
      tester,
    ) async {
      final tuned = <FeedTuningDirection>[];
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                children: const [
                  SizedBox.expand(child: Center(child: Text('page-0'))),
                  SizedBox.expand(child: Center(child: Text('page-1'))),
                  SizedBox.expand(child: Center(child: Text('page-2'))),
                ],
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FeedTuningSwipeOverlay)),
      );
      await gesture.moveBy(const Offset(24, -4));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(controller.page, 1);
    });
  });

  group(FeedTuningSwipeGate, () {
    testWidgets('wraps the child with the overlay when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeGate(
              enabled: true,
              onTuned: (_) {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);
    });

    testWidgets('renders only the child when disabled', (tester) async {
      const childKey = Key('feed-child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedTuningSwipeGate(
              enabled: false,
              onTuned: _noop,
              child: SizedBox(key: childKey, width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(FeedTuningSwipeOverlay), findsNothing);
      expect(find.byKey(childKey), findsOneWidget);
    });
  });
}

void _noop(FeedTuningDirection _) {}

Future<List<FeedTuningDirection>> pumpFullscreenRootOverlay(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final tuned = <FeedTuningDirection>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FeedTuningSwipeOverlay(
          onTuned: tuned.add,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  return tuned;
}

Future<List<FeedTuningDirection>> pumpPushedOverlay(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final tuned = <FeedTuningDirection>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return Scaffold(
                          body: FeedTuningSwipeOverlay(
                            onTuned: tuned.add,
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('home'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);

  return tuned;
}
