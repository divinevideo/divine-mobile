// ABOUTME: Widget tests for RequestPreviewPage.
// ABOUTME: Verifies route constants and that it renders RequestPreviewView
// ABOUTME: with RequestPreviewCubit and MessageRequestActionsCubit provided.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockOfficials extends Mock implements OfficialAccountsService {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group(RequestPreviewPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;
    late _MockOfficials mockOfficials;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockGoRouter = MockGoRouter();
      mockOfficials = _MockOfficials();

      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      when(
        () => mockDmRepository.countMessagesInConversation(any()),
      ).thenAnswer((_) async => 3);
      when(
        () => mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => const []);
      when(
        () => mockDmRepository.getConversation(any()),
      ).thenAnswer((_) async => null);

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    test('has correct route constants', () {
      expect(RequestPreviewPage.routeName, equals('requestPreview'));
      expect(
        RequestPreviewPage.pathPattern,
        equals('/inbox/message-requests/:id'),
      );
    });

    group('renders', () {
      testWidgets('renders $RequestPreviewView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const RequestPreviewPage(
              conversationId: conversationId,
              participantPubkeys: [otherPubkey],
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              goRouterProvider.overrideWithValue(mockGoRouter),
              isDmRestrictedProvider.overrideWithValue(false),
              officialAccountsServiceProvider.overrideWithValue(mockOfficials),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(RequestPreviewView), findsOneWidget);
      });
    });

    group('protected-minor gate (#176)', () {
      testWidgets(
        'a DM-restricted user with a non-approved counterparty is bounced '
        'to the inbox before any request data renders',
        (tester) async {
          when(
            () => mockOfficials.isReadableByProtectedMinor(any()),
          ).thenReturn(false);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                  participantPubkeys: [otherPubkey],
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          verify(() => mockGoRouter.go(InboxPage.path)).called(1);
          // No hidden request metadata was read for the denied preview.
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
        },
      );

      testWidgets(
        'a DM-restricted user landing via direct link (no route extras) is '
        'bounced to the inbox without the conversation being read',
        (tester) async {
          when(
            () => mockOfficials.isReadableByProtectedMinor(any()),
          ).thenReturn(true);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          verify(() => mockGoRouter.go(InboxPage.path)).called(1);
          // Resolving counterparties from the DB is itself a hidden-data
          // read, so the denied direct-link path must not touch the repo.
          verifyNever(() => mockDmRepository.getConversation(any()));
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
          verifyNever(
            () => mockDmRepository.getMessages(
              any(),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      testWidgets(
        'a DM-restricted user with an approved counterparty sees the preview',
        (tester) async {
          when(
            () => mockOfficials.isReadableByProtectedMinor(otherPubkey),
          ).thenReturn(true);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                  participantPubkeys: [otherPubkey],
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          expect(find.byType(RequestPreviewView), findsOneWidget);
          verifyNever(() => mockGoRouter.go(any()));
        },
      );
    });

    group('repository identity', () {
      testWidgets(
        'rebuilds $RequestPreviewCubit when the DM repository identity '
        'changes',
        (tester) async {
          // `dmRepositoryProvider` returns a brand-new owner-scoped repository
          // for `identityKnown`, then a credentialed one once the session is
          // ready. The
          // preview's `load()` runs once at construction, so the provider
          // must be re-keyed or it keeps reading through the first instance
          // forever. See #8187.
          final readyRepository = _MockDmRepository();
          when(() => readyRepository.userPubkey).thenReturn(testPubkey);
          when(
            () => readyRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 7);
          when(
            () =>
                readyRepository.getMessages(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => const []);
          when(
            () => readyRepository.getConversation(any()),
          ).thenAnswer((_) async => null);

          final activeRepository = StateProvider<DmRepository>(
            (ref) => mockDmRepository,
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: const RequestPreviewPage(
                conversationId: conversationId,
                participantPubkeys: [otherPubkey],
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWith(
                  (ref) => ref.watch(activeRepository),
                ),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(false),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          verify(
            () => mockDmRepository.countMessagesInConversation(conversationId),
          ).called(1);

          ProviderScope.containerOf(
            tester.element(find.byType(RequestPreviewView)),
          ).read(activeRepository.notifier).state = readyRepository;
          await tester.pump();
          await tester.pump();

          verify(
            () => readyRepository.countMessagesInConversation(conversationId),
          ).called(1);
        },
      );
    });

    group('page reuse across an in-place id change', () {
      // Same shape as ConversationPage's conversationId keying: go_router
      // 18.0.1 keys a declarative page by the route PATTERN, not the matched
      // id (`match.dart:231` `pageKey: ValueKey<String>(newMatchedPath)`), so
      // two consecutive `go()`s to different `/inbox/message-requests/:id`
      // URLs can reuse this exact element. Modelled here with a
      // ValueListenableBuilder rebuilding the SAME RequestPreviewPage
      // element with a new id, independent of go_router itself.
      testWidgets(
        'shows the new request, not the previous one, after an in-place id '
        'change reuses this element',
        (tester) async {
          const conversationIdB =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

          when(
            () => mockDmRepository.countMessagesInConversation(conversationId),
          ).thenAnswer((_) async => 3);
          when(
            () => mockDmRepository.countMessagesInConversation(conversationIdB),
          ).thenAnswer((_) async => 9);

          final currentConversationId = ValueNotifier<String>(conversationId);
          addTearDown(currentConversationId.dispose);

          await tester.pumpWidget(
            testMaterialApp(
              // The SAME RequestPreviewPage element is rebuilt with a new
              // conversationId, exactly like go_router reusing a
              // pattern-keyed page across two different matched ids.
              home: ValueListenableBuilder<String>(
                valueListenable: currentConversationId,
                builder: (context, id, _) => RequestPreviewPage(
                  conversationId: id,
                  participantPubkeys: const [otherPubkey],
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(false),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          final l10n = lookupAppLocalizations(const Locale('en'));

          verify(
            () => mockDmRepository.countMessagesInConversation(conversationId),
          ).called(1);
          expect(
            find.textContaining(l10n.messageRequestMessageCount(3)),
            findsOneWidget,
          );

          currentConversationId.value = conversationIdB;
          await tester.pump();
          await tester.pump();

          verify(
            () => mockDmRepository.countMessagesInConversation(conversationIdB),
          ).called(1);
          expect(
            find.textContaining(l10n.messageRequestMessageCount(9)),
            findsOneWidget,
            reason:
                "the reused element must load the NEW id's data, not keep "
                'showing the previous request',
          );
          expect(
            find.textContaining(l10n.messageRequestMessageCount(3)),
            findsNothing,
          );
        },
      );
    });
  });
}
