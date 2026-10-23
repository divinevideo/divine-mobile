// ABOUTME: Covers announcement route catalog resolution and withdrawal.
// ABOUTME: Route extras never supply trusted official announcement content.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/announcement_detail_screen.dart';
import 'package:openvine/router/routes/announcement_routes.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockAnnouncementsRepository extends Mock
    implements AnnouncementsRepository {}

void main() {
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
    NotificationRepository? repository,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );

  group('navigation', () {
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
      await tester.pumpAndSettle();

      expect(find.text('Untrusted route content'), findsNothing);
      expect(
        find.text('This announcement is no longer available.'),
        findsOneWidget,
      );
    });

    testWidgets('catalog hydration resolves detail and withdrawal clears it', (
      tester,
    ) async {
      final snapshots =
          StreamController<List<AnnouncementNotification>>.broadcast();
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      final announcement = item('current', 'Current announcement');
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.items).thenReturn(const []);
      when(announcements.watchSnapshot).thenAnswer((_) => snapshots.stream);
      final router = GoRouter(
        initialLocation: AnnouncementDetailScreen.pathForId('current'),
        routes: announcementRoutes(),
      );
      addTearDown(router.dispose);
      addTearDown(snapshots.close);
      await pump(tester, router, repository);
      await tester.pumpAndSettle();
      expect(
        find.text('This announcement is no longer available.'),
        findsOneWidget,
      );

      snapshots.add([announcement]);
      await tester.pumpAndSettle();
      expect(find.text('Current announcement'), findsOneWidget);

      snapshots.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Current announcement'), findsNothing);
      expect(
        find.text('This announcement is no longer available.'),
        findsOneWidget,
      );
    });

    testWidgets('changing the route ID resolves the new catalog item', (
      tester,
    ) async {
      final first = item('first', 'First announcement');
      final second = item('second', 'Second announcement');
      final announcements = _MockAnnouncementsRepository();
      final repository = _MockNotificationRepository();
      when(() => repository.announcementsRepository).thenReturn(announcements);
      when(() => announcements.items).thenReturn([first, second]);
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
}
