// ABOUTME: Widget tests for FollowingBar.
// ABOUTME: Verifies empty state, avatar rendering, and user tap callback.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../../helpers/retired_key_custody.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

void main() {
  const pubkey1 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkey2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const currentUserPubkey =
      'facade00facade00facade00facade00facade00facade00facade00facade00';

  final now = DateTime.now();

  UserProfile createTestProfile({
    required String pubkey,
    String? displayName,
    String? name,
  }) {
    return UserProfile(
      pubkey: pubkey,
      displayName: displayName,
      name: name,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  group(FollowingBar, () {
    late _MockMyFollowingBloc mockFollowingBloc;

    setUp(() {
      mockFollowingBloc = _MockMyFollowingBloc();
    });

    Widget buildSubject({
      required MyFollowingState state,
      List<Override> additionalOverrides = const [],
      ValueChanged<String>? onUserTapped,
      Locale? locale,
      String viewerPubkey = currentUserPubkey,
    }) {
      whenListen(
        mockFollowingBloc,
        Stream<MyFollowingState>.value(state),
        initialState: state,
      );

      return testMaterialApp(
        locale: locale,
        additionalOverrides: additionalOverrides,
        home: BlocProvider<MyFollowingBloc>.value(
          value: mockFollowingBloc,
          child: Scaffold(
            body: FollowingBar(
              onUserTapped: onUserTapped ?? (_) {},
              currentUserPubkey: viewerPubkey,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $SizedBox when following list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(state: const MyFollowingState()));
        await tester.pumpAndSettle();

        expect(find.byType(FollowingBar), findsOneWidget);
        expect(find.byType(UserAvatar), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('omits the viewer when their contact list self-follows', (
        tester,
      ) async {
        final profile1 = createTestProfile(
          pubkey: pubkey1,
          displayName: 'Alice',
        );
        final selfProfile = createTestProfile(
          pubkey: currentUserPubkey,
          displayName: 'Me',
        );

        await tester.pumpWidget(
          buildSubject(
            state: const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [pubkey1, currentUserPubkey],
            ),
            additionalOverrides: [
              fetchUserProfileProvider(
                pubkey1,
              ).overrideWith((ref) async => profile1),
              fetchUserProfileProvider(
                currentUserPubkey,
              ).overrideWith((ref) async => selfProfile),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.text('Me'), findsNothing);
      });

      testWidgets('collapses when the viewer is the only followed pubkey', (
        tester,
      ) async {
        final selfProfile = createTestProfile(
          pubkey: currentUserPubkey,
          displayName: 'Me',
        );

        await tester.pumpWidget(
          buildSubject(
            state: const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [currentUserPubkey],
            ),
            additionalOverrides: [
              fetchUserProfileProvider(
                currentUserPubkey,
              ).overrideWith((ref) async => selfProfile),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('renders $UserAvatar for each following user', (
        tester,
      ) async {
        final profile1 = createTestProfile(
          pubkey: pubkey1,
          displayName: 'Alice',
        );
        final profile2 = createTestProfile(pubkey: pubkey2, displayName: 'Bob');

        await tester.pumpWidget(
          buildSubject(
            state: const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [pubkey1, pubkey2],
            ),
            additionalOverrides: [
              fetchUserProfileProvider(
                pubkey1,
              ).overrideWith((ref) async => profile1),
              fetchUserProfileProvider(
                pubkey2,
              ).overrideWith((ref) async => profile2),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsNWidgets(2));
      });
    });

    group('interactions', () {
      testWidgets(
        'calls onUserTapped with correct pubkey when user is tapped',
        (tester) async {
          String? tappedPubkey;
          final profile1 = createTestProfile(
            pubkey: pubkey1,
            displayName: 'Alice',
          );
          final profile2 = createTestProfile(
            pubkey: pubkey2,
            displayName: 'Bob',
          );

          await tester.pumpWidget(
            buildSubject(
              state: const MyFollowingState(
                status: MyFollowingStatus.success,
                followingPubkeys: [pubkey1, pubkey2],
              ),
              additionalOverrides: [
                fetchUserProfileProvider(
                  pubkey1,
                ).overrideWith((ref) async => profile1),
                fetchUserProfileProvider(
                  pubkey2,
                ).overrideWith((ref) async => profile2),
              ],
              onUserTapped: (pk) => tappedPubkey = pk,
            ),
          );
          await tester.pumpAndSettle();

          // Tap the first user avatar
          await tester.tap(find.text('Alice'));
          await tester.pumpAndSettle();

          expect(tappedPubkey, equals(pubkey1));
        },
      );
    });

    group('moderation accounts', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      // A key's holder controls its kind-0, so the tests give it one that
      // tries to look official.
      Override looksOfficial(String pubkey) =>
          fetchUserProfileProvider(pubkey).overrideWith(
            (ref) async => UserProfile(
              pubkey: pubkey,
              displayName: 'Looks Official',
              picture: 'https://example.invalid/looks-official.png',
              rawData: const {},
              createdAt: now,
              eventId: 'c' * 64,
            ),
          );

      // Before #9963 this strip named an official moderation key but
      // pictured it with a generic placeholder, so the two disagreed.
      testWidgets('names the current account Divine over the wordmark', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [kModerationPubkeyHex],
            ),
            additionalOverrides: [looksOfficial(kModerationPubkeyHex)],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(wordmarkFinder(), findsOneWidget);
        expect(find.text('Looks Official'), findsNothing);
      });

      // Every send to a retired key is refused, so the strip never offers
      // one to start a conversation with, whatever its custody (#9711).
      for (final custody in RetiredKeyCustody.values) {
        testWidgets('${custody.name}: leaves a followed retired key out', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              state: MyFollowingState(
                status: MyFollowingStatus.success,
                followingPubkeys: [shippedRetiredKey, pubkey1],
              ),
              additionalOverrides: [
                retiredKeyCustody(custody),
                looksOfficial(shippedRetiredKey),
                fetchUserProfileProvider(pubkey1).overrideWith(
                  (ref) async =>
                      createTestProfile(pubkey: pubkey1, displayName: 'Alice'),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // The control: the ordinary account beside it is still offered.
          expect(find.text('Alice'), findsOneWidget);
          expect(find.byType(UserAvatar), findsOneWidget);
          expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
          expect(find.text(l10n.dmFormerModerationAccountName), findsNothing);
          expect(wordmarkFinder(), findsNothing);
        });
      }

      // A contact list stores `p` tags verbatim, so the retired key can
      // arrive as upper-case hex — the same hazard the viewer filter beside
      // it handles (#8351). It is the same identity and stays out (#9711).
      testWidgets(
        'leaves a followed retired key stored as upper-case hex out',
        (
          tester,
        ) async {
          final upper = shippedRetiredKey.toUpperCase();
          await tester.pumpWidget(
            buildSubject(
              state: MyFollowingState(
                status: MyFollowingStatus.success,
                followingPubkeys: [upper, pubkey1],
              ),
              additionalOverrides: [
                looksOfficial(upper),
                fetchUserProfileProvider(pubkey1).overrideWith(
                  (ref) async =>
                      createTestProfile(pubkey: pubkey1, displayName: 'Alice'),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // The control: the ordinary account beside it is still offered.
          expect(find.text('Alice'), findsOneWidget);
          expect(find.text('Looks Official'), findsNothing);
          expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
          expect(wordmarkFinder(), findsNothing);
        },
      );
    });

    group('deleted accounts', () {
      Future<void> pumpBar(
        WidgetTester tester, {
        required bool vanished,
        Locale? locale,
      }) async {
        await tester.pumpWidget(
          buildSubject(
            locale: locale,
            state: const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [pubkey1],
            ),
            additionalOverrides: [
              fetchUserProfileProvider(pubkey1).overrideWith(
                (ref) async =>
                    createTestProfile(pubkey: pubkey1, displayName: 'Alice'),
              ),
              profileVanishedProvider(pubkey1).overrideWith((ref) => vanished),
            ],
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('shows a deleted account under the deleted-account name', (
        tester,
      ) async {
        // A vanish cannot rewrite the viewer's own contact list, so the
        // account stays in this bar and must not keep its stale name.
        await pumpBar(tester, vanished: true);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
      });

      testWidgets('resolves the copy from l10n', (tester) async {
        // Pump in German and require the German string. Asserting the German
        // copy is *absent* from an English pump passes whether or not the
        // widget reads l10n, so it proved nothing.
        await pumpBar(tester, vanished: true, locale: const Locale('de'));

        final de = lookupAppLocalizations(const Locale('de'));
        expect(find.text(de.profileDeletedAccountName), findsOneWidget);
      });

      testWidgets('leaves a live account untouched', (tester) async {
        await pumpBar(tester, vanished: false);

        expect(find.text('Alice'), findsOneWidget);
      });
    });
  });
}
