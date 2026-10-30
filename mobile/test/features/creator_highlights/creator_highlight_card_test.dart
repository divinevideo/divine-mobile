import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:openvine/features/creator_highlights/creator_highlight_card.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _card = CreatorHighlight(
  owner: _owner,
  localDate: '2026-10-30',
  createdToday: 1,
  creationDaysThisWeek: 2,
  views: 3,
  celebrate: true,
  topVideo: VideoEvent(
    id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    pubkey: _owner,
    createdAt: 1793304000,
    timestamp: DateTime.utc(2026, 10, 30),
    content: 'A tiny dance',
    title: 'A tiny dance',
  ),
);

void main() {
  setUp(() {
    final controller = VisibilityDetectorController.instance;
    final previousInterval = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = previousInterval);
  });

  group('interactions', () {
    testWidgets('an offscreen built card waits for viewport presentation', (
      tester,
    ) async {
      final scrollController = ScrollController(initialScrollOffset: 1000);
      addTearDown(scrollController.dispose);
      var presented = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: CreatorHighlightCard(
                    highlight: _card,
                    isVisible: true,
                    onPresented: () => presented++,
                    onCreate: () {},
                    onAnalytics: () {},
                    onWatch: () {},
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 3000)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byType(CreatorHighlightCard, skipOffstage: false);
      expect(card, findsOneWidget);
      expect(
        tester.getBottomRight(card).dy,
        lessThan(0),
      );
      expect(presented, 0);
      scrollController.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(presented, 1);
      final scale = tester.widget<Transform>(
        find.descendant(
          of: find.byType(TweenAnimationBuilder<double>),
          matching: find.byType(Transform),
        ),
      );
      expect(scale.transform.entry(0, 0), lessThan(1));
      await tester.pumpAndSettle();
      expect(presented, 1);
    });

    testWidgets('only visible presentation is recorded and all actions work', (
      tester,
    ) async {
      var presented = 0;
      var created = 0;
      var analytics = 0;
      var watched = 0;
      Widget subject(bool visible) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreatorHighlightCard(
              highlight: _card,
              isVisible: visible,
              onPresented: () => presented++,
              onCreate: () => created++,
              onAnalytics: () => analytics++,
              onWatch: () => watched++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(false));
      await tester.pumpAndSettle();
      expect(presented, 0);
      await tester.pumpWidget(subject(true));
      await tester.pumpAndSettle();
      expect(presented, 1);
      await tester.tap(find.text('Make another'));
      await tester.tap(find.text('See your stats'));
      await tester.tap(find.text('Watch video'));
      expect((created, analytics, watched), (1, 1, 1));
      await tester.pumpWidget(subject(true));
      await tester.pumpAndSettle();
      expect(presented, 1);
      await tester.pumpWidget(subject(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(subject(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final scale = tester.widget<Transform>(
        find.descendant(
          of: find.byType(TweenAnimationBuilder<double>),
          matching: find.byType(Transform),
        ),
      );
      expect(scale.transform.entry(0, 0), 1);
      expect(presented, 1);
    });
  });

  group('renders', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'card scrolls at large text in $brightness with reduced motion',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: CreatorHighlightCard(
                        highlight: _card,
                        isVisible: true,
                        onPresented: () {},
                        onCreate: () {},
                        onAnalytics: () {},
                        onWatch: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('You made something today.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('See your stats'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
