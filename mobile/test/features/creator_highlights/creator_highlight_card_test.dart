import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:openvine/features/creator_highlights/creator_highlight_card.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _card = CreatorHighlight(
  owner: _owner,
  localDate: '2026-10-30',
  createdToday: 1,
  creationDaysThisWeek: 2,
  views: 3,
  topVideoViews: 3,
  likes: 4,
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

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

CreatorHighlight _inviteCard({required bool showInvite}) => CreatorHighlight(
  owner: _owner,
  localDate: '2026-10-30',
  createdToday: 1,
  creationDaysThisWeek: 2,
  views: null,
  topVideo: null,
  celebrate: false,
  showInvite: showInvite,
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
      var analytics = 0;
      var watched = 0;
      Widget subject(bool visible) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreatorHighlightCard(
              // Lead with the top video so its thumbnail is on screen.
              highlight: _card.copyWith(rotation: 1),
              isVisible: visible,
              onPresented: () => presented++,
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
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CreatorHighlightCard)),
      );
      await tester.tap(find.text(l10n.creatorHighlightAnalytics));
      await tester.tap(find.byType(NotificationVideoThumbnail));
      expect((analytics, watched), (1, 1));
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

  group('invite', () {
    late List<Map<Object?, Object?>> shareCalls;
    late int analyticsTaps;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      shareCalls = [];
      analyticsTaps = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            if (call.method == 'share') {
              shareCalls.add(call.arguments as Map<Object?, Object?>);
            }
            return 'com.apple.UIKit.activity.CopyToPasteboard';
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, null);
    });

    Future<void> pumpCard(WidgetTester tester, {required bool showInvite}) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CreatorHighlightCard(
                highlight: _inviteCard(showInvite: showInvite),
                isVisible: true,
                onPresented: () {},
                onAnalytics: () => analyticsTaps++,
                onWatch: () {},
              ),
            ),
          ),
        );

    testWidgets('shows the invite row when the highlight offers it', (
      tester,
    ) async {
      await pumpCard(tester, showInvite: true);
      expect(find.text(l10n.creatorHighlightInvite), findsOneWidget);
    });

    testWidgets('hides the invite row otherwise', (tester) async {
      await pumpCard(tester, showInvite: false);
      expect(find.text(l10n.creatorHighlightAnalytics), findsOneWidget);
      expect(find.text(l10n.creatorHighlightInvite), findsNothing);
    });

    testWidgets(
      'tapping the invite row shares the download link and does not open stats',
      (tester) async {
        await pumpCard(tester, showInvite: true);
        await tester.tap(find.text(l10n.creatorHighlightInvite));
        await tester.pumpAndSettle();
        expect(shareCalls, hasLength(1));
        expect(
          shareCalls.single['text'],
          l10n.creatorHighlightInviteMessage(AppConstants.downloadUrl),
        );
        expect(analyticsTaps, 0);
      },
    );

    testWidgets('the invite row is its own button for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, showInvite: true);
      expect(
        tester.getSemantics(find.text(l10n.creatorHighlightInvite)),
        isSemantics(
          label: l10n.creatorHighlightInvite,
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('renders', () {
    Widget subject(CreatorHighlight highlight) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CreatorHighlightCard(
            highlight: highlight,
            isVisible: true,
            onPresented: () {},
            onAnalytics: () {},
            onWatch: () {},
          ),
        ),
      ),
    );

    testWidgets('leads with one spotlight and links its video only there', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(subject(_card));
      await tester.pumpAndSettle();
      expect(find.text(l10n.creatorHighlightCreatedToday(1)), findsOneWidget);
      expect(find.text(l10n.creatorHighlightTopVideoViews(3)), findsNothing);
      expect(find.byType(NotificationVideoThumbnail), findsNothing);

      await tester.pumpWidget(subject(_card.copyWith(rotation: 1)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.creatorHighlightTopVideoViews(3)), findsOneWidget);
      expect(find.text('A tiny dance'), findsOneWidget);
      expect(find.text(l10n.creatorHighlightTopVideo), findsOneWidget);
      expect(find.byType(NotificationVideoThumbnail), findsOneWidget);
      expect(find.text(l10n.creatorHighlightCreatedToday(1)), findsNothing);

      await tester.pumpWidget(subject(_card.copyWith(rotation: 2)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.creatorHighlightWeeklyLikes(4)), findsOneWidget);
      expect(find.byType(NotificationVideoThumbnail), findsNothing);
      expect(find.text(l10n.creatorHighlightAnalytics), findsOneWidget);
    });

    testWidgets('screen readers reach the video apart from the stats card', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(subject(_card.copyWith(rotation: 1)));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(NotificationVideoThumbnail)),
        matchesSemantics(
          label: l10n.notificationsVideoThumbnailFor('A tiny dance'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      final card = tester.getSemantics(
        find.descendant(
          of: find.byType(CreatorHighlightCard),
          matching: find.byType(InkWell),
        ),
      );
      expect(card.flagsCollection.isButton, isTrue);
      expect(card.label, contains(l10n.creatorHighlightAnalytics));
      expect(card.label, contains(l10n.creatorHighlightTopVideoViews(3)));
      semantics.dispose();
    });

    testWidgets('advancing the spotlight records a new presentation', (
      tester,
    ) async {
      var presented = 0;
      Widget card(int rotation) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CreatorHighlightCard(
            highlight: _card.copyWith(rotation: rotation, celebrate: false),
            isVisible: true,
            onPresented: () => presented++,
            onAnalytics: () {},
            onWatch: () {},
          ),
        ),
      );
      await tester.pumpWidget(card(0));
      await tester.pumpAndSettle();
      expect(presented, 1);
      await tester.pumpWidget(card(0));
      await tester.pumpAndSettle();
      expect(presented, 1);
      await tester.pumpWidget(card(1));
      await tester.pumpAndSettle();
      expect(presented, 2);
    });

    for (final brightness in Brightness.values) {
      for (final locale in AppLocalizations.supportedLocales) {
        testWidgets(
          '${locale.languageCode} card scrolls at large text in $brightness '
          'with reduced motion',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
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
            final l10n = lookupAppLocalizations(locale);
            expect(
              find.text(l10n.creatorHighlightCreatedToday(_card.createdToday)),
              findsOneWidget,
            );
            expect(
              find.text(
                l10n.creatorHighlightCreationDays(_card.creationDaysThisWeek),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(
              find.text(l10n.creatorHighlightAnalytics),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
