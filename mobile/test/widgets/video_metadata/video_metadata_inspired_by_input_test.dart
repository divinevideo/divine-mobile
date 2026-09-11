import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Mock for ContentBlocklistRepository
class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setInspiredByPeople(List<String> npubs) {
    state = state.copyWith(inspiredByNpubs: npubs);
  }

  @override
  void clearInspiredBy() {
    state = state.copyWith(
      clearInspiredByNpub: true,
      clearInspiredByVideo: true,
    );
  }
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

_MockProfileRepository _createMockProfileRepository() {
  final mock = _MockProfileRepository();
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
      const ProgressiveSearchResult(
        profiles: [],
        sources: {},
        isComplete: true,
      ),
    ),
  );
  when(
    () => mock.getCachedProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);
  when(
    () => mock.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
  ).thenAnswer((_) async => []);
  return mock;
}

Override get _noVanishedProfiles =>
    vanishedProfilePubkeysProvider.overrideWith((ref) => Stream.value({}));

/// Create a mock ContentBlocklistRepository
_MockContentBlocklistRepository _createMockContentBlocklistRepository({
  bool hasMutedUs = false,
}) {
  final mock = _MockContentBlocklistRepository();
  when(() => mock.hasMutedUs(any())).thenReturn(hasMutedUs);
  when(() => mock.isBlocked(any())).thenReturn(false);
  return mock;
}

void main() {
  setUpAll(() {
    registerFallbackValue(SearchCancellationToken('test-search'));
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeEffectiveInspiredByNpubs', () {
    final npubA = NostrKeyUtils.encodePubKey('a' * 64);
    final npubB = NostrKeyUtils.encodePubKey('b' * 64);
    final npubC = NostrKeyUtils.encodePubKey('c' * 64);

    test('preserves a credited creator the picker never showed', () {
      // A creator whose profile has not resolved is not passed to the picker,
      // so the picker cannot return them — and cannot have deselected them.
      final effective = computeEffectiveInspiredByNpubs(
        confirmedNpubs: [npubA, npubB],
        preselectedNpubs: [npubB],
        pickerResultNpubs: [npubB, npubC],
      );

      expect(effective, equals([npubA, npubB, npubC]));
    });

    test('drops a creator the picker showed and the author deselected', () {
      final effective = computeEffectiveInspiredByNpubs(
        confirmedNpubs: [npubA, npubB],
        preselectedNpubs: [npubA, npubB],
        pickerResultNpubs: [npubB],
      );

      expect(effective, equals([npubB]));
    });

    test('keeps the author order, so the content line names the same '
        'creator', () {
      final effective = computeEffectiveInspiredByNpubs(
        confirmedNpubs: [npubA, npubB],
        preselectedNpubs: [npubB],
        pickerResultNpubs: [npubB, npubC],
      );

      // Position 0 is what reaches the NIP-27 content line; adding a creator
      // must not silently promote someone else past the author's first pick.
      expect(effective.first, equals(npubA));
    });

    test('names a creator once when the picker returns an existing one', () {
      final effective = computeEffectiveInspiredByNpubs(
        confirmedNpubs: [npubA],
        preselectedNpubs: [npubA],
        pickerResultNpubs: [npubA, npubA],
      );

      expect(effective, equals([npubA]));
    });

    test('caps the reconciled set at the picker limit', () {
      // The picker enforces the cap over what it was seeded with; it cannot
      // count a creator it never showed, so reconciling can overshoot.
      const limit = VideoEditorConstants.maxInspiredByCreators;
      final unresolved = [
        for (var i = 0; i < limit; i++)
          NostrKeyUtils.encodePubKey(
            '${'0' * 62}${i.toString().padLeft(2, '0')}',
          ),
      ];

      final effective = computeEffectiveInspiredByNpubs(
        confirmedNpubs: unresolved,
        preselectedNpubs: const [],
        pickerResultNpubs: [npubA, npubB, npubC],
      );

      expect(effective, hasLength(limit));
      expect(effective, equals(unresolved));
    });
  });

  group(VideoMetadataInspiredByInput, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders "Inspired by" label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataInspiredByLabel), findsOneWidget);
    });

    testWidgets('renders selection tile when no inspiration is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('renders caret icon when no inspiration is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Should have SVG icons (caret and info button)
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('has correct semantics for set inspired by action', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Find the Semantics widget with button=true and 'Set inspired by' label
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      var foundInspiredBySemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label ==
                lookupAppLocalizations(
                  const Locale('en'),
                ).videoMetadataSetInspiredBySemanticLabel) {
          foundInspiredBySemantics = true;
          break;
        }
      }
      expect(foundInspiredBySemantics, isTrue);
    });

    testWidgets('does not render legacy help tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      final tooltip = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message == 'How inspiration credits work',
      );
      expect(tooltip, findsNothing);
    });

    testWidgets('displays inspired by person chip when inspiredByNpub is set', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        inspiredByNpubs: const [
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Should NOT display "None" when inspired by is set
      expect(find.text('None'), findsNothing);
    });

    testWidgets('lists every credited creator on the tile', (tester) async {
      // The tile is the only place the author can see who they credited, so
      // showing just the first would make the extra picks invisible.
      final first = NostrKeyUtils.encodePubKey('a' * 64);
      final second = NostrKeyUtils.encodePubKey('b' * 64);
      final state = VideoEditorProviderState(
        inspiredByNpubs: [first, second],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('None'), findsNothing);
      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
      final tile = tester.widget<VideoMetadataSelectionTile>(
        find.byType(VideoMetadataSelectionTile),
      );
      // Neither profile is cached here, which is the point: an uncredited
      // name must still appear, so the author can see both picks.
      expect(tile.value.split(', ').length, equals(2));
    });

    testWidgets('Done preserves credited creators the picker could not show', (
      tester,
    ) async {
      final unresolved = NostrKeyUtils.encodePubKey('d' * 64);
      final state = VideoEditorProviderState(inspiredByNpubs: [unresolved]);
      final notifier = _MockVideoEditorNotifier(state);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _noVanishedProfiles,
            sharedPreferencesProvider.overrideWithValue(prefs),
            profileRepositoryProvider.overrideWithValue(
              _createMockProfileRepository(),
            ),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      await tester.tap(find.byType(VideoMetadataSelectionTile));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.bySemanticsLabel(l10n.userPickerConfirmSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(notifier.state.inspiredByNpubs, equals([unresolved]));
    });

    testWidgets("names the inspiring video's creator once", (tester) async {
      // Editing a published video seeds inspiredByVideo from its a-tag and
      // inspiredByNpubs from its inspired-by p-tags — and the a-tag creator
      // is carried by both, so the tile would name them twice.
      const creatorHex =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      final state = VideoEditorProviderState(
        inspiredByVideo: const InspiredByInfo(
          addressableId: '34236:$creatorHex:vine123',
        ),
        inspiredByNpubs: [NostrKeyUtils.encodePubKey(creatorHex)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );
      await tester.pump();

      final tile = tester.widget<VideoMetadataSelectionTile>(
        find.byType(VideoMetadataSelectionTile),
      );
      expect(tile.value, isNotEmpty);
      expect(tile.value.split(', '), hasLength(1));
    });

    testWidgets('selection tile still renders when inspired by is set', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        inspiredByNpubs: const [
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('selection tile renders when no inspired by is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });
  });
}
