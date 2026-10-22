// ABOUTME: Widget tests for FollowerCountTitle: the count line's copy, and
// ABOUTME: that it follows the count as the state moves.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';

import '../../helpers/test_provider_overrides.dart';

class _CountCubit extends Cubit<int> {
  _CountCubit(super.initialState);

  void set(int value) => emit(value);
}

void main() {
  group(FollowerCountTitle, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<_CountCubit> pumpTitle(
      WidgetTester tester, {
      required int count,
      String Function(BuildContext context, int count)? countLabel,
    }) async {
      final cubit = _CountCubit(count);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<_CountCubit>.value(
            value: cubit,
            child: Scaffold(
              body: countLabel == null
                  ? FollowerCountTitle<_CountCubit, int>(
                      title: 'Following',
                      selector: (state) => state,
                    )
                  : FollowerCountTitle<_CountCubit, int>(
                      title: 'Following',
                      selector: (state) => state,
                      countLabel: countLabel,
                    ),
            ),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('counts users by default', (tester) async {
      await pumpTitle(tester, count: 3);

      expect(find.text('Following'), findsOneWidget);
      expect(find.text(l10n.profileFollowerCountUsers(3)), findsOneWidget);
    });

    testWidgets('renders the count line a caller hands it', (tester) async {
      await pumpTitle(
        tester,
        count: 2,
        countLabel: (context, count) => context.l10n.listMemberCount(count),
      );

      expect(find.text(l10n.listMemberCount(2)), findsOneWidget);
      expect(find.text(l10n.profileFollowerCountUsers(2)), findsNothing);
    });

    testWidgets('follows the count as the state moves', (tester) async {
      final cubit = await pumpTitle(tester, count: 1);
      expect(find.text(l10n.profileFollowerCountUsers(1)), findsOneWidget);

      cubit.set(4);
      await tester.pump();

      expect(find.text(l10n.profileFollowerCountUsers(4)), findsOneWidget);
      expect(find.text(l10n.profileFollowerCountUsers(1)), findsNothing);
    });
  });
}
