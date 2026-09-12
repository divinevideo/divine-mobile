// ABOUTME: Pins the non-DM vanished-account substitution.
// ABOUTME: Narrower than the DM chain on purpose — no moderation step.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  Widget buildSubject(String Function(BuildContext context) resolve) {
    return testMaterialApp(
      home: Builder(builder: (context) => Text(resolve(context))),
    );
  }

  group('vanishedAccountName', () {
    testWidgets('substitutes the deleted-account label when vanished', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => vanishedAccountName(
            context,
            isVanished: true,
            fallbackName: 'Aeontropy',
          ),
        ),
      );

      expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
      expect(find.text('Aeontropy'), findsNothing);
    });

    testWidgets('returns the caller name when not vanished', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => vanishedAccountName(
            context,
            isVanished: false,
            fallbackName: 'Aeontropy',
          ),
        ),
      );

      expect(find.text('Aeontropy'), findsOneWidget);
    });

    testWidgets('leaves the moderation account alone', (tester) async {
      // The moderation substitution is scoped to DM surfaces
      // (moderation_identity.dart). A people picker naming an account
      // "Divine Moderation" would invent an identity the rest of the app does
      // not use outside the inbox.
      await tester.pumpWidget(
        buildSubject(
          (context) => vanishedAccountName(
            context,
            isVanished: false,
            fallbackName: 'moderation-bot-v2',
          ),
        ),
      );

      expect(find.text('moderation-bot-v2'), findsOneWidget);
      expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
    });
  });

  group('vanishedAccountNameFrom', () {
    test('substitutes the supplied label when vanished', () {
      expect(
        vanishedAccountNameFrom(
          isVanished: true,
          deletedAccountLabel: 'Deleted account',
          fallbackName: 'Aeontropy',
        ),
        'Deleted account',
      );
    });

    test('returns the caller name when not vanished', () {
      expect(
        vanishedAccountNameFrom(
          isVanished: false,
          deletedAccountLabel: 'Deleted account',
          fallbackName: 'Aeontropy',
        ),
        'Aeontropy',
      );
    });

    test('agrees with the context-taking variant for a moderation key', () {
      expect(
        vanishedAccountNameFrom(
          isVanished: false,
          deletedAccountLabel: 'Deleted account',
          fallbackName: kModerationPubkeyHex,
        ),
        kModerationPubkeyHex,
      );
    });
  });

  group('vanishedAccountPictureUrl', () {
    test('drops the picture when vanished', () {
      expect(
        vanishedAccountPictureUrl(
          isVanished: true,
          pictureUrl: 'https://example.invalid/a.png',
        ),
        isNull,
      );
    });

    test('keeps the picture when not vanished', () {
      expect(
        vanishedAccountPictureUrl(
          isVanished: false,
          pictureUrl: 'https://example.invalid/a.png',
        ),
        'https://example.invalid/a.png',
      );
    });

    test('tolerates a profile that has no picture', () {
      expect(vanishedAccountPictureUrl(isVanished: false), isNull);
    });
  });
}
