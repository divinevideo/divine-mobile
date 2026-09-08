// ABOUTME: Widget tests for the UploadFailureListener success-tracking state machine.
// ABOUTME: Covers: success while authenticated, success buffered during re-auth then
// ABOUTME: flushed on restore, BackgroundPublishVanished not miscounted as success,
// ABOUTME: BackgroundPublishBloc state coverage, and the sheet-vs-snackbar branch.

import 'dart:async';
import 'dart:typed_data';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/post_publish_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/startup/upload_failure_listener.dart' as app;
import 'package:openvine/utils/nostr_key_utils.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeDraft extends Fake implements DivineVideoDraft {
  _FakeDraft(this._id);

  final String _id;

  @override
  String get id => _id;
}

class _MockGoRouter extends Mock implements GoRouter {}

class _MockRouteInformationProvider extends Mock
    implements GoRouteInformationProvider {}

/// A [GoRouter] mock parked at [location], which is what decides whether the
/// confirmation appears as a sheet or a snackbar.
_MockGoRouter _routerAt(String location) {
  final router = _MockGoRouter();
  final routeInformation = _MockRouteInformationProvider();
  when(
    () => routeInformation.value,
  ).thenReturn(RouteInformation(uri: Uri.parse(location)));
  when(() => router.routeInformationProvider).thenReturn(routeInformation);
  when(() => router.push<void>(any())).thenAnswer((_) async {});
  return router;
}

const _ownHex =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final String _ownNpub = NostrKeyUtils.encodePubKey(_ownHex);
String get _ownProfileLocation => RoutePaths.profileForNpub(_ownNpub);

class _NoOpAnalytics implements AnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal harness matching production topology: [UploadFailureListener]
/// wraps [MaterialApp], while [ProviderScope] and [BlocProvider] remain above
/// the listener.
///
/// The [MaterialApp] is keyed to [NavigatorKeys.root] so that
/// the success confirmation can resolve its [ScaffoldMessenger] via
/// the same key the production code uses.
Widget _buildHarness({
  required _MockBackgroundPublishBloc publishBloc,
  required _MockAuthService authService,
  bool wireRootNavigatorKey = true,
  PostPublishExperiment? experiment,
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      if (experiment != null)
        postPublishExperimentProvider.overrideWithValue(experiment),
      if (router != null) goRouterProvider.overrideWithValue(router),
    ],
    child: BlocProvider<BackgroundPublishBloc>.value(
      value: publishBloc,
      child: app.UploadFailureListener(
        child: MaterialApp(
          // Wire the real NavigatorKeys.root so the snackbar helper can find
          // the ScaffoldMessenger and Localizations ancestors from
          // NavigatorKeys.root.currentContext.
          navigatorKey: wireRootNavigatorKey ? NavigatorKeys.root : null,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    ),
  );
}

/// Builds a harness whose [NavigatorKeys.root] navigator sits *outside*
/// [MaterialApp], so the root context is mounted but resolves neither
/// [Localizations] nor [ScaffoldMessenger].
///
/// This is the shape #7289 crashed on: reading l10n off a context that is
/// mounted but has no localization ancestor throws a null check. It stands in
/// for a deactivated root navigator, which resolves the same way only in
/// release builds — under asserts an ancestor lookup on a deactivated element
/// throws instead of returning null.
///
/// Both ancestors are dropped together on purpose. `MaterialApp` nests
/// `Localizations` *above* `ScaffoldMessenger`, so a root context that
/// resolves the messenger but not l10n cannot occur; either the tree is
/// healthy or a deactivated element nulls out both lookups at once.
Widget _buildHarnessWithoutAppAncestors({
  required _MockBackgroundPublishBloc publishBloc,
  required _MockAuthService authService,
}) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(authService)],
    child: BlocProvider<BackgroundPublishBloc>.value(
      value: publishBloc,
      child: app.UploadFailureListener(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Navigator(
            key: NavigatorKeys.root,
            onGenerateRoute: (_) => PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Creates a [BackgroundUpload] with result == null (in-progress).
BackgroundUpload _inProgress(String id) =>
    BackgroundUpload(draft: _FakeDraft(id), result: null, progress: 0.5);

/// A [BackgroundPublishState] that carries success signals, with no remaining
/// uploads — mirrors what the bloc emits on [PublishSuccess].
BackgroundPublishState _succeededState(
  String id, {
  String? secondId,
  String? stableId = _publishedStableId,
  Uint8List? thumbnailBytes,
}) => BackgroundPublishState(
  recentlyPublished: [
    PublishedVideo(
      draftId: id,
      stableId: stableId,
      thumbnailBytes: thumbnailBytes,
    ),
    if (secondId != null)
      PublishedVideo(draftId: secondId, stableId: 'second-$secondId'),
  ],
);

const _publishedStableId = 'published-d-tag';

/// A [BackgroundPublishState] where upload [id] disappeared without a success
/// signal — mirrors what the bloc emits on [BackgroundPublishVanished].
BackgroundPublishState _vanishedState() => const BackgroundPublishState();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// An experiment with [publishId] already assigned to the treatment arm.
Future<PostPublishExperiment> _treatmentExperiment(String publishId) async {
  final experiment = PostPublishExperiment(analytics: _NoOpAnalytics());
  await experiment.screenShown(
    publishId: publishId,
    destination: 'profile',
    variant: PostPublishVariant.viewShare,
  );
  return experiment;
}

void main() {
  late _MockBackgroundPublishBloc publishBloc;
  late _MockAuthService authService;
  late StreamController<BackgroundPublishState> publishStream;

  setUp(() {
    publishBloc = _MockBackgroundPublishBloc();
    authService = _MockAuthService();
    publishStream = StreamController<BackgroundPublishState>.broadcast();
  });

  tearDown(() {
    publishStream.close();
  });

  /// Stubs [publishBloc] with the given initial state and stream.
  void stubPublishBloc(BackgroundPublishState initial) {
    when(() => publishBloc.state).thenReturn(initial);
    whenListen(publishBloc, publishStream.stream, initialState: initial);
  }

  group('UploadFailureListener success tracking', () {
    testWidgets(
      'shows snackbar immediately when upload succeeds while authenticated',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Bloc emits a state with recentlySucceededIds populated (true success).
        publishStream.add(_succeededState('draft-1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets('shows plural snackbar when multiple uploads succeed', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );

      publishStream.add(_succeededState('draft-1', secondId: 'draft-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(2)), findsOneWidget);
    });

    testWidgets('shows the confirmation sheet on the treatment arm', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
        ),
      );

      publishStream.add(_succeededState('draft-treatment'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.postPublishConfirmationTitle), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationView), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationShare), findsOneWidget);
      // The sheet replaces the snackbar rather than stacking on it.
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);
    });

    testWidgets('view opens the published video over the profile', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final router = _routerAt(_ownProfileLocation);
      final experiment = await _treatmentExperiment('draft-treatment');

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: router,
        ),
      );

      publishStream.add(_succeededState('draft-treatment'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).postPublishConfirmationView,
        ),
      );
      await tester.pumpAndSettle();

      // `push`, not `go`: closing the video must pop back to the profile the
      // creator was standing on, not reset to the feed.
      verify(
        () => router.push<void>(
          RoutePaths.videoDetailForId(_publishedStableId),
        ),
      ).called(1);
      verifyNever(() => router.go(any()));
    });

    testWidgets('falls back to the snackbar once the user has moved on', (
      tester,
    ) async {
      // The publish lands in the background and can arrive minutes later. A
      // modal sheet over the feed is an ambush; the snackbar is not.
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(RoutePaths.videoFeedForIndex(0)),
        ),
      );

      publishStream.add(_succeededState('draft-treatment'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('falls back to the snackbar when the video has no d tag', (
      tester,
    ) async {
      // Without a stable id there is nothing to view or share, so the sheet
      // would offer two dead buttons.
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
        ),
      );

      publishStream.add(_succeededState('draft-treatment', stableId: null));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('falls back to the snackbar when a batch lands at once', (
      tester,
    ) async {
      // The sheet previews and navigates to one video; two have no correct
      // single target.
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = await _treatmentExperiment('draft-treatment');

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
        ),
      );

      publishStream.add(
        _succeededState('draft-treatment', secondId: 'draft-2'),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(2)), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('the control arm keeps a snackbar with no action', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_ownHex);
      final experiment = PostPublishExperiment(analytics: _NoOpAnalytics());
      await experiment.screenShown(
        publishId: 'draft-control',
        destination: 'profile',
        variant: PostPublishVariant.control,
      );

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          experiment: experiment,
          router: _routerAt(_ownProfileLocation),
        ),
      );

      publishStream.add(_succeededState('draft-control'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      expect(find.text(l10n.postPublishConfirmationTitle), findsNothing);
      expect(find.byType(SnackBarAction), findsNothing);
    });

    testWidgets(
      'buffers success while unauthenticated then flushes on re-auth',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Upload succeeds while user is NOT authenticated.
        publishStream.add(_succeededState('draft-2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        // No snackbar yet — auth is not restored.
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

        // Auth is now restored. Emit another state to trigger the listener.
        when(() => authService.isAuthenticated).thenReturn(true);
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        // Buffered success must now be flushed.
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets('keeps buffered success when root navigator is unavailable', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          wireRootNavigatorKey: false,
        ),
      );

      publishStream.add(_succeededState('draft-buffered'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

      when(() => authService.isAuthenticated).thenReturn(true);
      publishStream.add(const BackgroundPublishState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );
      publishStream.add(const BackgroundPublishState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
    });

    testWidgets(
      'buffers success shown while authenticated when root navigator is '
      'unavailable, then replays it once the context appears',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(
            publishBloc: publishBloc,
            authService: authService,
            wireRootNavigatorKey: false,
          ),
        );

        // Success arrives while authenticated, but the root navigator
        // context is unavailable — the snackbar cannot be shown yet.
        publishStream.add(_succeededState('draft-authed-no-root'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

        // Root navigator context appears; the buffered success replays on
        // the next state emission.
        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw or show snackbar when root navigator is unavailable',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(
            publishBloc: publishBloc,
            authService: authService,
            wireRootNavigatorKey: false,
          ),
        );

        publishStream.add(_succeededState('draft-no-root'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);
      },
    );

    testWidgets(
      'buffers the success when the root context resolves neither app '
      'ancestor, then replays it once they appear',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarnessWithoutAppAncestors(
            publishBloc: publishBloc,
            authService: authService,
          ),
        );

        publishStream.add(_succeededState('draft-no-l10n'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

        // Failing closed must hand the count back, not swallow it: once the
        // ancestors resolve, the buffered success replays on the next state.
        // The key is detached first so the root navigator is rebuilt under
        // [MaterialApp] rather than reparented with its ancestor-less route.
        await tester.pumpWidget(
          _buildHarness(
            publishBloc: publishBloc,
            authService: authService,
            wireRootNavigatorKey: false,
          ),
        );
        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets('does not duplicate snackbar for replayed success state', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );

      final succeeded = _succeededState('draft-replayed');
      publishStream.add(succeeded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      publishStream.add(succeeded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
    });

    testWidgets(
      'does not show snackbar when upload vanishes via BackgroundPublishVanished',
      (tester) async {
        // BackgroundPublishVanished emits a state with an empty
        // recentlySucceededIds — no success signal should be shown.
        stubPublishBloc(
          BackgroundPublishState(uploads: [_inProgress('draft-vanish')]),
        );
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Upload vanishes — draft removed from state but no success signal.
        publishStream.add(_vanishedState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // No snackbar must appear for a vanished upload.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);
        expect(find.text(l10n.uploadPublishedCountMessage(2)), findsNothing);
      },
    );
  });
}
