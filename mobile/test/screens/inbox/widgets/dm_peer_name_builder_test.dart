// ABOUTME: Widget tests for DmPeerNameBuilder and its naming chain.
// ABOUTME: Pins that a group member is named exactly as the inbox row and the
// ABOUTME: thread header would name them.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/moderation_presentation.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_name_builder.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  const pubkey =
      '3333333333333333333333333333333333333333333333333333333333333333';
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(DmPeerNameBuilder, () {
    Future<DmPeerNameResolution> resolve(
      WidgetTester tester, {
      UserProfile? profile,
      bool isVanished = false,
      bool isResolving = false,
      ModerationPresentation moderation = ModerationPresentation.ordinary,
    }) async {
      late DmPeerNameResolution resolution;
      final overrides = <Override>[
        fetchUserProfileProvider(pubkey).overrideWith((ref) async => profile),
        profileVanishedProvider(pubkey).overrideWith((ref) => isVanished),
        profileIdentityResolvingProvider(
          pubkey,
        ).overrideWithValue(isResolving),
        moderationPresentationProvider(pubkey).overrideWithValue(moderation),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DmPeerNameBuilder(
              pubkey: pubkey,
              builder: (context, name) {
                resolution = name;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return resolution;
    }

    UserProfile profileNamed(String name) => UserProfile(
      pubkey: pubkey,
      displayName: name,
      rawData: const {},
      createdAt: DateTime(2026),
      eventId: 'c' * 64,
    );

    testWidgets('names a member by their profile', (tester) async {
      final name = await resolve(tester, profile: profileNamed('Bob'));

      expect(name.name, equals('Bob'));
      expect(name.isResolving, isFalse);
    });

    testWidgets('falls back to the generated name once resolution settles', (
      tester,
    ) async {
      final name = await resolve(tester);

      expect(name.name, equals(UserProfile.defaultDisplayNameFor(pubkey)));
      expect(name.isResolving, isFalse);
    });

    testWidgets('withholds the generated name while the profile resolves', (
      tester,
    ) async {
      final name = await resolve(tester, isResolving: true);

      expect(name.name, isEmpty);
      expect(name.isResolving, isTrue);
      expect(
        name.visualName,
        equals(UserProfile.defaultDisplayNameFor(pubkey)),
      );
    });

    testWidgets('a vanished member is a deleted account, not their last name', (
      tester,
    ) async {
      final name = await resolve(
        tester,
        profile: profileNamed('Bob'),
        isVanished: true,
      );

      expect(name.name, equals(l10n.profileDeletedAccountName));
    });

    testWidgets('an official moderation key is named for Divine, not by its '
        'own kind-0', (tester) async {
      final name = await resolve(
        tester,
        profile: profileNamed('Looks Official'),
        moderation: ModerationPresentation.official,
      );

      expect(name.name, equals(l10n.inboxSupportRowTitle));
    });

    testWidgets('a former moderation key gets the neutral name', (
      tester,
    ) async {
      final name = await resolve(
        tester,
        profile: profileNamed('Looks Official'),
        moderation: ModerationPresentation.former,
      );

      expect(name.name, equals(l10n.dmFormerModerationAccountName));
    });
  });
}
