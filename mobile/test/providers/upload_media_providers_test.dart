// ABOUTME: Verifies upload backpressure activates only for visible playback
// ABOUTME: Covers home feed visibility and route-driven active video playback

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/playback_eligibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group('uploadManagerProvider', () {
    test('injects the container crash reporter', () {
      final authService = _MockAuthService();
      final crashReporting = CrashReportingService();
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          blossomUploadServiceProvider.overrideWithValue(
            _MockBlossomUploadService(),
          ),
          crashReportingServiceProvider.overrideWithValue(crashReporting),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(uploadManagerProvider).crashReporterForTesting,
        same(crashReporting),
      );
    });
  });

  group('uploadBackpressureActiveProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [activeVideoIdProvider.overrideWithValue(null)],
      );
    });

    tearDown(() => container.dispose());

    test('is active for the visible home feed', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;

      expect(container.read(uploadBackpressureActiveProvider), isTrue);
    });

    test('is inactive when the home feed is backgrounded', () {
      container.read(activeBranchIndexProvider.notifier).state = 1;

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test(
      'is inactive when the home feed is covered by a full-screen route',
      () {
        container.read(activeBranchIndexProvider.notifier).state = 0;
        container
            .read(shellObscuredProvider.notifier)
            .setObscured(obscured: true);

        expect(container.read(uploadBackpressureActiveProvider), isFalse);
      },
    );

    test('is inactive when an overlay pauses foreground playback', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpenForOwner(Object(), isOpen: true);

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test('is inactive when the app is backgrounded', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;
      container.read(appForegroundProvider.notifier).setForeground(false);

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test('stops yielding while the home feed is paused by window focus', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;
      expect(container.read(uploadBackpressureActiveProvider), isTrue);

      container.read(playbackWindowFocusedProvider.notifier).setFocused(false);
      expect(container.read(appForegroundProvider), isTrue);
      expect(container.read(uploadBackpressureActiveProvider), isFalse);

      container.read(playbackWindowFocusedProvider.notifier).setFocused(true);
      expect(container.read(uploadBackpressureActiveProvider), isTrue);
    });

    test('is active for route-driven playback outside the home feed', () {
      final container = ProviderContainer(
        overrides: [activeVideoIdProvider.overrideWithValue('video-1')],
      );
      addTearDown(container.dispose);
      container.read(activeBranchIndexProvider.notifier).state = 1;

      expect(container.read(uploadBackpressureActiveProvider), isTrue);
    });
  });
}
