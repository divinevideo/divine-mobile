// ABOUTME: Tests the shared owned-list card opens the list's feed on tap.
// ABOUTME: Pins the route and extra both My Lists surfaces rely on.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/widgets/owned_list_card.dart';

import '../helpers/go_router.dart';

void main() {
  group(OwnedListCard, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    CuratedList buildList({bool isPublic = true}) {
      final now = DateTime(2026);
      return CuratedList(
        id: 'puppets',
        name: 'Puppets',
        // Owned lists always carry the owner's pubkey — CuratedListService
        // stamps it at creation — so the fixture must too.
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        videoEventIds: const [],
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
      );
    }

    Widget buildSubject({VoidCallback? onTap, bool isPublic = true}) {
      return MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: Scaffold(
            body: OwnedListCard(
              curatedList: buildList(isPublic: isPublic),
              onTap: onTap,
            ),
          ),
        ),
      );
    }

    testWidgets('opens the list feed with its name', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Puppets'));
      await tester.pump();

      final captured = verify(
        () => mockGoRouter.push<Object?>(
          captureAny(),
          extra: captureAny(named: 'extra'),
        ),
      ).captured;

      expect(
        captured.first,
        equals(CuratedListFeedScreen.pathForId('puppets')),
      );
      expect(
        (captured.last as CuratedListRouteExtra).listName,
        equals('Puppets'),
      );
    });

    testWidgets('runs the host hook before navigating', (tester) async {
      var hookRan = false;

      await tester.pumpWidget(buildSubject(onTap: () => hookRan = true));
      await tester.tap(find.text('Puppets'));
      await tester.pump();

      expect(hookRan, isTrue);
      verify(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).called(1);
    });

    testWidgets('shows visibility, which is why owners get this card', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isPublic: false));

      expect(find.text(l10n.listVisibilityPrivate), findsOneWidget);
    });

    testWidgets('does not credit the owner as the list author', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text(l10n.listByAuthorPrefix), findsNothing);
    });
  });
}
