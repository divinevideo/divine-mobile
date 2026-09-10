// ABOUTME: Widget tests for SearchableFollowList.
// ABOUTME: Covers the search field, the filtered rows and the no-match copy.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/searchable_follow_list.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex pubkeys — never truncate in app code, logs, or
// stored state. Full IDs only.
const String _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const List<String> _allPubkeys = [_alicePubkey, _bobPubkey];

/// Long enough to clear the 300 ms search debounce.
const _pastDebounce = Duration(milliseconds: 400);

UserProfile _profile({required String pubkey, required String displayName}) {
  return UserProfile(
    pubkey: pubkey,
    displayName: displayName,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'event_for_$pubkey',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FollowListKind.followers);
  });

  group(SearchableFollowList, () {
    late _MockProfileRepository profileRepository;
    late _MockFollowRepository followRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      followRepository = _MockFollowRepository();
      when(
        () => followRepository.searchFollowList(
          pubkey: any(named: 'pubkey'),
          query: any(named: 'query'),
          kind: any(named: 'kind'),
        ),
      ).thenAnswer((_) async => const <String>{});
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer(
        (_) async => {
          _alicePubkey: _profile(pubkey: _alicePubkey, displayName: 'Alice'),
          _bobPubkey: _profile(pubkey: _bobPubkey, displayName: 'Bob'),
        },
      );
    });

    Widget buildTestWidget({List<String> pubkeys = _allPubkeys}) {
      return MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider(
            create: (_) => FollowListSearchBloc(
              followRepository: followRepository,
              subjectPubkey: _alicePubkey,
              listKind: FollowListKind.followers,
              profileRepository: profileRepository,
            ),
            child: SearchableFollowList(
              pubkeys: pubkeys,
              onRefresh: () async {},
              itemBuilder: (context, pubkey, index) => Text(pubkey),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the search hint and every row', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.exploreSearchHint), findsOneWidget);
      expect(find.text(_alicePubkey), findsOneWidget);
      expect(find.text(_bobPubkey), findsOneWidget);
    });

    testWidgets('typing narrows the list to the matching row', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pump(_pastDebounce);
      await tester.pump();

      expect(find.text(_alicePubkey), findsOneWidget);
      expect(find.text(_bobPubkey), findsNothing);
    });

    testWidgets('shows the no-results copy when nothing matches', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(_pastDebounce);
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.searchNoResultsFound('zzz')), findsOneWidget);
      expect(find.text(_alicePubkey), findsNothing);
    });

    testWidgets('keeps pull-to-refresh reachable when nothing matches', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(_pastDebounce);
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      // The empty state must itself be scrollable, or the gesture never
      // reaches the indicator. Fling the copy rather than the TextField's own
      // scrollable.
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.fling(
        find.text(l10n.searchNoResultsFound('zzz')),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();

      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    });

    testWidgets('resolves names for rows added while a query is active', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(pubkeys: const [_alicePubkey]));

      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pump(_pastDebounce);
      await tester.pump();

      expect(find.text(_alicePubkey), findsNothing);

      // A refresh lands Bob in the list. His name was never resolved with the
      // original query, so without a re-dispatch he could only match his
      // generated fallback name.
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(_pastDebounce);
      await tester.pump();

      expect(find.text(_bobPubkey), findsOneWidget);
      expect(find.text(_alicePubkey), findsNothing);
    });
  });
}
