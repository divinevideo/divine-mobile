import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../builders/user_profile_builder.dart';
import '../../helpers/test_provider_overrides.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void addCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: {...state.collaboratorPubkeys, pubkey},
    );
  }

  @override
  void removeCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: state.collaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
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
  when(
    mock.streamMyFollowers,
  ).thenAnswer((_) => Stream.value(followingPubkeys));
  return mock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeEffectiveCollaboratorResultPubkeys', () {
    test('preserves unresolved confirmed collaborators', () {
      final effective = computeEffectiveCollaboratorResultPubkeys(
        confirmedPubkeys: {'a', 'b'},
        preselectedPubkeys: {'a'},
        pickerResultPubkeys: {'a'},
        viewerPubkey: null,
      );

      expect(effective, equals({'a', 'b'}));
    });

    test('keeps explicit deselection for loaded collaborators', () {
      final effective = computeEffectiveCollaboratorResultPubkeys(
        confirmedPubkeys: {'a', 'b'},
        preselectedPubkeys: {'a', 'b'},
        pickerResultPubkeys: {'a'},
        viewerPubkey: null,
      );

      expect(effective, equals({'a'}));
    });

    test('removes the viewer from picker results', () {
      const viewerPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final effective = computeEffectiveCollaboratorResultPubkeys(
        confirmedPubkeys: const {},
        preselectedPubkeys: const {},
        pickerResultPubkeys: const {
          viewerPubkey,
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        },
        viewerPubkey: viewerPubkey,
      );

      expect(effective, {
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      });
    });

    test('removes the viewer case-insensitively', () {
      const viewerPubkey =
          'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';
      final effective = computeEffectiveCollaboratorResultPubkeys(
        confirmedPubkeys: const {},
        preselectedPubkeys: const {},
        pickerResultPubkeys: {viewerPubkey.toUpperCase()},
        viewerPubkey: viewerPubkey,
      );

      expect(effective, isEmpty);
    });

    test('preserves unresolved non-viewer collaborators', () {
      const viewerPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const unresolvedPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final effective = computeEffectiveCollaboratorResultPubkeys(
        confirmedPubkeys: const {viewerPubkey, unresolvedPubkey},
        preselectedPubkeys: const {},
        pickerResultPubkeys: const {},
        viewerPubkey: viewerPubkey,
      );

      expect(effective, {unresolvedPubkey});
    });
  });

  group(VideoMetadataCollaboratorsInput, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders Collaborators label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(find.text(_l10n.videoMetadataCollaboratorsLabel), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataSelectionTile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('renders correctly when collaborators exist in state', (
      tester,
    ) async {
      // Use valid 64-character hex pubkeys (Nostr spec)
      final state = VideoEditorProviderState(
        collaboratorPubkeys: {
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('renders caret icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Should have SVG icons (caret and info button)
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('has correct semantics for invite collaborator action', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Find the Semantics widget with button=true and invite label
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      var foundInviteCollaboratorSemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label ==
                _l10n.videoMetadataAddCollaboratorSemanticLabel) {
          foundInviteCollaboratorSemantics = true;
          break;
        }
      }
      expect(foundInviteCollaboratorSemantics, isTrue);
    });

    testWidgets(
      'renders $VideoMetadataSelectionTile when max collaborators reached',
      (tester) async {
        final state = VideoEditorProviderState(
          collaboratorPubkeys: {
            'abcd000000000000000000000000000000000000000000000000000000000000',
            'abcd000000000000000000000000000000000000000000000000000000000001',
            'abcd000000000000000000000000000000000000000000000000000000000002',
            'abcd000000000000000000000000000000000000000000000000000000000003',
            'abcd000000000000000000000000000000000000000000000000000000000004',
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataCollaboratorsInput()),
            ),
          ),
        );

        expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
      },
    );

    testWidgets('no chips rendered when no collaborators', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Wrap should not be present when no collaborators
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('tile value is empty when no collaborators', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            userProfileReactiveProvider.overrideWith(
              (ref, pubkey) => Stream<UserProfile?>.value(null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      final tile = tester.widget<VideoMetadataSelectionTile>(
        find.byType(VideoMetadataSelectionTile),
      );
      expect(tile.value, isEmpty);
    });

    testWidgets(
      'tile value joins display names of collaborators with profiles',
      (tester) async {
        const aliceKey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const bobKey =
            '2222222222222222222222222222222222222222222222222222222222222222';

        final state = VideoEditorProviderState(
          collaboratorPubkeys: {aliceKey, bobKey},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
              userProfileReactiveProvider.overrideWith((ref, pubkey) {
                final displayName = switch (pubkey) {
                  aliceKey => 'Alice',
                  bobKey => 'Bob',
                  _ => null,
                };
                if (displayName == null) {
                  return Stream<UserProfile?>.value(null);
                }
                return Stream<UserProfile?>.value(
                  UserProfileBuilder(
                    pubkey: pubkey,
                    displayName: displayName,
                  ).build(),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataCollaboratorsInput()),
            ),
          ),
        );

        await tester.pump();

        final tile = tester.widget<VideoMetadataSelectionTile>(
          find.byType(VideoMetadataSelectionTile),
        );
        expect(tile.value, anyOf(equals('Alice, Bob'), equals('Bob, Alice')));
      },
    );

    testWidgets('passes the viewer pubkey and removes a stale self-selection', (
      tester,
    ) async {
      const viewerPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const mutualPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final viewer = UserProfileBuilder(
        pubkey: viewerPubkey,
        displayName: 'Viewer',
      ).build();
      final mutual = UserProfileBuilder(
        pubkey: mutualPubkey,
        displayName: 'Mutual',
      ).build();
      final profileRepository = createMockProfileRepository();
      when(
        () => profileRepository.getCachedProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => [viewer, mutual]);
      final contentBlocklistRepository = _MockContentBlocklistRepository();
      when(
        () => contentBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      final editorNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          collaboratorPubkeys: {viewerPubkey},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(
              createMockAuthService(currentPublicKeyHex: viewerPubkey),
            ),
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(
                followingPubkeys: [viewerPubkey, mutualPubkey],
              ),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepository),
            videoEditorProvider.overrideWith(() => editorNotifier),
            contentBlocklistRepositoryProvider.overrideWithValue(
              contentBlocklistRepository,
            ),
            vanishedProfilePubkeysProvider.overrideWith(
              (ref) => const Stream<Set<String>>.empty(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      await tester.tap(find.byType(VideoMetadataSelectionTile));
      await tester.pumpAndSettle();

      expect(find.text('Viewer'), findsNothing);
      expect(find.text('Mutual'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel(_l10n.userPickerConfirmSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(editorNotifier.state.collaboratorPubkeys, isEmpty);
    });
  });
}
