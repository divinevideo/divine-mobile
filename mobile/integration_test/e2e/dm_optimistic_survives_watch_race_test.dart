// ABOUTME: E2E regression for #4193 / PR #4234.
// ABOUTME: After fix, the optimistic DM bubble must survive the empty
// ABOUTME: initial watchMessages tick on a freshly-opened conversation.
// ABOUTME: Requires: the full local Docker stack (mise run local_up), and
// ABOUTME: POST_NOTIFICATIONS pre-granted so no native dialog blocks the UI.

@Tags(['service'])
library;

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bug #4193: DM sent to fresh user invisible until restart', () {
    final senderEmail =
        'dm-race-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const senderPassword = 'TestPass123!';

    testWidgets(
      'optimistic bubble survives the empty initial watchMessages tick '
      'on a freshly-opened conversation',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        // ── Phase 1: Pre-publish recipient profile ──
        //
        // The race fires against any never-messaged pubkey; publishing a
        // Kind 0 here is hygiene so the conversation app bar resolves a
        // real display name and the test mirrors the bug report ("Search
        // for a user to start a DM").
        logPhase('── Phase 1: Pre-publish recipient profile on relay ──');
        final recipient = await publishTestProfileEvent(
          name: 'e2e-dm-race-recipient',
          displayName: 'E2E DM Race',
        );
        logPhase('Recipient profile published: ${recipient.pubkey}');

        // ── Phase 2: Register sender + verify email ──
        logPhase('── Phase 2: Register sender + verify email ──');
        // pumpAndSettle never returns here: the app runs persistent polling
        // timers, so the tree never reaches a quiescent frame. Poll for the
        // app instead of pumping a fixed budget — a cold launch takes well
        // over three seconds to mount MaterialApp.
        launchAppGuarded(app.main);
        final appStarted = await waitForWidget(
          tester,
          find.byType(MaterialApp),
          maxSeconds: 30,
        );
        expect(appStarted, isTrue, reason: 'App should start');

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, senderEmail, senderPassword);

        final foundVerify = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerify, isTrue);

        final token = await getVerificationToken(senderEmail);
        await callVerifyEmail(token);

        final leftVerify = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerify, isTrue);

        // The app requests POST_NOTIFICATIONS right after authentication. A
        // native dialog blocks Flutter interaction and a plain
        // integration_test cannot tap it, so the runner pre-grants the
        // permission (see local_stack/profile.sh). Allow a doubled settle
        // window for the grant to land before interacting again.
        await pumpUntilSettled(tester, maxSeconds: 10);

        // Verify we landed on the main app shell (bottom nav present).
        final hasBottomNav = find
            .bySemanticsIdentifier('home_tab')
            .evaluate()
            .isNotEmpty;
        expect(
          hasBottomNav,
          isTrue,
          reason: 'Should land on main app after verification',
        );

        // ── Phase 3: Resolve sender pubkey + push to conversation ──
        //
        // Skips the inbox FAB → search flow by design. The race lives in
        // ConversationBloc on a fresh conversation (no prior direct_messages
        // rows for these participants), and pushing directly to the route
        // exercises the same ConversationStarted → markConversationAsRead →
        // emit.forEach(watchMessages) path the user hits via search.
        logPhase('── Phase 3: Push directly to conversation route ──');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final senderPubkey = container
            .read(authServiceProvider)
            .currentPublicKeyHex!;
        expect(senderPubkey, isNotEmpty);

        final convId = DmRepository.computeConversationId(
          [senderPubkey, recipient.pubkey],
        );
        final router = GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        );
        router.push(
          ConversationPage.pathForId(convId),
          extra: <String>[recipient.pubkey],
        );
        await pumpUntilSettled(tester);
        expect(
          find.byType(ConversationView),
          findsOneWidget,
          reason: 'ConversationView should mount after route push',
        );

        // ── Phase 4: Type + submit via the keyboard send action ──
        //
        // MessageInputBar wires `TextInputAction.send` →
        // `onSubmitted: (_) => _handleSend()`, so receiveAction triggers
        // the same path as tapping the send button without depending on
        // the unlabelled GestureDetector for it.
        logPhase('── Phase 4: Submit message ──');
        final input = find.byType(TextField);
        expect(input, findsOneWidget);
        await tester.enterText(input, 'race window check');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.testTextInput.receiveAction(TextInputAction.send);

        // ── Phase 5: Pin the optimistic during the sending window ──
        //
        // Probe the bloc directly. Pump until sendStatus reaches sending
        // OR sent — on a fast emulator the status can transition past
        // sending before any pump tick observes the intermediate state,
        // so accepting `sent` here removes the device-speed dependency.
        // Phase 6 still pins the post-send invariants; this phase exists
        // primarily to anchor the bubble assertion on the in-flight or
        // just-completed window, the exact frame pre-fix code would have
        // shown an empty conversation because the watchMessages empty
        // initial tick would have wiped state.messages before
        // sendMessage's persistence committed.
        logPhase('── Phase 5: Pin optimistic visible during sending ──');
        final convElement = tester.element(find.byType(ConversationView));
        final bloc = BlocProvider.of<ConversationBloc>(convElement);

        var observedSendProgress = false;
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final status = bloc.state.sendStatus;
          if (status == SendStatus.sending || status == SendStatus.sent) {
            observedSendProgress = true;
            break;
          }
        }
        expect(
          observedSendProgress,
          isTrue,
          reason:
              'sendStatus should reach sending or sent within 4s '
              '(accepting sent here covers fast-emulator runs where the '
              'sending tick is missed between pumps).',
        );
        expect(
          find.byType(MessageBubble),
          findsOneWidget,
          reason:
              'Bubble must be visible across the send window (regression '
              'for #4193 — pre-fix the empty initial watchMessages tick '
              'would have wiped it before sendMessage committed the '
              'persisted row). pendingOutgoing vs persisted ownership '
              'is asserted in Phase 6 once status is deterministic.',
        );
        expect(
          find.byType(EmptyConversation),
          findsNothing,
          reason:
              'EmptyConversation must not render while an optimistic '
              'or freshly-persisted row exists.',
        );

        // ── Phase 6: Wait for sent + assert bubble persists ──
        //
        // Once sendStatus reaches sent, the pending key is stripped and
        // the watch tick has brought the persisted DmMessage into
        // state.messages. displayedMessages prefers the persisted row,
        // so the bubble stays mounted across the transition.
        logPhase('── Phase 6: Wait for sent + assert persistence ──');
        var observedSent = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (bloc.state.sendStatus == SendStatus.sent) {
            observedSent = true;
            break;
          }
        }
        expect(
          observedSent,
          isTrue,
          reason: 'sendStatus should reach sent within 15s',
        );
        expect(
          bloc.state.pendingOutgoing,
          isEmpty,
          reason:
              'queue row must be deleted on full delivery — '
              'watchOutgoing tick should remove the row in the same '
              'transaction that inserts the persisted message',
        );
        expect(
          bloc.state.messages,
          hasLength(1),
          reason:
              'persisted row must be present in messages after the '
              'watch tick',
        );
        expect(find.byType(MessageBubble), findsOneWidget);

        // ── Phase 7: Pop, re-enter — bubble survives a new bloc ──
        //
        // ConversationPage's BlocProvider is keyed on
        // `(dmRepository, currentPubkey)`, so a fresh push constructs a
        // new ConversationBloc that re-subscribes to watchMessages from
        // scratch. The persisted row must still appear.
        logPhase('── Phase 7: Pop + re-enter ──');
        router.pop();
        await pumpUntilSettled(tester);

        router.push(
          ConversationPage.pathForId(convId),
          extra: <String>[recipient.pubkey],
        );
        await pumpUntilSettled(tester, maxSeconds: 10);
        expect(
          find.byType(MessageBubble),
          findsOneWidget,
          reason: 'Persisted bubble must survive a ConversationBloc recreate.',
        );

        // ── Cleanup ──
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
