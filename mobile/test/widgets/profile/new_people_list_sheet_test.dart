// ABOUTME: Tests showNewPeopleListSheet's curatedLists gate.
// ABOUTME: The sheet reads the lazily-registered global PeopleListsBloc.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
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
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:rxdart/rxdart.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('showNewPeopleListSheet', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(),
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
      await tester.tap(find.text(l10n.listCollaboratorsNone));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileDeletedAccountName).last);
      await tester.pumpAndSettle();

      expect(find.text('Aeontropy'), findsNothing);
      expect(find.text(l10n.profileDeletedAccountName), findsWidgets);
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
}) {
  return ProviderScope(
    overrides: [
      isFeatureEnabledProvider(
        FeatureFlag.curatedLists,
      ).overrideWithValue(curatedListsEnabled),
      ...extraOverrides,
    ],
    child: BlocProvider<PeopleListsBloc>(
      create: (_) => createBloc(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showNewPeopleListSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}
