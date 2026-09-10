// ABOUTME: Tests for UserPickerSheet widget
// ABOUTME: Verifies search functionality, local follow search, and user selection

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
// Riverpod 3 exports `Override` from `misc.dart`, not the main entry point.
import 'package:riverpod/misc.dart';
import 'package:rxdart/rxdart.dart';

/// Mock for ProfileRepository
class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

_MockContentBlocklistRepository _createMockContentBlocklistRepository({
  Set<String> blockedPubkeys = const {},
}) {
  final mock = _MockContentBlocklistRepository();
  when(() => mock.shouldFilterFromFeeds(any())).thenReturn(false);
  for (final pubkey in blockedPubkeys) {
    when(() => mock.shouldFilterFromFeeds(pubkey)).thenReturn(true);
  }
  return mock;
}

/// Create a mock ProfileRepository
_MockProfileRepository _createMockProfileRepository({
  List<UserProfile> searchResults = const [],
  List<UserProfile> cachedProfiles = const [],
}) {
  final mock = _MockProfileRepository();

  // Mock searchUsersProgressive (used by UserSearchBloc)
  when(
    () => mock.searchUsersProgressive(
      query: any(named: 'query'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      sortBy: any(named: 'sortBy'),
      hasVideos: any(named: 'hasVideos'),
      boostPubkeys: any(named: 'boostPubkeys'),
      cancellationToken: any(named: 'cancellationToken'),
    ),
  ).thenAnswer(
    (_) => Stream.value(
      ProgressiveSearchResult(
        profiles: searchResults,
        sources: const {},
        isComplete: true,
      ),
    ),
  );

  // Default for unknown pubkeys. Registered first so the per-profile stubs
  // below win — mocktail resolves to the most recently registered match.
  when(
    () => mock.getCachedProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);

  // Mock getCachedProfile
  for (final profile in cachedProfiles) {
    when(
      () => mock.getCachedProfile(pubkey: profile.pubkey),
    ).thenAnswer((_) async => profile);
  }

  // The batch lookup answers from the same per-pubkey stubs, so a test that
  // stubs a single profile gets it back through either entry point.
  when(() => mock.getCachedProfiles(pubkeys: any(named: 'pubkeys'))).thenAnswer(
    (invocation) async {
      final pubkeys = invocation.namedArguments[#pubkeys] as List<String>;
      final profiles = await Future.wait(
        pubkeys.map((pubkey) => mock.getCachedProfile(pubkey: pubkey)),
      );
      return profiles.whereType<UserProfile>().toList();
    },
  );

  return mock;
}

/// Create a mock FollowRepository
_MockFollowRepository _createMockFollowRepository({
  List<String> followingPubkeys = const [],
}) {
  final mock = _MockFollowRepository();
  when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  when(() => mock.followingStream).thenAnswer(
    (_) => BehaviorSubject<List<String>>.seeded(followingPubkeys).stream,
  );
  when(() => mock.isInitialized).thenReturn(true);
  when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  when(mock.getMyFollowers).thenAnswer((_) async => followingPubkeys);
  when(
    mock.streamMyFollowers,
  ).thenAnswer((_) => Stream.value(followingPubkeys));
  return mock;
}

/// No account carries a NIP-62 tombstone.
///
/// Every scope needs it: `UserPickerSheet` resolves each row's name and avatar
/// through `profileVanishedProvider`, which derives from this stream, and
/// without an override that reaches the real database.
// ignore: specify_nonobvious_property_types
final _noVanishedProfiles = _vanishedProfiles(const {});

/// [pubkeys] carry a tombstone; nothing else does.
Override _vanishedProfiles(Set<String> pubkeys) =>
    vanishedProfilePubkeysProvider.overrideWith((ref) => Stream.value(pubkeys));

void main() {
  setUpAll(() {
    registerFallbackValue(SearchCancellationToken('test-search'));
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group(UserPickerSheet, () {
    group('renders', () {
      testWidgets('header describes cancel and confirm actions', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  maxCount: 2,
                ),
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.userPickerCancelSemanticLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(l10n.userPickerConfirmSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('header offers confirm in uncapped multi-select too', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  // No maxCount: the caller tracks the selection itself, and
                  // still needs a way to say "done".
                  onUserToggled: (_) {},
                ),
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.userPickerConfirmSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('header describes clearing an existing selection', (
        tester,
      ) async {
        final selectedProfile = UserProfile(
          pubkey: 'selected-pubkey',
          name: 'Selected User',
          rawData: const {'name': 'Selected User'},
          createdAt: DateTime(2026),
          eventId: 'selected-event',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  initialSelectedProfiles: [selectedProfile],
                ),
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.userPickerClearSelectionSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('header offers nothing to clear when the only initial '
          'selection is the excluded viewer', (tester) async {
        const viewerPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final viewer = UserProfile(
          pubkey: viewerPubkey,
          name: 'Viewer',
          rawData: const {'name': 'Viewer'},
          createdAt: DateTime(2026),
          eventId: 'viewer-event',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  excludeViewerPubkey: viewerPubkey,
                  initialSelectedProfiles: [viewer],
                ),
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.userPickerClearSelectionSemanticLabel),
          findsNothing,
        );
      });

      testWidgets('search text field', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('search icon in text field', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.search,
          ),
          findsOneWidget,
        );
      });

      testWidgets('"Type a name to search" hint for allUsers mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Type a name to search'), findsOneWidget);
      });

      testWidgets('shows custom searchText in the header when provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  searchText: 'Mutual followers',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Mutual followers'), findsOneWidget);
      });
    });

    group('mutualFollowsOnly mode', () {
      testWidgets('excludes the viewer from self-following mutuals', (
        tester,
      ) async {
        const viewerPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final viewer = UserProfile(
          pubkey: viewerPubkey,
          name: 'Viewer',
          rawData: const {'name': 'Viewer'},
          createdAt: DateTime.now(),
          eventId: 'viewer-event',
        );
        final mutual = UserProfile(
          pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          name: 'Mutual',
          rawData: const {'name': 'Mutual'},
          createdAt: DateTime.now(),
          eventId: 'mutual-event',
        );
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [viewer.pubkey, mutual.pubkey],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [viewer, mutual]),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  excludeViewerPubkey: viewerPubkey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Viewer'), findsNothing);
        expect(find.text('Mutual'), findsOneWidget);
      });

      testWidgets('excludes the viewer case-insensitively', (tester) async {
        const viewerPubkey =
            'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';
        final viewer = UserProfile(
          pubkey: viewerPubkey,
          name: 'Viewer',
          rawData: const {'name': 'Viewer'},
          createdAt: DateTime.now(),
          eventId: 'viewer-event',
        );
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [viewer.pubkey],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [viewer]),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  excludeViewerPubkey: viewerPubkey.toUpperCase(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Viewer'), findsNothing);
      });

      testWidgets('excluded initial viewer does not consume a selection slot', (
        tester,
      ) async {
        const viewerPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final viewer = UserProfile(
          pubkey: viewerPubkey,
          name: 'Viewer',
          rawData: const {'name': 'Viewer'},
          createdAt: DateTime.now(),
          eventId: 'viewer-event',
        );
        final mutual = UserProfile(
          pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          name: 'Mutual',
          rawData: const {'name': 'Mutual'},
          createdAt: DateTime.now(),
          eventId: 'mutual-event',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [viewer, mutual]),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(
                  followingPubkeys: [viewer.pubkey, mutual.pubkey],
                ),
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  maxCount: 1,
                  excludeViewerPubkey: viewerPubkey,
                  initialSelectedProfiles: [viewer],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0/1 Title'), findsOneWidget);
        await tester.tap(find.text('Mutual'));
        await tester.pumpAndSettle();

        expect(find.text('1/1 Title'), findsOneWidget);
      });

      testWidgets('shows loading indicator until the first follower source '
          'answers', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1'],
        );
        // No source has answered yet.
        final followers = StreamController<List<String>>();
        // Not awaited: the widget is still listening at teardown, so the done
        // event would never be delivered and the test would hang.
        addTearDown(() => unawaited(followers.close()));
        when(
          mockFollowRepo.streamMyFollowers,
        ).thenAnswer((_) => followers.stream);

        final mockProfileRepo = _createMockProfileRepository(
          cachedProfiles: [
            UserProfile(
              pubkey: 'pubkey1',
              name: 'User One',
              rawData: const {'name': 'User One'},
              createdAt: DateTime.now(),
              eventId: 'event1',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Profiles are already resolved — the spinner is waiting on the
        // mutual check, not on the profile lookup.
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text('User One'), findsNothing);
      });

      testWidgets('shows empty state when no follows exist', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show empty follow list message
        expect(find.text('Your crew is out there'), findsOneWidget);
      });

      testWidgets('shows "Go back" button in empty state', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Go back'), findsOneWidget);
      });

      testWidgets('falls back to local follows when every follower source '
          'fails', (tester) async {
        final profile = UserProfile(
          pubkey: 'pubkey1',
          name: 'User One',
          rawData: const {'name': 'User One'},
          createdAt: DateTime.now(),
          eventId: 'event1',
        );

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1'],
        );
        when(mockFollowRepo.streamMyFollowers).thenAnswer(
          (_) => Stream<List<String>>.error(Exception('relay down')),
        );

        final mockProfileRepo = _createMockProfileRepository();
        when(
          () => mockProfileRepo.getCachedProfile(pubkey: 'pubkey1'),
        ).thenAnswer((_) async => profile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BrandedLoadingIndicator), findsNothing);
        expect(find.text('User One'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('result tile announces the action and the nip05 handle', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final profile = UserProfile(
          pubkey: 'pubkey1',
          name: 'User One',
          nip05: 'user.one@example.com',
          rawData: const {'name': 'User One', 'nip05': 'user.one@example.com'},
          createdAt: DateTime.now(),
          eventId: 'event1',
        );

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1'],
        );
        when(
          mockFollowRepo.streamMyFollowers,
        ).thenAnswer((_) => Stream<List<String>>.value(['pubkey1']));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [profile]),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final label = tester
            .getSemantics(find.text('User One'))
            .getSemanticsData()
            .label;

        expect(label, contains(l10n.userPickerSelectSemantics('User One')));
        // Two follows can share a display name; the handle is what tells
        // them apart, so it must survive the tile's ExcludeSemantics.
        expect(label, contains('user.one@example.com'));

        handle.dispose();
      });

      testWidgets('renders mutuals from the first follower source and adds '
          'later ones', (tester) async {
        final profiles = [
          UserProfile(
            pubkey: 'pubkey1',
            name: 'Fast User',
            rawData: const {'name': 'Fast User'},
            createdAt: DateTime.now(),
            eventId: 'event1',
          ),
          UserProfile(
            pubkey: 'pubkey2',
            name: 'Slow User',
            rawData: const {'name': 'Slow User'},
            createdAt: DateTime.now(),
            eventId: 'event2',
          ),
        ];

        final followers = StreamController<List<String>>();
        // Not awaited: the widget is still listening at teardown, so the done
        // event would never be delivered and the test would hang.
        addTearDown(() => unawaited(followers.close()));

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1', 'pubkey2'],
        );
        when(
          mockFollowRepo.streamMyFollowers,
        ).thenAnswer((_) => followers.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: profiles),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The fast source alone is enough to leave the spinner. Two pumps:
        // one to deliver the stream event, one to render the rebuild.
        followers.add(['pubkey1']);
        await tester.pump();
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsNothing);
        expect(find.text('Fast User'), findsOneWidget);
        expect(find.text('Slow User'), findsNothing);

        // A slower source only ever adds rows.
        followers.add(['pubkey1', 'pubkey2']);
        await tester.pump();
        await tester.pump();

        expect(find.text('Fast User'), findsOneWidget);
        expect(find.text('Slow User'), findsOneWidget);
      });

      testWidgets(
        'keeps the active filter when later follower sources add rows',
        (tester) async {
          final profiles = [
            UserProfile(
              pubkey: 'pubkey1',
              name: 'Fast User',
              rawData: const {'name': 'Fast User'},
              createdAt: DateTime.now(),
              eventId: 'event1',
            ),
            UserProfile(
              pubkey: 'pubkey2',
              name: 'Slow Match',
              rawData: const {'name': 'Slow Match'},
              createdAt: DateTime.now(),
              eventId: 'event2',
            ),
          ];

          final followers = StreamController<List<String>>();
          addTearDown(() => unawaited(followers.close()));

          final mockFollowRepo = _createMockFollowRepository(
            followingPubkeys: ['pubkey1', 'pubkey2'],
          );
          when(
            mockFollowRepo.streamMyFollowers,
          ).thenAnswer((_) => followers.stream);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                _noVanishedProfiles,
                profileRepositoryProvider.overrideWithValue(
                  _createMockProfileRepository(cachedProfiles: profiles),
                ),
                followRepositoryProvider.overrideWithValue(mockFollowRepo),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  _createMockContentBlocklistRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    title: 'Title',
                    filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          followers.add(['pubkey1']);
          await tester.pump();
          await tester.pump();

          expect(find.text('Fast User'), findsOneWidget);
          expect(find.text('Slow Match'), findsNothing);

          await tester.enterText(find.byType(TextField), 'slow');
          await tester.pumpAndSettle();

          expect(find.text('Fast User'), findsNothing);
          expect(find.text('Slow Match'), findsNothing);

          followers.add(['pubkey1', 'pubkey2']);
          await tester.pump();
          await tester.pump();

          expect(find.text('Fast User'), findsNothing);
          expect(find.text('Slow Match'), findsOneWidget);
        },
      );

      testWidgets('keeps the spinner while an early source reports no '
          'followers', (tester) async {
        final profile = UserProfile(
          pubkey: 'pubkey1',
          name: 'Late Mutual',
          rawData: const {'name': 'Late Mutual'},
          createdAt: DateTime.now(),
          eventId: 'event1',
        );

        final followers = StreamController<List<String>>();
        // Not awaited: the widget is still listening at teardown, so the done
        // event would never be delivered and the test would hang.
        addTearDown(() => unawaited(followers.close()));

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1'],
        );
        when(
          mockFollowRepo.streamMyFollowers,
        ).thenAnswer((_) => followers.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [profile]),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // An empty first emission must not flash the "no follows" state.
        followers.add(const []);
        await tester.pump();
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text('Your crew is out there'), findsNothing);

        followers.add(['pubkey1']);
        await tester.pump();
        await tester.pump();

        expect(find.text('Late Mutual'), findsOneWidget);
      });

      testWidgets('displays follow list after loading', (tester) async {
        final followPubkeys = ['pubkey1', 'pubkey2'];
        final profiles = [
          UserProfile(
            pubkey: 'pubkey1',
            name: 'User One',
            rawData: const {'name': 'User One'},
            createdAt: DateTime.now(),
            eventId: 'event1',
          ),
          UserProfile(
            pubkey: 'pubkey2',
            name: 'User Two',
            rawData: const {'name': 'User Two'},
            createdAt: DateTime.now(),
            eventId: 'event2',
          ),
        ];

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: followPubkeys,
        );

        final mockProfileRepo = _createMockProfileRepository(
          cachedProfiles: profiles,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not show empty state
        expect(find.text('Your crew is out there'), findsNothing);
      });

      testWidgets('clear button restores the unfiltered follow list', (
        tester,
      ) async {
        final profiles = [
          UserProfile(
            pubkey: 'pubkey1',
            name: 'Alpha',
            rawData: const {'name': 'Alpha'},
            createdAt: DateTime.now(),
            eventId: 'event1',
          ),
          UserProfile(
            pubkey: 'pubkey2',
            name: 'Bravo',
            rawData: const {'name': 'Bravo'},
            createdAt: DateTime.now(),
            eventId: 'event2',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: profiles),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(
                  followingPubkeys: ['pubkey1', 'pubkey2'],
                ),
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Alpha');
        await tester.pumpAndSettle();
        expect(find.text('Bravo'), findsNothing);

        // TextEditingController.clear() alone does not fire onChanged, so the
        // button has to dispatch the reset itself.
        final clearButton = find.descendant(
          of: find.byType(TextField),
          matching: find.byType(DivineIconButton),
        );
        expect(clearButton, findsOneWidget);
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Bravo'), findsOneWidget);
      });

      testWidgets('clear button carries a semantic label', (tester) async {
        final profile = UserProfile(
          pubkey: 'pubkey1',
          name: 'Alpha',
          rawData: const {'name': 'Alpha'},
          createdAt: DateTime.now(),
          eventId: 'event1',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(cachedProfiles: [profile]),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(followingPubkeys: ['pubkey1']),
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Alpha');
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.userPickerClearSearchSemantics),
          findsOneWidget,
        );
      });

      testWidgets('filters blocked users from the follow list', (tester) async {
        final allowedProfile = UserProfile(
          pubkey: 'pubkey1',
          name: 'Allowed User',
          rawData: const {'name': 'Allowed User'},
          createdAt: DateTime.now(),
          eventId: 'event1',
        );
        final blockedProfile = UserProfile(
          pubkey: 'pubkey2',
          name: 'Blocked User',
          rawData: const {'name': 'Blocked User'},
          createdAt: DateTime.now(),
          eventId: 'event2',
        );

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [allowedProfile.pubkey, blockedProfile.pubkey],
        );
        final mockProfileRepo = _createMockProfileRepository(
          cachedProfiles: [allowedProfile, blockedProfile],
        );
        final mockBlocklistRepo = _createMockContentBlocklistRepository(
          blockedPubkeys: {blockedProfile.pubkey},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepo,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Allowed User'), findsOneWidget);
        expect(find.text('Blocked User'), findsNothing);
      });

      testWidgets(
        'displays "Filter by name..." hint for mutualFollowsOnly mode',
        (tester) async {
          final followPubkeys = ['pubkey1'];
          final profiles = [
            UserProfile(
              pubkey: 'pubkey1',
              name: 'User One',
              rawData: const {'name': 'User One'},
              createdAt: DateTime.now(),
              eventId: 'event1',
            ),
          ];

          final mockFollowRepo = _createMockFollowRepository(
            followingPubkeys: followPubkeys,
          );

          final mockProfileRepo = _createMockProfileRepository();
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'pubkey1'),
          ).thenAnswer((_) async => profiles.first);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                _noVanishedProfiles,
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                profileReadRepositoryProvider.overrideWithValue(
                  mockProfileRepo,
                ),
                followRepositoryProvider.overrideWithValue(mockFollowRepo),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  _createMockContentBlocklistRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    title: 'Title',
                    filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Check for hint text in TextField
          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(textField.decoration?.hintText, equals('Filter by name...'));
        },
      );
    });

    group('allUsers mode', () {
      testWidgets('excludes the viewer from network search results', (
        tester,
      ) async {
        const viewerPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final viewer = UserProfile(
          pubkey: viewerPubkey,
          name: 'Viewer',
          rawData: const {'name': 'Viewer'},
          createdAt: DateTime.now(),
          eventId: 'viewer-event',
        );
        final other = UserProfile(
          pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          name: 'Other',
          rawData: const {'name': 'Other'},
          createdAt: DateTime.now(),
          eventId: 'other-event',
        );
        final mockProfileRepo = _createMockProfileRepository(
          searchResults: [viewer, other],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  excludeViewerPubkey: viewerPubkey,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'vie');
        // Past the 300ms search debounce.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Other'), findsOneWidget);
        expect(find.text('Viewer'), findsNothing);
      });

      testWidgets('shows hint text initially', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should display hint to type a name
        expect(find.text('Type a name to search'), findsOneWidget);
      });

      testWidgets('displays "Search by name..." hint text', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        // Check for hint text in TextField
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, equals('Search by name...'));
      });

      testWidgets('renders tiles during progressive loading '
          'instead of the full-screen spinner', (tester) async {
        // Stream controller kept open after the first yield — this
        // simulates the real progressive search still running (e.g.
        // NIP-50 WebSocket phase) while the REST phase has already
        // delivered results.
        final streamController =
            StreamController<ProgressiveSearchResult>.broadcast();
        addTearDown(streamController.close);

        final alice = UserProfile(
          pubkey: 'p_alice',
          name: 'Alice',
          rawData: const {'name': 'Alice'},
          createdAt: DateTime.now(),
          eventId: 'event_alice',
        );
        final mockProfileRepo = _createMockProfileRepository();
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            boostPubkeys: any(named: 'boostPubkeys'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer((_) => streamController.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'alice');
        // Past the 300ms search debounce.
        await tester.pump(const Duration(milliseconds: 400));

        // Emit the first batch — stream stays open, so the BLoC
        // stays in `loading` with results available. The fix is that
        // the picker now renders these results instead of a spinner.
        streamController.add(
          ProgressiveSearchResult(
            profiles: [alice],
            sources: const {},
            isComplete: false,
          ),
        );
        await tester.pump();

        // The tile renders while the stream is still open (loading). Before
        // the fix, the UI showed a full-screen spinner and Alice never
        // appeared until the progressive stream completed.
        expect(find.text('Alice'), findsOneWidget);
        // Only the footer load-more spinner should be in the tree (1);
        // before the fix there was a full-screen spinner instead (also 1),
        // so we distinguish by asserting the tile is present above.
      });

      testWidgets(
        'boosts followed users above non-followed in search results',
        (tester) async {
          final zoe = UserProfile(
            pubkey: 'p_zoe',
            name: 'Zoe',
            rawData: const {'name': 'Zoe'},
            createdAt: DateTime.now(),
            eventId: 'event_zoe',
          );
          final liz = UserProfile(
            pubkey: 'p_liz',
            name: 'Liz Sweigart',
            rawData: const {'name': 'Liz Sweigart'},
            createdAt: DateTime.now(),
            eventId: 'event_liz',
          );
          final mockProfileRepo = _MockProfileRepository();
          // Simulate the real repository's boost behaviour: profiles whose
          // pubkey is in [boostPubkeys] are promoted to the front while
          // preserving server-relative order. Boost ordering itself is
          // unit-tested in profile_repository_test.dart; here we just need
          // a mock that reacts to [boostPubkeys] so the widget test can
          // assert that the UI reflects it.
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
              cancellationToken: any(named: 'cancellationToken'),
            ),
          ).thenAnswer((invocation) {
            final boost =
                invocation.namedArguments[#boostPubkeys] as Set<String>? ??
                const <String>{};
            final results = [zoe, liz];
            ProgressiveSearchResult wrap(List<UserProfile> profiles) =>
                ProgressiveSearchResult(
                  profiles: profiles,
                  sources: const {},
                  isComplete: true,
                );
            if (boost.isEmpty) return Stream.value(wrap(results));
            final boosted = <UserProfile>[];
            final rest = <UserProfile>[];
            for (final p in results) {
              if (boost.contains(p.pubkey)) {
                boosted.add(p);
              } else {
                rest.add(p);
              }
            }
            return Stream.value(wrap([...boosted, ...rest]));
          });
          when(
            () =>
                mockProfileRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
          ).thenAnswer((_) async => null);
          final mockFollowRepo = _createMockFollowRepository(
            followingPubkeys: ['p_liz'],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                _noVanishedProfiles,
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                profileReadRepositoryProvider.overrideWithValue(
                  mockProfileRepo,
                ),
                followRepositoryProvider.overrideWithValue(mockFollowRepo),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    title: 'Title',
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'liz');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          final lizTile = find.text('Liz Sweigart');
          final zoeTile = find.text('Zoe');
          expect(lizTile, findsOneWidget);
          expect(zoeTile, findsOneWidget);

          final lizY = tester.getTopLeft(lizTile).dy;
          final zoeY = tester.getTopLeft(zoeTile).dy;
          expect(
            lizY,
            lessThan(zoeY),
            reason: 'Followed user should render above non-followed user',
          );
        },
      );

      testWidgets('disables iOS autocorrect and predictive suggestions on the '
          'search field', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.autocorrect,
          isFalse,
          reason: 'autocorrect must be off or iOS silently rewrites queries',
        );
        expect(
          textField.enableSuggestions,
          isFalse,
          reason: 'enableSuggestions must be off for the same reason',
        );
      });

      testWidgets('preserves previous results while a new query is loading', (
        tester,
      ) async {
        final alice = UserProfile(
          pubkey: 'p_alice',
          name: 'Alice',
          rawData: const {'name': 'Alice'},
          createdAt: DateTime.now(),
          eventId: 'event_alice',
        );
        final bob = UserProfile(
          pubkey: 'p_bob',
          name: 'Bob',
          rawData: const {'name': 'Bob'},
          createdAt: DateTime.now(),
          eventId: 'event_bob',
        );
        final bobController =
            StreamController<ProgressiveSearchResult>.broadcast();
        addTearDown(bobController.close);

        final mockProfileRepo = _createMockProfileRepository();
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            boostPubkeys: any(named: 'boostPubkeys'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            ProgressiveSearchResult(
              profiles: [alice],
              sources: const {},
              isComplete: true,
            ),
          ),
        );
        when(
          () => mockProfileRepo.searchUsersProgressive(
            query: 'bob',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            boostPubkeys: any(named: 'boostPubkeys'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer((_) => bobController.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              profileReadRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        // First query — 'alice' succeeds.
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);

        // Second query — 'bob' starts loading (stream stays open).
        await tester.enterText(find.byType(TextField), 'bob');
        await tester.pump(const Duration(milliseconds: 400));

        // Alice is still visible — we did NOT blank the list.
        expect(find.text('Alice'), findsOneWidget);

        // When 'bob' results arrive, the list updates in place.
        bobController.add(
          ProgressiveSearchResult(
            profiles: [bob],
            sources: const {},
            isComplete: true,
          ),
        );
        // Pump twice: once to let the stream event propagate through the
        // bloc's emit.forEach, once more for the rebuilt BlocBuilder.
        await tester.pump();
        await tester.pump();
        expect(find.text('Bob'), findsOneWidget);
      });
    });

    group('autoFocus', () {
      testWidgets('text field is autofocused when autoFocus is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                  autoFocus: true,
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, isTrue);
      });

      testWidgets('text field is not autofocused by default', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, isFalse);
      });
    });

    group('null profileRepository', () {
      testWidgets(
        'shows error state for allUsers mode when profileRepository is null',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                _noVanishedProfiles,
                profileRepositoryProvider.overrideWithValue(null),
                profileReadRepositoryProvider.overrideWithValue(null),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    title: 'Title',
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text('User search is unavailable. Please try again later.'),
            findsOneWidget,
          );
          // Should not show the search field
          expect(find.byType(TextField), findsNothing);
        },
      );

      testWidgets('shows error state for mutualFollowsOnly mode '
          'when profileRepository is null', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _noVanishedProfiles,
              profileRepositoryProvider.overrideWithValue(null),
              profileReadRepositoryProvider.overrideWithValue(null),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _createMockContentBlocklistRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  title: 'Title',
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('User search is unavailable. Please try again later.'),
          findsOneWidget,
        );
        // Should not show the search field
        expect(find.byType(TextField), findsNothing);
      });
    });
  });

  // #8421 adjacent: this picker feeds badge awards (kind 8, which NIP-58
  // calls "immutable and non-transferable"), people lists (kind 30000) and
  // video `p` tags (kind 34236). A wrong identity here is published
  // permanently and in public, and `allUsers` mode reaches third-party
  // NIP-50 relays that a vanish addressed elsewhere never obliged to forget.
  group('vanished accounts', () {
    const vanishedPubkey =
        'b75b9a3131f4263add94ba20beb352a1'
        '1032684f2dac07a7e1af827c6f3c1505';
    const livePubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    UserProfile profileFor(String pubkey, String name, {String? nip05}) =>
        UserProfile(
          pubkey: pubkey,
          displayName: name,
          nip05: nip05,
          picture: 'https://example.invalid/$pubkey.png',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'e' * 64,
        );

    Future<void> pumpPicker(
      WidgetTester tester, {
      required List<UserProfile> profiles,
      required Set<String> vanished,
      UserPickerFilterMode filterMode = UserPickerFilterMode.mutualFollowsOnly,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _vanishedProfiles(vanished),
            profileRepositoryProvider.overrideWithValue(
              _createMockProfileRepository(
                cachedProfiles: profiles,
                searchResults: profiles,
              ),
            ),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(
                followingPubkeys: [for (final p in profiles) p.pubkey],
              ),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserPickerSheet(title: 'Title', filterMode: filterMode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names a vanished follow "Deleted account"', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpPicker(
        tester,
        profiles: [profileFor(vanishedPubkey, 'Aeontropy')],
        vanished: {vanishedPubkey},
      );

      expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
      expect(find.text('Aeontropy'), findsNothing);
    });

    testWidgets("hides a vanished account's NIP-05, which identifies it too", (
      tester,
    ) async {
      await pumpPicker(
        tester,
        profiles: [
          profileFor(
            vanishedPubkey,
            'Aeontropy',
            nip05: 'aeontropy@example.com',
          ),
        ],
        vanished: {vanishedPubkey},
      );

      expect(find.text('aeontropy@example.com'), findsNothing);
    });

    testWidgets('announces the substitute, not the name it no longer shows', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpPicker(
        tester,
        profiles: [profileFor(vanishedPubkey, 'Aeontropy')],
        vanished: {vanishedPubkey},
      );

      expect(
        find.bySemanticsLabel(
          l10n.userPickerSelectSemantics(l10n.profileDeletedAccountName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaves a live account untouched', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpPicker(
        tester,
        profiles: [profileFor(livePubkey, 'Alice')],
        vanished: const {},
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(l10n.profileDeletedAccountName), findsNothing);
    });

    testWidgets('orders rows by the rendered name, not the raw one', (
      tester,
    ) async {
      // Raw, "Aardvark" sorts first; rendered, "Deleted account" sorts last.
      // The two orders disagree, so only one of them can pass.
      await pumpPicker(
        tester,
        profiles: [
          profileFor(vanishedPubkey, 'Aardvark'),
          profileFor(livePubkey, 'Aaron'),
        ],
        vanished: {vanishedPubkey},
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => t == 'Aaron' || t == l10n.profileDeletedAccountName)
          .toList();
      expect(rendered, ['Aaron', l10n.profileDeletedAccountName]);
    });

    testWidgets(
      'renders a divine NIP-05 in the short form every other row uses',
      (tester) async {
        // The raw `nip05` field is the long form and skips the sanitizer;
        // `shortDisplayNip05` is what the rest of the app renders and runs the
        // value through `text_sanitizer` on the way. Relay search results are
        // arbitrary kind-0 JSON, so this row is a display boundary.
        await pumpPicker(
          tester,
          profiles: [
            profileFor(livePubkey, 'Alice', nip05: '_@alice.divine.video'),
          ],
          vanished: const {},
        );

        expect(find.text('@alice'), findsOneWidget);
        expect(find.text('_@alice.divine.video'), findsNothing);
      },
    );
  });

  group('showUserPickerSheet', () {
    testWidgets('a short drag on the results keeps the picker and its picks', (
      tester,
    ) async {
      final profiles = [
        UserProfile(
          pubkey: 'pubkey1',
          name: 'Picked User',
          rawData: const {'name': 'Picked User'},
          createdAt: DateTime(2026),
          eventId: 'event1',
        ),
        UserProfile(
          pubkey: 'pubkey2',
          name: 'Other User',
          rawData: const {'name': 'Other User'},
          createdAt: DateTime(2026),
          eventId: 'event2',
        ),
      ];

      var pickerClosed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _noVanishedProfiles,
            profileRepositoryProvider.overrideWithValue(
              _createMockProfileRepository(cachedProfiles: profiles),
            ),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(
                followingPubkeys: ['pubkey1', 'pubkey2'],
              ),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    await showUserPickerSheet(
                      context,
                      filterMode: UserPickerFilterMode.mutualFollowsOnly,
                      title: 'Title',
                      maxCount: 2,
                    );
                    pickerClosed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picked User'));
      await tester.pumpAndSettle();

      // A third of the viewport: past the floor the sheet used to sit on,
      // short of the one it sits on now. Reaching the floor pops the modal,
      // and the selection pops with it.
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(pickerClosed, isFalse);
      expect(find.byType(UserPickerSheet), findsOneWidget);
      expect(find.text('Picked User'), findsOneWidget);
    });
  });

  group(UserPickerFilterMode, () {
    test('has correct enum values', () {
      expect(UserPickerFilterMode.values.length, equals(2));
      expect(
        UserPickerFilterMode.values,
        contains(UserPickerFilterMode.mutualFollowsOnly),
      );
      expect(
        UserPickerFilterMode.values,
        contains(UserPickerFilterMode.allUsers),
      );
    });
  });
}
