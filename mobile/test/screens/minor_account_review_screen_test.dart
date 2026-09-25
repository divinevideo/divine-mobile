import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../helpers/go_router.dart';
import '../helpers/scroll.dart';
import '../helpers/url_launcher_test_double.dart';

void main() {
  group('MinorAccountReviewScreen', () {
    testWidgets('shows the welcome-entry family guidance copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinorAccountReviewScreen(
            entryPoint: MinorAccountReviewEntryPoint.welcome,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Family guide'), findsOneWidget);
      expect(find.text("Not 16 yet? That's OK."), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MinorAccountReviewScreen)),
      );
      final welcomeBody = tester.widget<Text>(
        find.text(l10n.minorAccountReviewWelcomeBody),
      );
      expect(welcomeBody.style?.color, VineTheme.whiteText);
      await tester.scrollUntilVisible(
        find.text('More for families'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('More for families'), findsOneWidget);
      expect(
        find.text("Read Divine's kids policy", skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Get family guides and tips', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(
          'If you are 16 or older and got sent here by mistake, contact Divine support so a real person can review it.',
        ),
        findsNothing,
      );
    });

    testWidgets('welcome-entry back button pops to the previous screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MinorAccountReviewScreen(
                          entryPoint: MinorAccountReviewEntryPoint.welcome,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open family guide'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open family guide'));
      await tester.pumpAndSettle();

      expect(find.text('Family guide'), findsOneWidget);

      // Not tester.pageBack(): it looks for a framework `BackButton` tooltip
      // or a `CupertinoNavigationBarBackButton`, and since #8916 neither type
      // is what DiVineAppBar builds.
      await tester.tap(
        find.bySemanticsIdentifier(DiVineAppBarLeading.backButtonSemanticId),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open family guide'), findsOneWidget);
      expect(find.text('Family guide'), findsNothing);
    });

    testWidgets('shows the condensed public under-13 copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(child: MinorAccountReviewUnder13Screen()),
        ),
      );

      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MinorAccountReviewUnder13Screen)),
      );

      expect(
        find.text(l10n.minorAccountReviewUnder13PublicTitle),
        findsOneWidget,
      );
      expect(find.text(l10n.minorAccountReviewUnder13WhyTitle), findsOneWidget);
      expect(
        find.text(l10n.minorAccountReviewUnder13PublicBody),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewUnder13FamilyTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewUnder13FamilyBody),
        findsOneWidget,
      );
      // Three boxes total: why / family / come-back-at-13.
      await tester.scrollUntilVisible(
        find.text(l10n.minorAccountReviewUnder13ComeBackTitle),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.minorAccountReviewUnder13ComeBackTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewUnder13ComeBackBody),
        findsOneWidget,
      );
      expect(
        l10n.minorAccountReviewUnder13ComeBackBody,
        'Depending on the rules where you live, you may be able to come back '
        'and apply for your own account. In that case, if you’re between '
        '13 and 15, you’ll need consent from a parent or guardian.',
      );
      // The honesty / legal cards from the original four-card layout
      // stay removed.
      expect(
        find.text("Why we won't tell you to just click back"),
        findsNothing,
      );
      expect(find.text('Why the answer is still no'), findsNothing);
      // No Close button — the user exits via the app bar back arrow or
      // by closing the app themselves (iOS has no sanctioned quit API).
      expect(find.text(l10n.commonClose), findsNothing);
    });

    testWidgets('shows the public parent-consent screen copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(child: MinorAccountReviewParentConsentScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MinorAccountReviewParentConsentScreen)),
      );

      expect(
        find.text(l10n.minorAccountReviewParentConsentTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewParentConsentHonestyTitle),
        findsOneWidget,
      );
      // The two "A parent or guardian should…" sentences moved into the
      // "why we're asking" balloon, after its paragraph and a gap.
      expect(
        find.text(
          '${l10n.minorAccountReviewParentConsentHonestyBody}'
          '\n\n'
          '${l10n.minorAccountReviewParentConsentBody}',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('What the video should show'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('What the video should show'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('How to send it'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('How to send it'), findsOneWidget);
      expect(
        find.text('Email Divine support', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows next step CTA for 13-15 cases', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-teen',
                  state: MinorReviewCaseState.restrictedPendingUserResponse,
                  suspectedAgeBand: SuspectedAgeBand.age13To15,
                  allowedResolution:
                      MinorReviewResolutionType.parentVideoOrEmail,
                  instructions: MinorReviewInstructions(
                    title: 'Account review required',
                    body: 'We need parental consent information.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Account review required'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Next step'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next step'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Open review page'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open review page'), findsOneWidget);
      expect(find.text('Continue', skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders the server-provided response clock states', (
      tester,
    ) async {
      final cases = <MinorReviewResponseClock, MinorReviewResponseDeadline>{
        MinorReviewResponseClock.running: MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.running,
          serverNow: DateTime.utc(2026, 8, 26, 14, 30),
          deadlineAt: DateTime.utc(2026, 9, 10, 14, 30),
        ),
        MinorReviewResponseClock.paused: MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.paused,
          pausedAt: DateTime.utc(2026, 8, 26, 14, 30),
          remainingDaysWhenPaused: 7.5,
        ),
        MinorReviewResponseClock.expired: MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.expired,
          serverNow: DateTime.utc(2026, 9, 11, 14, 30),
          deadlineAt: DateTime.utc(2026, 9, 10, 14, 30),
        ),
        MinorReviewResponseClock.notApplicable:
            const MinorReviewResponseDeadline(
              clock: MinorReviewResponseClock.notApplicable,
            ),
        MinorReviewResponseClock.unavailable:
            const MinorReviewResponseDeadline.unavailable(),
      };

      for (final entry in cases.entries) {
        await _pumpRestrictedReview(tester, entry.value);

        switch (entry.key) {
          case MinorReviewResponseClock.running:
            expect(find.text('Time to respond'), findsOneWidget);
            expect(
              find.textContaining('15 days left to respond'),
              findsOneWidget,
            );
          case MinorReviewResponseClock.paused:
            expect(find.text('Response clock paused'), findsOneWidget);
            expect(find.textContaining('About 7 days'), findsOneWidget);
          case MinorReviewResponseClock.expired:
            expect(find.text('Response deadline passed'), findsOneWidget);
            expect(find.textContaining('left to respond'), findsNothing);
          case MinorReviewResponseClock.notApplicable:
            expect(find.textContaining('left to respond'), findsNothing);
            expect(find.textContaining('Response clock'), findsNothing);
          case MinorReviewResponseClock.unavailable:
            expect(find.text('Deadline unavailable'), findsOneWidget);
            expect(find.textContaining('left to respond'), findsNothing);
        }
      }
    });

    testWidgets(
      'shows review in progress without primary CTA after submission',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                return const MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'case-reviewing',
                    state: MinorReviewCaseState.submittedForReview,
                    suspectedAgeBand: SuspectedAgeBand.age13To15,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: MinorReviewInstructions(
                      title: 'Submission received',
                      body: 'We are reviewing this case.',
                    ),
                    supportEmail: 'support@divine.video',
                  ),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(MinorAccountReviewScreen)),
        );

        await tester.scrollUntilVisible(
          find.text('Review in progress'),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text('Review in progress'), findsOneWidget);
        expect(find.text('Continue', skipOffstage: false), findsNothing);
        expect(
          find.text('Parent Support Instructions', skipOffstage: false),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.text(l10n.supportContactSupport),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.supportContactSupport), findsOneWidget);
      },
    );

    // #8157: restricted minors must not be offered account portability from
    // the hard-gate screen, regardless of their suspected age band.
    testWidgets('does not offer account portability to a restricted minor', (
      tester,
    ) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      final launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      for (final ageBand in [
        SuspectedAgeBand.under13,
        SuspectedAgeBand.age13To15,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                return MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'case-reviewing',
                    state: MinorReviewCaseState.submittedForReview,
                    suspectedAgeBand: ageBand,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: const MinorReviewInstructions(
                      title: 'Submission received',
                      body: 'We are reviewing this case.',
                    ),
                    supportEmail: 'support@divine.video',
                  ),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(MinorAccountReviewScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.minorAccountReviewLogOut),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You can take your account with you', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Move your account', skipOffstage: false),
          findsNothing,
        );
        expect(launcher.launched, isEmpty);
      }
    });

    testWidgets("explains what happens to a restricted minor's videos", (
      tester,
    ) async {
      for (final ageBand in [
        SuspectedAgeBand.under13,
        SuspectedAgeBand.age13To15,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                return MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'case-content-disclosure',
                    state: MinorReviewCaseState.submittedForReview,
                    suspectedAgeBand: ageBand,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: const MinorReviewInstructions(
                      title: 'Submission received',
                      body: 'We are reviewing this case.',
                    ),
                    supportEmail: 'support@divine.video',
                  ),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(MinorAccountReviewScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.minorAccountReviewContentTitle),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.minorAccountReviewContentTitle), findsOneWidget);
        expect(find.text(l10n.minorAccountReviewContentBody), findsOneWidget);
      }
    });

    testWidgets('explains reconsideration through support for both age bands', (
      tester,
    ) async {
      for (final ageBand in [
        SuspectedAgeBand.under13,
        SuspectedAgeBand.age13To15,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(ageBand),
            overrides: [
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                return MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                  currentCase: MinorReviewCase(
                    id: 'case-appeal-copy',
                    state: MinorReviewCaseState.submittedForReview,
                    suspectedAgeBand: ageBand,
                    allowedResolution:
                        MinorReviewResolutionType.parentVideoOrEmail,
                    instructions: const MinorReviewInstructions(
                      title: 'Submission received',
                      body: 'We are reviewing this case.',
                    ),
                    supportEmail: 'support@divine.video',
                  ),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(MinorAccountReviewScreen)),
        );
        final expectedBody = ageBand == SuspectedAgeBand.under13
            ? l10n.minorAccountReviewAppealUnder13Body
            : l10n.minorAccountReviewAppealTeenBody;
        final otherBody = ageBand == SuspectedAgeBand.under13
            ? l10n.minorAccountReviewAppealTeenBody
            : l10n.minorAccountReviewAppealUnder13Body;

        await tester.scrollUntilVisible(
          find.text(l10n.minorAccountReviewAppealTitle),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.minorAccountReviewAppealTitle), findsOneWidget);
        expect(find.text(expectedBody), findsOneWidget);
        expect(find.text(otherBody), findsNothing);
        expect(find.text(l10n.supportContactSupport), findsOneWidget);
      }
    });

    // #8239: a decided case has no remaining user action, so Support Center
    // used to be returned as the primary action *and* rendered unconditionally
    // below the reconsideration card — two identical buttons straddling it.
    // The reachable states are openReported, cleared, deniedClosed and unknown.
    testWidgets('offers the support contact once on a decided case, below the '
        'reconsideration card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-decided',
                  state: MinorReviewCaseState.deniedClosed,
                  suspectedAgeBand: SuspectedAgeBand.age13To15,
                  allowedResolution:
                      MinorReviewResolutionType.parentVideoOrEmail,
                  instructions: MinorReviewInstructions(
                    title: 'Review complete',
                    body: 'This case is closed.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MinorAccountReviewScreen)),
      );

      await tester.scrollUntilVisible(
        find.text(l10n.supportContactSupport),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportContactSupport), findsOneWidget);
      expect(find.text(l10n.minorAccountReviewAppealTitle), findsOneWidget);
    });

    testWidgets(
      'Check Again re-reads the protected-minor flag, not just the review '
      'status, so an approved teen is gated without relaunch (#176)',
      (tester) async {
        var protectedFetches = 0;
        final container = ProviderContainer(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-reviewing',
                  state: MinorReviewCaseState.submittedForReview,
                  suspectedAgeBand: SuspectedAgeBand.age13To15,
                  allowedResolution:
                      MinorReviewResolutionType.parentVideoOrEmail,
                  instructions: MinorReviewInstructions(
                    title: 'Submission received',
                    body: 'We are reviewing this case.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
            protectedMinorStatusProvider.overrideWith((ref) async {
              protectedFetches++;
              return ProtectedMinorStatus.notProtected();
            }),
          ],
        );
        addTearDown(container.dispose);
        // Keep the provider active so an invalidate forces a re-fetch we can
        // count. In production isProtectedMinorProvider keeps it live app-wide,
        // so invalidating it re-reads the flag and re-applies the DM/content
        // gates without a relaunch.
        container.listen(protectedMinorStatusProvider, (_, _) {});

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(protectedFetches, 1);

        await scrollUntilTappable(
          tester,
          find.text('Check Again'),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text('Check Again'));
        await tester.pumpAndSettle();

        expect(
          protectedFetches,
          2,
          reason:
              'tapping Check Again must re-read the protected-minor flag, not '
              'just the review status',
        );
      },
    );

    // The appeal is how a restricted account contests the decision, so it must
    // reach a person. Outside the under-13 path it opens private support
    // directly, as Account Status does. Under-13 goes to the parent-email
    // screen instead: a support conversation is filed against the signed-in
    // account, which here is the child's.
    group('appeal support contact', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      testWidgets('a teen appeal opens support messages without navigating', (
        tester,
      ) async {
        final goRouter = MockGoRouter();
        when(() => goRouter.push(any())).thenAnswer((_) async => null);
        var openCalls = 0;

        await _pumpAppeal(
          tester,
          ageBand: SuspectedAgeBand.age13To15,
          goRouter: goRouter,
          openSupportMessages: () async {
            openCalls++;
            return true;
          },
        );
        await tester.tap(find.text(l10n.supportContactSupport));
        await tester.pumpAndSettle();

        expect(openCalls, equals(1));
        verifyNever(() => goRouter.push(any()));
      });

      testWidgets(
        'a teen appeal falls back to email when messages cannot open',
        (
          tester,
        ) async {
          String? emailBody;
          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.age13To15,
            openSupportMessages: () async => false,
            composeEmail:
                ({
                  required toEmail,
                  required subject,
                  required body,
                  sharePositionOrigin,
                }) async {
                  emailBody = body;
                },
          );
          await tester.tap(find.text(l10n.supportContactSupport));
          await tester.pumpAndSettle();

          expect(emailBody, contains(l10n.supportCouldNotOpenMessages));
        },
      );

      testWidgets('a teen appeal shows progress and ignores a repeated tap', (
        tester,
      ) async {
        final opening = Completer<bool>();
        var openCalls = 0;
        await _pumpAppeal(
          tester,
          ageBand: SuspectedAgeBand.age13To15,
          openSupportMessages: () {
            openCalls++;
            return opening.future;
          },
        );
        await tester.tap(find.text(l10n.supportContactSupport));
        await tester.pump();
        await tester.tap(find.text(l10n.supportContactSupport));

        expect(openCalls, equals(1));
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

        opening.complete(true);
        await tester.pumpAndSettle();
        expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      });

      testWidgets(
        'an under-13 appeal goes to parent support, never messaging',
        (
          tester,
        ) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push(any())).thenAnswer((_) async => null);
          var openCalls = 0;

          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.under13,
            goRouter: goRouter,
            openSupportMessages: () async {
              openCalls++;
              return true;
            },
          );
          await tester.tap(find.text(l10n.supportContactSupport));
          await tester.pumpAndSettle();

          expect(openCalls, isZero);
          verify(
            () => goRouter.push(MinorAccountReviewUnder13SupportScreen.path),
          ).called(1);
        },
      );

      // The under-13 path is the band OR a support-email resolution. Keying the
      // appeal on the band alone would send this case into messaging as a child.
      testWidgets(
        'a support-email case with an unknown band still goes to parent support',
        (tester) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push(any())).thenAnswer((_) async => null);
          var openCalls = 0;

          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.unknown,
            allowedResolution: MinorReviewResolutionType.supportEmailOnly,
            goRouter: goRouter,
            openSupportMessages: () async {
              openCalls++;
              return true;
            },
          );
          await tester.tap(find.text(l10n.supportContactSupport));
          await tester.pumpAndSettle();

          expect(openCalls, isZero);
          verify(
            () => goRouter.push(MinorAccountReviewUnder13SupportScreen.path),
          ).called(1);
        },
      );

      // The server gives an account claiming 16+ a support-review resolution:
      // its next step is asking support to review, which is the appeal.
      // "Continue" used to reach that through the Support Center menu, the
      // Report a Bug path this issue closes.
      testWidgets(
        'a 16+ support-review case offers no Continue into the menu',
        (
          tester,
        ) async {
          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.age16PlusClaimed,
            state: MinorReviewCaseState.restrictedPendingUserResponse,
            allowedResolution: MinorReviewResolutionType.supportReviewOnly,
          );

          expect(find.text(l10n.minorAccountReviewContinue), findsNothing);
          expect(find.text(l10n.supportContactSupport), findsOneWidget);
        },
      );

      testWidgets(
        'an under-13 case that needs action offers parent instructions',
        (tester) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push(any())).thenAnswer((_) async => null);
          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.under13,
            state: MinorReviewCaseState.restrictedPendingSupportEmail,
            goRouter: goRouter,
          );

          await tester.tap(
            find.text(l10n.minorAccountReviewParentSupportInstructions),
          );
          await tester.pumpAndSettle();

          verify(
            () => goRouter.push(MinorAccountReviewUnder13SupportScreen.path),
          ).called(1);
        },
      );

      testWidgets('a parent-contact case continues to parent contact', (
        tester,
      ) async {
        final goRouter = MockGoRouter();
        when(() => goRouter.push(any())).thenAnswer((_) async => null);
        await _pumpAppeal(
          tester,
          ageBand: SuspectedAgeBand.age13To15,
          state: MinorReviewCaseState.restrictedPendingUserResponse,
          goRouter: goRouter,
        );

        await tester.tap(find.text(l10n.minorAccountReviewContinue));
        await tester.pumpAndSettle();

        verify(
          () => goRouter.push(MinorAccountReviewParentContactScreen.path),
        ).called(1);
      });

      // An unrecognised or missing resolution parses to unknown. The appeal
      // button is already the right next step, so there is no Continue into
      // the Support Center menu for it either.
      testWidgets(
        'an unrecognised resolution offers no Continue into the menu',
        (
          tester,
        ) async {
          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.age13To15,
            state: MinorReviewCaseState.restrictedPendingUserResponse,
            allowedResolution: MinorReviewResolutionType.unknown,
          );

          expect(find.text(l10n.minorAccountReviewContinue), findsNothing);
          expect(find.text(l10n.supportContactSupport), findsOneWidget);
        },
      );

      // An under-13 case that still needs action already offers "Parent
      // Support Instructions", which opens the same parent-support screen, so
      // a second button to it would only add a choice with no difference.
      testWidgets(
        'an under-13 case that needs action shows one button to parent support',
        (tester) async {
          await _pumpAppeal(
            tester,
            ageBand: SuspectedAgeBand.under13,
            state: MinorReviewCaseState.restrictedPendingSupportEmail,
          );

          expect(
            find.text(l10n.minorAccountReviewParentSupportInstructions),
            findsOneWidget,
          );
          expect(find.text(l10n.supportContactSupport), findsNothing);
        },
      );

      // Only the under-13 duplicate is hidden. A teen on the parent-contact
      // step has a Continue, and must still be able to contest the decision.
      testWidgets('a parent-contact case keeps the appeal beside Continue', (
        tester,
      ) async {
        await _pumpAppeal(
          tester,
          ageBand: SuspectedAgeBand.age13To15,
          state: MinorReviewCaseState.restrictedPendingUserResponse,
        );

        expect(find.text(l10n.minorAccountReviewContinue), findsOneWidget);
        expect(find.text(l10n.supportContactSupport), findsOneWidget);
      });

      // With no case the account's age is unknown. Support chat puts it in
      // front of a person who can find out; the parent-email screen would be a
      // dead end for an adult.
      testWidgets('an appeal with no review case opens support messages', (
        tester,
      ) async {
        final goRouter = MockGoRouter();
        when(() => goRouter.push(any())).thenAnswer((_) async => null);
        var openCalls = 0;

        await _pumpAppeal(
          tester,
          ageBand: SuspectedAgeBand.unknown,
          noCase: true,
          goRouter: goRouter,
          openSupportMessages: () async {
            openCalls++;
            return true;
          },
        );
        await tester.tap(find.text(l10n.supportContactSupport));
        await tester.pumpAndSettle();

        expect(openCalls, equals(1));
        verifyNever(() => goRouter.push(any()));
      });
    });
  });
}

/// Pumps a restricted case, by default one awaiting moderator review, which
/// renders no primary action. [noCase] pumps a restriction with no case, in
/// which [ageBand] is ignored.
Future<void> _pumpAppeal(
  WidgetTester tester, {
  required SuspectedAgeBand ageBand,
  MinorReviewCaseState state = MinorReviewCaseState.submittedForReview,
  MinorReviewResolutionType? allowedResolution,
  bool noCase = false,
  MockGoRouter? goRouter,
  OpenSupportMessages? openSupportMessages,
  ComposeSupportEmail? composeEmail,
}) async {
  // Tall surface so the appeal button is laid out without scrolling.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final app = MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MinorAccountReviewScreen(
      openSupportMessages: openSupportMessages,
      composeEmail: composeEmail,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
          return MinorAccountReviewStatus(
            restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
            currentCase: noCase
                ? null
                : MinorReviewCase(
                    id: 'case-appeal',
                    state: state,
                    suspectedAgeBand: ageBand,
                    allowedResolution:
                        allowedResolution ??
                        (ageBand == SuspectedAgeBand.under13
                            ? MinorReviewResolutionType.supportEmailOnly
                            : MinorReviewResolutionType.parentVideoOrEmail),
                    instructions: const MinorReviewInstructions(
                      title: 'Submission received',
                      body: 'We are reviewing this case.',
                    ),
                    supportEmail: 'support@divine.video',
                  ),
          );
        }),
      ],
      child: goRouter == null
          ? app
          : MockGoRouterProvider(goRouter: goRouter, child: app),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRestrictedReview(
  WidgetTester tester,
  MinorReviewResponseDeadline deadline,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
          return MinorAccountReviewStatus(
            restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
            currentCase: MinorReviewCase(
              id: 'clock-case',
              state: MinorReviewCaseState.restrictedPendingUserResponse,
              suspectedAgeBand: SuspectedAgeBand.age13To15,
              allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
              instructions: const MinorReviewInstructions(
                title: 'Account review required',
                body: 'We need parental consent information.',
              ),
              supportEmail: 'support@divine.video',
              responseDeadline: deadline,
            ),
          );
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MinorAccountReviewScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
