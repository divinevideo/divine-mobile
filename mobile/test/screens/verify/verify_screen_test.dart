// ABOUTME: Widget tests for the verify dashboard — verdict pills, unlinking,
// ABOUTME: and the platforms still on offer.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:openvine/screens/verify/widgets/verify_claim_row.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockVerifyCubit extends MockCubit<VerifyState> implements VerifyCubit {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

const _github = IdentityClaim(
  pubkey: _pubkey,
  platform: 'github',
  identity: 'octocat',
  proof: 'abc',
);
const _twitter = IdentityClaim(
  pubkey: _pubkey,
  platform: 'twitter',
  identity: 'jack',
  proof: IdentityClaim.oauthProof,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VerifyView, () {
    late _MockVerifyCubit cubit;

    setUpAll(() {
      registerFallbackValue(_github);
    });

    setUp(() {
      cubit = _MockVerifyCubit();
      when(cubit.load).thenAnswer((_) async {});
      when(() => cubit.removeClaim(any())).thenAnswer((_) async {});
    });

    /// The claim a connect flow hands back when it links Mastodon.
    const linkedMastodon = IdentityClaim(
      pubkey: _pubkey,
      platform: 'mastodon',
      identity: 'alice',
      proof: '110123',
    );

    Future<void> pump(
      WidgetTester tester,
      VerifyState state, {
      // The loading indicator animates forever, so states that render one
      // cannot settle.
      bool settle = true,
    }) async {
      when(() => cubit.state).thenReturn(state);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => BlocProvider<VerifyCubit>.value(
              value: cubit,
              child: const VerifyView(),
            ),
            routes: [
              GoRoute(
                path: VerifyConnectPage.path,
                name: VerifyConnectPage.routeName,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: [
                      Text('connect ${state.pathParameters['platform']}'),
                      TextButton(
                        onPressed: () => context.pop(linkedMastodon),
                        child: const Text('finish link'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    VerifyState ready({
      List<IdentityClaim> claims = const [_github, _twitter],
      Set<String> verifiedKeys = const {'github:octocat'},
      List<VerifierPlatform> platforms = const [
        VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
        VerifierPlatform(key: 'twitter', label: 'Twitter / X', supported: true),
        VerifierPlatform(key: 'mastodon', label: 'Mastodon', supported: true),
      ],
      bool verifierReachable = true,
      String? removingKey,
    }) {
      return VerifyState(
        status: VerifyStatus.ready,
        claims: claims,
        verifiedKeys: verifiedKeys,
        platforms: platforms,
        verifierReachable: verifierReachable,
        removingKey: removingKey,
      );
    }

    testWidgets('shows a loading indicator while reading', (tester) async {
      await pump(
        tester,
        VerifyState(status: VerifyStatus.loading),
        settle: false,
      );

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('offers a retry when the read failed', (tester) async {
      await pump(tester, VerifyState(status: VerifyStatus.failure));

      expect(find.text(l10n.verifyLoadFailed), findsOneWidget);
      await tester.tap(find.text(l10n.verifyRetry));

      verify(cubit.load).called(1);
    });

    testWidgets('marks each link verified or not', (tester) async {
      await pump(tester, ready());

      expect(find.text('octocat'), findsOneWidget);
      expect(find.text('jack'), findsOneWidget);
      expect(find.text(l10n.verifyStatusVerified), findsOneWidget);
      expect(find.text(l10n.verifyStatusUnverified), findsOneWidget);
    });

    testWidgets('says the verdicts are unknown when the verifier is down', (
      tester,
    ) async {
      await pump(
        tester,
        ready(verifiedKeys: const {}, verifierReachable: false),
      );

      expect(find.text(l10n.verifyVerifierUnreachable), findsOneWidget);
    });

    testWidgets('lists only platforms without a link', (tester) async {
      await pump(tester, ready());

      expect(find.text('Mastodon'), findsOneWidget);
      // GitHub and Twitter appear as linked rows, not as offers.
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text(l10n.verifyOneTapBadge), findsNothing);
    });

    testWidgets('says so when every platform is linked', (tester) async {
      await pump(
        tester,
        ready(
          platforms: const [
            VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
          ],
        ),
      );

      expect(find.text(l10n.verifyAllPlatformsLinked), findsOneWidget);
    });

    testWidgets('names the unlink action for screen readers', (tester) async {
      await pump(tester, ready());

      expect(
        find.bySemanticsLabel(
          l10n.verifyUnlinkSemanticLabel('Twitter / X', 'jack'),
        ),
        findsOneWidget,
      );
    });

    /// Taps the trash affordance on the row showing [identity].
    Future<void> tapUnlink(WidgetTester tester, String identity) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text(identity),
            matching: find.byType(VerifyClaimRow),
          ),
          matching: find.byType(DivineIconButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unlinks the tapped account once confirmed', (tester) async {
      await pump(tester, ready());

      await tapUnlink(tester, 'jack');
      // Unlinking also revokes the verifier's OAuth login, so the tap asks
      // first rather than acting.
      verifyNever(() => cubit.removeClaim(any()));
      expect(find.text(l10n.verifyUnlinkConfirmTitle('Twitter / X')), findsOne);

      await tester.tap(find.text(l10n.verifyUnlinkConfirmCta));
      await tester.pumpAndSettle();

      verify(() => cubit.removeClaim(_twitter)).called(1);
    });

    testWidgets('keeps the account when the unlink is declined', (
      tester,
    ) async {
      await pump(tester, ready());

      await tapUnlink(tester, 'jack');
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.removeClaim(any()));
      expect(find.text('jack'), findsOne);
    });

    /// Drives the state change the error listener reacts to.
    Future<void> pumpFailing(WidgetTester tester, VerifyError error) async {
      final failed = ready().copyWith(error: error, errorAttempt: 1);
      whenListen(
        cubit,
        Stream<VerifyState>.fromIterable([failed]),
        initialState: ready(),
      );
      // Pumped at the pre-failure state so the listener sees the transition;
      // seeding it already-failed would give it nothing to react to.
      await pump(tester, ready());
    }

    testWidgets('says so when an unlink does not land', (tester) async {
      // Silence here was the bug: the row stayed put and nothing explained it.
      await pumpFailing(tester, VerifyError.remove);

      expect(find.text(l10n.verifyErrorRemoveFailed), findsOneWidget);
    });

    testWidgets('distinguishes an unreadable link list from a failed unlink', (
      tester,
    ) async {
      await pumpFailing(tester, VerifyError.linksUnreadable);

      expect(find.text(l10n.verifyErrorLinksUnreadable), findsOneWidget);
    });

    testWidgets('blocks a second unlink while one is in flight', (
      tester,
    ) async {
      await pump(tester, ready(removingKey: 'twitter:jack'), settle: false);

      // The row being unlinked shows a spinner; the other row's button is
      // disabled so a second unlink cannot start on top of it.
      final button = tester.widget<DivineIconButton>(
        find.descendant(
          of: find.ancestor(
            of: find.text('octocat'),
            matching: find.byType(VerifyClaimRow),
          ),
          matching: find.byType(DivineIconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('confirms and shows the link when the flow returns one', (
      tester,
    ) async {
      await pump(tester, ready());

      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('finish link'));
      await tester.pumpAndSettle();

      // Silence here was the bug: the flow popped with no word either way.
      expect(
        find.text(l10n.verifyLinkedConfirmation('Mastodon')),
        findsOneWidget,
      );
      verify(() => cubit.claimLinked(linkedMastodon)).called(1);
      // Drawn from what was published, not from a fresh relay read that may
      // not carry the event yet.
      verifyNever(cubit.load);
    });

    testWidgets('says nothing when the flow is left without linking', (
      tester,
    ) async {
      await pump(tester, ready());

      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      verifyNever(() => cubit.claimLinked(any()));
    });

    testWidgets('explains the handshake on demand', (tester) async {
      await pump(tester, ready());

      await tester.tap(find.text(l10n.verifyHowItWorksTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.verifyHowItWorksIntro), findsOneWidget);
      // Both halves of the handshake, or the metaphor does not land.
      expect(find.text(l10n.verifyHowItWorksYourSide), findsOneWidget);
      expect(find.text(l10n.verifyHowItWorksOtherSide), findsOneWidget);
      expect(find.text(l10n.verifyHowItWorksOwnership), findsOneWidget);
    });

    testWidgets('opens the connect flow for an offered platform', (
      tester,
    ) async {
      await pump(tester, ready());

      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();

      expect(find.text('connect mastodon'), findsOneWidget);
    });
  });
}
