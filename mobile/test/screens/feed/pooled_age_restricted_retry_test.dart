// ABOUTME: Tests age-verification retry wiring for pooled native feed videos.
// ABOUTME: Verifies successful auth reloads playback and failures surface feedback.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class _FakeBuildContext extends Fake implements BuildContext {}

const _videoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _pubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';
const _sha256 =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _videoUrl = 'https://media.divine.video/$_sha256/720p.mp4';

/// Stands in for the Content Filters screen in the harness router.
const _contentFiltersRouteMarker = 'content filters screen';

String get _failureText =>
    lookupAppLocalizations(const Locale('en')).videoErrorVerifyAgeFailed;

String get _unavailableText =>
    lookupAppLocalizations(const Locale('en')).videoErrorUnavailableBody;

/// Retry recovered playback.
const PooledRetryOutcome _retryRecovered = (succeeded: true, errorType: null);

/// Retry ran with valid auth headers and the media server rejected it again.
const PooledRetryOutcome _retryStillUnauthorized = (
  succeeded: false,
  errorType: VideoErrorType.ageRestricted,
);

/// Retry failed for a reason unrelated to the age gate (network, decode).
const PooledRetryOutcome _retryFailedUnrelated = (
  succeeded: false,
  errorType: VideoErrorType.generic,
);

String get _signerUnreachableText => lookupAppLocalizations(
  const Locale('en'),
).videoErrorVerifyAgeSignerUnreachable;

String get _adultContentHiddenTitle => lookupAppLocalizations(
  const Locale('en'),
).videoErrorAdultContentHiddenTitle;

String get _adultContentHiddenBody =>
    lookupAppLocalizations(const Locale('en')).videoErrorAdultContentHiddenBody;

String get _adultContentHiddenAction => lookupAppLocalizations(
  const Locale('en'),
).videoErrorAdultContentHiddenAction;

String get _notNowText =>
    lookupAppLocalizations(const Locale('en')).commonNotNow;

AgeVerificationService _ageService({required bool verified}) {
  final service = _MockAgeVerificationService();
  when(() => service.isAdultContentVerified).thenReturn(verified);
  return service;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
  });

  group('retryAgeRestrictedPooledVideo', () {
    testWidgets('retries playback and clears status after auth succeeds', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      Map<String, String>? retryHeaders;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (headers) {
            retryCount++;
            retryHeaders = headers;
            return _retryRecovered;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(retryHeaders, equals({'Authorization': 'Nostr token'}));
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ready,
      );
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets('marks the video verifying during the retry and clears it '
        'after', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      final authCompleter = Completer<ViewerAuthResult>();
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) => authCompleter.future);

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) => _retryRecovered,
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      // markVerifying runs synchronously before the auth await.
      expect(playbackStatusCubit.state.isVerifying(_videoId), isTrue);

      authCompleter.complete(
        const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );
      await tester.pump();
      await tester.pump();
      // Cleared in the finally once the retry resolves.
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
    });

    testWidgets(
      'ignores duplicate retry calls while verification is in flight',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        final authCompleter = Completer<ViewerAuthResult>();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) => authCompleter.future);

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            retryPlayback: (_) {
              retryCount++;
              return _retryRecovered;
            },
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pump();
        expect(playbackStatusCubit.state.isVerifying(_videoId), isTrue);

        await tester.tap(find.text('Verify'));
        await tester.pump();

        verify(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).called(1);

        authCompleter.complete(
          const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );
        await tester.pump();
        await tester.pump();

        expect(retryCount, 1);
        expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
      },
    );

    testWidgets('keeps gate state and stays silent when auth is declined', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) async => const ViewerAuthUnavailable());

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          // Declining the age dialog leaves the viewer unverified.
          ageVerificationService: _ageService(verified: false),
          retryPlayback: (_) {
            retryCount++;
            return _retryRecovered;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 0);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      // A deliberate decline must not surface a failure message.
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets(
      'surfaces feedback when the viewer accepts but auth headers cannot be '
      'created',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // handleUnauthorizedMedia returns null even though the viewer accepted
        // (e.g. a remote signer that failed to produce the viewer-auth header).
        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            ageVerificationService: _ageService(verified: true),
            retryPlayback: (_) {
              retryCount++;
              return _retryRecovered;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        expect(find.text(_failureText), findsOneWidget);
      },
    );

    testWidgets('marks unavailable when authenticated retry fails', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return _retryStillUnauthorized;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.unavailable,
      );
      expect(playbackStatusCubit.state.hasAuthRetryExhausted(_videoId), isTrue);
      expect(find.text(_unavailableText), findsOneWidget);
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets('keeps the age-gated card when the retry fails for an '
        'unrelated reason', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return _retryFailedUnrelated;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      // A network / decode failure is not evidence the age gate is
      // unclearable, so the viewer keeps the retryable age-gated card.
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      expect(
        playbackStatusCubit.state.hasAuthRetryExhausted(_videoId),
        isFalse,
      );
      expect(find.text(_failureText), findsOneWidget);
      expect(find.text(_unavailableText), findsNothing);
    });

    testWidgets('offers the Content Filters sheet when playback is blocked by '
        'preference', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      late ProviderContainer container;
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      // A verified viewer whose Content Filters keep adult content hidden
      // (the default) is blocked; the remedy is opting in via settings.
      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          ageVerificationService: _ageService(verified: true),
          onContainerReady: (value) => container = value,
          retryPlayback: (_) {
            retryCount++;
            return _retryRecovered;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(retryCount, 0);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      // The settings-specific sheet, not the generic verify failure.
      expect(find.text(_adultContentHiddenTitle), findsOneWidget);
      expect(find.text(_adultContentHiddenBody), findsOneWidget);
      expect(find.text(_adultContentHiddenAction), findsOneWidget);
      expect(find.text(_failureText), findsNothing);
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isTrue,
      );
      // The spinner clears while the sheet is still up, so the age-gate
      // card behind it isn't stuck in a loading state.
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
    });

    testWidgets('opens Content Filters from the blocked-by-preference sheet', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      late ProviderContainer container;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          ageVerificationService: _ageService(verified: true),
          onContainerReady: (value) => container = value,
          retryPlayback: (_) => _retryRecovered,
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_adultContentHiddenAction));
      await tester.pumpAndSettle();

      // The sheet is a dead end without this jump — the remedy lives in the
      // Content Filters screen, not in re-verifying age.
      expect(find.text(_contentFiltersRouteMarker), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isFalse,
      );
    });

    testWidgets(
      'dismisses the blocked-by-preference sheet without navigating on Not now',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        late ProviderContainer container;
        addTearDown(playbackStatusCubit.close);

        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            ageVerificationService: _ageService(verified: true),
            onContainerReady: (value) => container = value,
            retryPlayback: (_) => _retryRecovered,
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_notNowText));
        await tester.pumpAndSettle();

        // "Not now" closes the sheet and leaves the viewer on the feed — it
        // must not fall through to the Content Filters push.
        expect(find.text(_adultContentHiddenTitle), findsNothing);
        expect(find.text(_contentFiltersRouteMarker), findsNothing);
        expect(
          container.read(overlayVisibilityProvider).hasVisibleOverlay,
          isFalse,
        );
      },
    );

    testWidgets(
      'dismisses the blocked-by-preference sheet after the host feed item is '
      'disposed',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        final hostVisible = ValueNotifier(true);
        late ProviderContainer container;
        addTearDown(playbackStatusCubit.close);
        addTearDown(hostVisible.dispose);

        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            ageVerificationService: _ageService(verified: true),
            onContainerReady: (value) => container = value,
            hostVisible: hostVisible,
            retryPlayback: (_) => _retryRecovered,
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(find.text(_adultContentHiddenTitle), findsOneWidget);

        // A non-append-only feed emit clears the error state behind the open
        // sheet, unmounting the overlay that opened it (#7291).
        hostVisible.value = false;
        await tester.pump();

        await tester.tap(find.text(_notNowText));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(_adultContentHiddenTitle), findsNothing);
        // A pop that runs while the host is gone still has to release the
        // overlay flag, or the feed stays paused for the rest of the session
        // (#6239).
        expect(
          container.read(overlayVisibilityProvider).hasVisibleOverlay,
          isFalse,
        );
      },
    );

    testWidgets(
      'opens Content Filters even after the host feed item is disposed',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        final hostVisible = ValueNotifier(true);
        late ProviderContainer container;
        addTearDown(playbackStatusCubit.close);
        addTearDown(hostVisible.dispose);

        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            ageVerificationService: _ageService(verified: true),
            onContainerReady: (value) => container = value,
            hostVisible: hostVisible,
            retryPlayback: (_) => _retryRecovered,
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        hostVisible.value = false;
        await tester.pump();

        await tester.tap(find.text(_adultContentHiddenAction));
        await tester.pumpAndSettle();

        // The button has to do what it says even when the overlay that opened
        // the sheet is gone, or the viewer is left with a CTA that only closes
        // the sheet (#7350). The push falls back to the root navigator here,
        // since the caller's context is defunct.
        expect(tester.takeException(), isNull);
        expect(find.text(_adultContentHiddenTitle), findsNothing);
        expect(find.text(_contentFiltersRouteMarker), findsOneWidget);
        // The sheet flag has to come back down on the way through, or the feed
        // stays paused for the rest of the session (#6239).
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
        expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);
      },
    );

    testWidgets(
      'surfaces the connectivity message when the remote signer is unreachable',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // A non-interactive remote signer timed out: distinct from a verify
        // failure, so the viewer is told to check their connection.
        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthSignerUnreachable());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            retryPlayback: (_) {
              retryCount++;
              return _retryRecovered;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        // The distinct signer-unreachable copy, not the generic verify failure.
        expect(find.text(_signerUnreachableText), findsOneWidget);
        expect(find.text(_failureText), findsNothing);
      },
    );

    testWidgets(
      'refuses retry and surfaces feedback when sha256 cannot be resolved',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // No sha256 field and a URL without a 64-hex blob segment, so
        // _resolveSha256 returns null and the hash-bound BUD-01 path is
        // unavailable. The retry must refuse rather than fall back to a
        // URL-bound NIP-98 token that would not authenticate the variants.
        final video = VideoEvent(
          id: _videoId,
          pubkey: _pubkey,
          createdAt: 1704067200,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
          videoUrl: 'https://media.divine.video/video.mp4',
        );

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            video: video,
            retryPlayback: (_) {
              retryCount++;
              return _retryRecovered;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        verifyNever(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
            category: any(named: 'category'),
          ),
        );
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        expect(find.text(_failureText), findsOneWidget);
      },
    );
  });

  group('autoRetryAgeRestrictedPooledVideo', () {
    testWidgets('stops when the caller unmounts during eligibility', (
      tester,
    ) async {
      final eligibility = Completer<bool>();
      final hostVisible = ValueNotifier<bool>(true);
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(hostVisible.dispose);
      addTearDown(playbackStatusCubit.close);

      when(
        mediaAuthInterceptor.canAutoAuthorizeAdultMedia,
      ).thenAnswer((_) => eligibility.future);

      await tester.pumpWidget(
        _AutoRetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return _retryRecovered;
          },
          hostVisible: hostVisible,
        ),
      );

      await tester.tap(find.text('Auto retry'));
      await tester.pump();
      hostVisible.value = false;
      await tester.pump();

      eligibility.complete(true);
      await tester.pump();

      expect(retryCount, 0);
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
      verifyNever(
        () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    testWidgets('marks authenticated retry exhausted silently when playback '
        'still fails', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        mediaAuthInterceptor.canAutoAuthorizeAdultMedia,
      ).thenAnswer((_) async => true);
      when(
        () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _AutoRetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return _retryStillUnauthorized;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Auto retry'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.unavailable,
      );
      expect(playbackStatusCubit.state.hasAuthRetryExhausted(_videoId), isTrue);
      expect(find.text(_unavailableText), findsNothing);
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets('leaves the age-gated status alone when the retry fails for '
        'an unrelated reason', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        mediaAuthInterceptor.canAutoAuthorizeAdultMedia,
      ).thenAnswer((_) async => true);
      when(
        () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _AutoRetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return _retryFailedUnrelated;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Auto retry'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      expect(
        playbackStatusCubit.state.hasAuthRetryExhausted(_videoId),
        isFalse,
      );
    });
  });
}

class _RetryHarness extends StatefulWidget {
  const _RetryHarness({
    required this.mediaAuthInterceptor,
    required this.playbackStatusCubit,
    required this.retryPlayback,
    this.video,
    this.ageVerificationService,
    this.onContainerReady,
    this.hostVisible,
  });

  final MediaAuthInterceptor mediaAuthInterceptor;
  final VideoPlaybackStatusCubit playbackStatusCubit;
  final PooledRetryPlayback retryPlayback;
  final VideoEvent? video;
  final AgeVerificationService? ageVerificationService;
  final ValueChanged<ProviderContainer>? onContainerReady;

  /// Drives whether the widget that calls the retry is in the tree, so a test
  /// can dispose the caller's context the way the pooled feed does.
  final ValueListenable<bool>? hostVisible;

  @override
  State<_RetryHarness> createState() => _RetryHarnessState();
}

class _RetryHarnessState extends State<_RetryHarness> {
  // A real router, so the sheet's "Open Content Filters" push is exercised
  // rather than stubbed out.
  late final GoRouter _router = GoRouter(
    // Mirrors app_router.dart, so the CTA's fallback to the root navigator's
    // context resolves here the way it does in the app.
    navigatorKey: NavigatorKeys.root,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ValueListenableBuilder<bool>(
            // A const listenable that never fires, for the harnesses that keep
            // the retry caller mounted for the whole test.
            valueListenable:
                widget.hostVisible ?? const AlwaysStoppedAnimation<bool>(true),
            builder: (_, hostVisible, _) {
              if (!hostVisible) return const SizedBox.shrink();
              return Consumer(
                builder: (context, ref, _) {
                  return TextButton(
                    onPressed: () => retryAgeRestrictedPooledVideo(
                      context: context,
                      ref: ref,
                      video: widget.video ?? _video,
                      index: 0,
                      resolveSha256: _resolveSha256,
                      retryPlayback: widget.retryPlayback,
                    ),
                    child: const Text('Verify'),
                  );
                },
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: ContentFiltersScreen.path,
        builder: (_, _) =>
            const Scaffold(body: Text(_contentFiltersRouteMarker)),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mediaAuthInterceptorProvider.overrideWithValue(
          widget.mediaAuthInterceptor,
        ),
        if (widget.ageVerificationService != null)
          ageVerificationServiceProvider.overrideWithValue(
            widget.ageVerificationService!,
          ),
      ],
      child: Consumer(
        builder: (context, _, _) {
          widget.onContainerReady?.call(
            ProviderScope.containerOf(context, listen: false),
          );
          return BlocProvider<VideoPlaybackStatusCubit>.value(
            value: widget.playbackStatusCubit,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}

class _AutoRetryHarness extends StatelessWidget {
  const _AutoRetryHarness({
    required this.mediaAuthInterceptor,
    required this.playbackStatusCubit,
    required this.retryPlayback,
    this.hostVisible,
  });

  final MediaAuthInterceptor mediaAuthInterceptor;
  final VideoPlaybackStatusCubit playbackStatusCubit;
  final PooledRetryPlayback retryPlayback;
  final ValueListenable<bool>? hostVisible;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mediaAuthInterceptorProvider.overrideWithValue(mediaAuthInterceptor),
      ],
      child: BlocProvider<VideoPlaybackStatusCubit>.value(
        value: playbackStatusCubit,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable:
                  hostVisible ?? const AlwaysStoppedAnimation<bool>(true),
              builder: (_, hostVisible, _) {
                if (!hostVisible) return const SizedBox.shrink();
                return Consumer(
                  builder: (context, ref, _) {
                    return TextButton(
                      onPressed: () => autoRetryAgeRestrictedPooledVideo(
                        context: context,
                        ref: ref,
                        video: _video,
                        index: 0,
                        resolveSha256: _resolveSha256,
                        retryPlayback: retryPlayback,
                      ),
                      child: const Text('Auto retry'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final _video = VideoEvent(
  id: _videoId,
  pubkey: _pubkey,
  createdAt: 1704067200,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  videoUrl: _videoUrl,
  sha256: _sha256,
);

String? _resolveSha256({String? explicitSha256, String? videoUrl}) {
  if (explicitSha256 != null && explicitSha256.isNotEmpty) {
    return explicitSha256;
  }
  return null;
}
