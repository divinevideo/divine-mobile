// ABOUTME: Widget tests for the category gallery screen.
// ABOUTME: Verifies picker-driven category navigation and gallery state handling.

import 'dart:async';

import 'package:categories_repository/categories_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/og_diviner_eligibility_provider.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/categories/category_glyph.dart';

import '../helpers/test_provider_overrides.dart';

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  Widget buildSubject({
    required VideoCategory category,
    required CategoriesState state,
    void Function(String)? onSortChanged,
    VoidCallback? onBack,
    VoidCallback? onRetry,
    Widget? galleryOverride,
  }) {
    // No Scaffold: the route mounts this view on the root navigator, so
    // nothing above it supplies a Material. Pump it the same way here.
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CategoryGalleryView(
        category: category,
        state: state,
        onBack: onBack ?? () {},
        onRetry: onRetry ?? () {},
        onSortChanged: onSortChanged ?? (_) {},
        onVideoTap: (videos, index) {},
        onLoadMore: () async {},
        onRefresh: () async {},
        galleryOverride: galleryOverride,
      ),
    );
  }

  group('CategoryGalleryView', () {
    const category = VideoCategory(name: 'animals', videoCount: 1500);

    group('header mascot', () {
      Future<void> pumpHeader(WidgetTester tester, VideoCategory shown) {
        return tester.pumpWidget(
          buildSubject(
            category: shown,
            state: CategoriesState(
              selectedCategory: shown,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
          ),
        );
      }

      final mascot = find.descendant(
        of: find.byKey(const Key('category-header-mascot-slot')),
        matching: find.byType(DivineSticker),
      );

      testWidgets('draws the category sticker', (tester) async {
        await pumpHeader(tester, category);

        expect(
          tester.widget<DivineSticker>(mascot).sticker,
          equals(DivineStickerName.horse),
        );
        expect(find.byType(CategoryGlyph), findsNothing);
      });

      testWidgets('keeps the glyph for a category without a sticker', (
        tester,
      ) async {
        await pumpHeader(
          tester,
          const VideoCategory(name: 'technology', videoCount: 12),
        );

        expect(mascot, findsNothing);
        expect(find.byType(CategoryGlyph), findsOneWidget);
      });
    });

    testWidgets(
      'shows category title and picker trigger without inline sort labels',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(
            category: category,
            state: const CategoriesState(
              selectedCategory: category,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
          ),
        );

        expect(find.text('Animals'), findsOneWidget);
        expect(find.bySemanticsLabel('Category sort options'), findsOneWidget);
        expect(
          find.byKey(const Key('category-header-back-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('category-header-filter-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('category-header-mascot-slot')),
          findsOneWidget,
        );
        expect(find.text('Hot'), findsNothing);
        expect(find.text('New'), findsNothing);
        expect(find.text('Classic'), findsNothing);
        expect(find.text('For You'), findsNothing);

        final backButtonDecoration = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-header-back-button')),
        );
        final backDecoration = backButtonDecoration.decoration as BoxDecoration;
        expect(backDecoration.color, const Color(0xFF3E0C1F));
        expect(backDecoration.border, isNotNull);

        final filterButtonDecoration = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-header-filter-button')),
        );
        final filterDecoration =
            filterButtonDecoration.decoration as BoxDecoration;
        expect(filterDecoration.color, const Color(0xFF3E0C1F));
        expect(filterDecoration.border, isNotNull);

        expect(
          tester.getSize(find.byKey(const Key('category-header-mascot-slot'))),
          const Size(149, 90),
        );

        final filterLeft = tester
            .getTopLeft(find.byKey(const Key('category-header-filter-button')))
            .dx;
        expect(filterLeft, greaterThan(900));

        final backTop = tester
            .getTopLeft(find.byKey(const Key('category-header-back-button')))
            .dy;
        expect(backTop, greaterThan(24));
      },
    );

    group('layout', () {
      // The Figma frame is 402 wide. With no device inset the header keeps
      // its 24 px minimum top, so the 72 px bar ends at 96.
      const screenWidth = 402.0;
      const barBottom = 24.0 + 72.0;

      final backButton = find.byKey(const Key('category-header-back-button'));
      final filterButton = find.byKey(
        const Key('category-header-filter-button'),
      );
      final mascotSlot = find.byKey(const Key('category-header-mascot-slot'));
      final bodyClip = find.byKey(const Key('category-gallery-body-clip'));

      Future<void> pumpAtPhoneSize(
        WidgetTester tester, {
        VideoCategory shown = category,
      }) async {
        tester.view.physicalSize = const Size(screenWidth, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildSubject(
            category: shown,
            state: CategoriesState(
              selectedCategory: shown,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
            galleryOverride: const SizedBox.expand(),
          ),
        );
      }

      testWidgets('places the actions inside 48 px slots with 12 px padding', (
        tester,
      ) async {
        await pumpAtPhoneSize(tester);

        // 12 px bar padding plus the 4 px slot margin around each button.
        expect(tester.getTopLeft(backButton), equals(const Offset(16, 40)));
        expect(
          tester.getTopRight(filterButton),
          equals(const Offset(screenWidth - 16, 40)),
        );
        expect(tester.getSize(backButton), equals(const Size(40, 40)));
      });

      testWidgets('grows the bar with large text and keeps actions square', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpAtPhoneSize(tester);

        final back = tester.getSize(backButton);
        expect(back.width, greaterThan(40));
        expect(back.height, equals(back.width));
        expect(
          tester.getRect(mascotSlot).right,
          closeTo(tester.getRect(filterButton).left, 0.001),
        );
        expect(
          tester.getRect(mascotSlot).bottom,
          equals(tester.getRect(bodyClip).top),
        );
      });

      testWidgets('starts the gallery right below the bar, edge to edge', (
        tester,
      ) async {
        await pumpAtPhoneSize(tester);

        expect(
          tester.getRect(bodyClip),
          equals(const Rect.fromLTRB(0, barBottom, screenWidth, 874)),
        );
      });

      testWidgets('rests the mascot on the bar and next to the sort button', (
        tester,
      ) async {
        await pumpAtPhoneSize(tester);

        expect(
          tester.getRect(mascotSlot),
          equals(
            const Rect.fromLTRB(
              screenWidth - 56 - 149,
              barBottom - 90,
              screenWidth - 56,
              barBottom,
            ),
          ),
        );
        expect(
          tester.getRect(mascotSlot).right,
          equals(tester.getRect(filterButton).left),
        );
      });

      testWidgets('stops the title box where the mascot begins', (
        tester,
      ) async {
        const entertainment = VideoCategory(
          name: 'entertainment',
          videoCount: 1500,
        );
        await pumpAtPhoneSize(tester, shown: entertainment);

        final title = find.text(
          lookupAppLocalizations(const Locale('en')).categoryEntertainment,
        );
        expect(
          tester.getRect(title).right,
          lessThanOrEqualTo(tester.getRect(mascotSlot).left),
        );
      });

      testWidgets('rounds the gallery top corners into the header colour', (
        tester,
      ) async {
        await pumpAtPhoneSize(tester);

        final clip = tester.widget<ClipRRect>(bodyClip);
        expect(
          clip.borderRadius,
          equals(const BorderRadius.vertical(top: Radius.circular(48))),
        );

        // What shows through the cut corners is the page behind the clip,
        // which must be the header's own colour.
        final page = tester.widget<Material>(
          find.ancestor(of: bodyClip, matching: find.byType(Material)).first,
        );
        final headerColor = tester.element(backButton).vineColors.nav;
        expect(page.color, equals(headerColor));
      });
    });

    testWidgets(
      'opens picker sheet and calls back when a different mode is tapped',
      (tester) async {
        String? selectedSort;

        await tester.pumpWidget(
          buildSubject(
            category: category,
            state: const CategoriesState(
              selectedCategory: category,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
            onSortChanged: (sort) => selectedSort = sort,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Category sort options'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('category-sort-sheet')), findsOneWidget);
        expect(
          find.byKey(const Key('category-sort-sheet-handle')),
          findsOneWidget,
        );
        expect(find.text('Hot'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('For You'), findsOneWidget);

        final selectedRow = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-sort-option-trending')),
        );
        final selectedRowDecoration = selectedRow.decoration as BoxDecoration;
        expect(selectedRowDecoration.color, const Color(0xFF032017));

        await tester.tap(find.text('For You'));
        await tester.pumpAndSettle();

        expect(selectedSort, 'forYou');
      },
    );

    testWidgets(
      'sort sheet surface reaches the bottom edge and keeps its options '
      'above the bottom inset',
      (tester) async {
        const screenSize = Size(402, 874);
        const bottomInset = 34.0;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screenSize;
        tester.view.padding = const FakeViewPadding(bottom: bottomInset);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);

        await tester.pumpWidget(
          buildSubject(
            category: category,
            state: const CategoriesState(
              selectedCategory: category,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
          ),
        );

        await tester.tap(find.bySemanticsLabel('Category sort options'));
        await tester.pumpAndSettle();

        final sheetRect = tester.getRect(
          find.byKey(const Key('category-sort-sheet')),
        );
        expect(sheetRect.bottom, equals(screenSize.height));

        final lastOptionRect = tester.getRect(
          find.byKey(const Key('category-sort-option-forYou')),
        );
        expect(
          lastOptionRect.bottom,
          lessThanOrEqualTo(screenSize.height - bottomInset),
        );
      },
    );

    testWidgets('shows retry state when category videos fail to load', (
      tester,
    ) async {
      var retries = 0;

      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.error,
          ),
          onRetry: () => retries += 1,
        ),
      );

      expect(find.text('Could not load videos'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('provides a $Material ancestor for its own text', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      // Without a Material the view's Text widgets inherit MaterialApp's
      // yellow double-underline fallback style.
      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.error,
          ),
        ),
      );

      final inheritedStyle = DefaultTextStyle.of(
        tester.element(find.text(l10n.categoryGalleryCouldNotLoadVideos)),
      ).style;
      expect(inheritedStyle.decoration, isNot(TextDecoration.underline));
    });

    testWidgets('shows empty state when selected category has no videos', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loaded,
          ),
        ),
      );

      expect(find.text('No videos in this category'), findsOneWidget);
    });

    testWidgets('renders the gallery content when videos are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loaded,
          ),
          galleryOverride: const SizedBox(key: Key('gallery-body')),
        ),
      );

      expect(find.byKey(const Key('gallery-body')), findsOneWidget);
    });
  });

  group('CategoryGalleryScreen', () {
    late _MockCategoriesRepository categoriesRepository;
    late _MockContentBlocklistRepository blocklistRepository;
    late MockAuthService authService;
    late ProviderContainer container;

    const category = VideoCategory(name: 'animals', videoCount: 1500);
    final blockedVideo = _video(
      id: 'blocked-id',
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      title: 'Blocked Video',
      authorName: 'Blocked User',
    );
    final allowedVideo = _video(
      id: 'allowed-id',
      pubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      title: 'Allowed Video',
      authorName: 'Allowed User',
    );

    setUp(() {
      categoriesRepository = _MockCategoriesRepository();
      when(
        () => categoriesRepository.watchVideosForCategoryCached(
          category: any(named: 'category'),
          sort: any(named: 'sort'),
          platform: any(named: 'platform'),
          viewerPubkey: any(named: 'viewerPubkey'),
        ),
      ).thenAnswer((invocation) async* {
        yield CacheResult.live(
          await categoriesRepository.getVideosForCategory(
            category: invocation.namedArguments[#category] as String,
            sort: invocation.namedArguments[#sort] as String,
            platform: invocation.namedArguments[#platform] as String?,
          ),
        );
      });
      blocklistRepository = _MockContentBlocklistRepository();
      authService = createMockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_viewerPubkey);

      when(
        () => categoriesRepository.getVideosForCategory(
          category: 'animals',
          before: any(named: 'before'),
          sort: any(named: 'sort'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer(
        (_) async => CategoryVideosPage(
          videos: [blockedVideo, allowedVideo],
          hasMore: false,
        ),
      );

      when(
        () => blocklistRepository.filterContent<VideoEvent>(any(), any()),
      ).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<VideoEvent>,
      );

      container = ProviderContainer(
        overrides: [
          categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
          authServiceProvider.overrideWithValue(authService),
          subscribedListVideoCacheProvider.overrideWithValue(null),
          ogDivinerEligibilityProvider.overrideWith(
            (ref, pubkey) async => false,
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    testWidgets('removes blocked videos when blocklistVersion increments', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CategoryGalleryScreen(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked Video'), findsOneWidget);
      expect(find.text('Allowed Video'), findsOneWidget);

      when(() => blocklistRepository.filterContent<VideoEvent>(any(), any()))
          .thenReturn([allowedVideo]);
      container.read(blocklistVersionProvider.notifier).increment();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Blocked Video'), findsNothing);
      expect(find.text('Allowed Video'), findsOneWidget);
    });

    testWidgets('shows cached gallery during refresh and keeps it on failure', (
      tester,
    ) async {
      final results = StreamController<CacheResult<CategoryVideosPage>>();
      addTearDown(results.close);
      when(
        () => categoriesRepository.watchVideosForCategoryCached(
          category: 'animals',
          viewerPubkey: _viewerPubkey,
        ),
      ).thenAnswer((_) => results.stream);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CategoryGalleryScreen(category: category)),
          ),
        ),
      );
      await tester.pump();
      results.add(
        CacheResult.cached(
          CategoryVideosPage(videos: [allowedVideo], hasMore: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Allowed Video'), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      results.addError(const FormatException('Refresh unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Allowed Video'), findsOneWidget);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en'))
              .categoryGalleryCouldNotLoadVideos,
        ),
        findsNothing,
      );
    });

    for (final refreshFails in [false, true]) {
      testWidgets(
        'cached tiles wait for refresh ${refreshFails ? 'failure' : 'success'} '
        'before opening fullscreen',
        (tester) async {
          final results = StreamController<CacheResult<CategoryVideosPage>>();
          addTearDown(results.close);
          when(
            () => categoriesRepository.watchVideosForCategoryCached(
              category: 'animals',
              viewerPubkey: _viewerPubkey,
            ),
          ).thenAnswer((_) => results.stream);
          PooledFullscreenVideoFeedArgs? pushedArgs;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(
                  body: CategoryGalleryScreen(category: category),
                ),
              ),
              GoRoute(
                path: PooledFullscreenVideoFeedScreen.path,
                builder: (context, state) {
                  pushedArgs = state.extra! as PooledFullscreenVideoFeedArgs;
                  return const Scaffold(body: SizedBox());
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pump();
          results.add(
            CacheResult.cached(
              CategoryVideosPage(videos: [allowedVideo], hasMore: false),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Allowed Video'));
          await tester.pumpAndSettle();
          expect(pushedArgs, isNull);

          if (refreshFails) {
            results.addError(const FormatException('Refresh unavailable'));
          } else {
            results.add(
              CacheResult.live(
                CategoryVideosPage(videos: [blockedVideo], hasMore: false),
              ),
            );
          }
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(refreshFails ? 'Allowed Video' : 'Blocked Video'),
          );
          await tester.pumpAndSettle();
          expect(
            pushedArgs?.initialVideoId,
            refreshFails ? 'allowed-id' : 'blocked-id',
          );
        },
      );
    }

    testWidgets('lays the videos out edge to edge with 4 px gaps', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CategoryGalleryScreen(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Rect tile(int index) => tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'video_thumbnail_$index',
        ),
      );

      // Two (402 - 4) / 2 px columns from the bar's bottom: the 24 px
      // minimum top plus the 72 px bar.
      expect(tile(0).topLeft, equals(const Offset(0, 96)));
      expect(tile(0).width, equals(199));
      expect(tile(1).left - tile(0).right, equals(4));
      expect(tile(1).right, equals(402));
    });

    Future<({Uri uri, PooledFullscreenVideoFeedArgs args})> tapAllowedVideo(
      WidgetTester tester,
    ) async {
      Uri? pushedUri;
      PooledFullscreenVideoFeedArgs? pushedArgs;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: CategoryGalleryScreen(category: category)),
          ),
          GoRoute(
            path: PooledFullscreenVideoFeedScreen.path,
            builder: (context, state) {
              pushedUri = state.uri;
              pushedArgs = state.extra! as PooledFullscreenVideoFeedArgs;
              return const Scaffold(body: SizedBox());
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allowed Video'));
      await tester.pumpAndSettle();

      expect(
        pushedArgs,
        isNotNull,
        reason: 'tapping the tile should open the fullscreen route',
      );
      return (uri: pushedUri!, args: pushedArgs!);
    }

    testWidgets('tapping a video opens its fullscreen route', (tester) async {
      final (:uri, :args) = await tapAllowedVideo(tester);

      expect(
        uri.queryParameters[PooledFullscreenVideoFeedScreen
            .videoQueryParameter],
        equals('allowed-id'),
      );
      expect(args.initialVideoId, equals('allowed-id'));
      expect(args.initialIndex, equals(1));
      expect(
        args.contextTitle,
        equals(lookupAppLocalizations(const Locale('en')).categoryAnimals),
      );
      expect(args.source, equals(const CategoryViewSource('animals')));
    });

    testWidgets('seeds the fullscreen feed with the videos the gallery shows', (
      tester,
    ) async {
      final (:args, uri: _) = await tapAllowedVideo(tester);

      final seededVideos = <List<VideoEvent>>[];
      final seededHasMore = <bool>[];
      final videosSubscription = args.feedRepository
          .watchView(args.source)
          .listen(seededVideos.add);
      final hasMoreSubscription = args.feedRepository
          .watchHasMore(args.source)
          .listen(seededHasMore.add);
      addTearDown(videosSubscription.cancel);
      addTearDown(hasMoreSubscription.cancel);
      await tester.pump();

      expect(seededVideos, isNotEmpty);
      expect(
        seededVideos.first.map((video) => video.id),
        equals(['blocked-id', 'allowed-id']),
      );
      expect(seededHasMore, equals([false]));
    });

    testWidgets('loading more in the fullscreen feed loads the next page', (
      tester,
    ) async {
      when(
        () => categoriesRepository.getVideosForCategory(
          category: 'animals',
          before: any(named: 'before'),
          sort: any(named: 'sort'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer(
        (_) async => CategoryVideosPage(
          videos: [blockedVideo, allowedVideo],
          hasMore: true,
        ),
      );
      final (:args, uri: _) = await tapAllowedVideo(tester);
      clearInteractions(categoriesRepository);

      await args.feedRepository.loadMore(args.source);
      await tester.pumpAndSettle();

      verify(
        () => categoriesRepository.getVideosForCategory(
          category: 'animals',
          before: any(named: 'before'),
          sort: any(named: 'sort'),
          platform: any(named: 'platform'),
        ),
      ).called(1);
    });
  });
}

const _viewerPubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

VideoEvent _video({
  required String id,
  required String pubkey,
  required String title,
  required String authorName,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    videoUrl: 'https://example.com/$id.mp4',
    thumbnail: 'https://example.com/$id.jpg',
    title: title,
    authorName: authorName,
    createdAt: DateTime(2026),
    kind: 34236,
    dTag: id,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  ).toVideoEvent();
}
