// ABOUTME: Tests the library routes registered by libraryRoutes.
// ABOUTME: Pins which tab each location opens and how clips-only reads `type`.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/router/routes/library_routes.dart';
import 'package:openvine/screens/library_screen.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(String location, {this.name})
    : uri = Uri.parse(location),
      matchedLocation = Uri.parse(location).path,
      fullPath = Uri.parse(location).path,
      pageKey = ValueKey<String>(location);

  @override
  final String? name;

  @override
  final Uri uri;

  @override
  final String matchedLocation;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  String? get path => fullPath;

  @override
  GoRoute? get topRoute => null;

  @override
  Object? get extra => null;

  @override
  Map<String, String> get pathParameters => const {};
}

void main() {
  group('libraryRoutes', () {
    late BuildContext context;

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    LibraryScreen screenAt(String routeName, String location) {
      final route = libraryRoutes().whereType<GoRoute>().singleWhere(
        (route) => route.name == routeName,
      );
      final page = route.pageBuilder!(
        context,
        _FakeGoRouterState(location, name: routeName),
      );
      return (page as CustomTransitionPage<void>).child as LibraryScreen;
    }

    testWidgets('drafts opens the Drafts tab', (tester) async {
      await captureContext(tester);

      final screen = screenAt(
        LibraryScreen.draftsRouteName,
        LibraryScreen.draftsPath,
      );

      expect(screen.initialTabIndex, equals(0));
      expect(screen.tabsMode, equals(LibraryTabsMode.allTabs));
    });

    testWidgets('clips opens the Clips tab', (tester) async {
      await captureContext(tester);

      final screen = screenAt(
        LibraryScreen.clipsRouteName,
        LibraryScreen.clipsPath,
      );

      expect(screen.initialTabIndex, equals(1));
      expect(screen.clipTypeFilter, equals(LibraryClipTypeFilter.all));
    });

    testWidgets('sounds opens the Sounds tab', (tester) async {
      await captureContext(tester);

      final screen = screenAt(
        LibraryScreen.soundsRouteName,
        LibraryScreen.soundsPath,
      );

      expect(screen.initialTabIndex, equals(2));
    });

    group(LibraryScreen.clipsOnlyPath, () {
      testWidgets('scopes the clips to the type in the query', (tester) async {
        await captureContext(tester);

        final screen = screenAt(
          LibraryScreen.clipsOnlyRouteName,
          '${LibraryScreen.clipsOnlyPath}?type='
          '${LibraryClipTypeFilter.stopMotion.queryValue}',
        );

        expect(screen.clipTypeFilter, equals(LibraryClipTypeFilter.stopMotion));
        expect(screen.initialTabIndex, equals(1));
        expect(screen.tabsMode, equals(LibraryTabsMode.withoutSounds));
        expect(screen.includeAutosaveDraft, isFalse);
      });

      testWidgets('shows both clip types without a type', (tester) async {
        await captureContext(tester);

        final screen = screenAt(
          LibraryScreen.clipsOnlyRouteName,
          LibraryScreen.clipsOnlyPath,
        );

        expect(screen.clipTypeFilter, equals(LibraryClipTypeFilter.all));
      });
    });
  });
}
