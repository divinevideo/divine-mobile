// ABOUTME: Tests for PeopleListMembershipIndicator: flag/count gating + copy.
// ABOUTME: Uses mocked PeopleListsBloc state + overridden feature flag.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_membership_indicator.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

const _fullPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  group(PeopleListMembershipIndicator, () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({
      required bool flagEnabled,
      required PeopleListsState state,
    }) {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: state,
      );
      return ProviderScope(
        overrides: [
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWith((ref) => flagEnabled),
        ],
        child: BlocProvider<PeopleListsBloc>.value(
          value: bloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PeopleListMembershipIndicator(pubkey: _fullPubkey),
            ),
          ),
        ),
      );
    }

    testWidgets('renders SizedBox.shrink when flag is off', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          flagEnabled: false,
          state: const PeopleListsState(),
        ),
      );

      expect(find.textContaining('list'), findsNothing);
    });

    testWidgets(
      'renders SizedBox.shrink when count is 0',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            flagEnabled: true,
            state: const PeopleListsState(),
          ),
        );

        expect(find.textContaining('list'), findsNothing);
      },
    );

    testWidgets(
      'renders "In 1 list" when pubkey appears in exactly one list',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            flagEnabled: true,
            state: const PeopleListsState(
              listIdsByPubkey: {
                _fullPubkey: {'listA'},
              },
            ),
          ),
        );

        expect(find.text('In 1 list'), findsOneWidget);
      },
    );

    testWidgets(
      'renders "In 3 lists" when pubkey appears in three lists',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            flagEnabled: true,
            state: const PeopleListsState(
              listIdsByPubkey: {
                _fullPubkey: {'a', 'b', 'c'},
              },
            ),
          ),
        );

        expect(find.text('In 3 lists'), findsOneWidget);
      },
    );

    testWidgets(
      'accepts full 64-char pubkey without truncation',
      (tester) async {
        expect(_fullPubkey.length, equals(64));

        await tester.pumpWidget(
          buildSubject(
            flagEnabled: true,
            state: const PeopleListsState(
              listIdsByPubkey: {
                _fullPubkey: {'listA', 'listB'},
              },
            ),
          ),
        );

        expect(find.text('In 2 lists'), findsOneWidget);
      },
    );
  });
}
