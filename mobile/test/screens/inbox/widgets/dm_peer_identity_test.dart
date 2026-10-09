// ABOUTME: Tests the shared DM peer identity resolution order.
// ABOUTME: Pins vanished, override, moderation, profile, and fallback branches.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Widget buildSubject(String Function(BuildContext context) resolve) {
    return testMaterialApp(
      home: Builder(
        builder: (context) => Text(resolve(context)),
      ),
    );
  }

  group('dmPeerDisplayName', () {
    testWidgets('vanished state wins over every identity branch', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: true,
            moderation: ModerationPresentation.official,
            displayNameOverride: 'Override',
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Deleted account'), findsOneWidget);
    });

    testWidgets('override wins over moderation and profile', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            moderation: ModerationPresentation.official,
            displayNameOverride: 'Override',
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Override'), findsOneWidget);
    });

    testWidgets('moderation wins over profile', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            moderation: ModerationPresentation.official,
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Divine Moderation'), findsOneWidget);
    });

    // Official branding follows recorded custody (#9963): a retired key
    // someone could still sign as is named neutrally, whatever name its holder
    // published, and never as Divine.
    testWidgets('a former moderation key gets the neutral label', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
            moderation: ModerationPresentation.former,
            profile: _profile(pubkey, l10n.inboxSupportRowTitle),
          ),
        ),
      );

      expect(find.text(l10n.dmFormerModerationAccountName), findsOneWidget);
      expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
    });

    testWidgets('profile wins over generated fallback', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
            moderation: ModerationPresentation.ordinary,
            profile: _profile(pubkey, 'Profile'),
          ),
        ),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('withholds a generated profile fallback while resolving', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
            moderation: ModerationPresentation.ordinary,
            profile: _profile(pubkey, ''),
            isResolving: true,
          ),
        ),
      );

      expect(
        find.text(UserProfile.defaultDisplayNameFor(pubkey)),
        findsNothing,
      );
      expect(find.text(''), findsOneWidget);
    });

    testWidgets('generates a name when no identity is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
            moderation: ModerationPresentation.ordinary,
          ),
        ),
      );

      expect(
        find.text(UserProfile.defaultDisplayNameFor(pubkey)),
        findsOneWidget,
      );
    });
  });

  group('dmConversationDisplayTitle', () {
    const me =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const bob =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const carol =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

    testWidgets('a 1:1 renders the peer name it was handed', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmConversationDisplayTitle(
            context,
            participantPubkeys: const [me, pubkey],
            currentUserPubkey: me,
            isGroup: false,
            peerName: 'Alice',
            subject: 'Weekend trip',
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('a titled group renders its NIP-17 subject', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmConversationDisplayTitle(
            context,
            participantPubkeys: const [me, pubkey, bob],
            currentUserPubkey: me,
            isGroup: true,
            peerName: 'Alice',
            subject: 'Weekend trip',
          ),
        ),
      );

      expect(find.text('Weekend trip'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('an untitled 3-person group counts one other', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(
          (context) => dmConversationDisplayTitle(
            context,
            participantPubkeys: const [me, pubkey, bob],
            currentUserPubkey: me,
            isGroup: true,
            peerName: 'Alice',
          ),
        ),
      );

      expect(
        find.text(l10n.inboxGroupConversationTitle('Alice', 1)),
        findsOneWidget,
      );
    });

    // The viewer is in `participantPubkeys`; counting them would tell the
    // third member of a room that two OTHER people are in it with them.
    testWidgets('never counts the viewer among the others', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(
          (context) => dmConversationDisplayTitle(
            context,
            participantPubkeys: const [me, pubkey, bob, carol],
            currentUserPubkey: me,
            isGroup: true,
            peerName: 'Alice',
          ),
        ),
      );

      expect(
        find.text(l10n.inboxGroupConversationTitle('Alice', 2)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.inboxGroupConversationTitle('Alice', 3)),
        findsNothing,
      );
    });
  });

  group('dmPeerNameWithoutProfile', () {
    testWidgets('returns null when a profile lookup is still needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) =>
              dmPeerNameWithoutProfile(
                context,
                isVanished: false,
                moderation: ModerationPresentation.ordinary,
              ) ??
              'lookup required',
        ),
      );

      expect(find.text('lookup required'), findsOneWidget);
    });

    testWidgets('names a former moderation key without a profile lookup', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(
          (context) =>
              dmPeerNameWithoutProfile(
                context,
                isVanished: false,
                moderation: ModerationPresentation.former,
              ) ??
              'lookup required',
        ),
      );

      expect(find.text(l10n.dmFormerModerationAccountName), findsOneWidget);
    });
  });

  group('dmPeerAvatar', () {
    const picture = 'https://example.invalid/peer.png';

    test("keeps a live peer's picture and adds no override", () {
      final avatar = dmPeerAvatar(
        isVanished: false,
        moderation: ModerationPresentation.ordinary,
        pictureUrl: picture,
      );

      expect(avatar.imageUrl, picture);
      expect(avatar.contentOverride, isNull);
    });

    test("drops a vanished peer's picture", () {
      final avatar = dmPeerAvatar(
        isVanished: true,
        moderation: ModerationPresentation.ordinary,
        pictureUrl: picture,
      );

      expect(avatar.imageUrl, isNull);
    });

    test('substitutes the bundled wordmark for an official moderation key', () {
      final avatar = dmPeerAvatar(
        isVanished: false,
        moderation: ModerationPresentation.official,
        pictureUrl: picture,
      );

      expect(avatar.contentOverride, isA<ModerationAvatar>());
    });

    // Neutral means neutral: no wordmark, and not whatever picture the key's
    // holder published either, because for a compromised key that is exactly
    // what an attacker would choose (#9963).
    test('a former moderation key gets no wordmark and no picture', () {
      final avatar = dmPeerAvatar(
        isVanished: false,
        moderation: ModerationPresentation.former,
        pictureUrl: picture,
      );

      expect(avatar.contentOverride, isNull);
      expect(avatar.imageUrl, isNull);
    });

    test('a vanish drops the picture even for the moderation account', () {
      final avatar = dmPeerAvatar(
        isVanished: true,
        moderation: ModerationPresentation.official,
        pictureUrl: picture,
      );

      expect(avatar.imageUrl, isNull);
    });
  });
}

UserProfile _profile(String pubkey, String displayName) => UserProfile(
  pubkey: pubkey,
  displayName: displayName,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);
