// ABOUTME: Tests UserName OG Beta Tester badge display from the frozen roster.
// ABOUTME: Pins roster membership and OG Viner precedence at the render site.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final rosterPubkey = ogBetaTesterPubkeys.first;
  const strangerPubkey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  Future<Widget> buildSubject({
    required String pubkey,
    bool cachedOgViner = false,
    bool showProfileBadges = true,
  }) async {
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
              showProfileBadges: showProfileBadges,
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

  group('renders', () {
    testWidgets('shows OG Beta Tester badge for a roster pubkey', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      final data = tester
          .getSemantics(find.byType(OgBetaBadge))
          .getSemanticsData();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('OG'), findsOneWidget);
      expect(data.label, l10n.ogBetaTesterBadgeLabel);
      // The chit announces itself as a button, so it has to carry the action
      // that makes one activatable. Declaring the flag without the action
      // leaves a screen reader saying "button" over something it cannot open.
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('shows OG Beta Tester for a non-team roster member', (
      tester,
    ) async {
      final pubkey = ogBetaTesterPubkeys.firstWhere(
        (candidate) => !kDivineTeamPubkeys.contains(candidate),
      );
      await tester.pumpWidget(await buildSubject(pubkey: pubkey));
      await tester.pump();

      expect(find.byType(SpecialProfileCheckmark), findsNothing);
      expect(find.byType(OgBetaBadge), findsOneWidget);
    });

    testWidgets('a screen reader can open the explainer, not just a finger', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));

      // `tester.tap` sends a pointer, which reaches the GestureDetector through
      // hit testing whether or not the semantics tree exposes it. Activating
      // through the semantics owner is what VoiceOver and TalkBack actually do,
      // and it is the path `ExcludeSemantics` around the detector removes.
      final node = tester.getSemantics(find.byType(OgBetaBadge));
      SemanticsOwner? owner;
      tester.binding.rootPipelineOwner.visitChildren((child) {
        owner ??= child.semanticsOwner;
      });
      owner!.performAction(node.id, ui.SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBadgeOgBetaTesterBody), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders the glyph in a real ExtraBold face, not fake bold', (
      tester,
    ) async {
      await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
      await tester.pump();

      final style = tester.widget<Text>(find.text('OG')).style!;

      // Inter is bundled at 400/600 only, so a w800 against it would be
      // synthesised by Skia. Bricolage Grotesque ships a real ExtraBold.
      expect(style.fontFamily, contains('BricolageGrotesque'));
      expect(style.fontWeight, FontWeight.w800);
    });

    testWidgets('hides the badge for a pubkey off the roster', (tester) async {
      await tester.pumpWidget(await buildSubject(pubkey: strangerPubkey));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('opens the explainer when the inline chit is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('OG'));
      await tester.pumpAndSettle();

      // The disclaimer is the point: a filled brand-primary circle beside a
      // name reads as verified, so it has to be reachable from every surface
      // the chit appears on, not just the profile header.
      expect(find.text(l10n.profileBadgeOgBetaTesterBody), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
    });

    testWidgets('hides the badge when showProfileBadges is false', (
      tester,
    ) async {
      // The profile header passes false and renders its own full-size,
      // tappable explanation button instead of the inline chit.
      await tester.pumpWidget(
        await buildSubject(pubkey: rosterPubkey, showProfileBadges: false),
      );
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('yields to the profile checkmark so only one chit renders', (
      tester,
    ) async {
      // Many team accounts also appear on the beta roster, so this overlap is
      // the default for Divine team accounts, not an edge.
      final overlapping = kDivineTeamPubkeys
          .where(isOgBetaTesterPubkey)
          .toList();
      expect(
        overlapping,
        isNotEmpty,
        reason: 'no checkmark pubkey is on the roster, so this cannot regress',
      );

      await tester.pumpWidget(await buildSubject(pubkey: overlapping.first));
      await tester.pump();

      expect(find.byType(SpecialProfileCheckmark), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('yields to the OG Viner badge so only one chit renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        await buildSubject(pubkey: rosterPubkey, cachedOgViner: true),
      );
      await tester.pump();

      expect(find.byType(OgVinerBadge), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });
  });
}
