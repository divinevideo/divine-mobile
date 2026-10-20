// ABOUTME: Per-person triage controls exercise real message storage.
// ABOUTME: Read/dismiss preserve messages and never accept the request.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/widgets/conversation_triage_bar.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  final owner = 'a' * 64;
  final peer = 'b' * 64;
  final id = 'c' * 64;
  late AppDatabase database;
  late DmRepository repository;
  var protectPeer = false;

  setUp(() async {
    protectPeer = false;
    database = AppDatabase.test(NativeDatabase.memory());
    repository = DmRepository(
      nostrClient: createMockNostrService(),
      directMessagesDao: database.directMessagesDao,
      conversationsDao: database.conversationsDao,
      userPubkey: owner,
      removalPolicy: (key) => protectPeer && key == peer,
    );
    await database.conversationsDao.upsertConversation(
      id: id,
      participantPubkeys: '["$owner","$peer"]',
      isGroup: false,
      createdAt: 100,
      lastMessageTimestamp: 101,
      ownerPubkey: owner,
      isRead: false,
    );
    await database.directMessagesDao.insertMessage(
      id: 'd' * 64,
      conversationId: id,
      senderPubkey: peer,
      content: 'Keep this message',
      createdAt: 101,
      giftWrapId: 'e' * 64,
      ownerPubkey: owner,
    );
    // Match the page's resolved-repository boundary before widget fake async.
    await repository.getConversations();
  });

  tearDown(() async {
    await repository.stopListening();
    await database.close();
  });

  Widget subject() => testMaterialApp(
    mockAuthService: createMockAuthService(currentPublicKeyHex: owner),
    additionalOverrides: [dmRepositoryProvider.overrideWithValue(repository)],
    home: Scaffold(
      body: ConversationTriageBar(
        conversationId: id,
        participantPubkeys: [peer],
      ),
    ),
  );

  group('renders and interactions', () {
    testWidgets('protected notices offer read without dismissal', (
      tester,
    ) async {
      protectPeer = true;
      await tester.pumpWidget(subject());
      expect(find.text('Mark as read'), findsOneWidget);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('dismiss keeps history and returns to the inbox', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/thread',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Inbox')),
            routes: [
              GoRoute(
                path: 'thread',
                builder: (_, _) => Scaffold(
                  body: ConversationTriageBar(
                    conversationId: id,
                    participantPubkeys: [peer],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(currentPublicKeyHex: owner),
          additionalOverrides: [
            dmRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.runAsync(
        () => database.conversationsDao.getConversation(id, ownerPubkey: owner),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      final row = await tester.runAsync(() => repository.getConversation(id));
      expect(row!.isDismissed, isTrue);
      expect(row.isRead, isTrue);
      expect(row.currentUserHasSent, isFalse);
      expect(
        await tester.runAsync(() => repository.getMessages(id)),
        hasLength(1),
      );
    });

    testWidgets('mark as read affects only this thread without accepting it', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.tap(find.text('Mark as read'));
      await tester.runAsync(() async {
        // The Drift write runs on the native executor outside fake async.
        await database.conversationsDao.getConversation(id, ownerPubkey: owner);
      });
      await tester.pumpAndSettle();
      final row = await tester.runAsync(() => repository.getConversation(id));
      expect(row!.isRead, isTrue);
      expect(row.currentUserHasSent, isFalse);
      expect(row.isDismissed, isFalse);
      expect(
        await tester.runAsync(() => repository.getMessages(id)),
        hasLength(1),
      );
      expect(find.text('Marked as read'), findsOneWidget);
    });
  });
}
