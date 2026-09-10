import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
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
      () => profileRepository.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer((_) async => [_profile(_ogab, 'OG-AB')]);
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

  Future<ProviderContainer> pumpField(
    WidgetTester tester, {
    bool enableMentionAutocomplete = true,
    bool dismissKeyboardOnDrag = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        followRepositoryProvider.overrideWithValue(followRepository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
    );
    addTearDown(container.dispose);

    final form = Column(
      children: [
        VideoMetadataCaptionField(
          controller: controller,
          focusNode: focusNode,
          enableMentionAutocomplete: enableMentionAutocomplete,
        ),
        const TextField(key: Key('other-field')),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The capture and classic stacks host this field inside a
            // dismiss-on-drag scroll view.
            body: dismissKeyboardOnDrag
                ? SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: form,
                  )
                : form,
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

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsOneWidget);
        expect(find.text('OG-AB'), findsOneWidget);

        await flushAutosaveDebounce(tester);
      });

      testWidgets('shows nothing before an @ is typed', (tester) async {
        await pumpField(tester);

        await tester.enterText(find.byType(TextField).first, 'dedicated to OG');
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);

        await flushAutosaveDebounce(tester);
      });

      testWidgets('picking a suggestion writes the handle and records it', (
        tester,
      ) async {
        final container = await pumpField(tester);

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
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

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OG-AB'));
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);

        await flushAutosaveDebounce(tester);
      });

      testWidgets('dismisses the list when the caption loses focus', (
        tester,
      ) async {
        await pumpField(tester);

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
        await tester.pumpAndSettle();
        expect(find.byType(MentionOverlay), findsOneWidget);

        await tester.tap(find.byKey(const Key('other-field')));
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);
        await flushAutosaveDebounce(tester);
      });

      testWidgets('keeps the list open while its suggestions are scrolled', (
        tester,
      ) async {
        // Enough followed accounts to overflow the overlay's 240px cap, so
        // the inner list can actually scroll.
        final pubkeys = [for (var i = 0; i < 8; i++) '$i' * 64];
        when(() => followRepository.followingPubkeys).thenReturn(pubkeys);
        when(
          () => profileRepository.getCachedProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => [
            for (var i = 0; i < pubkeys.length; i++)
              _profile(pubkeys[i], 'OG-AB$i'),
          ],
        );

        await pumpField(tester, dismissKeyboardOnDrag: true);

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
        await tester.pumpAndSettle();
        expect(find.byType(MentionOverlay), findsOneWidget);

        ScrollPosition suggestionScroll() => tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(MentionOverlay),
                matching: find.byType(Scrollable),
              ),
            )
            .position;

        // Positive control: without room to scroll, the drag below would
        // prove nothing.
        expect(suggestionScroll().maxScrollExtent, greaterThan(0));

        await tester.drag(find.byType(ListView), const Offset(0, -60));
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsOneWidget);
        expect(suggestionScroll().pixels, greaterThan(0));

        await flushAutosaveDebounce(tester);
      });

      testWidgets('disables a picked mention that would exceed the limit', (
        tester,
      ) async {
        final container = await pumpField(tester);
        final caption = '${List.filled(997, 'a').join()}@OG';

        await tester.enterText(find.byType(TextField).first, caption);
        await tester.pumpAndSettle();

        final suggestion = find.ancestor(
          of: find.text('OG-AB'),
          matching: find.byType(InkWell),
        );
        expect(tester.widget<InkWell>(suggestion).onTap, isNull);

        await tester.tap(find.text('OG-AB'));
        await tester.pumpAndSettle();

        expect(controller.text, caption);
        expect(container.read(videoEditorProvider).description, caption);
        expect(container.read(videoEditorProvider).captionMentions, isEmpty);
        await flushAutosaveDebounce(tester);
      });

      testWidgets('does not search when autocomplete is disabled', (
        tester,
      ) async {
        await pumpField(tester, enableMentionAutocomplete: false);

        await tester.enterText(
          find.byType(TextField).first,
          'dedicated to @OG',
        );
        await tester.pumpAndSettle();

        expect(find.byType(MentionOverlay), findsNothing);
        verifyNever(
          () => profileRepository.getCachedProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        );
        await flushAutosaveDebounce(tester);
      });
    });
  });
}
