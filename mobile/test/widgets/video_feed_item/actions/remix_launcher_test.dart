// ABOUTME: Tests opening the saved remix in the clip library from a video sheet.
// ABOUTME: Covers ownership tabs and leaving newer navigation untouched.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/remix_launcher.dart';

void main() {
  group('openRemixInLibrary', () {
    late GoRouter router;
    late BuildContext sheetContext;
    late List<Uri> libraryLocations;

    Future<void> openSheet(
      WidgetTester tester, {
      bool fromOthers = true,
    }) async {
      libraryLocations = [];
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) {
                    sheetContext = context;
                    return TextButton(
                      onPressed: () => openRemixInLibrary(
                        context,
                        fromOthers: fromOthers,
                      ),
                      child: const Text('remix'),
                    );
                  },
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
          GoRoute(
            path: '/clips',
            builder: (_, state) {
              libraryLocations.add(state.uri);
              return const Scaffold(body: Text('clip library'));
            },
          ),
          GoRoute(
            path: '/video-editor',
            builder: (_, _) => const Scaffold(body: Text('editor')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows other creators footage in From others', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('remix'));
      await tester.pumpAndSettle();

      expect(find.text('clip library'), findsOneWidget);
      expect(find.text('editor'), findsNothing);
      expect(libraryLocations.single.path, '/clips');
      expect(libraryLocations.single.queryParameters, {'from-others': 'true'});
    });

    testWidgets('shows the users own footage in Clips', (tester) async {
      await openSheet(tester, fromOthers: false);
      await tester.tap(find.text('remix'));
      await tester.pumpAndSettle();

      expect(find.text('clip library'), findsOneWidget);
      expect(libraryLocations.single.queryParameters, isEmpty);
    });

    testWidgets('leaves a route opened over the sheet untouched', (
      tester,
    ) async {
      await openSheet(tester);
      Navigator.of(sheetContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covering route')),
        ),
      );
      await tester.pumpAndSettle();

      await openRemixInLibrary(sheetContext, fromOthers: true);
      await tester.pumpAndSettle();

      expect(find.text('covering route'), findsOneWidget);
      expect(libraryLocations, isEmpty);
    });

    testWidgets('does nothing after the sheet is dismissed', (tester) async {
      await openSheet(tester);
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();

      await openRemixInLibrary(sheetContext, fromOthers: true);
      await tester.pumpAndSettle();

      expect(libraryLocations, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
