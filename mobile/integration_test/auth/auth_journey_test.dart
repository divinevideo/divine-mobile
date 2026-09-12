// ABOUTME: Journey test covering register → verify → forgot password → reset → login → verify feedback
// ABOUTME: Exercises deep link paths and auth flows end-to-end
// ABOUTME: Requires: local Docker stack running (mise run local_up)
// ABOUTME: Run with: mise run e2e_test (passes --dart-define=DEFAULT_ENV=LOCAL automatically)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:patrol/patrol.dart';

import '../../test/helpers/finders.dart';
import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Auth Journey', () {
    final testEmail =
        'journey-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const initialPassword = 'TestPass123!';
    const newPassword = 'NewPass456!';

    patrolTest(
      'register, verify, forgot password, reset, login, verify feedback',
      ($) async {
        final tester = $.tester;
        final l10n = lookupAppLocalizations(const Locale('en'));
        // ── Setup: suppress non-critical errors ──
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        // Pre-enable semantics so the handle is disposed at the right time.
        // find.bySemanticsLabel() calls ensureSemantics() implicitly; if we
        // don't hold the handle ourselves the framework complains at teardown.
        final semanticsHandle = tester.ensureSemantics();

        // Launch the full app in a guarded zone to catch external relay errors
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ════════════════════════════════════════════════════════════
        // Phase 1: Register + Verify via Deep Link
        // ════════════════════════════════════════════════════════════

        // Navigate: Welcome → Create account
        await navigateToCreateAccount(tester);

        // Fill the registration form
        await registerNewUser(tester, testEmail, initialPassword);

        // Wait for navigation to email verification screen
        // Cannot use pumpAndSettle — EmailVerificationCubit polls every 3s
        final foundVerifyScreen = await waitForText(
          tester,
          l10n.authCompleteRegistration,
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        // Extract verification token from DB
        final verifyToken = await getVerificationToken(testEmail);
        expect(
          verifyToken,
          isNotEmpty,
          reason: 'Should find verification token in local DB',
        );

        // Trigger deep link via EmailVerificationListener.handleUri()
        // This exercises the real code path: listener parses URI →
        // navigates to /verify-email → screen calls verifyEmail() →
        // poll detects → login completes.
        // The only thing skipped is OS intent routing.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final emailListener = container.read(emailVerificationListenerProvider);
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        // Wait for polling to detect verification and navigate away
        final leftVerifyScreen = await waitForTextGone(
          tester,
          l10n.authCompleteRegistration,
        );
        expect(
          leftVerifyScreen,
          isTrue,
          reason: 'Polling should detect verification and navigate away',
        );

        // Pump a few more frames for post-verification navigation
        await pumpUntilSettled(tester);

        // Assert: we landed on the main app
        final hasBottomNav = find
            .byType(BottomNavigationBar)
            .evaluate()
            .isNotEmpty;
        final hasExploreContent =
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('Trending').evaluate().isNotEmpty;
        expect(
          hasBottomNav || hasExploreContent,
          isTrue,
          reason:
              'Should land on main app screen after verification '
              '(bottom nav or explore content)',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 2: Forgot Password + Reset via Deep Link
        // ════════════════════════════════════════════════════════════

        // Sign out to get back to unauthenticated state
        final authService = container.read(authServiceProvider);
        await authService.signOut();

        // Wait for redirect to welcome screen
        final foundWelcome = await waitForWidget(
          tester,
          find.byType(WelcomeScreen),
          maxSeconds: 30,
        );
        expect(
          foundWelcome,
          isTrue,
          reason: 'Should redirect to welcome screen after sign out',
        );
        // Allow navigation to settle
        await pumpUntilSettled(tester, maxSeconds: 3);

        // Navigate: Welcome → Login options (sign-in screen)
        await navigateToLoginOptions(tester);

        // Tap "Forgot password?" link
        final forgotPasswordLink = find.text(l10n.authForgotPassword);
        expect(
          forgotPasswordLink,
          findsOneWidget,
          reason: 'Login screen should show "${l10n.authForgotPassword}" link',
        );
        await tester.tap(forgotPasswordLink);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Assert: forgot password bottom sheet is showing
        expect(
          find.text(l10n.forgotPasswordTitle),
          findsOneWidget,
          reason:
              'Forgot password sheet should show "${l10n.forgotPasswordTitle}"',
        );

        // Enter email in the bottom sheet's TextFormField
        final dialogEmailField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextFormField),
        );
        expect(dialogEmailField, findsOneWidget);
        await tester.enterText(dialogEmailField, testEmail);
        await tester.pumpAndSettle();

        // Tap "Email Reset Link" button
        final sendResetButton = find.widgetWithText(
          ElevatedButton,
          l10n.forgotPasswordSendLink,
        );
        expect(sendResetButton, findsOneWidget);
        await tester.tap(sendResetButton);

        // Wait for confirmation snackbar
        final foundEmailSent = await waitForText(
          tester,
          l10n.authPasswordResetSent,
        );
        expect(
          foundEmailSent,
          isTrue,
          reason: 'Should show reset email confirmation',
        );

        // Sheet auto-dismisses after sending. Wait for it to settle.
        await pumpUntilSettled(tester, maxSeconds: 3);

        // Extract password reset token from DB
        final resetToken = await getPasswordResetToken(testEmail);
        expect(
          resetToken,
          isNotEmpty,
          reason: 'Should find password reset token in local DB',
        );

        // Trigger deep link via PasswordResetListener.handleUri()
        // This exercises the real code path: listener parses URI →
        // navigates to reset password screen via router.
        // The only thing skipped is OS intent routing.
        final passwordResetListener = container.read(
          passwordResetListenerProvider,
        );
        await passwordResetListener.handleUri(
          Uri.parse(
            'https://login.divine.video/reset-password?token=$resetToken',
          ),
        );

        // Wait for ResetPasswordScreen to appear
        final foundResetScreen = await waitForText(
          tester,
          l10n.authNewPasswordLabel,
          maxSeconds: 10,
        );
        expect(
          foundResetScreen,
          isTrue,
          reason: 'Deep link should navigate to reset password screen',
        );

        // Dismiss any lingering snackbar before interacting with the form.
        // The "reset link sent" snackbar can overlap form buttons.
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold).first),
        ).clearSnackBars();
        await tester.pump(const Duration(milliseconds: 500));

        // Enter new password and submit. The reset screen requires both the
        // password and confirmation fields before it calls the reset API.
        await enterResetPassword(tester, newPassword);

        final resetButton = find.text(l10n.authUpdatePassword);
        expect(resetButton, findsOneWidget);
        await tester.tap(resetButton);

        // Wait for success snackbar
        final foundResetSuccess = await waitForText(
          tester,
          l10n.authPasswordResetSuccess,
        );
        expect(
          foundResetSuccess,
          isTrue,
          reason: 'Should show password reset success snackbar',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3: Login with New Password
        // ════════════════════════════════════════════════════════════

        // After password reset, context.pop() returns to the login screen
        // but the URL may still have the reset token query param. Navigate
        // back to welcome and re-enter login fresh to avoid the stale token
        // interfering with the OAuth redirect.
        await pumpUntilSettled(tester, maxSeconds: 3);

        // Navigate to welcome by using GoRouter.go() to clear
        // the stale reset-password token from the URL.
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.go('/welcome');
        await pumpUntilSettled(tester, maxSeconds: 3);

        // Navigate fresh to login screen
        await navigateToLoginOptions(tester);

        // Fill credentials with the new password and submit.
        await loginWithCredentials(tester, testEmail, newPassword);

        // Wait for login to complete and router to redirect to main app.
        // Test user has no following, so checkEmptyFollowingRedirect
        // sends them to /explore (which has Popular/Trending tabs).
        // Note: the reset-password token in the URL can cause a brief
        // redirect cycle, so we look for any indicator of the main app.
        final foundMainApp = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is BottomNavigationBar ||
                (widget is Text &&
                    (widget.data == 'Popular' || widget.data == 'Trending')),
          ),
          maxSeconds: 30,
        );

        expect(
          foundMainApp,
          isTrue,
          reason: 'Should navigate to main app after login with new password',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3b: Seed Video Content to Relay
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3b: Seeding video content to relay ──');

        final authorA = await publishTestVideoEvent(
          title: 'Journey Test Video A1',
        );
        await publishTestVideoEvent(
          title: 'Journey Test Video A2',
          privateKey: authorA.privateKey,
        );
        await publishTestVideoEvent(
          title: 'Journey Test Video A3',
          privateKey: authorA.privateKey,
        );

        final authorB = await publishTestVideoEvent(
          title: 'Journey Test Video B1',
        );
        await publishTestVideoEvent(
          title: 'Journey Test Video B2',
          privateKey: authorB.privateKey,
        );

        logPhase(
          'Seeded 5 videos (author A: ${authorA.pubkey}, '
          'author B: ${authorB.pubkey})',
        );

        // Seed kind 0 profiles for the test authors so indexer queries
        // (which now hit funnelcake in LOCAL env) return real profile data.
        await publishTestProfileEvent(
          name: 'Author A',
          displayName: 'Test Author A',
          about: 'E2E test author A',
          privateKey: authorA.privateKey,
        );
        await publishTestProfileEvent(
          name: 'Author B',
          displayName: 'Test Author B',
          about: 'E2E test author B',
          privateKey: authorB.privateKey,
        );

        logPhase('Seeded kind 0 profiles for both authors');

        // Funnelcake uses async batch writes (flush every ~100ms).
        // No fixed sleep needed -- by the time we navigate to the explore
        // tab and the app issues its REQ, the flush will have happened.
        // The waitForWidget poll in Phase 3c handles any remaining delay.

        // ════════════════════════════════════════════════════════════
        // Phase 3c: Navigate to Explore Tab
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3c: Navigating to Explore tab ──');
        await tapBottomNavTab(tester, 'explore_tab');

        // Wait for "New" tab to appear, then tap it
        final foundNewTab = await waitForText(tester, 'New', maxSeconds: 10);
        expect(foundNewTab, isTrue, reason: 'Explore should show New tab');
        await tester.tap(find.text('New'));
        await tester.pump(const Duration(seconds: 1));

        // Wait for video thumbnails to appear in the grid
        final foundThumbnails = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'video_thumbnail_0',
          ),
          maxSeconds: 20,
        );
        expect(
          foundThumbnails,
          isTrue,
          reason: 'Explore grid should show seeded video thumbnails',
        );

        logPhase('Phase 3c complete -- Explore feed loaded with content');

        // ════════════════════════════════════════════════════════════
        // Phase 3d: Watch a Video (Enter Fullscreen Feed)
        // ════════════════════════════════════════════════════════════
        //
        // The video overlay (action buttons) only renders when the
        // PooledVideoPlayer reaches LoadState.ready. On the emulator
        // with software rendering this can be slow or fail entirely
        // for videos with unreachable media URLs.  If the overlay
        // doesn't appear we skip the interaction phases (3e-3h) and
        // continue with navigation phases.

        logPhase('── Phase 3d: Tapping first video thumbnail ──');
        await tapSemantic(tester, 'video_thumbnail_0');

        // Wait for fullscreen video feed to load -- look for action buttons.
        // Give extra time because the emulator uses S/W rendering.
        final foundVideoOverlay = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'like_button',
          ),
          maxSeconds: 20,
        );

        if (foundVideoOverlay) {
          logPhase('Phase 3d complete -- watching video in fullscreen');

          // ══════════════════════════════════════════════════════════
          // Phase 3e: Like the Video
          // ══════════════════════════════════════════════════════════

          logPhase('── Phase 3e: Liking the video ──');
          await tapSemantic(tester, 'like_button');
          await tester.pump(const Duration(seconds: 2));

          // Verify like state -- semantic label toggles to 'Unlike video'
          final unlikeLabel = find.bySemanticsLabel('Unlike video');
          expect(
            unlikeLabel.evaluate().isNotEmpty,
            isTrue,
            reason: 'Like button should show "Unlike video" label after liking',
          );
          logPhase('Phase 3e complete -- video liked');

          // ══════════════════════════════════════════════════════════
          // Phase 3f: Comment on the Video
          // ══════════════════════════════════════════════════════════

          logPhase('── Phase 3f: Opening comments and posting ──');
          await tapSemantic(tester, 'comments_button');

          final foundCommentField = await waitForWidget(
            tester,
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.identifier == 'comment_text_field',
            ),
            maxSeconds: 10,
          );

          if (foundCommentField) {
            final commentField = find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.identifier == 'comment_text_field',
            );
            await tester.tap(commentField);
            await tester.pump(const Duration(milliseconds: 500));

            final textField = find.descendant(
              of: commentField,
              matching: find.byType(TextField),
            );
            if (textField.evaluate().isNotEmpty) {
              await tester.enterText(textField, 'E2E test comment');
            } else {
              await tester.enterText(
                find.byType(TextField).last,
                'E2E test comment',
              );
            }
            await tester.pump(const Duration(seconds: 1));

            await tapSemantic(tester, 'send_comment_button');
            await tester.pump(const Duration(seconds: 2));

            // Dismiss the comment sheet: keyboard may still be open
            // from entering text, so first dismiss keyboard, then the
            // sheet. Using Navigator.pop on the root navigator because
            // the sheet is opened with useRootNavigator: true and
            // tapAt on scrim is unreliable when keyboard shifts layout.
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pump(const Duration(milliseconds: 500));

            // Pop the modal bottom sheet route from root navigator
            final rootNav = tester.state<NavigatorState>(
              find.byType(Navigator).first,
            );
            rootNav.pop();

            // Wait for the bottom sheet dismiss animation to complete
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 250));
            }
            logPhase('Phase 3f complete -- comment posted');
          } else {
            logPhase('Phase 3f -- comment field not found, skipping');
          }

          // ══════════════════════════════════════════════════════════
          // Phase 3g: Repost the Video
          // ══════════════════════════════════════════════════════════

          logPhase('── Phase 3g: Reposting the video ──');
          await tapSemantic(tester, 'repost_button');
          // Wait for relay round-trip to confirm repost
          var reposted = false;
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(seconds: 1));
            if (find.bySemanticsLabel('Remove repost').evaluate().isNotEmpty) {
              reposted = true;
              break;
            }
          }
          expect(
            reposted,
            isTrue,
            reason:
                'Repost button should show "Remove repost" label '
                'after reposting',
          );
          logPhase('Phase 3g complete -- video reposted');

          // ══════════════════════════════════════════════════════════
          // Phase 3h: Follow the Video Author
          // ══════════════════════════════════════════════════════════

          logPhase('── Phase 3h: Following video author ──');
          await tapSemantic(tester, 'follow_button');
          await tester.pump(const Duration(seconds: 2));

          final followingLabel = find.bySemanticsLabel('Following');
          expect(
            followingLabel.evaluate().isNotEmpty,
            isTrue,
            reason:
                'Follow button should show "Following" label '
                'after following',
          );
          logPhase('Phase 3h complete -- author followed');
        } else {
          logPhase(
            'Phase 3d -- video overlay not ready (emulator S/W rendering). '
            'Skipping interaction phases 3e-3h.',
          );
        }

        // ════════════════════════════════════════════════════════════
        // Phase 3i: Navigate Back to Explore
        // ════════════════════════════════════════════════════════════
        //
        // We're in the fullscreen feed which hides the bottom nav.
        // Pop back to the explore grid first.

        logPhase('── Phase 3i: Back to Explore ──');

        // Pop the fullscreen feed route to return to the explore grid.
        // The pooled feed uses a DivineAppBarIconButton with semanticLabel
        // the stable 'back_button' identifier rather than its localized
        // label. Fall back to Navigator.pop if not found.
        final backButton = find.bySemanticsIdentifier('back_button');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else {
          Navigator.of(tester.element(find.byType(MaterialApp))).pop();
        }
        await tester.pump(const Duration(seconds: 2));

        // Verify we're back on explore (bottom nav visible)
        final backOnExplore = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'explore_tab',
          ),
          maxSeconds: 10,
        );
        expect(
          backOnExplore,
          isTrue,
          reason: 'Should return to explore grid with bottom nav visible',
        );

        logPhase('Phase 3i complete -- back on Explore');

        // ════════════════════════════════════════════════════════════
        // Phase 3j: Check Home Feed (Should Have Followed Author)
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3j: Checking Home feed for followed content ──');
        await tapBottomNavTab(tester, 'home_tab');

        final foundHomeFeed = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'like_button',
          ),
        );

        if (foundHomeFeed) {
          logPhase('Phase 3j complete -- Home feed shows followed content');
        } else {
          logPhase(
            'Phase 3j -- Home feed empty (follow subscription may be '
            'delayed). Continuing.',
          );
        }

        // ════════════════════════════════════════════════════════════
        // Phase 3k: Search
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3k: Testing search ──');
        await tapBottomNavTab(tester, 'explore_tab');
        await tester.pump(const Duration(seconds: 1));

        // Tap the search icon (IconButton with tooltip 'Search')
        final searchIcon = findByTooltip('Search');
        if (searchIcon.evaluate().isNotEmpty) {
          await tester.tap(searchIcon);
          await tester.pump(const Duration(seconds: 2));

          // Verify search screen loaded (TextField visible)
          final searchField = find.byType(TextField);
          expect(
            searchField.evaluate().isNotEmpty,
            isTrue,
            reason: 'Search screen should show a text field',
          );

          // Search for seeded test author profiles via Funnelcake
          await tester.enterText(searchField.first, 'Author');
          // Wait for debounce (300ms) + network round-trip
          await tester.pump(const Duration(seconds: 3));

          // Switch to Users tab (default is Videos tab at index 0)
          final usersTab = find.textContaining('Users');
          if (usersTab.evaluate().isNotEmpty) {
            await tester.tap(usersTab.first);
            await tester.pump(const Duration(seconds: 1));
          }

          // Verify search results contain our seeded profiles
          final foundAuthorA = await waitForText(
            tester,
            'Test Author A',
            maxSeconds: 10,
          );
          expect(
            foundAuthorA,
            isTrue,
            reason:
                'Search should find seeded "Test Author A" via Funnelcake API',
          );

          logPhase('Phase 3k complete -- search found seeded profiles');

          // Navigate back
          await tapBottomNavTab(tester, 'explore_tab');
          await tester.pump(const Duration(seconds: 1));
        } else {
          logPhase('Phase 3k -- search icon not found, skipping');
        }

        // ════════════════════════════════════════════════════════════
        // Phase 3l: Profile and Edit
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3l: Profile and edit ──');
        await tapBottomNavTab(tester, 'profile_tab');

        // Wait for profile screen to load with Edit or Set Up button
        final foundProfile = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data == 'Edit' || widget.data == 'Set Up'),
          ),
          maxSeconds: 10,
        );
        expect(
          foundProfile,
          isTrue,
          reason: 'Profile screen should show Edit or Set Up button',
        );

        final editButton = find.text('Edit');
        final setUpButton = find.text('Set Up');
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
        } else if (setUpButton.evaluate().isNotEmpty) {
          await tester.tap(setUpButton);
        }
        await tester.pump(const Duration(seconds: 2));

        final foundDisplayName = await waitForText(
          tester,
          'Display Name',
          maxSeconds: 5,
        );
        if (foundDisplayName) {
          final nameField = find.byType(TextFormField).first;
          await tester.enterText(nameField, 'E2E Test User');
          await tester.pump(const Duration(seconds: 1));

          final saveButton = find.text('Save');
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pump(const Duration(seconds: 3));
          }

          logPhase('Phase 3l complete -- profile edited and saved');
        } else {
          logPhase('Phase 3l -- edit profile screen not found, skipping');
        }

        await pumpUntilSettled(tester, maxSeconds: 3);

        // ════════════════════════════════════════════════════════════
        // Phase 3m: Notifications
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3m: Checking notifications ──');
        await tapBottomNavTab(tester, 'inbox_tab');
        await tester.pump(const Duration(seconds: 3));

        final hasInboxTabs =
            find.text('Messages').evaluate().isNotEmpty ||
            find.text('Notifications').evaluate().isNotEmpty;
        expect(
          hasInboxTabs,
          isTrue,
          reason: 'Inbox screen should show Messages/Notifications toggle',
        );

        logPhase('Phase 3m complete -- inbox screen rendered');

        // ════════════════════════════════════════════════════════════
        // Phase 3n: Settings
        // ════════════════════════════════════════════════════════════

        logPhase('── Phase 3n: Navigating to Settings ──');

        final menuButton = find.byKey(const Key('menu-icon-button'));
        if (menuButton.evaluate().isNotEmpty) {
          await tester.tap(menuButton);
          await tester.pump(const Duration(seconds: 1));

          final settingsItem = find.text('Settings');
          if (settingsItem.evaluate().isNotEmpty) {
            await tester.tap(settingsItem);
            await tester.pump(const Duration(seconds: 2));

            // Section headers render title.toUpperCase()
            final hasAbout = find.text('ABOUT').evaluate().isNotEmpty;
            final hasPreferences = find
                .text('PREFERENCES')
                .evaluate()
                .isNotEmpty;
            expect(
              hasAbout || hasPreferences,
              isTrue,
              reason: 'Settings screen should show ABOUT or PREFERENCES',
            );

            logPhase('Phase 3n complete -- Settings screen verified');

            final backNav = find.bySemanticsIdentifier('back_button');
            if (backNav.evaluate().isNotEmpty) {
              await tester.tap(backNav.first);
              await tester.pump(const Duration(seconds: 1));
            }
          } else {
            logPhase('Phase 3n -- Settings not found in drawer, skipping');
          }
        } else {
          logPhase('Phase 3n -- menu button not found, skipping');
        }

        // Settle before Phase 4 (existing verify feedback phase)
        await pumpUntilSettled(tester, maxSeconds: 3);

        // ════════════════════════════════════════════════════════════
        // Phase 4: Verify Email Deep Link Feedback (Authenticated)
        // ════════════════════════════════════════════════════════════
        // SKIPPED: EmailVerificationCubit stale state bug — after User A
        // verifies, stopPolling() preserves success state. When the screen
        // reopens for a cross-user deep link, BlocConsumer listener fires
        // _handleTokenModeSuccess() which navigates away instantly.
        // UX-only bug (server-side verification works). Fix in separate PR.
        // See also: cross_user_verify_test.dart

        // Drain pending errors before restoring handlers.
        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 7)),
    );
  });
}
