// ABOUTME: Widget tests for the inbox Badges tab — only undecided awards are
// ABOUTME: listed, and accepting one publishes through the repository.

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/view/pending_badge_awards_view.dart';

import '../../helpers/badge_fixtures.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(PendingBadgeAwardsView, () {
    late _MockBadgeRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(badgeAwardFixture(isAccepted: false));
    });

    setUp(() {
      repository = _MockBadgeRepository();
    });

    void stubDashboard(List<BadgeAwardViewData> awarded) {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: awarded,
          issued: const [],
          created: const [],
        ),
      );
    }

    Widget buildSubject() {
      return testMaterialApp(
        home: BlocProvider(
          create: (_) => BadgesCubit(repository: repository)..load(),
          child: const PendingBadgeAwardsView(),
        ),
      );
    }

    testWidgets('lists an award that is waiting on a decision', (tester) async {
      stubDashboard([badgeAwardFixture(isAccepted: false)]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Diviner of the Day'), findsOneWidget);
      expect(find.text(l10n.badgesActionAccept), findsOneWidget);
    });

    testWidgets('leaves an already-accepted award out of the queue', (
      tester,
    ) async {
      stubDashboard([
        badgeAwardFixture(isAccepted: true, name: 'Already Mine'),
        badgeAwardFixture(
          isAccepted: false,
          name: 'Still Waiting',
          dTag: 'weekly-diviner',
          seed: 2,
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Still Waiting'), findsOneWidget);
      expect(find.text('Already Mine'), findsNothing);
    });

    testWidgets('shows the empty message when nothing is waiting', (
      tester,
    ) async {
      stubDashboard([badgeAwardFixture(isAccepted: true)]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.notificationsBadgesEmpty), findsOneWidget);
    });

    testWidgets('accepting an award publishes through the repository', (
      tester,
    ) async {
      final award = badgeAwardFixture(isAccepted: false);
      stubDashboard([award]);
      when(() => repository.acceptAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesActionAccept));
      await tester.pumpAndSettle();

      verify(() => repository.acceptAward(award)).called(1);
    });
  });
}
