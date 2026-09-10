// ABOUTME: Router tests for category gallery routes.
// ABOUTME: Prevents category detail URLs from falling back to the home route.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/screens/category_gallery_screen.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pathParameters,
    this.extra,
    String location = '/',
  }) : uri = Uri.parse(location),
       matchedLocation = location,
       fullPath = location,
       pageKey = ValueKey<String>(location);

  @override
  final Object? extra;

  @override
  final String? fullPath;

  @override
  final String matchedLocation;

  @override
  final Map<String, String> pathParameters;

  @override
  final ValueKey<String> pageKey;

  @override
  final Uri uri;
}

void main() {
  group('Category gallery routes', () {
    test('buildRoute preserves category gallery URLs', () {
      final location = CategoryGalleryScreen.locationFor('animals');

      expect(buildRoute(parseRoute(location)), location);
    });

    test('parseRoute treats category gallery as its own route type', () {
      final context = parseRoute(CategoryGalleryScreen.locationFor('animals'));

      expect(context.type, RouteType.categoryGallery);
      expect(context.categoryName, 'animals');
      expect(context.videoIndex, isNull);
    });

    testWidgets('denied category names resolve to route error', (tester) async {
      final route = _categoryGalleryRoute();

      await _buildWithContext(tester, (context) {
        final adultScreen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/categories/adult',
            pathParameters: const {'categoryName': 'adult'},
          ),
        );
        final violenceScreen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/categories/%20Violence%20',
            pathParameters: const {'categoryName': ' Violence '},
          ),
        );
        final pornScreen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/categories/porn',
            pathParameters: const {'categoryName': 'porn'},
          ),
        );

        expect(adultScreen, isA<RouteErrorScreen>());
        expect(violenceScreen, isA<RouteErrorScreen>());
        expect(pornScreen, isA<RouteErrorScreen>());
      });
    });

    testWidgets(
      'denied category passed through extra resolves to route error',
      (
        tester,
      ) async {
        final route = _categoryGalleryRoute();

        await _buildWithContext(tester, (context) {
          final screen = route.builder!(
            context,
            _FakeGoRouterState(
              location: '/categories/adult',
              pathParameters: const {'categoryName': 'adult'},
              extra: const VideoCategory(name: 'adult', videoCount: 319),
            ),
          );

          expect(screen, isA<RouteErrorScreen>());
        });
      },
    );

    testWidgets('allowed category names resolve to gallery', (tester) async {
      final route = _categoryGalleryRoute();
      late CategoryGalleryScreen screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/categories/animals',
            pathParameters: const {'categoryName': 'animals'},
            extra: const VideoCategory(name: 'animals', videoCount: 1),
          ),
        ) as CategoryGalleryScreen;
      });

      expect(screen.category.name, 'animals');
    });
  });
}

GoRoute _categoryGalleryRoute() {
  return searchRoutes().whereType<GoRoute>().singleWhere(
    (route) => route.name == CategoryGalleryScreen.routeName,
  );
}

Future<void> _buildWithContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}
