// ABOUTME: Widget tests for the category gallery screen.
// ABOUTME: Verifies picker-driven category navigation and gallery state handling.

import 'package:categories_repository/categories_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/category_gallery_screen.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      ).thenReturn([allowedVideo]);

      container = ProviderContainer(
        overrides: [
          categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
          authServiceProvider.overrideWithValue(authService),
          subscribedListVideoCacheProvider.overrideWithValue(null),
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

      container.read(blocklistVersionProvider.notifier).increment();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Blocked Video'), findsNothing);
      expect(find.text('Allowed Video'), findsOneWidget);
      verify(
        () => blocklistRepository.filterContent<VideoEvent>(any(), any()),
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
