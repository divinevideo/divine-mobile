// ABOUTME: Widget tests for ConversationPage, verifying BLoC setup and
// ABOUTME: route constants. Ensures ConversationPage provides ConversationBloc
// ABOUTME: to ConversationView via BlocProvider.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/minor_dm_approval.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/connection_status_service.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

/// The real service arms a 30s periodic timer in its constructor, which
/// would still be pending when the tree is torn down.
class _MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334455667788112233445566778811223344556677881122334455667788';
  const testConversationId =
      'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00';

  group(ConversationPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();

      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchOutgoing(any()),
      ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
      // Consumed by DmRestoreStatusCubit, which qualifies the empty state.
      when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
      when(() => mockDmRepository.hasAttemptedHistoryRecovery).thenReturn(true);
      when(
        () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(true);
      when(
        () => mockDmRepository.historyRecoveryStream,
      ).thenAnswer((_) => const Stream<bool>.empty());

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    test('has correct route constants', () {
      expect(ConversationPage.routeName, equals('conversation'));
      expect(ConversationPage.pathPattern, equals('/inbox/conversation/:id'));
      expect(
        ConversationPage.pathForId('abc'),
        equals('/inbox/conversation/abc'),
      );
    });

    group('allParticipantsApprovedForMinor (#176 route-guard predicate)', () {
      test('empty participant list fails closed, not vacuously approved', () {
        // `[].every(...)` is vacuously true; a protected minor must NOT be let
        // into a degenerate zero-counterparty thread. Must fail closed.
        expect(allParticipantsApprovedForMinor(const [], (_) => true), isFalse);
      });

      test('every counterparty approved -> allowed', () {
        expect(
          allParticipantsApprovedForMinor(const ['a', 'b'], (_) => true),
          isTrue,
        );
      });

      test('any non-approved counterparty -> blocked', () {
        expect(
          allParticipantsApprovedForMinor(const ['a', 'b'], (p) => p == 'a'),
          isFalse,
        );
      });
    });

    group('renders', () {
      // Only these tests pump the page and build a ConversationBloc, which
      // holds its loading state while the repository owner is unknown
      // (#8187). Declared here rather than in the shared setUp so the
      // dependency sits beside the tests that have it.
      setUp(() {
        when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      });

      testWidgets('renders $ConversationView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(ConversationView), findsOneWidget);
      });

      testWidgets('resolves the counterparty from the conversation row when '
          'the route carried no extra (deep link / browser refresh)', (
        tester,
      ) async {
        when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
        when(
          () => mockDmRepository.getConversation(testConversationId),
        ).thenAnswer(
          (_) async => DmConversation(
            id: testConversationId,
            participantPubkeys: const [testPubkey, otherPubkey],
            isGroup: false,
            createdAt: 1700000000,
          ),
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [],
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Without this the thread renders with no identity in its header and
        // an unaddressable send bar (#3335).
        final view = tester.widget<ConversationView>(
          find.byType(ConversationView),
        );
        expect(view.participantPubkeys, equals([otherPubkey]));
      });

      testWidgets('a DM-restricted user deep-linking without extras is '
          'bounced to the inbox and never reads the thread (#176)', (
        tester,
      ) async {
        when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
        final router = GoRouter(
          initialLocation: ConversationPage.pathForId(testConversationId),
          routes: [
            GoRoute(
              path: ConversationPage.pathPattern,
              builder: (_, _) => const ConversationPage(
                conversationId: testConversationId,
                participantPubkeys: [],
              ),
            ),
            GoRoute(
              path: InboxPage.path,
              builder: (_, _) => const Scaffold(body: Text('inbox')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          testProviderScope(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(true),
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ConversationView), findsNothing);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals(InboxPage.path),
        );
        // Resolving counterparties is itself a read of conversation data the
        // restricted user may not access, so the gate precedes the fallback.
        verifyNever(() => mockDmRepository.getConversation(any()));
      });

      testWidgets('ejects an already-open thread when the DM restriction '
          'flips mid-session (#176)', (tester) async {
        when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
        final restrictedFlag = StateProvider<bool>((ref) => false);
        final router = GoRouter(
          initialLocation: ConversationPage.pathForId(testConversationId),
          routes: [
            GoRoute(
              path: ConversationPage.pathPattern,
              builder: (_, _) => const ConversationPage(
                conversationId: testConversationId,
                participantPubkeys: [otherPubkey],
              ),
            ),
            GoRoute(
              path: InboxPage.path,
              builder: (_, _) => const Scaffold(body: Text('inbox')),
            ),
          ],
        );
        addTearDown(router.dispose);
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            // testProviderScope adds this one on top of the standard set; a
            // hand-rolled container has to mirror it or the real
            // VideoEventService builds its own ConnectionStatusService.
            videoEventServiceProvider.overrideWithValue(
              createMockVideoEventService(),
            ),
            connectionStatusServiceProvider.overrideWithValue(
              _MockConnectionStatusService(),
            ),
            isDmRestrictedProvider.overrideWith(
              (ref) => ref.watch(restrictedFlag),
            ),
            dmRepositoryProvider.overrideWithValue(mockDmRepository),
            fetchUserProfileProvider(
              otherPubkey,
            ).overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

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
        expect(find.byType(ConversationView), findsOneWidget);

        // The restriction resolves asynchronously and can land after the
        // thread is on screen; it must not survive the flip.
        container.read(restrictedFlag.notifier).state = true;
        // Discrete pumps rather than pumpAndSettle: the mounted DM machinery
        // arms a periodic timer that settling would leave pending at teardown.
        await tester.pump();
        await tester.pump();

        expect(find.byType(ConversationView), findsNothing);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals(InboxPage.path),
        );
      });
    });
  });
}
