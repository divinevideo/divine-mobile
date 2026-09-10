import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_app_bar.dart';

import '../../../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataClassicAppBar, () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/test',
            builder: (context, state) => const Scaffold(
              appBar: VideoMetadataClassicAppBar(),
              body: Text('Test'),
            ),
          ),
        ],
      );
    });

    Widget buildTestWidget() {
      return MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
    }

    testWidgets('renders $VideoMetadataClassicAppBar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoMetadataClassicAppBar), findsOneWidget);
    });

    testWidgets('renders title text "Share"', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('renders subtitle text "Video details"', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Video details'), findsOneWidget);
    });

    testWidgets('renders back button with $DivineIconButton', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('renders back button icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('wraps back button in Hero with correct tag', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      final hero = tester.widget<Hero>(heroFinder);
      expect(hero.tag, equals(VideoEditorConstants.heroBackButtonId));
    });

    testWidgets('implements PreferredSizeWidget with kToolbarHeight', (
      tester,
    ) async {
      const header = VideoMetadataClassicAppBar();

      expect(header, isA<PreferredSizeWidget>());
      expect(header.preferredSize.height, equals(kToolbarHeight));
    });

    testWidgets('tapping back button triggers pop navigation', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: VideoMetadataClassicAppBar(),
              body: Text('Test'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VideoMetadataClassicAppBar), findsOneWidget);

      await tester.tap(find.byType(DivineIconButton));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.pop<Object?>(any())).called(1);
    });

    testWidgets('renders inside SafeArea with bottom: false', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final safeAreaFinder = find.descendant(
        of: find.byType(VideoMetadataClassicAppBar),
        matching: find.byType(SafeArea),
      );
      expect(safeAreaFinder, findsOneWidget);

      final safeArea = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeArea.bottom, isFalse);
    });
  });
}
