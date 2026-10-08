// ABOUTME: Tests showNewPeopleListSheet's curatedLists gate.
// ABOUTME: The sheet reads the lazily-registered global PeopleListsBloc.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:rxdart/rxdart.dart';

import '../../helpers/test_provider_overrides.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      const PeopleListsCreateRequested(
        expectedOwnerPubkey: _owner,
        name: 'Fallback',
      ),
    ),
  );
  group('showNewPeopleListSheet', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
        ),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    // The global PeopleListsBloc is registered unconditionally in main.dart
    // (a conditional entry re-inflated the Navigator on every flag flip), so
    // BlocProvider laziness is what keeps it unbuilt while curated lists are
    // off. `create` firing means a relay query and cache subscription started
    // for a disabled feature.
    testWidgets(
      'does not open or construct $PeopleListsBloc when curatedLists is off',
      (tester) async {
        var blocCreated = false;

        await tester.pumpWidget(
          _buildSubject(
            curatedListsEnabled: false,
            createBloc: () {
              blocCreated = true;
              return bloc;
            },
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(blocCreated, isFalse);
        expect(find.text(l10n.listNewPeopleList), findsNothing);
      },
    );

    // The summary line keeps the `UserProfile` the picker handed back and
    // formats its own text, so it does not inherit the picker's own
    // substitution — a deleted collaborator was still named here after the
    // picker itself stopped naming them.
    testWidgets('names a vanished collaborator "Deleted account"', (
      tester,
    ) async {
      const vanishedPubkey =
          'b75b9a3131f4263add94ba20beb352a1'
          '1032684f2dac07a7e1af827c6f3c1505';
      final collaborator = UserProfile(
        pubkey: vanishedPubkey,
        displayName: 'Aeontropy',
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'e' * 64,
      );

      final profileRepo = _MockProfileRepository();
      when(
        () => profileRepo.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer((_) async => [collaborator]);
      when(
        () => profileRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => collaborator);

      final followRepo = _MockFollowRepository();
      when(() => followRepo.followingPubkeys).thenReturn([vanishedPubkey]);
      when(() => followRepo.isInitialized).thenReturn(true);
      when(() => followRepo.followingCount).thenReturn(1);
      when(
        () => followRepo.followingStream,
      ).thenAnswer(
        (_) => BehaviorSubject<List<String>>.seeded([
          vanishedPubkey,
        ]).stream,
      );
      when(
        followRepo.streamMyFollowers,
      ).thenAnswer((_) => Stream.value([vanishedPubkey]));
      when(followRepo.getMyFollowers).thenAnswer((_) async => [vanishedPubkey]);

      final blocklist = _MockContentBlocklistRepository();
      when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);

      await tester.pumpWidget(
        _buildSubject(
          curatedListsEnabled: true,
          createBloc: () => bloc,
          initialCollaborator: collaborator,
          extraOverrides: [
            vanishedProfilePubkeysProvider.overrideWith(
              (ref) => Stream.value({vanishedPubkey}),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            followRepositoryProvider.overrideWithValue(followRepo),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Aeontropy'), findsNothing);
      expect(find.text(l10n.profileDeletedAccountName), findsWidgets);
    });

    testWidgets(
      'an account change while create is open does not create under the replacement account',
      (tester) async {
        String? owner = _owner;
        final auth = createMockAuthService(currentPublicKeyHex: owner);
        when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
        await tester.pumpWidget(
          _buildSubject(
            curatedListsEnabled: true,
            createBloc: () => bloc,
            auth: auth,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Entered in A');
        await tester.pump();
        owner = 'e' * 64;
        await tester.tap(find.bySemanticsLabel(l10n.listDone));
        await tester.pumpAndSettle();
        verifyNever(() => bloc.add(any()));
      },
    );
    testWidgets("joins the collaborators' names with the locale's own "
        'separator', (tester) async {
      // Japanese lists names with 、, so a Latin ", " cannot pass here.
      const seededPubkey =
          'c75b9a3131f4263add94ba20beb352a1'
          '1032684f2dac07a7e1af827c6f3c1505';
      const pickedPubkey =
          'd75b9a3131f4263add94ba20beb352a1'
          '1032684f2dac07a7e1af827c6f3c1505';
      UserProfile profile(String pubkey, String name) => UserProfile(
        pubkey: pubkey,
        displayName: name,
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'e' * 64,
      );
      final seeded = profile(seededPubkey, 'Aki');
      final picked = profile(pickedPubkey, 'Rin');

      final profileRepo = _MockProfileRepository();
      when(
        () => profileRepo.searchUsersProgressive(
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
            profiles: [picked],
            sources: const {},
            isComplete: true,
          ),
        ),
      );
      when(
        () => profileRepo.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer((_) async => [picked]);
      when(
        () => profileRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => picked);
      final followRepo = _MockFollowRepository();
      when(() => followRepo.followingPubkeys).thenReturn([pickedPubkey]);
      when(() => followRepo.isInitialized).thenReturn(true);
      when(() => followRepo.followingCount).thenReturn(1);
      when(() => followRepo.followingStream).thenAnswer(
        (_) => BehaviorSubject<List<String>>.seeded([pickedPubkey]).stream,
      );
      when(
        followRepo.streamMyFollowers,
      ).thenAnswer((_) => Stream.value([pickedPubkey]));
      when(followRepo.getMyFollowers).thenAnswer((_) async => [pickedPubkey]);
      final blocklist = _MockContentBlocklistRepository();
      when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);

      await tester.pumpWidget(
        _buildSubject(
          curatedListsEnabled: true,
          createBloc: () => bloc,
          initialCollaborator: seeded,
          locale: const Locale('ja'),
          extraOverrides: [
            // Nobody is vanished; the real provider is a drift stream whose
            // teardown timer would outlive the test.
            vanishedProfilePubkeysProvider.overrideWith(
              (ref) => Stream.value(const <String>{}),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            followRepositoryProvider.overrideWithValue(followRepo),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aki'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Rin');
      // Advance the search's configured debounce before waiting for results.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rin').last);
      await tester.pumpAndSettle();

      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(ja.listMemberNamesSeparator, isNot(', '));
      expect(
        find.text(['Aki', 'Rin'].join(ja.listMemberNamesSeparator)),
        findsOneWidget,
      );
    });

    testWidgets('Done stays disabled until a name is entered', (tester) async {
      await tester.pumpWidget(
        _buildSubject(curatedListsEnabled: true, createBloc: () => bloc),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final done = find.widgetWithText(DivineButton, l10n.listDone);

      expect(tester.widget<DivineButton>(done).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(tester.widget<DivineButton>(done).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Film Club');
      await tester.pump();
      expect(tester.widget<DivineButton>(done).onPressed, isNotNull);
    });

    testWidgets('keeps entered name open until confirmed and after failure', (
      tester,
    ) async {
      final pending = Completer<PeopleListsOperationResult>();
      when(() => bloc.submit(any())).thenAnswer((_) => pending.future);
      await tester.pumpWidget(
        _buildSubject(curatedListsEnabled: true, createBloc: () => bloc),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'My people');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.listDone));
      await tester.pump();
      expect(find.text('My people'), findsOneWidget);
      pending.complete(PeopleListsOperationResult.failed);
      await tester.pumpAndSettle();
      expect(find.text('My people'), findsOneWidget);
      expect(find.text(l10n.listCreateFailed), findsOneWidget);
    });

    testWidgets('opens when curatedLists is on', (tester) async {
      await tester.pumpWidget(
        _buildSubject(curatedListsEnabled: true, createBloc: () => bloc),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listNewPeopleList), findsOneWidget);
    });
  });
}

/// Mirrors the app shell: a lazy `BlocProvider` above the navigator, so
/// [createBloc] only runs if something below actually reads the bloc.
Widget _buildSubject({
  required bool curatedListsEnabled,
  required PeopleListsBloc Function() createBloc,
  List<Override> extraOverrides = const [],
  MockAuthService? auth,
  UserProfile? initialCollaborator,
  String? initialPubkey,
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(
        auth ?? createMockAuthService(currentPublicKeyHex: _owner),
      ),
      isFeatureEnabledProvider(
        FeatureFlag.curatedLists,
      ).overrideWithValue(curatedListsEnabled),
      ...extraOverrides,
    ],
    child: BlocProvider<PeopleListsBloc>(
      create: (_) => createBloc(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showNewPeopleListSheet(
                context,
                initialCollaborator: initialCollaborator,
                initialPubkey: initialPubkey,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}
