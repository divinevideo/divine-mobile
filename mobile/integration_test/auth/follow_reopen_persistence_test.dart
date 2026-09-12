// ABOUTME: Verifies authenticated follow state survives app background/reopen
// ABOUTME: Covers the #4577 auth/following persistence path end-to-end

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Follow persistence after reopen', () {
    patrolTest(
      'authenticated following survives app reopen and repository reload',
      ($) async {
        final tester = $.tester;
        final testEmail =
            'follow-reopen-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
        const password = 'TestPass123!';

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, password);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Registration should navigate to email verification',
        );

        final verifyToken = await getVerificationToken(testEmail);
        expect(
          verifyToken,
          isNotEmpty,
          reason: 'Local Keycast DB should contain verification token',
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        await container
            .read(emailVerificationListenerProvider)
            .handleUri(
              Uri.parse(
                'https://login.divine.video/verify-email?token=$verifyToken',
              ),
            );

        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(
          leftVerifyScreen,
          isTrue,
          reason: 'Verification should complete and leave verification screen',
        );
        await pumpUntilSettled(tester, maxSeconds: 3);

        final author = await publishTestVideoEvent(
          title: 'Follow Reopen Persistence Video',
        );
        await publishTestProfileEvent(
          name: 'Follow Reopen Author',
          displayName: 'Follow Reopen Author',
          about: 'E2E follow persistence author',
          privateKey: author.privateKey,
        );

        final followRepository = container.read(followRepositoryProvider);
        await followRepository.follow(author.pubkey);
        expect(
          followRepository.isFollowing(author.pubkey),
          isTrue,
          reason: 'FollowRepository should record the followed author',
        );
        expect(
          container.read(cachedFollowingListProvider),
          contains(author.pubkey),
          reason: 'Cached following list should include the followed author',
        );

        await $.platformAutomator.mobile.pressHome();
        await Future<void>.delayed(const Duration(seconds: 2));
        await $.platformAutomator.mobile.openApp();
        await tester.pump(const Duration(seconds: 3));

        container.invalidate(followRepositoryProvider);
        await tester.pump(const Duration(milliseconds: 250));
        final reloadedFollowRepository = container.read(
          followRepositoryProvider,
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (reloadedFollowRepository.isFollowing(author.pubkey)) break;
        }

        expect(
          reloadedFollowRepository.isFollowing(author.pubkey),
          isTrue,
          reason:
              'Follow state should survive app reopen and repository reload',
        );
        // cachedFollowingListProvider is keepAlive, so force it to re-read
        // SharedPreferences rather than reusing the pre-background value.
        container.invalidate(cachedFollowingListProvider);
        expect(
          container.read(cachedFollowingListProvider),
          contains(author.pubkey),
          reason: 'Cached following list should still include followed author',
        );

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
