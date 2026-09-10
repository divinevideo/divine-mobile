// ABOUTME: Tests curated-list cards expose owned-list visibility.
// ABOUTME: Prevents public/private state from becoming invisible again.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/list_card.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group(CuratedListCard, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildSubject({required bool isPublic, String? pubkey}) {
      final now = DateTime(2026);
      return ProviderScope(
        overrides: [...getStandardTestOverrides()],
        child: MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CuratedListCard(
              curatedList: CuratedList(
                id: 'puppets',
                name: 'Puppets',
                pubkey: pubkey,
                videoEventIds: const [],
                createdAt: now,
                updatedAt: now,
                isPublic: isPublic,
              ),
              showVisibility: true,
              onTap: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('labels a public list', (tester) async {
      await tester.pumpWidget(buildSubject(isPublic: true));

      expect(find.text(l10n.listVisibilityPublic), findsOneWidget);
    });

    testWidgets('labels a private list as device-only', (tester) async {
      await tester.pumpWidget(buildSubject(isPublic: false));

      expect(find.text(l10n.listVisibilityPrivate), findsOneWidget);
    });

    testWidgets('shows the list author when available', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          isPublic: true,
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );

      expect(find.text(l10n.listByAuthorPrefix), findsOneWidget);
    });

    testWidgets('omits the list author when unavailable', (tester) async {
      await tester.pumpWidget(buildSubject(isPublic: true));

      expect(find.text(l10n.listByAuthorPrefix), findsNothing);
    });
  });
}
