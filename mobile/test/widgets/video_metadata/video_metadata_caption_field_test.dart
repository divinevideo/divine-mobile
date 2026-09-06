import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_caption_field.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _ogab =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

UserProfile _profile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  name: name,
  rawData: const {},
  createdAt: DateTime.utc(2026),
  eventId: 'event-$pubkey',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _MockFollowRepository followRepository;
  late _MockProfileRepository profileRepository;
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    controller = TextEditingController();
    focusNode = FocusNode();

    followRepository = _MockFollowRepository();
    when(() => followRepository.followingPubkeys).thenReturn([_ogab]);
    when(() => followRepository.followingStream).thenAnswer(
      (_) => BehaviorSubject<List<String>>.seeded([_ogab]).stream,
    );
    when(() => followRepository.isInitialized).thenReturn(true);
    when(() => followRepository.followingCount).thenReturn(1);

    profileRepository = _MockProfileRepository();
    when(
      () => profileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) async => _profile(_ogab, 'OG-AB'));
    when(
      () => profileRepository.searchUsersFromApi(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenAnswer((_) async => const <UserProfile>[]);
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<ProviderContainer> pumpField(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        followRepositoryProvider.overrideWithValue(followRepository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoMetadataCaptionField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );
    return container;
  }

  /// Fires the editor's autosave debounce so no timer is pending at teardown.
  Future<void> flushAutosaveDebounce(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  group(VideoMetadataCaptionField, () {
    group('interactions', () {
      testWidgets('suggests a followed account while an @ is being typed', (
        tester,
      ) async {
        await pumpField(tester);

        await tester.enterText(find.byType(TextField), 'dedicated to @OG');
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsOneWidget);
        expect(find.text('OG-AB'), findsOneWidget);

        await flushAutosaveDebounce(tester);
      });

      testWidgets('shows nothing before an @ is typed', (tester) async {
        await pumpField(tester);

        await tester.enterText(find.byType(TextField), 'dedicated to OG');
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);

        await flushAutosaveDebounce(tester);
      });

      testWidgets('picking a suggestion writes the handle and records it', (
        tester,
      ) async {
        final container = await pumpField(tester);

        await tester.enterText(find.byType(TextField), 'dedicated to @OG');
        await tester.pumpAndSettle();
        await tester.tap(find.text('OG-AB'));
        await tester.pumpAndSettle();

        expect(controller.text, equals('dedicated to @OG-AB '));

        final mentions = container.read(videoEditorProvider).captionMentions;
        expect(mentions, hasLength(1));
        expect(mentions.single.pubkey, equals(_ogab));
        expect(mentions.single.display, equals('OG-AB'));
        // The recorded range must bound the handle actually written.
        final start = mentions.single.start;
        final end = mentions.single.end;
        expect(start, isNotNull);
        expect(end, isNotNull);
        expect(
          controller.text.substring(start!, end),
          equals('@OG-AB'),
        );

        await flushAutosaveDebounce(tester);
      });

      testWidgets('dismisses the list once a suggestion is picked', (
        tester,
      ) async {
        await pumpField(tester);

        await tester.enterText(find.byType(TextField), 'dedicated to @OG');
        await tester.pumpAndSettle();
        await tester.tap(find.text('OG-AB'));
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);

        await flushAutosaveDebounce(tester);
      });
    });
  });
}
