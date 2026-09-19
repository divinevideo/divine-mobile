// ABOUTME: Tests the Crashlytics gate on the app-wired ViewEventPublisher.
// ABOUTME: Structural drops become reports; a failed signature does not.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';

import '../test_data/video_test_data.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

class _FixedNostrService extends NostrService {
  _FixedNostrService(this._client);

  final NostrClient _client;

  @override
  NostrClient build() => _client;
}

void main() {
  group('viewEventPublisherProvider', () {
    late _MockAuthService authService;
    late _MockCrashReportingService crashReporting;
    late ProviderContainer container;

    const creatorPubkey =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    setUp(() {
      authService = _MockAuthService();
      crashReporting = _MockCrashReportingService();
      final nostrClient = _MockNostrClient();

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      when(() => nostrClient.connectedRelays).thenReturn([]);
      when(
        () => crashReporting.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          nostrServiceProvider.overrideWith(
            () => _FixedNostrService(nostrClient),
          ),
          appVersionProvider.overrideWithValue('1.0.23'),
          crashReportingServiceProvider.overrideWithValue(crashReporting),
        ],
      );
      addTearDown(container.dispose);
    });

    test('does not report a view the signer could not sign', () async {
      // A Keycast RPC timeout, a 5xx, no network and a declined NIP-55
      // prompt all reach the publisher as this null. Reporting it filed one
      // non-fatal per queued row per retry sweep (#9340).
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      final published = await container
          .read(viewEventPublisherProvider)
          .publishViewEvent(
            video: createTestVideoEvent(
              pubkey: creatorPubkey,
              vineId: 'unsigned_d_tag',
            ),
            startSeconds: 0,
            endSeconds: 5,
          );

      expect(published, isFalse);
      verifyNever(
        () => crashReporting.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      );
    });

    test('still reports a structural drop', () async {
      // Positive control for the gate above: a view the client can never
      // build must keep reaching Crashlytics.
      final published = await container
          .read(viewEventPublisherProvider)
          .publishViewEvent(
            video: createTestVideoEvent(
              id: 'video_without_d_tag',
              pubkey: creatorPubkey,
              clearAddressableDTag: true,
              eventKind: NIP71VideoKinds.addressableShortVideo,
            ),
            startSeconds: 0,
            endSeconds: 5,
          );

      expect(published, isFalse);
      final captured = verify(
        () => crashReporting.recordError(
          captureAny(),
          any(),
          reason: captureAny(named: 'reason'),
        ),
      ).captured;
      expect(
        captured.first,
        isA<Reportable<ViewEventInvariantException>>().having(
          (r) => r.unwrap().reason,
          'reason',
          ViewEventDropReason.missingAddressableDTag,
        ),
      );
      expect(
        captured.last,
        'ViewEventPublisher.publishViewEvent.missingAddressableDTag.'
        'videoId=video_without_d_tag',
      );
    });
  });
}
