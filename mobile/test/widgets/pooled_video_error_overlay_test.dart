// ABOUTME: Tests for PooledVideoErrorOverlay widget
// ABOUTME: Verifies UI rendering for each VideoErrorType and moderation
// ABOUTME: enrichment for divine URL 404 errors.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../builders/test_video_event_builder.dart';
import '../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager;

Finder _findDivineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

/// The single blurhash layer rendered beneath the error scrim.
BlurhashDisplay _blurhashOf(WidgetTester tester) =>
    tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay));

/// A valid event-level blurhash used to distinguish the frame-derived preview
/// from the generic content-type fallback.
const _eventBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

void main() {
  group(PooledVideoErrorOverlay, () {
    late VideoEvent divineVideo;
    late VideoEvent thirdPartyVideo;
    late bool retryPressed;
    late bool skipPressed;
    late bool verifyAgePressed;
    late AppLocalizations l10n;

    // Valid 64-char hex sha256 for moderation status resolution.
    const testSha256 =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUp(() {
      divineVideo = TestVideoEventBuilder.create(
        id: 'test-video-id',
        videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
      );
      thirdPartyVideo = TestVideoEventBuilder.create(
        id: 'third-party-video',
        videoUrl: 'https://cdn.example.com/video.mp4',
      );
      retryPressed = false;
      skipPressed = false;
      verifyAgePressed = false;
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Widget buildWidget({
      VideoErrorType? errorType,
      VideoEvent? video,
      VoidCallback? onVerifyAge,
      VoidCallback? onSkip,
      bool isVerifying = false,
      bool isAuthRetryExhausted = false,
      VideoPlaybackStatusCubit? playbackStatusCubit,
    }) {
      final overlay = PooledVideoErrorOverlay(
        video: video ?? divineVideo,
        onRetry: () => retryPressed = true,
        onSkip: onSkip,
        onVerifyAge: onVerifyAge,
        errorType: errorType,
        isVerifying: isVerifying,
        isAuthRetryExhausted: isAuthRetryExhausted,
      );
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => null,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: playbackStatusCubit == null
                ? BlocProvider(
                    create: (_) => VideoPlaybackStatusCubit(),
                    child: overlay,
                  )
                : BlocProvider<VideoPlaybackStatusCubit>.value(
                    value: playbackStatusCubit,
                    child: overlay,
                  ),
          ),
        ),
      );
    }

    Widget buildWidgetWithModeration({
      required VideoErrorType? errorType,
      required VideoModerationStatus moderationStatus,
      VideoEvent? video,
      VoidCallback? onVerifyAge,
      VoidCallback? onSkip,
      VideoPlaybackStatusCubit? playbackStatusCubit,
    }) {
      final overlay = PooledVideoErrorOverlay(
        video: video ?? divineVideo,
        onRetry: () => retryPressed = true,
        onSkip: onSkip,
        onVerifyAge: onVerifyAge,
        errorType: errorType,
      );
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => moderationStatus,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: playbackStatusCubit == null
                ? BlocProvider(
                    create: (_) => VideoPlaybackStatusCubit(),
                    child: overlay,
                  )
                : BlocProvider<VideoPlaybackStatusCubit>.value(
                    value: playbackStatusCubit,
                    child: overlay,
                  ),
          ),
        ),
      );
    }

    Widget buildWidgetWithModerationFuture({
      required VideoErrorType? errorType,
      required Future<VideoModerationStatus?> moderationFuture,
      VideoEvent? video,
    }) {
      final overlay = PooledVideoErrorOverlay(
        video: video ?? divineVideo,
        onRetry: () => retryPressed = true,
        onVerifyAge: () => verifyAgePressed = true,
        errorType: errorType,
      );
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) => moderationFuture,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider(
              create: (_) => VideoPlaybackStatusCubit(),
              child: overlay,
            ),
          ),
        ),
      );
    }

    group('forbidden', () {
      testWidgets('shows shield icon and "Content restricted"', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.forbidden),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
        expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
      });

      testWidgets('does not show retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.forbidden),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoErrorRetry), findsNothing);
      });

      testWidgets('shows retryable playback error for third-party video URLs', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.forbidden,
            video: thirdPartyVideo,
            onSkip: () => skipPressed = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
        expect(find.text(l10n.videoErrorContentRestricted), findsNothing);
        expect(find.text(l10n.videoErrorContentRestrictedBody), findsNothing);
        expect(find.text(l10n.videoErrorSkip), findsNothing);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);

        await tester.tap(find.text(l10n.videoErrorRetry));
        await tester.pump();

        expect(retryPressed, isTrue);
        expect(skipPressed, isFalse);
      });
    });

    group('ageRestricted', () {
      testWidgets('shows lock icon and "Age-restricted content"', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.ageRestricted),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.lockSimple), findsOneWidget);
        expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
      });

      testWidgets('shows Retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.ageRestricted),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows a loading spinner and disables Verify age while verifying',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgePressed = true,
              isVerifying: true,
            ),
          );
          // Not pumpAndSettle: the loading spinner animates indefinitely.
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          // Disabled while verifying — a tap must be a no-op.
          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));
          await tester.pump();
          expect(verifyAgePressed, isFalse);
        },
      );

      testWidgets('auto-runs Verify age for already-authorized viewers', (
        tester,
      ) async {
        final playbackStatusCubit = VideoPlaybackStatusCubit(
          canAutoAuthorizeAgeRestrictedMedia: () async => true,
        );

        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.ageRestricted,
            onVerifyAge: () => verifyAgePressed = true,
            playbackStatusCubit: playbackStatusCubit,
          ),
        );
        await tester.pump();

        expect(verifyAgePressed, isTrue);
        await playbackStatusCubit.close();
      });

      testWidgets(
        'auto-runs Verify age only once across overlay teardown and rebuild',
        (tester) async {
          final playbackStatusCubit = VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () async => true,
          );
          var verifyAgeCalls = 0;

          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgeCalls++,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pump();

          expect(verifyAgeCalls, 1);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgeCalls++,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pump();

          expect(verifyAgeCalls, 1);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await playbackStatusCubit.close();
        },
      );

      testWidgets(
        'preserves auto retry when the overlay unmounts during eligibility',
        (tester) async {
          final eligibility = Completer<bool>();
          final playbackStatusCubit = VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () => eligibility.future,
          );
          var verifyAgeCalls = 0;

          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgeCalls++,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pump();

          await tester.pumpWidget(const SizedBox.shrink());
          eligibility.complete(true);
          await tester.pump();

          expect(verifyAgeCalls, 0);
          expect(
            playbackStatusCubit.state.hasAutoRetryAttempted(divineVideo.id),
            isFalse,
          );

          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgeCalls++,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pump();

          expect(verifyAgeCalls, 1);
          expect(
            playbackStatusCubit.state.hasAutoRetryAttempted(divineVideo.id),
            isTrue,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await playbackStatusCubit.close();
        },
      );

      testWidgets('does not auto-run Verify age when adult content is hidden', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.ageRestricted,
            onVerifyAge: () => verifyAgePressed = true,
          ),
        );
        await tester.pump();

        expect(verifyAgePressed, isFalse);
      });

      testWidgets(
        'shows unavailable copy after authenticated retry is exhausted',
        (tester) async {
          final playbackStatusCubit = VideoPlaybackStatusCubit();
          addTearDown(playbackStatusCubit.close);
          playbackStatusCubit.markAuthRetryExhausted(divineVideo.id);

          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgePressed = true,
              onSkip: () => skipPressed = true,
              isAuthRetryExhausted: true,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
          expect(find.text(l10n.videoErrorUnavailable), findsOneWidget);
          expect(find.text(l10n.videoErrorUnavailableBody), findsOneWidget);
          expect(find.text(l10n.videoErrorAgeRestricted), findsNothing);
          expect(find.text(l10n.videoErrorVerifyAgeButton), findsNothing);
          expect(find.text(l10n.videoErrorRetry), findsNothing);
          expect(find.text(l10n.videoErrorSkip), findsOneWidget);

          await tester.tap(find.text(l10n.videoErrorSkip));
          await tester.pump();

          expect(skipPressed, isTrue);
          expect(verifyAgePressed, isFalse);
        },
      );
    });

    group('notFound', () {
      testWidgets('shows "Video not found" with retry', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.notFound),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows shield icon when moderation status indicates blocked',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: true,
                quarantined: false,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);
        },
      );

      testWidgets('shows Skip when moderation status indicates blocked', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidgetWithModeration(
            errorType: VideoErrorType.notFound,
            moderationStatus: const VideoModerationStatus(
              moderated: true,
              blocked: true,
              quarantined: false,
              ageRestricted: false,
              needsReview: false,
              aiGenerated: false,
            ),
            onSkip: () => skipPressed = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoErrorSkip), findsOneWidget);

        await tester.tap(find.text(l10n.videoErrorSkip));
        await tester.pump();

        expect(skipPressed, isTrue);
      });

      testWidgets(
        'shows shield icon when moderation status indicates quarantined',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: true,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
        },
      );

      testWidgets(
        'shows age-gated explanation and verify action when moderation status is ageRestricted',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: false,
                ageRestricted: true,
                needsReview: false,
                aiGenerated: false,
              ),
              onVerifyAge: () => verifyAgePressed = true,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorVerifyAgeBody), findsOneWidget);
          expect(find.text(l10n.videoErrorVerifyAgeButton), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);

          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));

          expect(verifyAgePressed, isTrue);
        },
      );

      testWidgets(
        'shows retry when moderation age restriction has no verify action',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: false,
                ageRestricted: true,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorVerifyAgeButton), findsNothing);
          expect(find.text(l10n.videoErrorRetry), findsOneWidget);

          await tester.tap(find.text(l10n.videoErrorRetry));
          await tester.pump();

          expect(retryPressed, isTrue);
        },
      );

      testWidgets(
        'auto-runs verify action for moderation age restriction when already authorized',
        (tester) async {
          final playbackStatusCubit = VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () async => true,
          );

          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: false,
                ageRestricted: true,
                needsReview: false,
                aiGenerated: false,
              ),
              onVerifyAge: () => verifyAgePressed = true,
              playbackStatusCubit: playbackStatusCubit,
            ),
          );
          await tester.pumpAndSettle();

          expect(verifyAgePressed, isTrue);
          await playbackStatusCubit.close();
        },
      );

      testWidgets('skips moderation lookup for non-divine video URLs', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidgetWithModeration(
            errorType: VideoErrorType.notFound,
            moderationStatus: const VideoModerationStatus(
              moderated: true,
              blocked: true,
              quarantined: false,
              ageRestricted: false,
              needsReview: false,
              aiGenerated: false,
            ),
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        // Should show plain 404, not moderation-restricted.
        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });
    });

    group('generic', () {
      testWidgets('shows "Video playback error" with retry', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.generic,
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets('shows generic error for null error type', (tester) async {
        await tester.pumpWidget(buildWidget(video: thirdPartyVideo));
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows "Content restricted" when moderation status indicates blocked',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: true,
                quarantined: false,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);
        },
      );
    });

    group('dead media fallback', () {
      // Route the thumbnail through a stubbed cache so its load fails
      // deterministically (like an expired 401/404) and stays off the real
      // on-disk cache in the merged test isolate.
      setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
      tearDown(() => debugImageCacheOverride = null);

      testWidgets(
        'reveals the blurhash when a present thumbnail fails to load (#6242)',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(errorType: VideoErrorType.notFound),
          );
          await tester.pumpAndSettle();

          // The thumbnail collapsed into its (empty) errorWidget, so it no
          // longer covers the blurhash beneath it...
          expect(find.byKey(const ValueKey('error')), findsOneWidget);
          // ...leaving the blurhash visible instead of a bare color.
          expect(find.byType(BlurhashDisplay), findsOneWidget);
        },
      );

      testWidgets('renders a blurhash when the thumbnail URL is missing', (
        tester,
      ) async {
        final noThumbnail = TestVideoEventBuilder.create(
          id: 'no-thumbnail-video',
          videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
          thumbnailUrl: '',
        );

        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.notFound, video: noThumbnail),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('keeps the event blurhash for not-found dead media', (
        tester,
      ) async {
        final withBlurhash = TestVideoEventBuilder.create(
          id: 'blurhash-video',
          videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
          thumbnailUrl: '',
          blurhash: _eventBlurhash,
        );

        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.notFound, video: withBlurhash),
        );
        await tester.pumpAndSettle();

        // The event's own blurhash is passed through, not the generic
        // content-type fallback, so broken/expired media still degrades to
        // the real frame impression.
        expect(_blurhashOf(tester).blurhash, equals(_eventBlurhash));
      });
    });

    group('restricted media suppression', () {
      // Keep the stubbed thumbnail off the real on-disk cache, matching the
      // dead-media group, so the pre-suppression frame never hits the network.
      setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
      tearDown(() => debugImageCacheOverride = null);

      // Carries both a thumbnail and its own event blurhash, so a failure to
      // suppress would surface a frame-derived preview.
      VideoEvent restrictedVideo() => TestVideoEventBuilder.create(
        id: 'restricted-video',
        videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
        thumbnailUrl: 'https://blossom.divine.video/$testSha256.jpg',
        blurhash: _eventBlurhash,
      );

      testWidgets('suppresses event blurhash and thumbnail for forbidden', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.forbidden,
            video: restrictedVideo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(_blurhashOf(tester).blurhash, isNull);
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets(
        'suppresses event blurhash and thumbnail for age-restricted',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              video: restrictedVideo(),
            ),
          );
          await tester.pumpAndSettle();

          expect(_blurhashOf(tester).blurhash, isNull);
          expect(find.byType(VineCachedImage), findsNothing);
        },
      );

      testWidgets(
        'suppresses event blurhash and thumbnail for moderation-blocked media',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              video: restrictedVideo(),
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: true,
                quarantined: false,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_blurhashOf(tester).blurhash, isNull);
          expect(find.byType(VineCachedImage), findsNothing);
        },
      );

      testWidgets(
        'suppresses event blurhash and thumbnail while moderation is loading',
        (tester) async {
          final moderationCompleter = Completer<VideoModerationStatus?>();

          await tester.pumpWidget(
            buildWidgetWithModerationFuture(
              errorType: VideoErrorType.notFound,
              video: restrictedVideo(),
              moderationFuture: moderationCompleter.future,
            ),
          );
          await tester.pump();

          expect(_blurhashOf(tester).blurhash, isNull);
          expect(find.byType(VineCachedImage), findsNothing);

          moderationCompleter.complete(null);
          await tester.pumpAndSettle();
        },
      );
    });

    group('retry', () {
      testWidgets('retry button calls onRetry', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.generic,
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.videoErrorRetry));
        expect(retryPressed, isTrue);
      });
    });
  });
}
