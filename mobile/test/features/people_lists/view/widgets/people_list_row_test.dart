// ABOUTME: Widget tests for PeopleListRow: the list's collage, name and
// ABOUTME: member count, the check while picked, and the pick toggled on tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_row.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_picker_row.dart';

import '../../../../helpers/test_provider_overrides.dart';

// Full-length Nostr pubkeys — never truncate.
const String _memberPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _otherPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

UserList _buildList({List<String> pubkeys = const []}) => UserList(
  id: 'list-1',
  name: 'Close Friends',
  pubkeys: pubkeys,
  createdAt: _frozenNow,
  updatedAt: _frozenNow,
);

Finder _check() => find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == DivineIconName.check,
);

void main() {
  group(PeopleListRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late PeopleListPicksCubit cubit;

    setUp(() {
      cubit = PeopleListPicksCubit(memberListIds: const {});
    });

    tearDown(() => cubit.close());

    Widget buildSubject(UserList list) => ProviderScope(
      overrides: getStandardTestOverrides(),
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PeopleListPicksCubit>.value(
            value: cubit,
            child: PeopleListRow(list: list),
          ),
        ),
      ),
    );

    testWidgets('renders the name, the member count and the collage', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(_buildList(pubkeys: const [_memberPubkey])),
      );

      expect(find.text('Close Friends'), findsOneWidget);
      expect(find.text(l10n.listMemberCount(1)), findsOneWidget);
      expect(find.byType(DivineListMedia), findsOneWidget);
      expect(find.byType(ListPickerRow), findsOneWidget);
    });

    testWidgets('drops the count badge the gallery card draws, since the row '
        'says the count itself', (tester) async {
      // Two members: the card's badge would read "2" on its own, apart from
      // the "2 members" line.
      await tester.pumpWidget(
        buildSubject(_buildList(pubkeys: const [_memberPubkey, _otherPubkey])),
      );

      expect(find.text(l10n.listMemberCount(2)), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('shows a check while the list is picked', (tester) async {
      cubit.toggled('list-1');

      await tester.pumpWidget(buildSubject(_buildList()));

      expect(_check(), findsOneWidget);
    });

    testWidgets('shows no check while the list is not picked', (tester) async {
      await tester.pumpWidget(buildSubject(_buildList()));

      expect(_check(), findsNothing);
    });

    testWidgets('tapping toggles the pick without writing anything', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(_buildList()));

      await tester.tap(find.text('Close Friends'));
      await tester.pump();

      expect(cubit.state.selectedListIds, {'list-1'});
      expect(_check(), findsOneWidget);
    });
  });
}
