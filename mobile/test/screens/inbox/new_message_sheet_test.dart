// ABOUTME: Pins the new-message picker to the shared DM peer naming chain.
// ABOUTME: A send-target row must name and picture its peer exactly as the
// ABOUTME: inbox row for the same pubkey does (#8421).

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/retired_key_custody.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(NewMessageSheet, () {
    const currentUserPubkey =
        'facade00facade00facade00facade00facade00facade00facade00facade00';
    const vanishedPubkey =
        'b75b9a3131f4263add94ba20beb352a11032684f2dac07a7e1af827c6f3c1505';

    late _MockProfileRepository profileRepository;
    late _MockFollowRepository followRepository;
    late AppLocalizations l10n;

    setUp(() {
      profileRepository = _MockProfileRepository();
      followRepository = _MockFollowRepository();
      l10n = lookupAppLocalizations(const Locale('en'));
      when(
        profileRepository.watchVanishedPubkeys,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
    });

    UserProfile profileFor(
      String pubkey,
      String displayName, {
      String? name,
    }) => UserProfile(
      pubkey: pubkey,
      displayName: displayName,
      name: name,
      picture: 'https://example.invalid/$pubkey.png',
      rawData: const {},
      createdAt: DateTime(2026),
      eventId:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    Future<void> pumpPickerWith(
      WidgetTester tester, {
      required UserProfile contact,
      bool isVanished = false,
      List<Override> extraOverrides = const [],
    }) async {
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn([contact.pubkey]);
      when(
        () => profileRepository.getCachedProfile(pubkey: contact.pubkey),
      ).thenAnswer((_) async => contact);

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            profileVanishedProvider(
              contact.pubkey,
            ).overrideWith((ref) => isVanished),
            ...extraOverrides,
          ],
          home: NewMessageSheet(
            profileRepository: profileRepository,
            followRepository: followRepository,
            currentUserPubkey: currentUserPubkey,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('names a vanished peer "Deleted account", not their kind-0 '
          'name', (tester) async {
        await pumpPickerWith(
          tester,
          contact: profileFor(vanishedPubkey, 'Aeontropy'),
          isVanished: true,
        );

        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        // The whole point: the picker's search reaches third-party NIP-50
        // relays a vanish addressed elsewhere never obliged to forget, so the
        // real name is genuinely available here and must not be rendered.
        expect(find.text('Aeontropy'), findsNothing);
      });

      testWidgets("loads a live peer's photo", (tester) async {
        // The control for the vanish case below: without it, a green
        // `findsNothing` there could just mean the finder is dead.
        await pumpPickerWith(
          tester,
          contact: profileFor(vanishedPubkey, 'Aeontropy'),
        );

        expect(find.byType(VineCachedImage), findsOneWidget);
      });

      testWidgets("drops a vanished peer's photo, not just their name", (
        tester,
      ) async {
        await pumpPickerWith(
          tester,
          contact: profileFor(vanishedPubkey, 'Aeontropy'),
          isVanished: true,
        );

        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('gives the moderation account its bundled wordmark', (
        tester,
      ) async {
        await pumpPickerWith(
          tester,
          contact: profileFor(kModerationPubkeyHex, 'Divine Moderation'),
        );

        expect(find.byType(ModerationAvatar), findsOneWidget);
      });

      testWidgets('names the moderation account from the shared label, not '
          'its kind-0 name', (tester) async {
        // The current key's kind 0 happens to match the label, so a raw render
        // is indistinguishable today. Give it a different one: the row must
        // still read "Divine Moderation".
        await pumpPickerWith(
          tester,
          contact: profileFor(kModerationPubkeyHex, 'moderation-bot-v2'),
        );

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(find.text('moderation-bot-v2'), findsNothing);
      });

      // Official branding follows recorded custody (#9963). The picker shares
      // the inbox row's helpers, so a withdrawn key must read the same here.
      for (final custody in keptCustodies) {
        testWidgets("${custody.name}: Divine's name and wordmark", (
          tester,
        ) async {
          await pumpPickerWith(
            tester,
            contact: profileFor(shippedRetiredKey, 'Looks Official'),
            extraOverrides: [retiredKeyCustody(custody)],
          );

          expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
          expect(find.byType(ModerationAvatar), findsOneWidget);
        });
      }

      for (final custody in withdrawnCustodies) {
        testWidgets('${custody.name}: neutral label, no wordmark, no photo', (
          tester,
        ) async {
          await pumpPickerWith(
            tester,
            contact: profileFor(shippedRetiredKey, 'Looks Official'),
            extraOverrides: [retiredKeyCustody(custody)],
          );

          expect(find.text(l10n.dmFormerModerationAccountName), findsOneWidget);
          expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
          expect(find.text('Looks Official'), findsNothing);
          expect(find.byType(ModerationAvatar), findsNothing);
          expect(find.byType(VineCachedImage), findsNothing);
        });
      }

      // With no NIP-05 the handle line falls back to the kind-0 `name`.
      for (final custody in keptCustodies) {
        testWidgets('${custody.name}: shows the handle the key published', (
          tester,
        ) async {
          await pumpPickerWith(
            tester,
            contact: profileFor(
              shippedRetiredKey,
              'Looks Official',
              name: 'looks_official',
            ),
            extraOverrides: [retiredKeyCustody(custody)],
          );

          expect(find.text('@looks_official'), findsOneWidget);
        });
      }

      for (final custody in withdrawnCustodies) {
        testWidgets('${custody.name}: hides the handle its holder chose', (
          tester,
        ) async {
          await pumpPickerWith(
            tester,
            contact: profileFor(
              shippedRetiredKey,
              'Looks Official',
              name: 'looks_official',
            ),
            extraOverrides: [retiredKeyCustody(custody)],
          );

          expect(find.text('@looks_official'), findsNothing);
        });
      }

      testWidgets('renders an ordinary peer under their own name', (
        tester,
      ) async {
        const peer =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        await pumpPickerWith(tester, contact: profileFor(peer, 'Alice'));

        expect(find.text('Alice'), findsOneWidget);
      });
    });
  });
}
