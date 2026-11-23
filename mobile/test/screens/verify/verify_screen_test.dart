// ABOUTME: Widget tests for the verify dashboard — verdict pills, unlinking,
// ABOUTME: and the platforms still on offer.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/verify/verify_confirmation_screen.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:openvine/screens/verify/widgets/verify_claim_row.dart';
import 'package:openvine/screens/verify/widgets/verify_platform_row.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verifier_client/verifier_client.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVerifyCubit extends MockCubit<VerifyState> implements VerifyCubit {}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }
}

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
    late CrashReporter originalReporter;
    late _RecordingCrashReporter reporter;

    setUpAll(() {
      registerFallbackValue(_github);
    });

    setUp(() {
      cubit = _MockVerifyCubit();
      when(cubit.load).thenAnswer((_) async {});
      when(cubit.rereadConfirmationAccess).thenAnswer((_) async {});
      when(() => cubit.isClosed).thenReturn(false);
      when(() => cubit.removeClaim(any())).thenAnswer((_) async {});
      originalReporter = detachedFailureReporter;
      reporter = _RecordingCrashReporter();
      detachedFailureReporter = reporter;
    });

    tearDown(() {
      detachedFailureReporter = originalReporter;
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
      // Whether this device can run a sign-in; off unless a test is about it.
      bool oauthUsable = false,
      // Whether the `confirmationSignIn` flag is on, and whether this build
      // can buy; the flag is off unless a test is about it.
      bool confirmationSignIn = false,
      bool canBuy = true,
    }) async {
      when(() => cubit.state).thenReturn(state);
      // Mounted at the production paths: the view pushes the connect flow by
      // its typed location, which is nested under the verify dashboard.
      final router = GoRouter(
        initialLocation: VerifyPage.path,
        routes: [
          GoRoute(
            path: VerifyPage.path,
            builder: (context, _) => BlocProvider<VerifyCubit>.value(
              value: cubit,
              child: VerifyView(
                oauthUsable: oauthUsable,
                confirmationSignIn: confirmationSignIn,
                canBuy: canBuy,
              ),
            ),
            routes: [
              GoRoute(
                path: VerifyConfirmationPage.path,
                builder: (context, _) => Scaffold(
                  body: Column(
                    children: [
                      const Text('confirmation screen'),
                      TextButton(
                        onPressed: context.pop,
                        child: const Text('leave confirmation'),
                      ),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: VerifyConnectPage.path,
                name: VerifyConnectPage.routeName,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: [
                      Text('connect ${state.pathParameters['platform']}'),
                      if (state.uri.queryParameters['replacing']
                          case final replacing?)
                        Text('replacing $replacing'),
                      TextButton(
                        onPressed: () => context.pop<VerifyConnectResult>((
                          linked: linkedMastodon,
                          replacedIdentity: null,
                        )),
                        child: const Text('finish link'),
                      ),
                      // A renewal that replaced the link it was opened for.
                      TextButton(
                        onPressed: () => context.pop<VerifyConnectResult>((
                          linked: linkedMastodon,
                          replacedIdentity:
                              state.uri.queryParameters['replacing'],
                        )),
                        child: const Text('finish renewal'),
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
      // The verifier's reason the sign-in link stopped counting.
      Map<String, SignInLapse> signInCodes = const {
        'twitter:jack': SignInLapse.expired,
      },
      String? removingKey,
    }) {
      return VerifyState(
        status: VerifyStatus.ready,
        claims: claims,
        verifiedKeys: verifiedKeys,
        platforms: platforms,
        verifierReachable: verifierReachable,
        signInCodes: signInCodes,
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

    testWidgets('reports a retry that fails instead of leaking it', (
      tester,
    ) async {
      when(cubit.load).thenAnswer((_) async {
        throw StateError('retry failed');
      });
      await pump(tester, VerifyState(status: VerifyStatus.failure));
      expect(reporter.recordedErrors, isEmpty);

      await tester.tap(find.text(l10n.verifyRetry));
      await tester.pump();

      verify(cubit.load).called(1);
      expect(
        reporter.recordedErrors.single,
        isA<Reportable<Object>>().having(
          (r) => r.unwrap(),
          'unwrap',
          isA<StateError>(),
        ),
      );
    });

    testWidgets('marks each link verified or not', (tester) async {
      await pump(tester, ready(signInCodes: const {}));

      expect(find.text('octocat'), findsOneWidget);
      expect(find.text('jack'), findsOneWidget);
      expect(find.text(l10n.verifyStatusVerified), findsOneWidget);
      expect(find.text(l10n.verifyStatusUnverified), findsOneWidget);
      expect(find.text(l10n.verifyVerifierUnreachable), findsNothing);
    });

    group('verdict pill', () {
      testWidgets('says a sign-in expired', (tester) async {
        await pump(tester, ready());

        expect(find.text(l10n.verifyStatusSignInExpired), findsOneWidget);
        expect(find.text(l10n.verifyStatusUnverified), findsNothing);
        expect(find.text(l10n.verifyStatusVerified), findsOneWidget);
      });

      testWidgets('says the account changed', (tester) async {
        await pump(
          tester,
          ready(
            signInCodes: const {'twitter:jack': SignInLapse.accountChanged},
          ),
        );

        expect(find.text(l10n.verifyStatusAccountChanged), findsOneWidget);
        expect(find.text(l10n.verifyStatusSignInExpired), findsNothing);
      });

      testWidgets('says a link needs Confirmation and offers no sign-in', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            signInCodes: const {'twitter:jack': SignInLapse.needsConfirmation},
          ),
          oauthUsable: true,
        );

        expect(find.text(l10n.verifyStatusNeedsConfirmation), findsOneWidget);
        expect(find.text(l10n.verifyStatusUnverified), findsNothing);
        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });

      testWidgets('says not verified when the verifier gave no reason', (
        tester,
      ) async {
        await pump(tester, ready(signInCodes: const {}));

        expect(find.text(l10n.verifyStatusUnverified), findsOneWidget);
        expect(find.text(l10n.verifyStatusSignInExpired), findsNothing);
        expect(find.text(l10n.verifyStatusAccountChanged), findsNothing);
      });

      testWidgets('says why even where sign-in is off for the platform', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            platforms: const [
              VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
              VerifierPlatform(
                key: 'twitter',
                label: 'Twitter / X',
                supported: true,
                oauth: false,
              ),
            ],
          ),
          oauthUsable: true,
        );

        expect(find.text(l10n.verifyStatusSignInExpired), findsOneWidget);
        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });

      testWidgets('keeps a proof-post link on not verified', (tester) async {
        // The verifier can send an account-changed code for a proof-post
        // claim on a sign-in platform; only sign-in rows say why.
        const proofPostTwitter = IdentityClaim(
          pubkey: _pubkey,
          platform: 'twitter',
          identity: 'jack',
          proof: 'abc',
        );
        await pump(
          tester,
          ready(
            claims: const [proofPostTwitter],
            verifiedKeys: const {},
            signInCodes: const {'twitter:jack': SignInLapse.accountChanged},
          ),
        );

        expect(find.text(l10n.verifyStatusUnverified), findsOneWidget);
        expect(find.text(l10n.verifyStatusAccountChanged), findsNothing);
      });
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

    testWidgets('drops the unknown-verdicts note once every link reads '
        'verified', (tester) async {
      // A link re-made after a "couldn't check" answer is shown as verified
      // straight away, so no row is left for the note to explain.
      await pump(
        tester,
        ready(
          verifiedKeys: const {'github:octocat', 'twitter:jack'},
          verifierReachable: false,
        ),
      );

      expect(find.text(l10n.verifyVerifierUnreachable), findsNothing);
    });

    testWidgets('lists only platforms without a link', (tester) async {
      await pump(tester, ready());

      expect(find.text('Mastodon'), findsOneWidget);
      // GitHub and Twitter appear as linked rows, not as offers.
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text(l10n.verifyOneTapBadge), findsNothing);
    });

    testWidgets('marks one-tap only where the verifier has sign-in on', (
      tester,
    ) async {
      await pump(
        tester,
        ready(
          claims: const [],
          verifiedKeys: const {},
          platforms: const [
            VerifierPlatform(
              key: 'twitter',
              label: 'Twitter / X',
              supported: true,
              oauth: false,
            ),
            VerifierPlatform(
              key: 'bluesky',
              label: 'Bluesky',
              supported: true,
              oauth: true,
            ),
            // A verifier answer with no flag: the app's own list decides.
            VerifierPlatform(key: 'youtube', label: 'YouTube', supported: true),
            VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
          ],
        ),
      );

      Finder badgeOn(String label) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(VerifyPlatformRow),
        ),
        matching: find.text(l10n.verifyOneTapBadge),
      );

      expect(badgeOn('Twitter / X'), findsNothing);
      expect(badgeOn('Bluesky'), findsOneWidget);
      expect(badgeOn('YouTube'), findsOneWidget);
      expect(badgeOn('GitHub'), findsNothing);
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
      when(() => cubit.isClosed).thenReturn(false);
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

    testWidgets('drops the unlink when the cubit closed behind the prompt', (
      tester,
    ) async {
      await pump(tester, ready());

      await tapUnlink(tester, 'jack');
      // The prompt lives on the navigator, so an identity change can close the
      // cubit and leave the prompt open. Unlinking on it throws.
      when(() => cubit.isClosed).thenReturn(true);
      await tester.tap(find.text(l10n.verifyUnlinkConfirmCta));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.removeClaim(any()));
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

    testWidgets('keeps the link confirmation when its announcement fails', (
      tester,
    ) async {
      var announcementRejected = false;
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            (Object? message) async {
              if (message is Map && message['type'] == 'announce') {
                announcementRejected = true;
                throw StateError('announcement failed');
              }
              return null;
            },
          );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      await pump(tester, ready());
      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('finish link'));
      await tester.pumpAndSettle();

      expect(announcementRejected, isTrue);
      expect(
        reporter.recordedErrors.single,
        isA<Reportable<Object>>().having(
          (r) => r.unwrap(),
          'unwrap',
          isA<StateError>(),
        ),
      );
      expect(
        find.text(l10n.verifyLinkedConfirmation('Mastodon')),
        findsOneWidget,
      );
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

    testWidgets('takes the remembered access answer when the flow returns, '
        'linked or not', (tester) async {
      await pump(tester, ready());

      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();
      verifyNever(cubit.rereadConfirmationAccess);
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      verify(cubit.rereadConfirmationAccess).called(1);

      await tester.tap(find.text('Mastodon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('finish link'));
      await tester.pumpAndSettle();
      verify(cubit.rereadConfirmationAccess).called(1);
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

    group('Divine Confirmation', () {
      const gated = [
        VerifierPlatform(
          key: 'bluesky',
          label: 'Bluesky',
          supported: true,
          oauth: true,
          signinRequires: SigninRequirement.confirmation,
        ),
        VerifierPlatform(
          key: 'twitter',
          label: 'Twitter / X',
          supported: true,
          oauth: true,
        ),
        VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
      ];

      VerifyState offers({
        ConfirmationAccess access = ConfirmationAccess.hasNot,
      }) => VerifyState(
        status: VerifyStatus.ready,
        platforms: gated,
        confirmationAccess: access,
      );

      Finder badgeOn(String label) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(VerifyPlatformRow),
        ),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == l10n.verifyOneTapBadge ||
                  widget.data == l10n.verifyOneTapWithConfirmationBadge),
        ),
      );

      String badgeText(String label) =>
          (badgeOn(label).evaluate().single.widget as Text).data!;

      testWidgets('a gated platform reads "One tap with Confirmation" for '
          'hasNot', (tester) async {
        await pump(
          tester,
          offers(),
          oauthUsable: true,
          confirmationSignIn: true,
        );

        expect(
          badgeText('Bluesky'),
          equals(l10n.verifyOneTapWithConfirmationBadge),
        );
        // A platform the verifier does not gate stays "One tap".
        expect(badgeText('Twitter / X'), equals(l10n.verifyOneTapBadge));
        expect(badgeOn('GitHub'), findsNothing);
      });

      // The badge itself is hidden from screen readers, so the row's label
      // carries the requirement.
      testWidgets('a screen reader hears that a gated platform needs '
          'Confirmation', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          offers(),
          oauthUsable: true,
          confirmationSignIn: true,
        );

        expect(
          find.bySemanticsLabel(
            l10n.verifyLinkNeedsConfirmationSemanticLabel('Bluesky'),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(l10n.verifyLinkSemanticLabel('Twitter / X')),
          findsOneWidget,
        );
        semantics.dispose();
      });

      for (final access in [
        ConfirmationAccess.has,
        ConfirmationAccess.unknown,
      ]) {
        testWidgets('the badge stays "One tap" for ${access.name}', (
          tester,
        ) async {
          await pump(
            tester,
            offers(access: access),
            oauthUsable: true,
            confirmationSignIn: true,
          );

          expect(badgeText('Bluesky'), equals(l10n.verifyOneTapBadge));
        });
      }

      testWidgets('the badge stays "One tap" with the flag off', (
        tester,
      ) async {
        await pump(tester, offers(), oauthUsable: true);

        expect(badgeText('Bluesky'), equals(l10n.verifyOneTapBadge));
      });

      testWidgets('the badge stays "One tap" where sign-in is hidden', (
        tester,
      ) async {
        await pump(tester, offers(), confirmationSignIn: true);

        expect(badgeText('Bluesky'), equals(l10n.verifyOneTapBadge));
      });

      group('renew', () {
        VerifyState needsIt() => ready(
          signInCodes: const {'twitter:jack': SignInLapse.needsConfirmation},
        );

        final renewLabel = l10n.verifyRenewConfirmationSemanticLabel(
          'Twitter / X',
          'jack',
        );

        testWidgets('a link that needs Confirmation offers Renew '
            'Confirmation with the flag on', (tester) async {
          await pump(
            tester,
            needsIt(),
            oauthUsable: true,
            confirmationSignIn: true,
          );

          expect(find.text(l10n.verifyRenewConfirmation), findsOneWidget);
          expect(find.bySemanticsLabel(renewLabel), findsOneWidget);
          // Renewing restores the link; signing in again would not.
          expect(find.text(l10n.verifySignInAgain), findsNothing);
          expect(find.text(l10n.verifyStatusNeedsConfirmation), findsOneWidget);
        });

        testWidgets('opens the Confirmation screen, not a sign-in', (
          tester,
        ) async {
          await pump(
            tester,
            needsIt(),
            oauthUsable: true,
            confirmationSignIn: true,
          );

          await tester.tap(find.text(l10n.verifyRenewConfirmation));
          await tester.pumpAndSettle();

          expect(find.text('confirmation screen'), findsOneWidget);
          expect(find.text('connect twitter'), findsNothing);
        });

        testWidgets('refreshes access and the verdicts on return', (
          tester,
        ) async {
          await pump(
            tester,
            needsIt(),
            oauthUsable: true,
            confirmationSignIn: true,
          );
          when(cubit.refreshQuietly).thenAnswer((_) async {});

          await tester.tap(find.text(l10n.verifyRenewConfirmation));
          await tester.pumpAndSettle();
          verifyNever(cubit.refreshQuietly);

          await tester.tap(find.text('leave confirmation'));
          await tester.pumpAndSettle();

          verify(cubit.refreshQuietly).called(1);
        });

        testWidgets('an expired sign-in offers Sign in again, not Renew', (
          tester,
        ) async {
          await pump(
            tester,
            ready(),
            oauthUsable: true,
            confirmationSignIn: true,
          );

          expect(find.text(l10n.verifySignInAgain), findsOneWidget);
          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
        });

        testWidgets('a verified sign-in carrying the code offers no Renew', (
          tester,
        ) async {
          await pump(
            tester,
            ready(
              verifiedKeys: const {'github:octocat', 'twitter:jack'},
              signInCodes: const {
                'twitter:jack': SignInLapse.needsConfirmation,
              },
            ),
            oauthUsable: true,
            confirmationSignIn: true,
          );

          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
        });

        testWidgets('with the flag off the pill shows and no renew action', (
          tester,
        ) async {
          await pump(tester, needsIt(), oauthUsable: true);

          expect(find.text(l10n.verifyStatusNeedsConfirmation), findsOneWidget);
          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
          expect(find.text(l10n.verifyConfirmationStoreOnly), findsNothing);
        });

        testWidgets('iOS below 17.4 shows the pill and no renew action', (
          tester,
        ) async {
          await pump(tester, needsIt(), confirmationSignIn: true);

          expect(find.text(l10n.verifyStatusNeedsConfirmation), findsOneWidget);
          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
          expect(find.text(l10n.verifyConfirmationStoreOnly), findsNothing);
        });

        testWidgets('is not offered while an unlink is in flight', (
          tester,
        ) async {
          await pump(
            tester,
            ready(
              signInCodes: const {
                'twitter:jack': SignInLapse.needsConfirmation,
              },
              removingKey: 'github:octocat',
            ),
            oauthUsable: true,
            confirmationSignIn: true,
            settle: false,
          );

          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
        });

        testWidgets('a build that cannot buy shows the store note instead of '
            'Renew', (tester) async {
          await pump(
            tester,
            needsIt(),
            oauthUsable: true,
            confirmationSignIn: true,
            canBuy: false,
          );

          expect(find.text(l10n.verifyConfirmationStoreOnly), findsOneWidget);
          expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
          expect(find.text(l10n.verifyStatusNeedsConfirmation), findsOneWidget);
        });
      });
    });

    group('sign in again', () {
      testWidgets('is offered on a sign-in link that no longer verifies', (
        tester,
      ) async {
        await pump(tester, ready(), oauthUsable: true);

        expect(
          find.bySemanticsLabel(
            l10n.verifySignInAgainSemanticLabel('Twitter / X', 'jack'),
          ),
          findsOneWidget,
        );
        // Not on the proof-post link, which verifies.
        expect(find.text(l10n.verifySignInAgain), findsOneWidget);
      });

      testWidgets('is offered while another link could not be checked', (
        tester,
      ) async {
        // GitHub's check was inconclusive; the sign-in's lapse still stands.
        await pump(
          tester,
          ready(verifiedKeys: const {}, verifierReachable: false),
          oauthUsable: true,
        );

        expect(find.text(l10n.verifyVerifierUnreachable), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l10n.verifySignInAgainSemanticLabel('Twitter / X', 'jack'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('is not offered when the verifier gave no sign-in reason', (
        tester,
      ) async {
        await pump(tester, ready(signInCodes: const {}), oauthUsable: true);

        expect(find.text('jack'), findsOneWidget);
        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });

      testWidgets('is not offered where this device cannot sign in', (
        tester,
      ) async {
        await pump(tester, ready());

        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });

      testWidgets('is not offered while an unlink is in flight', (
        tester,
      ) async {
        await pump(
          tester,
          ready(removingKey: 'github:octocat'),
          oauthUsable: true,
          settle: false,
        );

        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });

      testWidgets('opens the connect flow to replace that link', (
        tester,
      ) async {
        await pump(tester, ready(), oauthUsable: true);

        await tester.tap(find.text(l10n.verifySignInAgain));
        await tester.pumpAndSettle();

        expect(find.text('connect twitter'), findsOneWidget);
        expect(find.text('replacing jack'), findsOneWidget);
      });

      testWidgets('swaps the renewed link out once the flow replaced it', (
        tester,
      ) async {
        await pump(tester, ready(), oauthUsable: true);

        await tester.tap(find.text(l10n.verifySignInAgain));
        await tester.pumpAndSettle();
        await tester.tap(find.text('finish renewal'));
        await tester.pumpAndSettle();

        verify(
          () => cubit.claimLinked(linkedMastodon, replacing: _twitter),
        ).called(1);
      });

      testWidgets('keeps the renewed link when the flow replaced nothing', (
        tester,
      ) async {
        // A proof post linked from the renewal flow publishes beside the
        // link, so its row has to stay.
        await pump(tester, ready(), oauthUsable: true);

        await tester.tap(find.text(l10n.verifySignInAgain));
        await tester.pumpAndSettle();
        await tester.tap(find.text('finish link'));
        await tester.pumpAndSettle();

        verifyNever(() => cubit.claimLinked(any(), replacing: _twitter));
        verify(() => cubit.claimLinked(linkedMastodon)).called(1);
      });
    });
  });

  group(VerifyClaimRow, () {
    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback? onRenewConfirmation,
      bool renewNeedsStore = false,
    }) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: VerifyClaimRow(
            claim: _twitter,
            isVerified: false,
            isRemoving: false,
            onRemove: () {},
            lapse: SignInLapse.needsConfirmation,
            onRenewConfirmation: onRenewConfirmation,
            renewNeedsStore: renewNeedsStore,
          ),
        ),
      ),
    );

    testWidgets('shows only the store text when a build cannot buy, even '
        'with a renew action given', (tester) async {
      await pumpRow(
        tester,
        onRenewConfirmation: () {},
        renewNeedsStore: true,
      );

      expect(find.text(l10n.verifyConfirmationStoreOnly), findsOneWidget);
      expect(find.text(l10n.verifyRenewConfirmation), findsNothing);
    });

    testWidgets('shows the renew button when the build can buy', (
      tester,
    ) async {
      await pumpRow(tester, onRenewConfirmation: () {});

      expect(find.text(l10n.verifyRenewConfirmation), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationStoreOnly), findsNothing);
    });
  });

  group(VerifyPage, () {
    late _MockIdentityClaimsRepository repository;

    // The flag is off, so Divine Confirmation changes nothing here.
    final confirmationOverrides = [
      supporterStoreBillingAvailableProvider.overrideWithValue(true),
      isFeatureEnabledProvider(
        FeatureFlag.confirmationSignIn,
      ).overrideWithValue(false),
      confirmationAccessReaderProvider.overrideWithValue(
        ({bool refresh = false}) async => ConfirmationAccess.unknown,
      ),
    ];

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      when(repository.supportedPlatforms).thenAnswer(
        (_) async => const [
          VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
        ],
      );
      when(() => repository.claimsWithVerdicts(any())).thenAnswer(
        (_) async => const IdentityClaimStatus(
          claims: [_github],
          verifiedKeys: {'github:octocat'},
          verifierReachable: true,
        ),
      );
    });

    testWidgets('reads the signed-in identity links as soon as it opens', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityClaimsRepositoryProvider.overrideWithValue(repository),
            ...confirmationOverrides,
            authServiceProvider.overrideWithValue(
              createMockAuthService(
                authState: AuthState.authenticated,
                currentPublicKeyHex: _pubkey,
              ),
            ),
            currentAuthStateProvider.overrideWithValue(
              AuthState.authenticated,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const VerifyPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.claimsWithVerdicts(_pubkey)).called(1);
      expect(find.text('octocat'), findsOneWidget);
    });

    group('Divine Confirmation', () {
      late _MockIdentityClaimsRepository secondRepository;

      setUp(() {
        secondRepository = _MockIdentityClaimsRepository();
        for (final repo in [repository, secondRepository]) {
          when(repo.supportedPlatforms).thenAnswer(
            (_) async => const [
              VerifierPlatform(
                key: 'bluesky',
                label: 'Bluesky',
                supported: true,
                oauth: true,
                signinRequires: SigninRequirement.confirmation,
              ),
            ],
          );
          when(() => repo.claimsWithVerdicts(any())).thenAnswer(
            (_) async => const IdentityClaimStatus(
              claims: [],
              verifiedKeys: {},
              verifierReachable: true,
            ),
          );
        }
      });

      Widget app(
        _MockIdentityClaimsRepository repo,
        ConfirmationAccessReader reader,
      ) => ProviderScope(
        overrides: [
          identityClaimsRepositoryProvider.overrideWithValue(repo),
          supporterStoreBillingAvailableProvider.overrideWithValue(true),
          isFeatureEnabledProvider(
            FeatureFlag.confirmationSignIn,
          ).overrideWithValue(true),
          confirmationAccessReaderProvider.overrideWithValue(reader),
          authServiceProvider.overrideWithValue(
            createMockAuthService(
              authState: AuthState.authenticated,
              currentPublicKeyHex: _pubkey,
            ),
          ),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          appOAuthSupportProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const VerifyPage(),
        ),
      );

      group('returning from the Confirmation screen', () {
        const needsIt = IdentityClaimStatus(
          claims: [_twitter],
          verifiedKeys: {},
          verifierReachable: true,
          signInCodes: {'twitter:jack': SignInLapse.needsConfirmation},
        );

        Future<void> pumpApp(WidgetTester tester) async {
          when(repository.supportedPlatforms).thenAnswer(
            (_) async => const [
              VerifierPlatform(
                key: 'twitter',
                label: 'Twitter / X',
                supported: true,
                oauth: true,
                signinRequires: SigninRequirement.confirmation,
              ),
            ],
          );
          when(
            () => repository.claimsWithVerdicts(any()),
          ).thenAnswer((_) async => needsIt);
          final router = GoRouter(
            initialLocation: VerifyPage.path,
            routes: [
              GoRoute(
                path: VerifyPage.path,
                builder: (context, _) => const VerifyPage(),
                routes: [
                  GoRoute(
                    path: VerifyConfirmationPage.path,
                    builder: (context, _) => Scaffold(
                      body: TextButton(
                        onPressed: context.pop,
                        child: const Text('leave confirmation'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                identityClaimsRepositoryProvider.overrideWithValue(repository),
                supporterStoreBillingAvailableProvider.overrideWithValue(true),
                isFeatureEnabledProvider(
                  FeatureFlag.confirmationSignIn,
                ).overrideWithValue(true),
                confirmationAccessReaderProvider.overrideWithValue(
                  ({bool refresh = false}) async => ConfirmationAccess.hasNot,
                ),
                authServiceProvider.overrideWithValue(
                  createMockAuthService(
                    authState: AuthState.authenticated,
                    currentPublicKeyHex: _pubkey,
                  ),
                ),
                currentAuthStateProvider.overrideWithValue(
                  AuthState.authenticated,
                ),
                appOAuthSupportProvider.overrideWith((ref) async => true),
              ],
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets('keeps the list on screen while it re-reads', (
          tester,
        ) async {
          await pumpApp(tester);
          final reread = Completer<IdentityClaimStatus>();
          when(
            () => repository.claimsWithVerdicts(any()),
          ).thenAnswer((_) => reread.future);

          await tester.tap(find.text(l10n.verifyRenewConfirmation));
          await tester.pumpAndSettle();
          await tester.tap(find.text('leave confirmation'));
          await tester.pumpAndSettle();

          // The read is still pending, and the list never left.
          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.text('jack'), findsOneWidget);
          expect(find.text(l10n.verifyRenewConfirmation), findsOneWidget);

          reread.complete(needsIt);
          await tester.pumpAndSettle();
          expect(find.text('jack'), findsOneWidget);
        });

        testWidgets('keeps the list and says so when the re-read fails', (
          tester,
        ) async {
          await pumpApp(tester);
          when(
            () => repository.claimsWithVerdicts(any()),
          ).thenThrow(StateError('relay down'));

          await tester.tap(find.text(l10n.verifyRenewConfirmation));
          await tester.pumpAndSettle();
          await tester.tap(find.text('leave confirmation'));
          await tester.pumpAndSettle();

          expect(find.text('jack'), findsOneWidget);
          expect(find.text(l10n.verifyLoadFailed), findsOneWidget);
        });
      });

      testWidgets("reads access from the signed-in account's reader, and a "
          'new account gets its own', (tester) async {
        final firstReads = <bool>[];
        final secondReads = <bool>[];

        await tester.pumpWidget(
          app(repository, ({bool refresh = false}) async {
            firstReads.add(refresh);
            return ConfirmationAccess.hasNot;
          }),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.verifyOneTapWithConfirmationBadge),
          findsOneWidget,
        );
        expect(firstReads, equals([false]));

        // Another account: a new repository, so a new cubit with the new
        // reader, whose answer replaces the first account's.
        await tester.pumpWidget(
          app(secondRepository, ({bool refresh = false}) async {
            secondReads.add(refresh);
            return ConfirmationAccess.has;
          }),
        );
        await tester.pumpAndSettle();

        expect(secondReads, equals([false]));
        expect(firstReads, equals([false]));
        expect(find.text(l10n.verifyOneTapBadge), findsOneWidget);
        expect(find.text(l10n.verifyOneTapWithConfirmationBadge), findsNothing);
      });

      testWidgets('a changed developer override starts a new read', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final reads = <bool>[];
        when(repository.supportedPlatforms).thenAnswer(
          (_) async => const [
            VerifierPlatform(
              key: 'bluesky',
              label: 'Bluesky',
              supported: true,
              oauth: true,
              signinRequires: SigninRequirement.confirmation,
            ),
          ],
        );
        when(() => repository.claimsWithVerdicts(any())).thenAnswer(
          (_) async => const IdentityClaimStatus(
            claims: [],
            verifiedKeys: {},
            verifierReachable: true,
          ),
        );
        when(
          () => repository.confirmationAccess(refresh: any(named: 'refresh')),
        ).thenAnswer((invocation) async {
          reads.add(invocation.namedArguments[#refresh]! as bool);
          return ConfirmationAccess.has;
        });

        // The real reader, so the override's notifier is what swaps it.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityClaimsRepositoryProvider.overrideWithValue(repository),
              sharedPreferencesProvider.overrideWithValue(prefs),
              confirmationAccessDebugBuildProvider.overrideWithValue(true),
              supporterStoreBillingAvailableProvider.overrideWithValue(true),
              isFeatureEnabledProvider(
                FeatureFlag.confirmationSignIn,
              ).overrideWithValue(true),
              authServiceProvider.overrideWithValue(
                createMockAuthService(
                  authState: AuthState.authenticated,
                  currentPublicKeyHex: _pubkey,
                ),
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
              appOAuthSupportProvider.overrideWith((ref) async => true),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: const VerifyPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.verifyOneTapBadge), findsOneWidget);
        expect(reads, equals([false]));

        await ProviderScope.containerOf(tester.element(find.byType(VerifyPage)))
            .read(confirmationAccessOverrideProvider.notifier)
            .set(ConfirmationAccess.hasNot);
        await tester.pumpAndSettle();

        // A new cubit, not the old one with a stale answer: the forced answer
        // shows, and the repository wasn't asked again.
        expect(
          find.text(l10n.verifyOneTapWithConfirmationBadge),
          findsOneWidget,
        );
        expect(reads, equals([false]));
      });
    });

    group('sign in again', () {
      // A sign-in link the verifier says expired, on a platform with sign-in
      // on.
      setUp(() {
        when(repository.supportedPlatforms).thenAnswer(
          (_) async => const [
            VerifierPlatform(
              key: 'twitter',
              label: 'Twitter / X',
              supported: true,
            ),
          ],
        );
        when(() => repository.claimsWithVerdicts(any())).thenAnswer(
          (_) async => const IdentityClaimStatus(
            claims: [_twitter],
            verifiedKeys: {},
            verifierReachable: true,
            signInCodes: {'twitter:jack': SignInLapse.expired},
          ),
        );
      });

      Future<void> pumpPage(
        WidgetTester tester, {
        required bool deviceSupportsOAuth,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityClaimsRepositoryProvider.overrideWithValue(repository),
              ...confirmationOverrides,
              authServiceProvider.overrideWithValue(
                createMockAuthService(
                  authState: AuthState.authenticated,
                  currentPublicKeyHex: _pubkey,
                ),
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
              appOAuthSupportProvider.overrideWith(
                (ref) async => deviceSupportsOAuth,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: const VerifyPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('is offered where the device can finish a sign-in', (
        tester,
      ) async {
        await pumpPage(tester, deviceSupportsOAuth: true);

        expect(find.text(l10n.verifySignInAgain), findsOneWidget);
      });

      testWidgets("is not offered where the device can't finish one", (
        tester,
      ) async {
        await pumpPage(tester, deviceSupportsOAuth: false);

        expect(find.text('jack'), findsOneWidget);
        expect(find.text(l10n.verifySignInAgain), findsNothing);
      });
    });
  });
}
