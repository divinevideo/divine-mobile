// ABOUTME: Pull-to-refresh on the bookmarks view, and the app bar's exit path
// ABOUTME: Both regress when the screen is entered cold rather than pushed

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/saved_videos_screen.dart';

import '../helpers/test_provider_overrides.dart';

class _MockProfileSavedVideosBloc
    extends MockBloc<ProfileSavedVideosEvent, ProfileSavedVideosState>
    implements ProfileSavedVideosBloc {}

void main() {
  group(SavedVideosView, () {
    late _MockProfileSavedVideosBloc mockBloc;

    setUpAll(() {
      registerFallbackValue(const ProfileSavedVideosSyncRequested());
    });

    setUp(() {
      mockBloc = _MockProfileSavedVideosBloc();
    });

    Widget buildSubject() {
      return testProviderScope(
        additionalOverrides: [],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileSavedVideosBloc>.value(
              value: mockBloc,
              child: const SavedVideosView(userIdHex: 'test-user'),
            ),
          ),
        ),
      );
    }

    testWidgets('a pull requests a sync the indicator can wait on', (
      tester,
    ) async {
      // Empty is the state a pull most needs to work in: unbookmarking the
      // last video leaves nothing to scroll.
      when(() => mockBloc.state).thenReturn(
        const ProfileSavedVideosState(status: ProfileSavedVideosStatus.success),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => mockBloc.add(captureAny<ProfileSavedVideosSyncRequested>()),
      ).captured.cast<ProfileSavedVideosSyncRequested>();

      // A completer is what releases the spinner; without one the indicator
      // would spin until it timed out rather than until the sync finished.
      expect(captured, hasLength(1));
      expect(captured.single.completer, isNotNull);

      // Settle the indicator so the test does not end mid-animation.
      captured.single.completer!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('does not sync without a pull', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const ProfileSavedVideosState(status: ProfileSavedVideosStatus.success),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      verifyNever(
        () => mockBloc.add(any<ProfileSavedVideosSyncRequested>()),
      );
    });
  });

  // A divine:///saved-videos deep link lands here with a one-entry stack, and
  // the screen is registered outside the shell — no bottom nav either. Without
  // an explicit back affordance that survives an empty stack, the deep link
  // delivers a dead end (#7074).
  group(SavedVideosAppBar, () {
    GoRouter buildRouter({required String initialLocation}) {
      return GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: VideoFeedPage.pathForIndex(0),
            builder: (_, _) => const Scaffold(body: Text('feed')),
          ),
          GoRoute(
            path: SavedVideosScreen.path,
            builder: (_, _) => const Scaffold(
              appBar: SavedVideosAppBar(),
              body: Text('bookmarks'),
            ),
          ),
        ],
      );
    }

    Widget wrap(GoRouter router) {
      return MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        routerConfig: router,
      );
    }

    testWidgets('back lands on the feed when there is nothing to pop', (
      tester,
    ) async {
      final router = buildRouter(initialLocation: SavedVideosScreen.path);
      addTearDown(router.dispose);

      await tester.pumpWidget(wrap(router));
      await tester.pumpAndSettle();

      // Precondition: cold entry really does leave a one-entry stack, so a
      // raw context.pop() here would throw GoError.
      expect(router.canPop(), isFalse);

      await tester.tap(find.byType(DivineIconButton));
      await tester.pumpAndSettle();

      expect(find.text('feed'), findsOneWidget);
    });

    testWidgets('back pops when the user pushed here from elsewhere', (
      tester,
    ) async {
      final router = buildRouter(
        initialLocation: VideoFeedPage.pathForIndex(0),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(wrap(router));
      await tester.pumpAndSettle();

      unawaited(router.push(SavedVideosScreen.path));
      await tester.pumpAndSettle();
      expect(find.text('bookmarks'), findsOneWidget);

      await tester.tap(find.byType(DivineIconButton));
      await tester.pumpAndSettle();

      expect(find.text('feed'), findsOneWidget);
    });
  });
}
