// ABOUTME: Full user journey E2E test: register → verify → record → publish → delete → verify gone
// ABOUTME: Requires: local Docker stack running (mise run local_up) + Android emulator
// ABOUTME: Run with: mise run e2e_test (passes --dart-define=DEFAULT_ENV=LOCAL automatically)

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('User Journey: Register → Record → Publish → Delete → Verify', () {
    final testEmail =
        'e2e-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'full video lifecycle: create account, record, publish, delete, '
      'confirm gone',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1-3: Register and verify email ──
        logPhase('── Phase 1: Registration ──');
        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerifyScreen, isTrue);

        final token = await getVerificationToken(testEmail);
        expect(token, isNotEmpty);
        await callVerifyEmail(token);

        final verified = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(verified, isTrue);
        await pumpUntilSettled(tester);

        final hasBottomNav = find
            .bySemanticsIdentifier('home_tab')
            .evaluate()
            .isNotEmpty;
        final hasExploreContent =
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('Trending').evaluate().isNotEmpty;
        expect(
          hasBottomNav || hasExploreContent,
          isTrue,
          reason: 'Should land on main app after verification',
        );
        logPhase('Registration and verification complete');

        // ── Phase 4: Open camera and record a video ──
        logPhase('── Phase 4: Record video via emulator camera ──');

        // Tap the camera button in bottom nav
        await tapSemantic(tester, 'camera_button');
        logPhase('Camera button tapped');

        // Tapping the camera button fires the native OS permission dialog
        // directly on the current page — no in-app "Continue" priming screen.
        // Grant camera permission via Patrol native automation.
        if (await $.platformAutomator.mobile.isPermissionDialogVisible(
          timeout: const Duration(seconds: 5),
        )) {
          await $.platformAutomator.mobile.grantPermissionWhenInUse();
          logPhase('Camera permission granted');
        }

        // Grant microphone permission if prompted
        await tester.pump(const Duration(seconds: 1));
        if (await $.platformAutomator.mobile.isPermissionDialogVisible(
          timeout: const Duration(seconds: 3),
        )) {
          await $.platformAutomator.mobile.grantPermissionWhenInUse();
          logPhase('Microphone permission granted');
        }

        // Dismiss the "Why six seconds?" onboarding sheet if it appears
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          final gotIt = find.text('Got it!');
          if (gotIt.evaluate().isNotEmpty) {
            await tester.tap(gotIt);
            await tester.pump(const Duration(milliseconds: 500));
            logPhase('Dismissed onboarding sheet');
            break;
          }
        }

        // Wait for camera to fully initialize (authorized state, child
        // rendered, camera service started). The record button exists in the
        // placeholder but is disabled until isCameraInitialized is true.
        // We wait for the tooltip to say "Start recording" with the button
        // actually in the authorized camera view.
        logPhase('Waiting for camera to initialize...');
        var cameraReady = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          // Check if we're past the permission gate: the pre-permission
          // sheet text should be gone and the record button should be enabled.
          final noPermSheet = find
              .text('Allow camera, microphone & gallery access')
              .evaluate()
              .isEmpty;
          final hasRecordBtn = find
              .bySemanticsIdentifier('divine-camera-record-button')
              .evaluate()
              .isNotEmpty;
          if (noPermSheet && hasRecordBtn) {
            cameraReady = true;
            break;
          }
        }
        expect(
          cameraReady,
          isTrue,
          reason: 'Camera should initialize after granting permissions',
        );
        // Give camera service a moment to fully start
        await tester.pump(const Duration(seconds: 2));
        logPhase('Camera ready');

        // Use tap-based recording instead of long-press. The native camera
        // on the emulator needs several seconds to produce its first keyframe
        // (startRecording awaits this). A long-press release at 2s would call
        // stopRecording while _isStartingRecording is still true, causing an
        // early return with no clip added.
        final recordButton = find.bySemanticsIdentifier(
          'divine-camera-record-button',
        );

        // First tap → toggleRecording() → startRecording()
        await tester.tap(recordButton);
        logPhase('Record tap 1 — starting recording');

        // Wait for recording to truly start. On the emulator the camera
        // can take 5-15s to produce its first keyframe. Poll the record
        // button's tooltip: it changes from "Start recording" to
        // "Stop recording" once recording begins.
        var recordingStarted = false;
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          final button = find.bySemanticsIdentifier(
            'divine-camera-record-button',
          );
          if (button.evaluate().isNotEmpty) {
            final semantics = tester.getSemantics(button);
            if (semantics.tooltip == 'Stop recording') {
              recordingStarted = true;
              logPhase('Recording truly started (tooltip: Stop recording)');
              break;
            }
          }
        }
        if (!recordingStarted) {
          logPhase('Warning: recording did not start within 20s');
        }

        // Now record for at least 3 seconds to get a usable clip
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        logPhase('Recorded for 3s');

        // Second tap → toggleRecording() → stopRecording() → addClip()
        await tester.tap(recordButton);
        logPhase('Record tap 2 — stopping recording');

        // Wait for clip processing (thumbnail, metadata extraction).
        // On the emulator, stopRecording can take several seconds.
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        logPhase('Clip processing done (10s wait)');

        // Tap the continue button and verify we navigate to the editor.
        // The button exists in the tree but has onPressed: null when no clips,
        // so tapping it when disabled is a no-op.
        final continueButton = find.bySemanticsLabel(
          'Continue to video editor',
        );

        // Poll: tap continue and check if we leave the recorder screen.
        // If recording succeeded, clipCount > 0 and the button is enabled.
        var leftRecorder = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (continueButton.evaluate().isEmpty) {
            leftRecorder = true;
            break;
          }
          // Re-tap every ~2 seconds in case it just became enabled
          if (i % 8 == 0) {
            await tester.tap(continueButton);
          }
        }
        expect(
          leftRecorder,
          isTrue,
          reason:
              'Should navigate away from recorder after tapping Continue. '
              'If this fails, the emulator camera did not produce a clip — '
              'check logcat for "Recording truly started".',
        );
        logPhase('Proceeding to video editor');

        // ── Phase 5: Skip editor, add title, publish ──
        logPhase('── Phase 5: Publish video ──');

        // Wait for the editor "Done" button (check icon) that pops with clips
        final doneButton = find.bySemanticsLabel('Done');
        final foundEditor = await waitForWidget(
          tester,
          doneButton,
        );
        expect(
          foundEditor,
          isTrue,
          reason: 'Editor "Done" button should appear on clip editor screen',
        );

        await tester.tap(doneButton);
        await tester.pump(const Duration(seconds: 2));
        logPhase('Editor Next tapped, proceeding to metadata');

        // Wait for metadata screen — look for the Post button
        final foundPost = await waitForWidget(
          tester,
          find.bySemanticsIdentifier('post_button'),
        );
        expect(foundPost, isTrue, reason: 'Metadata screen should appear');

        // Enter a unique title
        final videoTitle =
            'E2E Delete Test ${DateTime.now().millisecondsSinceEpoch}';
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, videoTitle);
        await tester.pump(const Duration(milliseconds: 500));

        // Dismiss keyboard
        await tester.tapAt(const Offset(10, 100));
        await tester.pump(const Duration(milliseconds: 500));

        // Wait for the video render to finish (Post button becomes enabled
        // only when finalRenderedClip is available and isProcessing is false).
        // Then tap Post and wait for navigation to the profile screen.
        final postButton = find.bySemanticsIdentifier('post_button');
        var posted = false;
        for (var i = 0; i < 240; i++) {
          await tester.pump(const Duration(milliseconds: 250));

          // Check if we've already navigated to the shell
          if (find.bySemanticsIdentifier('profile_tab').evaluate().isNotEmpty) {
            posted = true;
            break;
          }

          // Re-tap Post every ~2s in case it just became enabled
          if (i % 8 == 0 && postButton.evaluate().isNotEmpty) {
            await tester.tap(postButton);
            logPhase('Post tap attempt ${i ~/ 8 + 1}');
          }
        }
        expect(
          posted,
          isTrue,
          reason: 'Should return to main shell after publishing',
        );
        await pumpUntilSettled(tester);
        logPhase('Video published successfully');

        // ── Phase 6: Find the video and query relay to confirm ──
        logPhase('── Phase 6: Verify video on relay ──');

        // Get the user's pubkey to query their videos
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(userPubkey, isNotNull, reason: 'User pubkey should be in DB');

        // Poll the relay until the video event appears. The blossom upload
        // and relay publish happen asynchronously after the UI navigates
        // to the profile screen, so we need to wait.
        logPhase('Waiting for video to appear on relay...');
        var userVideos = <Event>[];
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          userVideos = await queryRelay({
            'kinds': [34236],
            'authors': [userPubkey],
          });
          if (userVideos.isNotEmpty) {
            logPhase('Video found on relay after ${i * 500}ms');
            break;
          }
        }
        expect(
          userVideos,
          isNotEmpty,
          reason: 'User should have at least one video on relay',
        );
        final publishedVideo = userVideos.first;
        logPhase(
          'Found video on relay: ${publishedVideo.id} '
          '(author: $userPubkey)',
        );

        // ── Phase 7: Navigate to profile, open video, delete via Edit ──
        logPhase('── Phase 7: Delete video through Edit Video dialog ──');

        // Go to profile tab to see own videos
        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester, maxSeconds: 10);
        logPhase('On profile tab');

        // Tap the video thumbnail to open fullscreen player.
        // ProfileVideosGrid assigns semantics identifier
        // 'video_thumbnail_$index' to each tile.
        final videoTile = find.bySemanticsIdentifier('video_thumbnail_0');
        final foundTile = await waitForWidget(
          tester,
          videoTile,
        );
        expect(
          foundTile,
          isTrue,
          reason: 'Profile should show video thumbnail tile',
        );

        await tester.tap(videoTile);
        await tester.pump(const Duration(seconds: 2));
        logPhase('Tapped video thumbnail → fullscreen player');

        // Tap the edit pencil icon to open the Edit Video dialog.
        // The button has semanticLabel: 'Edit video' in
        // pooled_fullscreen_video_feed_screen.dart.
        final editButton = find.bySemanticsLabel('Edit video');
        final foundEdit = await waitForWidget(
          tester,
          editButton,
          maxSeconds: 10,
        );
        expect(
          foundEdit,
          isTrue,
          reason: 'Edit video button should appear on fullscreen player',
        );

        await tester.tap(editButton);
        await tester.pump(const Duration(seconds: 2));
        logPhase('Tapped Edit video → Edit Video dialog');

        // Find and tap "Delete Video" button in the Edit Video dialog
        final deleteButton = find.text('Delete Video');
        final foundDelete = await waitForWidget(
          tester,
          deleteButton,
          maxSeconds: 10,
        );
        expect(
          foundDelete,
          isTrue,
          reason: 'Delete Video button should appear in Edit Video dialog',
        );
        await tester.tap(deleteButton);
        await tester.pump(const Duration(seconds: 1));
        logPhase('Tapped Delete Video');

        // Confirm deletion in the "Delete Video?" confirmation dialog.
        // The dialog has "Cancel" and "Delete" buttons.
        final confirmDelete = find.text('Delete');
        final foundConfirm = await waitForWidget(
          tester,
          confirmDelete,
          maxSeconds: 5,
        );
        expect(
          foundConfirm,
          isTrue,
          reason: 'Delete confirmation dialog should appear',
        );
        // Tap the last "Delete" (the action button, not the dialog title)
        await tester.tap(confirmDelete.last);
        await tester.pump(const Duration(seconds: 2));
        logPhase('Confirmed deletion');

        // Wait for "Video deleted" snackbar (confirms success)
        final foundSnackbar = await waitForText(
          tester,
          'Video deleted',
        );
        expect(
          foundSnackbar,
          isTrue,
          reason: 'Should see "Video deleted" snackbar',
        );
        logPhase('Delete snackbar confirmed');

        // ── Phase 8: Navigate back to profile, verify video is gone ──
        logPhase('── Phase 8: Verify video gone after deletion ──');

        // The edit dialog pops after deletion. We should be back on the
        // fullscreen player. Navigate back to profile.
        // Use system back or tap back button to leave fullscreen player.
        await tester.pageBack();
        await pumpUntilSettled(tester);

        // Navigate: profile → home → explore → profile to force refresh
        await tapBottomNavTab(tester, 'home_tab');
        await pumpUntilSettled(tester);

        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);

        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester, maxSeconds: 10);
        logPhase('Navigated back to profile');

        // Verify the deleted video is no longer visible on the profile grid
        final videoTileAfterDelete = find.bySemanticsIdentifier(
          'video_thumbnail_0',
        );
        expect(
          videoTileAfterDelete,
          findsNothing,
          reason: 'Deleted video should not appear on profile after deletion',
        );
        logPhase('Confirmed: video tile gone from profile grid');

        // ── Phase 9: Query relay to confirm deletion ──
        logPhase('── Phase 9: Relay verification ──');

        // Poll for the kind 5 delete event (app publishes async, may
        // take a moment to reach the relay).
        var hasDeleteForVideo = false;
        for (var i = 0; i < 15; i++) {
          final deleteEvents = await queryRelay({
            'kinds': [5],
            'authors': [userPubkey],
          });
          hasDeleteForVideo = deleteEvents.any(
            (e) => e.tags.any(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'e' &&
                  tag[1] == publishedVideo.id,
            ),
          );
          if (hasDeleteForVideo) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          hasDeleteForVideo,
          isTrue,
          reason: 'Kind 5 delete event should exist on relay for the video',
        );
        logPhase('Kind 5 delete event confirmed on relay');

        // FunnelCake filters deleted events immediately — the original
        // event should no longer appear in query results.
        final afterDelete = await queryRelay({
          'ids': [publishedVideo.id],
        });
        expect(
          afterDelete,
          isEmpty,
          reason: 'Deleted video should be filtered from relay queries',
        );
        logPhase('Relay confirmed: video filtered after kind 5');

        // ── Phase 10: Final stability check ──
        logPhase('── Phase 10: Final state verification ──');
        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);

        final hasExploreScreen =
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('New').evaluate().isNotEmpty;
        expect(
          hasExploreScreen,
          isTrue,
          reason: 'Should be on explore screen after full journey',
        );

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  });
}
