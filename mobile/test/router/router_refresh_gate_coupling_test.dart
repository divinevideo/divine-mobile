// ABOUTME: Coupling guard — proves appRouterRedirect only branches on the
// ABOUTME: review-status fields that minorAccountReviewStatusAffectsRouting tracks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/providers/route_normalization_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

/// Authenticated identity is known but the signer-backed Nostr client has not
/// finished initializing — mirrors the router-gating suite's harness.
class _NotReadyNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

void main() {
  // The router refreshes only when [minorAccountReviewStatusAffectsRouting]
  // reports a routing-relevant change. That gate projects the review status
  // onto the exact fields [appRouterRedirect] branches on. This suite pins the
  // coupling from the *other* side: if the redirect ever starts depending on a
  // review-status field the gate does not track, two statuses that share a
  // routing signature will route differently and this test fails — signalling
  // that `_minorReviewRoutingSignature` must be extended.
  group('router-refresh gate stays coupled to appRouterRedirect', () {
    late MockAuthService mockAuthService;

    setUp(() {
      resetNavigationState();
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('user-pubkey');
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    // Protected locations that exercise the restricted-account branches of
    // appRouterRedirect (feed → review screen, parent-contact gating,
    // under-13 support gating).
    final probeLocations = <String>[
      VideoFeedPage.pathForIndex(0),
      MinorAccountReviewParentContactScreen.path,
      MinorAccountReviewUnder13SupportScreen.path,
    ];

    MinorAccountReviewStatus restrictedStatus({
      required String id,
      MinorReviewCaseState state =
          MinorReviewCaseState.restrictedPendingUserResponse,
      SuspectedAgeBand ageBand = SuspectedAgeBand.age13To15,
      MinorReviewResolutionType resolution =
          MinorReviewResolutionType.parentVideoOrEmail,
      String instructionsTitle = 'Account review required',
      String supportEmail = 'support@divine.video',
    }) {
      return MinorAccountReviewStatus(
        restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        currentCase: MinorReviewCase(
          id: id,
          state: state,
          suspectedAgeBand: ageBand,
          allowedResolution: resolution,
          instructions: MinorReviewInstructions(
            title: instructionsTitle,
            body: 'We need parental consent information.',
          ),
          supportEmail: supportEmail,
          moderationConversationPubkey: 'moderation-pubkey',
        ),
      );
    }

    /// Lands the router at each probe location under [status] and returns the
    /// resulting locations — the status's "routing fingerprint". Fully tears
    /// its container down before returning so each call is self-contained.
    Future<List<String>> routingFingerprint(
      WidgetTester tester,
      MinorAccountReviewStatus status,
    ) async {
      resetNavigationState();
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => status,
          ),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      );
      // Route normalization is required for the parent-contact fallbacks.
      container.read(routeNormalizationProvider);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(goRouterProvider);
      final landings = <String>[];
      for (final location in probeLocations) {
        router.go(location);
        await tester.pumpAndSettle();
        landings.add(router.routeInformationProvider.value.uri.toString());
      }

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      return landings;
    }

    testWidgets(
      'a routing-identical status refetch produces identical redirect outcomes',
      (tester) async {
        // Two restricted statuses that differ ONLY in fields the redirect must
        // not branch on (case state, id, instructions, support email). The
        // signatured fields — isRestricted, hasCase, moderation ids, and
        // allowsParentVideoOrEmail — are held equal.
        final baseline = restrictedStatus(id: 'case-baseline');
        final routingIdentical = restrictedStatus(
          id: 'case-refetched',
          state: MinorReviewCaseState.submittedForReview,
          instructionsTitle: 'Updated review instructions',
          supportEmail: 'help@divine.video',
        );

        // Precondition: the gate agrees these are routing-identical, so it
        // suppresses the refresh (the whole point of the fix).
        expect(
          minorAccountReviewStatusAffectsRouting(
            AsyncData(baseline),
            AsyncData(routingIdentical),
          ),
          isFalse,
          reason: 'fixtures must share a routing signature for this guard',
        );

        final baselineFingerprint = await routingFingerprint(tester, baseline);
        final refetchedFingerprint = await routingFingerprint(
          tester,
          routingIdentical,
        );

        expect(
          refetchedFingerprint,
          baselineFingerprint,
          reason:
              'appRouterRedirect routed two statuses with an equal routing '
              'signature differently. It now branches on a review-status field '
              'that minorAccountReviewStatusAffectsRouting does not track, so a '
              'genuine change to that field would be swallowed by the refresh '
              'gate. Add the field to _minorReviewRoutingSignature.',
        );
      },
    );
  });
}
