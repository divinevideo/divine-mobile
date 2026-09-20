// ABOUTME: Tests that VerifyingAwareVideoErrorOverlay reflects the cubit's
// ABOUTME: in-flight verifying flag and wires Verify age to the retry helper.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType, VideoRetryResult;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/widgets/video_feed_item/verifying_aware_video_error_overlay.dart';

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

String? _resolveSha256({String? explicitSha256, String? videoUrl}) {
  if (explicitSha256 != null && explicitSha256.isNotEmpty) {
    return explicitSha256;
  }
  return null;
}

class _FakeBuildContext extends Fake implements BuildContext {}

const _videoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _pubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';
const _sha256 =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _videoUrl = 'https://media.divine.video/$_sha256/720p.mp4';

final _video = VideoEvent(
  id: _videoId,
  pubkey: _pubkey,
  createdAt: 1704067200,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  videoUrl: _videoUrl,
  sha256: _sha256,
);

String get _verifyLabel =>
    lookupAppLocalizations(const Locale('en')).videoErrorVerifyAgeButton;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
  });

  group(VerifyingAwareVideoErrorOverlay, () {
    Future<void> pumpOverlay(
      WidgetTester tester, {
      required VideoPlaybackStatusCubit cubit,
      MediaAuthInterceptor? interceptor,
      bool isProtectedMinor = false,
      VideoErrorType errorType = VideoErrorType.ageRestricted,
    }) {
      final authInterceptor = interceptor ?? _MockMediaAuthInterceptor();
      when(
        authInterceptor.canAutoAuthorizeAdultMedia,
      ).thenAnswer((_) async => false);
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaAuthInterceptorProvider.overrideWithValue(authInterceptor),
            isProtectedMinorProvider.overrideWithValue(isProtectedMinor),
          ],
          child: BlocProvider<VideoPlaybackStatusCubit>.value(
            value: cubit,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VerifyingAwareVideoErrorOverlay(
                  video: _video,
                  index: 0,
                  resolveSha256: _resolveSha256,
                  onRetry: () {},
                  retryPlayback: (_) => (
                    status: VideoRetryResult.played,
                    errorType: null,
                  ),
                  errorType: errorType,
                  shouldPortraitExpand: true,
                  isSquare: false,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows the Verify age spinner when the cubit reports verifying',
      (tester) async {
        final cubit = VideoPlaybackStatusCubit();
        addTearDown(cubit.close);

        await pumpOverlay(tester, cubit: cubit);
        await tester.pump();

        expect(find.text(_verifyLabel), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        cubit.markVerifying(_videoId);
        // Two pumps: the first delivers the cubit's stream emission to the
        // BlocSelector, the second rebuilds with the spinner.
        await tester.pump();
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('tapping Verify age runs the retry and toggles the flag', (
      tester,
    ) async {
      final interceptor = _MockMediaAuthInterceptor();
      final cubit = VideoPlaybackStatusCubit();
      final authCompleter = Completer<ViewerAuthResult>();
      addTearDown(cubit.close);

      when(
        () => interceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) => authCompleter.future);

      await pumpOverlay(tester, cubit: cubit, interceptor: interceptor);
      await tester.pump();
      expect(cubit.state.isVerifying(_videoId), isFalse);

      await tester.tap(find.text(_verifyLabel));
      await tester.pump();
      // markVerifying runs synchronously before the auth await, so the
      // spinner is visible while the retry is in flight.
      expect(cubit.state.isVerifying(_videoId), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      authCompleter.complete(
        const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );
      await tester.pump();
      await tester.pump();
      // Cleared in the retry helper's finally once playback reloads.
      expect(cubit.state.isVerifying(_videoId), isFalse);
    });

    testWidgets('hides Verify age for protected minors', (tester) async {
      final cubit = VideoPlaybackStatusCubit();
      addTearDown(cubit.close);

      await pumpOverlay(
        tester,
        cubit: cubit,
        isProtectedMinor: true,
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(_verifyLabel), findsNothing);
      expect(find.text(l10n.videoErrorRetry), findsNothing);
      expect(find.text(l10n.videoErrorAdultContentLocked), findsOneWidget);
    });

    testWidgets('keeps Retry for protected minors on an unrelated playback '
        'error', (tester) async {
      final cubit = VideoPlaybackStatusCubit();
      addTearDown(cubit.close);

      await pumpOverlay(
        tester,
        cubit: cubit,
        isProtectedMinor: true,
        errorType: VideoErrorType.generic,
      );
      await tester.pump();

      // The account-level lock walls off adult media, not every video the
      // account fails to play.
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      expect(find.text(l10n.videoErrorAdultContentLocked), findsNothing);
      expect(find.text(_verifyLabel), findsNothing);
    });
  });
}
