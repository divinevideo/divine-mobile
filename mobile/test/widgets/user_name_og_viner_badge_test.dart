// ABOUTME: Tests UserName OG Viner badge display from the local cache.
// ABOUTME: Keeps badge rendering tied to known cached pubkeys only.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Future<Widget> buildSubject({required bool cachedOgViner}) async {
    SharedPreferences.setMockInitialValues({
      if (cachedOgViner) ogVinerPubkeysCacheKey: jsonEncode([pubkey]),
    });
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: UserName.fromUserProfile(
              UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              ),
            ),
          ),
        ),
      ),
    );
  }

  group(OgVinerBadge, () {
    testWidgets('shows OG Viner badge for cached pubkey', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(await buildSubject(cachedOgViner: true));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      final data = tester
          .getSemantics(find.byType(OgVinerBadge))
          .getSemanticsData();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(data.label, l10n.ogVinerBadgeLabel);
      expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('does not open explanation sheet when tapped inline', (
      tester,
    ) async {
      await tester.pumpWidget(await buildSubject(cachedOgViner: true));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('V'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBadgeOgVinerBody), findsNothing);
      expect(find.text(l10n.commonClose), findsNothing);
    });

    testWidgets('hides OG Viner badge for unknown pubkey', (tester) async {
      await tester.pumpWidget(await buildSubject(cachedOgViner: false));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('V'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == l10n.ogVinerBadgeLabel,
        ),
        findsNothing,
      );
    });
  });
}
