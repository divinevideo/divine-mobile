// ABOUTME: Widget tests for the new-message picker.
// ABOUTME: Pins it to the shared DM peer naming chain (#8421) and covers the
// ABOUTME: "New group" mode that hands back several people (#8269).

import 'dart:ui' show SemanticsFlags, Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/bloc/bloc.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/retired_key_custody.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// What `NewMessageSheet.show` handed back to the code that opened it.
class _SheetOutcome {
  bool didClose = false;
  List<UserProfile>? selected;
}

void main() {
  group(NewMessageSheet, () {
    const currentUserPubkey =
        'facade00facade00facade00facade00facade00facade00facade00facade00';
    const vanishedPubkey =
        'b75b9a3131f4263add94ba20beb352a11032684f2dac07a7e1af827c6f3c1505';
    const alicePubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const bobPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const carolPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

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

    /// A candidate with no picture, so a test that is not about artwork does
    /// not start an image request for every row.
    UserProfile candidate(String pubkey, String displayName) => UserProfile(
      pubkey: pubkey,
      displayName: displayName,
      rawData: const {},
      createdAt: DateTime(2026),
      eventId:
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    );

    void stubContacts(List<UserProfile> contacts) {
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn([for (final contact in contacts) contact.pubkey]);
      for (final contact in contacts) {
        when(
          () => profileRepository.getCachedProfile(pubkey: contact.pubkey),
        ).thenAnswer((_) async => contact);
      }
    }

    Future<void> pumpPickerWith(
      WidgetTester tester, {
      required UserProfile contact,
      bool isVanished = false,
      List<Override> extraOverrides = const [],
    }) async {
      stubContacts([contact]);

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
            allowGroups: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Opens the sheet through `NewMessageSheet.show`, the way the inbox does,
    /// so a test can read what the sheet hands back when it closes.
    Future<_SheetOutcome> openSheet(
      WidgetTester tester, {
      required bool allowGroups,
      required List<UserProfile> contacts,
      Set<String> vanishedPubkeys = const {},
      List<Override> extraOverrides = const [],
    }) async {
      stubContacts(contacts);
      final outcome = _SheetOutcome();

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            for (final pubkey in vanishedPubkeys)
              profileVanishedProvider(pubkey).overrideWith((ref) => true),
            ...extraOverrides,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    outcome.selected = await NewMessageSheet.show(
                      context,
                      profileRepository: profileRepository,
                      followRepository: followRepository,
                      currentUserPubkey: currentUserPubkey,
                      allowGroups: allowGroups,
                    );
                    outcome.didClose = true;
                  },
                  child: const SizedBox.square(dimension: 48),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      return outcome;
    }

    /// Makes room for a list long enough to fill a group without scrolling.
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// The row for [name] in the people list. Scoped to the list because a
    /// picked person's name is also on their chip.
    Finder personRow(String name) =>
        find.descendant(of: find.byType(ListView), matching: find.text(name));

    Finder chipFor(String name) =>
        find.bySemanticsLabel(l10n.userPickerRemoveSelectionSemantics(name));

    // Functions rather than values: a semantics finder cannot be built before
    // a test is running.
    Finder newGroupRow() =>
        find.bySemanticsIdentifier(SemanticIds.newMessageNewGroupRow);

    Finder startButton() =>
        find.bySemanticsIdentifier(SemanticIds.newMessageStartGroupButton);

    Future<void> enterGroupMode(WidgetTester tester) async {
      await tester.tap(newGroupRow());
      await tester.pumpAndSettle();
    }

    /// Taps [name]'s row and lets the picks strip finish easing open.
    Future<void> tapPerson(WidgetTester tester, String name) async {
      await tester.tap(personRow(name));
      await tester.pumpAndSettle();
    }

    /// The avatar drawn on [name]'s chip.
    UserAvatar chipAvatar(WidgetTester tester, String name) =>
        tester.widget<UserAvatar>(
          find.descendant(
            of: chipFor(name),
            matching: find.byType(UserAvatar),
          ),
        );

    /// The people list's own scroll position, apart from the picks strip.
    ScrollPosition peopleScrollPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    /// Enough contacts that the list has to scroll.
    List<UserProfile> manyContacts() => [
      for (var index = 1; index <= 30; index++)
        candidate(
          index.toRadixString(16).padLeft(2, '0') * 32,
          'Person $index',
        ),
    ];

    SemanticsFlags flagsOf(WidgetTester tester, Finder finder) =>
        tester.getSemantics(finder).getSemanticsData().flagsCollection;

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
        await pumpPickerWith(tester, contact: profileFor(alicePubkey, 'Alice'));

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('announces a person as one button named for them', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: false,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        expect(
          tester.getSemantics(personRow('Alice')),
          isSemantics(label: 'Alice', isButton: true, hasTapAction: true),
        );
        // Outside group mode a row has no selection to report.
        expect(flagsOf(tester, personRow('Alice')).isSelected, Tristate.none);
      });

      testWidgets('offers no group row when groups are not allowed', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: false,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        // The control: the sheet is up and listing people.
        expect(personRow('Alice'), findsOneWidget);
        expect(newGroupRow(), findsNothing);
        expect(find.text(l10n.newMessageNewGroup), findsNothing);
      });

      testWidgets('offers the group row above the people when groups are '
          'allowed', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        expect(newGroupRow(), findsOneWidget);
        expect(
          tester.getRect(find.text(l10n.newMessageNewGroup)).bottom,
          lessThanOrEqualTo(tester.getRect(personRow('Alice')).top),
        );
      });

      testWidgets('keeps the group row while searching', (tester) async {
        when(
          () => profileRepository.searchUsers(
            query: 'bo',
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => [candidate(bobPubkey, 'Bob')]);
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        await tester.enterText(find.byType(TextField), 'bo');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Bob only exists in the network result, so finding him proves the
        // list really is showing search results.
        expect(personRow('Bob'), findsOneWidget);
        expect(newGroupRow(), findsOneWidget);
      });

      testWidgets('shows no selection mark before group mode', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        expect(personRow('Alice'), findsOneWidget);
        expect(find.byType(DivineSpriteCheckbox), findsNothing);
      });

      testWidgets('titles the sheet for the group and offers a way back and a '
          'way forward', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        await enterGroupMode(tester);

        expect(find.text(l10n.newMessageTitle), findsNothing);
        // Once, as the title: the row that was tapped steps aside for it.
        expect(find.text(l10n.newMessageNewGroup), findsOneWidget);
        expect(newGroupRow(), findsNothing);
        expect(find.bySemanticsLabel(l10n.commonBack), findsOneWidget);
        expect(find.text(l10n.newMessageStartChat), findsOneWidget);
      });

      testWidgets('marks a picked person, for the eye and for a screen '
          'reader', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        await enterGroupMode(tester);
        expect(
          flagsOf(tester, personRow('Alice')).isSelected,
          Tristate.isFalse,
        );

        await tapPerson(tester, 'Alice');

        expect(flagsOf(tester, personRow('Alice')).isSelected, Tristate.isTrue);
        expect(flagsOf(tester, personRow('Bob')).isSelected, Tristate.isFalse);
        expect(
          tester
              .widgetList<DivineSpriteCheckbox>(
                find.byType(DivineSpriteCheckbox),
              )
              .map((checkbox) => checkbox.state),
          equals([
            DivineCheckboxState.selected,
            DivineCheckboxState.unselected,
          ]),
        );
      });

      testWidgets('lists picked people as chips between the search field and '
          'the people', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        await enterGroupMode(tester);

        await tapPerson(tester, 'Alice');

        final chip = tester.getRect(chipFor('Alice'));
        expect(
          chip.top,
          greaterThanOrEqualTo(tester.getRect(find.byType(TextField)).bottom),
        );
        expect(
          chip.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(ListView)).top),
        );
        // From the sheet's leading edge, not centred: a centred strip moves
        // every chip each time someone is picked.
        final leadingEdge =
            tester.getRect(find.byType(NewMessageSheet)).left + 16;
        expect(chip.left, equals(leadingEdge));

        await tapPerson(tester, 'Bob');

        for (final (index, name) in ['Alice', 'Bob'].indexed) {
          expect(
            tester
                .getSemantics(
                  find.bySemanticsIdentifier(
                    SemanticIds.newMessageRecipientChip(index),
                  ),
                )
                .label,
            equals(l10n.userPickerRemoveSelectionSemantics(name)),
          );
        }
        expect(tester.getRect(chipFor('Alice')).left, equals(leadingEdge));
      });

      testWidgets('names a vanished pick "Deleted account" on its chip too', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(vanishedPubkey, 'Aeontropy')],
          vanishedPubkeys: {vanishedPubkey},
        );
        await enterGroupMode(tester);

        await tapPerson(tester, l10n.profileDeletedAccountName);

        expect(chipFor(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('Aeontropy'), findsNothing);
      });

      testWidgets("drops a vanished pick's photo from its chip, not just "
          'their name', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            profileFor(vanishedPubkey, 'Aeontropy'),
            profileFor(alicePubkey, 'Alice'),
          ],
          vanishedPubkeys: {vanishedPubkey},
        );
        await enterGroupMode(tester);

        await tapPerson(tester, l10n.profileDeletedAccountName);
        await tapPerson(tester, 'Alice');

        // The control: a live pick's chip does get their photo.
        expect(chipAvatar(tester, 'Alice').imageUrl, isNotNull);
        expect(
          chipAvatar(tester, l10n.profileDeletedAccountName).imageUrl,
          isNull,
        );
      });

      // Official branding follows recorded custody (#9963), on the chip as
      // on the row it was picked from.
      testWidgets("keeps Divine's name and wordmark on the chip of a retired "
          'key nobody can sign as', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [profileFor(shippedRetiredKey, 'Looks Official')],
          extraOverrides: [retiredKeyCustody(keptCustodies.first)],
        );
        await enterGroupMode(tester);

        await tapPerson(tester, l10n.inboxSupportRowTitle);

        expect(
          chipAvatar(tester, l10n.inboxSupportRowTitle).contentOverride,
          isA<ModerationAvatar>(),
        );
      });

      testWidgets('gives a retired key someone could still sign as its '
          'neutral name, and no wordmark or photo, on its chip', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [profileFor(shippedRetiredKey, 'Looks Official')],
          extraOverrides: [retiredKeyCustody(withdrawnCustodies.first)],
        );
        await enterGroupMode(tester);

        await tapPerson(tester, l10n.dmFormerModerationAccountName);

        final avatar = chipAvatar(tester, l10n.dmFormerModerationAccountName);
        expect(avatar.contentOverride, isNull);
        expect(avatar.imageUrl, isNull);
        expect(find.text('Looks Official'), findsNothing);
      });

      group('start button placement', () {
        const surface = Size(800, 1200);

        Future<void> openGroupMode(WidgetTester tester) async {
          tester.view.physicalSize = surface;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await openSheet(
            tester,
            allowGroups: true,
            contacts: [candidate(alicePubkey, 'Alice')],
          );
          await enterGroupMode(tester);
        }

        testWidgets('sits at the bottom of the sheet, clear of the safe area', (
          tester,
        ) async {
          const safeAreaBottom = 34.0;
          tester.view.padding = const FakeViewPadding(bottom: safeAreaBottom);
          addTearDown(tester.view.resetPadding);
          await openGroupMode(tester);

          final button = tester.getRect(startButton());
          expect(
            button.bottom,
            lessThanOrEqualTo(surface.height - safeAreaBottom),
          );
          expect(
            button.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom),
          );
        });

        testWidgets('rides above the keyboard', (tester) async {
          const keyboardHeight = 300.0;
          await openGroupMode(tester);
          final restingBottom = tester.getRect(startButton()).bottom;
          expect(restingBottom, greaterThan(surface.height - keyboardHeight));

          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();

          expect(
            tester.getRect(startButton()).bottom,
            lessThanOrEqualTo(surface.height - keyboardHeight),
          );
        });
      });

      testWidgets('gives every group control a full-size tap target', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        expect(
          tester.getSize(newGroupRow()).height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');

        for (final control in [
          find.bySemanticsLabel(l10n.commonBack),
          chipFor('Alice'),
          startButton(),
        ]) {
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
          expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
        }
      });
    });

    group('interactions', () {
      testWidgets('one tap picks one person when groups are not allowed', (
        tester,
      ) async {
        final outcome = await openSheet(
          tester,
          allowGroups: false,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );

        await tester.tap(personRow('Bob'));
        await tester.pumpAndSettle();

        expect(outcome.didClose, isTrue);
        expect(
          outcome.selected?.map((profile) => profile.pubkey),
          equals([bobPubkey]),
        );
      });

      testWidgets('one tap still picks one person when groups are allowed', (
        tester,
      ) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );

        await tester.tap(personRow('Bob'));
        await tester.pumpAndSettle();

        expect(outcome.didClose, isTrue);
        expect(
          outcome.selected?.map((profile) => profile.pubkey),
          equals([bobPubkey]),
        );
      });

      testWidgets('dismissing the sheet hands back nothing', (tester) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );

        // The strip above the sheet is the modal barrier.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(outcome.didClose, isTrue);
        expect(outcome.selected, isNull);
      });

      testWidgets('picking a person in group mode keeps the sheet open', (
        tester,
      ) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );
        await enterGroupMode(tester);

        await tapPerson(tester, 'Alice');
        await tester.pumpAndSettle();

        expect(outcome.didClose, isFalse);
        expect(chipFor('Alice'), findsOneWidget);
      });

      testWidgets('will not start a group until two people are picked', (
        tester,
      ) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        await enterGroupMode(tester);
        expect(flagsOf(tester, startButton()).isEnabled, Tristate.isFalse);

        await tapPerson(tester, 'Alice');

        expect(flagsOf(tester, startButton()).isEnabled, Tristate.isFalse);
        await tester.tap(startButton(), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(outcome.didClose, isFalse);

        await tapPerson(tester, 'Bob');

        expect(flagsOf(tester, startButton()).isEnabled, Tristate.isTrue);
      });

      testWidgets('starts the group with the people picked, in the order they '
          'were picked', (tester) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
            candidate(carolPubkey, 'Carol'),
          ],
        );
        await enterGroupMode(tester);

        // Against the list's alphabetical order, so order-of-picking and
        // order-of-listing cannot both satisfy the assertion.
        await tapPerson(tester, 'Carol');
        await tapPerson(tester, 'Alice');
        await tester.tap(startButton());
        await tester.pumpAndSettle();

        expect(outcome.didClose, isTrue);
        expect(
          outcome.selected?.map((profile) => profile.pubkey),
          equals([carolPubkey, alicePubkey]),
        );
      });

      testWidgets('tapping a chip drops that person from the group', (
        tester,
      ) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');
        await tapPerson(tester, 'Bob');
        expect(chipFor('Alice'), findsOneWidget);

        await tester.tap(chipFor('Alice'));
        await tester.pump();

        expect(chipFor('Alice'), findsNothing);
        expect(chipFor('Bob'), findsOneWidget);
        expect(
          flagsOf(tester, personRow('Alice')).isSelected,
          Tristate.isFalse,
        );
        expect(flagsOf(tester, startButton()).isEnabled, Tristate.isFalse);
      });

      testWidgets('a chip is removed by a tap on its edge, not only on the '
          'pill', (tester) async {
        await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');
        final chip = tester.getRect(chipFor('Alice'));

        // One pixel inside the top edge: above the pill, inside the target.
        await tester.tapAt(chip.topCenter + const Offset(0, 1));
        await tester.pumpAndSettle();

        expect(chipFor('Alice'), findsNothing);
      });

      testWidgets('starts a group from a contact and a search result', (
        tester,
      ) async {
        when(
          () => profileRepository.searchUsers(
            query: 'bo',
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => [candidate(bobPubkey, 'Bob')]);
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [candidate(alicePubkey, 'Alice')],
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');

        await tester.enterText(find.byType(TextField), 'bo');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        // Alice is off the list now and still picked.
        expect(personRow('Alice'), findsNothing);
        expect(chipFor('Alice'), findsOneWidget);

        await tapPerson(tester, 'Bob');
        await tester.tap(startButton());
        await tester.pumpAndSettle();

        expect(
          outcome.selected?.map((profile) => profile.pubkey),
          equals([alicePubkey, bobPubkey]),
        );
      });

      testWidgets('keeps the list where it was scrolled when group mode '
          'opens', (tester) async {
        await openSheet(tester, allowGroups: true, contacts: manyContacts());
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        final scrolledTo = peopleScrollPosition(tester).pixels;
        expect(scrolledTo, greaterThan(0));

        await enterGroupMode(tester);

        expect(peopleScrollPosition(tester).pixels, equals(scrolledTo));
      });

      testWidgets('dragging the list puts the keyboard away in group mode', (
        tester,
      ) async {
        await openSheet(tester, allowGroups: true, contacts: manyContacts());
        await enterGroupMode(tester);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
      });

      testWidgets('dragging the one-to-one list leaves the keyboard up', (
        tester,
      ) async {
        await openSheet(tester, allowGroups: true, contacts: manyContacts());
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();

        // The control for the test above: the list did move.
        expect(peopleScrollPosition(tester).pixels, greaterThan(0));
        expect(tester.testTextInput.isVisible, isTrue);
      });

      group('at the size limit', () {
        final people = [
          for (var index = 0; index < dmGroupMaxParticipants; index++)
            'Person ${String.fromCharCode(65 + index)}',
        ];
        Finder fullNotice() =>
            find.text(l10n.newMessageGroupFull(dmGroupMaxParticipants));

        /// Opens group mode over ten candidates and picks all but the last
        /// two, leaving the group one short of full.
        Future<void> openOneShortOfFull(WidgetTester tester) async {
          useTallSurface(tester);
          await openSheet(
            tester,
            allowGroups: true,
            contacts: [
              for (final (index, name) in people.indexed)
                candidate(
                  (index + 1).toRadixString(16).padLeft(2, '0') * 32,
                  name,
                ),
            ],
          );
          await enterGroupMode(tester);
          for (final name in people.take(dmGroupMaxRecipients - 1)) {
            await tapPerson(tester, name);
          }
        }

        testWidgets('says the group is full once the ninth person is picked', (
          tester,
        ) async {
          await openOneShortOfFull(tester);
          expect(fullNotice(), findsNothing);

          await tapPerson(tester, people[dmGroupMaxRecipients - 1]);

          expect(fullNotice(), findsOneWidget);
          expect(
            tester.getRect(fullNotice()).top,
            greaterThanOrEqualTo(tester.getRect(chipFor(people.first)).bottom),
          );
          // Announced as it appears: nothing else tells a screen reader why
          // the remaining rows just went quiet.
          expect(flagsOf(tester, fullNotice()).isLiveRegion, isTrue);
        });

        testWidgets('stops offering anyone else once the group is full', (
          tester,
        ) async {
          await openOneShortOfFull(tester);
          final lastPerson = personRow(people.last);
          expect(flagsOf(tester, lastPerson).isEnabled, Tristate.isTrue);

          await tapPerson(tester, people[dmGroupMaxRecipients - 1]);

          expect(flagsOf(tester, lastPerson).isEnabled, Tristate.isFalse);
          await tapPerson(tester, people.last);
          expect(chipFor(people.last), findsNothing);
          expect(flagsOf(tester, lastPerson).isSelected, Tristate.isFalse);
        });

        testWidgets('lets a picked person go from a full group, which reopens '
            'it', (tester) async {
          await openOneShortOfFull(tester);
          await tapPerson(tester, people[dmGroupMaxRecipients - 1]);
          expect(fullNotice(), findsOneWidget);
          expect(
            flagsOf(tester, personRow(people.first)).isEnabled,
            Tristate.isTrue,
          );

          await tapPerson(tester, people.first);

          expect(fullNotice(), findsNothing);
          expect(chipFor(people.first), findsNothing);
          expect(
            flagsOf(tester, personRow(people.last)).isEnabled,
            Tristate.isTrue,
          );
        });

        testWidgets('fits a full group on a small screen with the keyboard up '
            'and large text', (tester) async {
          const screen = Size(375, 667);
          const keyboardHeight = 260.0;
          await openOneShortOfFull(tester);
          await tapPerson(tester, people[dmGroupMaxRecipients - 1]);
          expect(fullNotice(), findsOneWidget);

          // The picks, the notice and the button now want more room than the
          // sheet has left.
          tester.view.physicalSize = screen;
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(startButton()).bottom,
            lessThanOrEqualTo(screen.height - keyboardHeight),
          );
          expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
        });
      });

      testWidgets('back leaves group mode and forgets who was picked', (
        tester,
      ) async {
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');
        expect(chipFor('Alice'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.commonBack));
        await tester.pumpAndSettle();

        expect(outcome.didClose, isFalse);
        expect(find.text(l10n.newMessageTitle), findsOneWidget);
        expect(newGroupRow(), findsOneWidget);

        await enterGroupMode(tester);

        expect(chipFor('Alice'), findsNothing);
        expect(
          flagsOf(tester, personRow('Alice')).isSelected,
          Tristate.isFalse,
        );
      });

      testWidgets('withdraws group mode when a DM restriction resolves while '
          'the sheet is open', (tester) async {
        final isRestricted = StateProvider<bool>((ref) => false);
        final outcome = await openSheet(
          tester,
          allowGroups: true,
          contacts: [
            candidate(alicePubkey, 'Alice'),
            candidate(bobPubkey, 'Bob'),
          ],
          extraOverrides: [
            isDmRestrictedProvider.overrideWith(
              (ref) => ref.watch(isRestricted),
            ),
          ],
        );
        await enterGroupMode(tester);
        await tapPerson(tester, 'Alice');
        expect(chipFor('Alice'), findsOneWidget);
        expect(startButton(), findsOneWidget);

        ProviderScope.containerOf(
          tester.element(find.byType(NewMessageSheet)),
        ).read(isRestricted.notifier).state = true;
        await tester.pumpAndSettle();

        expect(find.text(l10n.newMessageTitle), findsOneWidget);
        expect(newGroupRow(), findsNothing);
        expect(startButton(), findsNothing);
        expect(chipFor('Alice'), findsNothing);
        expect(find.byType(DivineSpriteCheckbox), findsNothing);

        await tester.tap(personRow('Bob'));
        await tester.pumpAndSettle();

        expect(outcome.didClose, isTrue);
        expect(
          outcome.selected?.map((profile) => profile.pubkey),
          equals([bobPubkey]),
        );
      });
    });
  });
}
