// ABOUTME: Tests for FindPeopleSheet widget
// ABOUTME: Validates rendering, search states, user selection, and hasVideos
// ABOUTME: regression guard

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(SearchCancellationToken('test-search'));
  });

  group(FindPeopleSheet, () {
    const currentUserPubkey =
        'facade00facade00facade00facade00facade00facade00facade00facade00';
    late _MockProfileRepository mockProfileRepo;

    setUp(() {
      mockProfileRepo = _MockProfileRepository();
    });

    Widget createTestWidget({
      List<ShareableUser> contacts = const [],
      Duration? searchTimeout = const Duration(seconds: 20),
      List<Override> extraOverrides = const [],
    }) {
      return testMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<ShareableUser>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    // The real sheet gets its bounded height from
                    // VineBottomSheet's DraggableScrollableSheet; these
                    // content tests supply their own so the Expanded
                    // result list has something to fill.
                    builder: (context) => SizedBox(
                      height: 600,
                      child: FindPeopleSheet(
                        contacts: contacts,
                        currentUserPubkey: currentUserPubkey,
                        searchTimeout: searchTimeout,
                      ),
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            );
          },
        ),
        additionalOverrides: [
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
          profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
          ...extraOverrides,
        ],
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(searchTimeout: null));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
    }

    group('rendering', () {
      testWidgets('renders search field with "Find people" hint text', (
        tester,
      ) async {
        await openSheet(tester);

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Find people'), findsOneWidget);
      });

      testWidgets('renders "No contacts found" when follow list is empty', (
        tester,
      ) async {
        await openSheet(tester);

        expect(
          find.text(
            'No contacts found.\nStart following people to see them here.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders contact list when contacts are loaded', (
        tester,
      ) async {
        final pubkey = 'a' * 64;
        final contacts = [ShareableUser(pubkey: pubkey, displayName: 'Alice')];

        await tester.pumpWidget(
          createTestWidget(contacts: contacts, searchTimeout: null),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });

      testWidgets('renders the handle under a contact that has one', (
        tester,
      ) async {
        final contacts = [
          ShareableUser(
            pubkey: 'a' * 64,
            displayName: 'Alice',
            handle: '@alice',
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(contacts: contacts, searchTimeout: null),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('@alice'), findsOneWidget);
      });

      testWidgets('renders no npub for a contact without a handle', (
        tester,
      ) async {
        final contacts = [
          ShareableUser(pubkey: 'a' * 64, displayName: 'Alice'),
        ];

        await tester.pumpWidget(
          createTestWidget(contacts: contacts, searchTimeout: null),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.textContaining('npub'), findsNothing);
        expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
      });
    });

    group('search states', () {
      testWidgets('shows loading indicator when search is in progress', (
        tester,
      ) async {
        // Use a StreamController to control when results arrive
        final controller = StreamController<ProgressiveSearchResult>();
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer((_) => controller.stream);

        await openSheet(tester);

        // Type a search query
        await tester.enterText(find.byType(TextField), 'alice');
        // Wait for debounce (300ms) + some processing
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Close the stream to avoid pending timer errors
        controller.add(
          const ProgressiveSearchResult(
            profiles: [],
            sources: {},
            isComplete: true,
          ),
        );
        await controller.close();
        await tester.pumpAndSettle();
      });

      testWidgets('shows search results when search succeeds with results', (
        tester,
      ) async {
        final pubkey = 'b' * 64;
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ProgressiveSearchResult(
              profiles: [
                UserProfile(
                  pubkey: pubkey,
                  displayName: 'Bob',
                  picture: 'https://example.com/bob.jpg',
                  createdAt: DateTime.now(),
                  eventId: 'event-$pubkey',
                  rawData: const {'display_name': 'Bob'},
                ),
              ],
              sources: const {},
              isComplete: true,
            ),
          ),
        );

        await openSheet(tester);

        await tester.enterText(find.byType(TextField), 'bob');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Bob'), findsOneWidget);
      });

      testWidgets('does not offer the viewer in search results', (
        tester,
      ) async {
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ProgressiveSearchResult(
              profiles: [
                UserProfile(
                  pubkey: currentUserPubkey.toUpperCase(),
                  displayName: 'Me',
                  createdAt: DateTime.now(),
                  eventId: 'event-$currentUserPubkey',
                  rawData: const {'display_name': 'Me'},
                ),
                UserProfile(
                  pubkey: 'b' * 64,
                  displayName: 'Bob',
                  createdAt: DateTime.now(),
                  eventId: 'event-${'b' * 64}',
                  rawData: const {'display_name': 'Bob'},
                ),
              ],
              sources: const {},
              isComplete: true,
            ),
          ),
        );

        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'me');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Me'), findsNothing);
        expect(find.text('Bob'), findsOneWidget);
      });

      testWidgets('shows the full nip05 handle for a search result', (
        tester,
      ) async {
        final pubkey = 'b' * 64;
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ProgressiveSearchResult(
              profiles: [
                UserProfile(
                  pubkey: pubkey,
                  displayName: 'Bob',
                  nip05: 'bob@divine.video',
                  createdAt: DateTime.now(),
                  eventId: 'event-$pubkey',
                  rawData: const {'display_name': 'Bob'},
                ),
              ],
              sources: const {},
              isComplete: true,
            ),
          ),
        );

        await openSheet(tester);

        await tester.enterText(find.byType(TextField), 'bob');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('@bob.divine.video'), findsOneWidget);
        expect(find.textContaining('npub'), findsNothing);
      });

      testWidgets('shows an external nip05 without a doubled @', (
        tester,
      ) async {
        final pubkey = 'd' * 64;
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ProgressiveSearchResult(
              profiles: [
                UserProfile(
                  pubkey: pubkey,
                  displayName: 'Dana',
                  nip05: 'dana@nostrplebs.com',
                  createdAt: DateTime.now(),
                  eventId: 'event-$pubkey',
                  rawData: const {'display_name': 'Dana'},
                ),
              ],
              sources: const {},
              isComplete: true,
            ),
          ),
        );

        await openSheet(tester);

        await tester.enterText(find.byType(TextField), 'dana');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('dana@nostrplebs.com'), findsOneWidget);
      });

      testWidgets(
        'shows "No users found" when search succeeds with empty results',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              cancellationToken: any(named: 'cancellationToken'),
            ),
          ).thenAnswer(
            (_) => Stream.value(
              const ProgressiveSearchResult(
                profiles: [],
                sources: {},
                isComplete: true,
              ),
            ),
          );

          await openSheet(tester);

          await tester.enterText(find.byType(TextField), 'nonexistent');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(find.text('No users found'), findsOneWidget);
        },
      );

      testWidgets('shows "Search failed" when search fails', (tester) async {
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) =>
              Stream<ProgressiveSearchResult>.error(Exception('Network error')),
        );

        await openSheet(tester);

        await tester.enterText(find.byType(TextField), 'error');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Search failed. Please try again.'), findsOneWidget);
      });

      testWidgets('returns to contact list when search is cleared', (
        tester,
      ) async {
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            const ProgressiveSearchResult(
              profiles: [],
              sources: {},
              isComplete: true,
            ),
          ),
        );

        await openSheet(tester);

        // Type something
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('No users found'), findsOneWidget);

        // Clear the search
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // Should return to contacts (empty state in this case)
        expect(
          find.text(
            'No contacts found.\nStart following people to see them here.',
          ),
          findsOneWidget,
        );
      });
    });

    group('user selection', () {
      testWidgets(
        'tapping a contact pops the sheet with the selected $ShareableUser',
        (tester) async {
          final pubkey = 'c' * 64;
          final contact = ShareableUser(pubkey: pubkey, displayName: 'Charlie');

          ShareableUser? result;
          await tester.pumpWidget(
            testMaterialApp(
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        result = await FindPeopleSheet.show(
                          context,
                          contacts: [contact],
                          currentUserPubkey: currentUserPubkey,
                        );
                      },
                      child: const Text('Open Sheet'),
                    ),
                  );
                },
              ),
              additionalOverrides: [
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                profileReadRepositoryProvider.overrideWithValue(
                  mockProfileRepo,
                ),
              ],
            ),
          );

          // Open the sheet
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          // The sheet ships the design-system chrome, not a bare modal.
          expect(find.byType(VineBottomSheet), findsOneWidget);

          // Tap the contact
          await tester.tap(find.text('Charlie'));
          await tester.pumpAndSettle();

          expect(result, isNotNull);
          expect(result!.pubkey, equals(pubkey));
          expect(result!.displayName, equals('Charlie'));
        },
      );
    });

    group('integration', () {
      testWidgets('dragging the contacts list drags the sheet with it', (
        tester,
      ) async {
        final contacts = [
          for (var index = 0; index < 20; index++)
            ShareableUser(
              pubkey: '$index'.padLeft(64, '0'),
              displayName: 'User $index',
            ),
        ];

        await tester.pumpWidget(
          testMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => FindPeopleSheet.show(
                    context,
                    contacts: contacts,
                    currentUserPubkey: currentUserPubkey,
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
            additionalOverrides: [
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
            ],
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final sheet = find.byType(VineBottomSheet);
        final topBeforeDrag = tester.getRect(sheet).top;

        await tester.drag(find.text('User 0'), const Offset(0, 200));
        await tester.pumpAndSettle();

        // Without the enclosing sheet's ScrollController the drag would be
        // swallowed by the list's own (already at offset 0) and the sheet
        // would stay put.
        expect(tester.getRect(sheet).top, greaterThan(topBeforeDrag));
      });

      testWidgets(
        'creates UserSearchBloc with hasVideos: false (regression guard)',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              cancellationToken: any(named: 'cancellationToken'),
            ),
          ).thenAnswer(
            (_) => Stream.value(
              const ProgressiveSearchResult(
                profiles: [],
                sources: {},
                isComplete: true,
              ),
            ),
          );

          await openSheet(tester);

          // Type a search query to trigger the bloc
          await tester.enterText(find.byType(TextField), 'test');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          // Verify searchUsersProgressive was called WITHOUT hasVideos
          // (hasVideos: false means the parameter is not passed to the API)
          verify(
            () => mockProfileRepo.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              cancellationToken: any(named: 'cancellationToken'),
            ),
          ).called(1);
        },
      );
    });

    // #8421: Find People routes straight into DmRepository.sendMessage, and
    // its search reaches third-party NIP-50 relays a NIP-62 vanish addressed
    // elsewhere never obliged to forget. So a deleted account's kind 0 does
    // come back here, and the row must not present it as an identity.
    group('DM peer identity', () {
      const vanishedPubkey =
          'b75b9a3131f4263add94ba20beb352a11032684f2dac07a7e1af827c6f3c1505';

      Future<void> openWith(
        WidgetTester tester, {
        required ShareableUser contact,
        bool isVanished = false,
      }) async {
        await tester.pumpWidget(
          createTestWidget(
            contacts: [contact],
            searchTimeout: null,
            extraOverrides: [
              profileVanishedProvider(
                contact.pubkey,
              ).overrideWith((ref) => isVanished),
            ],
          ),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();
      }

      testWidgets('names a vanished peer "Deleted account"', (tester) async {
        await openWith(
          tester,
          contact: const ShareableUser(
            pubkey: vanishedPubkey,
            displayName: 'Aeontropy',
            handle: '@aeontropy',
          ),
          isVanished: true,
        );

        expect(find.text('Deleted account'), findsOneWidget);
        expect(find.text('Aeontropy'), findsNothing);
      });

      testWidgets("hides a vanished peer's handle, which identifies them too", (
        tester,
      ) async {
        await openWith(
          tester,
          contact: const ShareableUser(
            pubkey: vanishedPubkey,
            displayName: 'Aeontropy',
            handle: '@aeontropy',
          ),
          isVanished: true,
        );

        expect(find.text('@aeontropy'), findsNothing);
      });

      testWidgets('gives the moderation account its bundled wordmark and '
          'shared name', (tester) async {
        await openWith(
          tester,
          contact: const ShareableUser(
            pubkey: kModerationPubkeyHex,
            displayName: 'moderation-bot-v2',
          ),
        );

        expect(find.byType(ModerationAvatar), findsOneWidget);
        expect(find.text('Divine Moderation'), findsOneWidget);
        expect(find.text('moderation-bot-v2'), findsNothing);
      });

      testWidgets('hands the resolved identity on, so the share sheet cannot '
          'name the peer differently', (tester) async {
        const contact = ShareableUser(
          pubkey: vanishedPubkey,
          displayName: 'Aeontropy',
          handle: '@aeontropy',
          picture: 'https://example.invalid/a.png',
        );
        ShareableUser? result;

        await tester.pumpWidget(
          testMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await FindPeopleSheet.show(
                      context,
                      contacts: const [contact],
                      currentUserPubkey: currentUserPubkey,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
            additionalOverrides: [
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileVanishedProvider(
                vanishedPubkey,
              ).overrideWith((ref) => true),
            ],
          ),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Deleted account'));
        await tester.pumpAndSettle();

        expect(result?.displayName, 'Deleted account');
        expect(result?.handle, isNull);
        expect(result?.picture, isNull);
      });
    });
  });
}
