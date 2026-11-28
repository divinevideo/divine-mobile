// ABOUTME: Widget tests for the categories discovery surface.
// ABOUTME: Verifies loading/error/empty states and the redesigned pinned-first list.

import 'package:categories_repository/categories_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/widgets/categories/category_glyph.dart';
import 'package:openvine/widgets/categories_tab.dart';

import '../helpers/large_screen_layout.dart';

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

void main() {
  Widget buildSubject({
    required CategoriesState state,
    void Function(VideoCategory)? onCategoryTap,
    VoidCallback? onRetry,
    Locale? locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CategoriesDiscoveryView(
          state: state,
          onCategoryTap: onCategoryTap ?? (_) {},
          onRetry: onRetry ?? () {},
        ),
      ),
    );
  }

  group('CategoriesDiscoveryView', () {
    testWidgets('renders loading indicator when status is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loading,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders retry state when loading categories fails', (
      tester,
    ) async {
      var retries = 0;

      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.error,
          ),
          onRetry: () => retries += 1,
        ),
      );

      expect(find.text('Could not load categories'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('renders empty state when there are no categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
          ),
        ),
      );

      expect(find.text('No categories available'), findsOneWidget);
    });

    testWidgets('renders featured categories first in a vertical tile list', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'animals', videoCount: 1500),
              VideoCategory(name: 'fashion', videoCount: 1200),
              VideoCategory(name: 'technology', videoCount: 300),
            ],
          ),
        ),
      );

      expect(find.byType(GridView), findsNothing);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);

      final animalsTopLeft = tester.getTopLeft(find.text('Animals'));
      final styleTopLeft = tester.getTopLeft(find.text('Style'));
      final technologyTopLeft = tester.getTopLeft(find.text('Technology'));

      expect(animalsTopLeft.dy, lessThan(styleTopLeft.dy));
      expect(styleTopLeft.dy, lessThan(technologyTopLeft.dy));
    });

    group('on a wide window', () {
      const loaded = CategoriesState(
        categoriesStatus: CategoriesStatus.loaded,
        categories: [
          VideoCategory(name: 'animals', videoCount: 1500),
          VideoCategory(name: 'fashion', videoCount: 1200),
          VideoCategory(name: 'technology', videoCount: 300),
        ],
      );

      Future<void> pumpWide(
        WidgetTester tester, {
        required bool largeScreenLayout,
      }) async {
        setTestWindowSize(tester, 1000);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: largeScreenLayout,
            home: Scaffold(
              body: CategoriesDiscoveryView(
                state: loaded,
                onCategoryTap: (_) {},
                onRetry: () {},
              ),
            ),
          ),
        );
      }

      testWidgets('lays the tiles side by side with the large-screen layouts', (
        tester,
      ) async {
        await pumpWide(tester, largeScreenLayout: true);

        // 1000 pt less the side padding crosses two breakpoints: one row of
        // three tiles.
        final animals = tester.getTopLeft(find.text('Animals'));
        final style = tester.getTopLeft(find.text('Style'));
        final technology = tester.getTopLeft(find.text('Technology'));
        expect([style.dy, technology.dy], everyElement(equals(animals.dy)));
        expect(style.dx, greaterThan(animals.dx));
        expect(technology.dx, greaterThan(style.dx));
      });

      testWidgets('keeps one full-width tile per row with the flag off', (
        tester,
      ) async {
        await pumpWide(tester, largeScreenLayout: false);

        expect(find.byType(GridView), findsNothing);
        final animals = tester.getTopLeft(find.text('Animals'));
        final style = tester.getTopLeft(find.text('Style'));
        expect(style.dx, equals(animals.dx));
        expect(style.dy, greaterThan(animals.dy));
      });
    });

    testWidgets('exposes stable category tile identifiers', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'animals', videoCount: 1500),
              VideoCategory(name: 'music', videoCount: 900),
            ],
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == SemanticIds.categoryTile(0),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == SemanticIds.categoryTile(1),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a linear refresh indicator over cached categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 1500)],
            isRefreshing: true,
          ),
        ),
      );

      expect(find.text('Animals'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('localizes category video counts for Amharic', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          locale: const Locale('am'),
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 1500)],
          ),
        ),
      );

      expect(find.text('1.5K ቪዲዮዎች'), findsOneWidget);
      expect(find.text('1.5K videos'), findsNothing);
    });

    testWidgets('calls back when a category tile is tapped', (tester) async {
      VideoCategory? tappedCategory;

      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 1500)],
          ),
          onCategoryTap: (category) => tappedCategory = category,
        ),
      );

      await tester.tap(find.text('Animals'));

      expect(
        tappedCategory,
        const VideoCategory(name: 'animals', videoCount: 1500),
      );
    });

    group('category sticker', () {
      CategoriesState loadedWith(String slug) {
        return CategoriesState(
          categoriesStatus: CategoriesStatus.loaded,
          categories: [VideoCategory(name: slug, videoCount: 1500)],
        );
      }

      final sticker = find.byType(DivineSticker);
      final slot = find.ancestor(
        of: sticker,
        matching: find.byType(OverflowBox),
      );
      final tile = find.ancestor(of: sticker, matching: find.byType(ClipRRect));

      testWidgets('draws the sticker design chose for the category', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(state: loadedWith('animals')));

        expect(
          tester.widget<DivineSticker>(sticker).sticker,
          equals(DivineStickerName.horse),
        );
        expect(find.byType(CategoryGlyph), findsNothing);
      });

      testWidgets('keeps the glyph for a category without a sticker', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(state: loadedWith('technology')));

        expect(find.byType(CategoryGlyph), findsOneWidget);
        expect(sticker, findsNothing);
      });

      testWidgets('lets the sticker bleed past the tile that clips it', (
        tester,
      ) async {
        // Food's pizza slice is not rotated, so its rect is its painted bounds.
        await tester.pumpWidget(buildSubject(state: loadedWith('food')));

        final tileRect = tester.getRect(tile);
        expect(tileRect.height, equals(96));
        expect(tester.getRect(sticker).bottom, greaterThan(tileRect.bottom));
      });

      testWidgets('keeps the decorative sticker out of the semantics tree', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildSubject(state: loadedWith('animals')));

        // An unexcluded Image marks the tile it merges into as an image.
        expect(
          find.semantics.byPredicate((node) => node.flagsCollection.isImage),
          findsNothing,
        );
        handle.dispose();
      });

      testWidgets('nudges the sticker toward the trailing edge', (
        tester,
      ) async {
        // Style's sunglasses carry the largest sideways nudge in the design.
        await tester.pumpWidget(buildSubject(state: loadedWith('fashion')));

        final nudge = tester.getCenter(sticker).dx - tester.getCenter(slot).dx;
        expect(nudge, closeTo(16.5, 0.01));
      });

      testWidgets('mirrors the nudge in a right-to-left layout', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: loadedWith('fashion'),
            locale: const Locale('ar'),
          ),
        );

        final nudge = tester.getCenter(sticker).dx - tester.getCenter(slot).dx;
        expect(nudge, closeTo(-16.5, 0.01));
        // The slot itself moved to the leading (left) half of the tile.
        expect(
          tester.getCenter(slot).dx,
          lessThan(tester.getRect(tile).center.dx),
        );
      });
    });
  });

  group('CategoriesTab', () {
    testWidgets('opens the category gallery route with the tapped category', (
      tester,
    ) async {
      const animals = VideoCategory(name: 'animals', videoCount: 1500);
      final repository = _MockCategoriesRepository();
      when(repository.watchCategoriesCached)
          .thenAnswer((_) => Stream.value(const CacheResult.live([animals])));
      Object? galleryExtra;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: CategoriesTab()),
          ),
          GoRoute(
            path: CategoryGalleryScreen.path,
            builder: (context, state) {
              galleryExtra = state.extra;
              return Text('gallery:${state.pathParameters['categoryName']}');
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Animals'));
      await tester.pumpAndSettle();

      expect(find.text('gallery:animals'), findsOneWidget);
      expect(galleryExtra, animals);
    });
  });
}
