// ABOUTME: Covers announcement route catalog resolution and withdrawal.
// ABOUTME: Route extras never supply trusted official announcement content.

import 'dart:async';

import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/announcement_detail_screen.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/announcement_routes.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockAnnouncementsRepository extends Mock
    implements AnnouncementsRepository {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  AnnouncementNotification item(String id, String title) =>
      AnnouncementNotification(
        announcementId: id,
        title: title,
        body: 'A current message from the catalog.',
        timestamp: DateTime.utc(2026, 10, 23),
        expiresAt: DateTime.utc(2026, 11, 23),
      );

  Future<void> pump(
    WidgetTester tester,
    GoRouter router,
    NotificationRepository? repository, {
    List<Override> overrides = const [],
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );

  group('navigation', () {
    test('typed location preserves the encoded announcement ID', () {
      const id = 'announcement:a/b c';
      expect(
        const AnnouncementDetailRouteData(id: id).location,
        AnnouncementDetailScreen.pathForId(id),
      );
      final route = announcementRoutes().single as GoRoute;
      expect(route.path, AnnouncementDetailScreen.path);
      expect(route.name, AnnouncementDetailScreen.routeName);
    });

    testWidgets('cold route ignores untrusted extras when catalog is absent', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('missing'),
        initialExtra: item('missing', 'Untrusted route content'),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      await pump(tester, router, null);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Untrusted route content'), findsNothing);
      expect(find.text(l10n.announcementUnavailable), findsNothing);
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
    });

    testWidgets('back from a cold entry falls back to notifications', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('missing'),
        routes: [
          ...announcementRoutes(),
          GoRoute(
            path: NotificationsPage.pathWithIndex,
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pump(tester, router, null);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.bySemanticsIdentifier(DiVineAppBarLeading.backButtonSemanticId),
      );
      await tester.pumpAndSettle();

      expect(
        router.state.uri.path,
        equals(RoutePaths.notificationsForIndex(0)),
      );
      expect(find.byType(AnnouncementDetailScreen), findsNothing);
    });

    testWidgets('catalog hydration resolves detail and withdrawal clears it', (
      tester,
    ) async {
      final snapshots =
          StreamController<List<AnnouncementNotification>>.broadcast();
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      final announcement = item('current', 'Current announcement');
      final refresh = Completer<bool>();
      List<AnnouncementNotification>? catalog;
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.hasCatalog).thenAnswer((_) => catalog != null);
      when(() => announcements.items).thenAnswer((_) => catalog ?? const []);
      when(announcements.refresh).thenAnswer((_) => refresh.future);
      when(announcements.watchSnapshot).thenAnswer((_) => snapshots.stream);
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('current'),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      addTearDown(snapshots.close);
      await pump(tester, router, repository);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text(l10n.announcementUnavailable),
        findsNothing,
      );

      verify(announcements.refresh).called(1);
      catalog = [announcement];
      snapshots.add([announcement]);
      refresh.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Current announcement'), findsOneWidget);

      catalog = const [];
      snapshots.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Current announcement'), findsNothing);
      expect(
        find.text(l10n.announcementUnavailable),
        findsOneWidget,
      );
    });

    testWidgets('a failed cold lookup allows retry before confirming absence', (
      tester,
    ) async {
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      var hasCatalog = false;
      final retry = Completer<void>();
      var refreshCount = 0;
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.hasCatalog).thenAnswer((_) => hasCatalog);
      when(() => announcements.items).thenReturn(const []);
      when(announcements.refresh).thenAnswer((_) async {
        if (++refreshCount < 2) return false;
        await retry.future;
        return true;
      });
      when(announcements.watchSnapshot).thenAnswer(
        (_) => Stream.value(const []),
      );
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('missing'),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      await pump(tester, router, repository);
      await tester.pumpAndSettle();

      expect(find.text(l10n.announcementUnavailable), findsNothing);
      expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.announcementUnavailable), findsNothing);

      hasCatalog = true;
      retry.complete();
      await tester.pumpAndSettle();
      expect(refreshCount, 2);
      expect(find.text(l10n.announcementUnavailable), findsOneWidget);
    });

    testWidgets('changing the route ID resolves the new catalog item', (
      tester,
    ) async {
      final first = item('first', 'First announcement');
      final second = item('second', 'Second announcement');
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.hasCatalog).thenReturn(true);
      when(() => announcements.items).thenReturn([first, second]);
      when(announcements.refresh).thenAnswer((_) async => true);
      when(announcements.watchSnapshot).thenAnswer(
        (_) => const Stream<List<AnnouncementNotification>>.empty(),
      );
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('first'),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      await pump(tester, router, repository);
      await tester.pumpAndSettle();
      expect(find.text('First announcement'), findsOneWidget);

      router.go(AnnouncementDetailScreen.pathForId('second'));
      await tester.pumpAndSettle();
      expect(find.text('Second announcement'), findsOneWidget);
      expect(find.text('First announcement'), findsNothing);
    });
  });

  group('actions', () {
    const id = 'with-action';
    const updateToTwo = UpdateAppAnnouncementAction(
      platform: 'android',
      channel: 'google_play',
      version: '2.0.0',
    );

    Future<void> pumpAction(
      WidgetTester tester,
      AnnouncementAction action, {
      String installedVersion = '1.0.0',
    }) async {
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.hasCatalog).thenReturn(true);
      when(() => announcements.items).thenReturn([
        AnnouncementNotification(
          announcementId: id,
          title: 'Announcement with an action',
          body: 'A current message from the catalog.',
          timestamp: DateTime.utc(2026, 10, 23),
          expiresAt: DateTime.utc(2026, 11, 23),
          action: action,
        ),
      ]);
      when(announcements.refresh).thenAnswer((_) async => true);
      when(announcements.watchSnapshot).thenAnswer(
        (_) => const Stream<List<AnnouncementNotification>>.empty(),
      );
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId(id),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      await pump(
        tester,
        router,
        repository,
        overrides: [
          installSourceProvider.overrideWithValue(InstallSource.playStore),
          appVersionProvider.overrideWithValue(installedVersion),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a contest action offers to view the contest', (tester) async {
      await pumpAction(
        tester,
        ContestAnnouncementAction(
          url: Uri.parse('https://divine-challenges.pages.dev/contests/spring'),
        ),
      );

      expect(
        find.widgetWithText(DivineButton, l10n.announcementViewContest),
        findsOneWidget,
      );
      expect(find.text(l10n.updateAction), findsNothing);
    });

    testWidgets('an update action offers to update an older matching install', (
      tester,
    ) async {
      await pumpAction(tester, updateToTwo);

      expect(
        find.widgetWithText(DivineButton, l10n.updateAction),
        findsOneWidget,
      );
      expect(find.text(l10n.announcementViewContest), findsNothing);
    });

    testWidgets('an update action is hidden from an install already on it', (
      tester,
    ) async {
      await pumpAction(tester, updateToTwo, installedVersion: '2.0.0');

      expect(find.text('Announcement with an action'), findsOneWidget);
      expect(find.text(l10n.updateAction), findsNothing);
    });
  });
}
