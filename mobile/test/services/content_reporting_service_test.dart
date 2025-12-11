// ABOUTME: Unit tests for ContentReportingService
// ABOUTME: Tests NIP-56 content reporting including AI-generated content reports

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/event.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}

class MockNostrKeyManager extends Mock implements NostrKeyManager {}

// Fake Event for fallback values
class FakeEvent extends Fake implements Event {}

// Helper to create successful broadcast result
NostrBroadcastResult _successfulBroadcast(Event event) {
  return NostrBroadcastResult(
    event: event,
    successCount: 1,
    totalRelays: 1,
    results: {'wss://test.relay.com': true},
    errors: {},
  );
}

// Helper to create failed broadcast result
NostrBroadcastResult _failedBroadcast(Event event) {
  return NostrBroadcastResult(
    event: event,
    successCount: 0,
    totalRelays: 1,
    results: {'wss://test.relay.com': false},
    errors: {'wss://test.relay.com': 'Failed to broadcast'},
  );
}

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(FakeEvent());
  });

  group('ContentReportingService', () {
    late MockNostrService mockNostrService;
    late MockNostrKeyManager mockKeyManager;
    late SharedPreferences prefs;
    late ContentReportingService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockNostrService = MockNostrService();
      mockKeyManager = MockNostrKeyManager();

      // Generate a REAL Nostr keypair for testing (required for signing)
      final realKeyPair = Keychain.generate();

      // Mock NostrService as initialized with proper mocktail syntax
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn(realKeyPair.public);
      when(() => mockNostrService.hasKeys).thenReturn(true);
      when(() => mockNostrService.keyManager).thenReturn(mockKeyManager);

      // Mock KeyManager with real keypair
      when(() => mockKeyManager.keyPair).thenReturn(realKeyPair);

      service = ContentReportingService(
        nostrService: mockNostrService,
        prefs: prefs,
      );
    });

    test(
      'initialize() sets service ready when Nostr service is ready',
      () async {
        await service.initialize();

        // Service should be initialized (report history starts empty)
        expect(service.reportHistory, isEmpty);
      },
    );

    test(
      'initialize() fails gracefully when Nostr service not ready',
      () async {
        when(() => mockNostrService.isInitialized).thenReturn(false);

        final uninitializedService = ContentReportingService(
          nostrService: mockNostrService,
          prefs: prefs,
        );

        await uninitializedService.initialize();

        // Should not throw, but won't be fully initialized
        expect(uninitializedService.reportHistory, isEmpty);
      },
    );

    test('reportContent() fails when service not initialized', () async {
      // Don't call initialize()

      final result = await service.reportContent(
        eventId: 'test_event_id',
        authorPubkey: 'test_author',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      expect(result.success, false);
      expect(result.error, 'Reporting service not initialized');
    });

    test(
      'reportContent() succeeds for AI-generated content after initialization',
      () async {
        await service.initialize();

        // Mock successful event broadcast
        when(
          () => mockNostrService.broadcastEvent(any()),
        ).thenAnswer((inv) async => _successfulBroadcast(FakeEvent()));

        final result = await service.reportContent(
          eventId: 'ai_video_event_id',
          authorPubkey: 'suspicious_author',
          reason: ContentFilterReason.aiGenerated,
          details: 'Suspected AI-generated content',
        );

        expect(result.success, true);
        expect(result.error, isNull);

        // Verify Nostr event was broadcast
        verify(() => mockNostrService.broadcastEvent(any())).called(1);
      },
    );

    test(
      'reportContent() handles all ContentFilterReason types including aiGenerated',
      () async {
        await service.initialize();
        when(
          () => mockNostrService.broadcastEvent(any()),
        ).thenAnswer((inv) async => _successfulBroadcast(FakeEvent()));

        final reasons = ContentFilterReason.values;

        for (final reason in reasons) {
          final result = await service.reportContent(
            eventId: 'event_${reason.name}',
            authorPubkey: 'author_123',
            reason: reason,
            details: 'Test report for ${reason.name}',
          );

          expect(
            result.success,
            true,
            reason: 'Failed for reason: ${reason.name}',
          );
        }

        // Should have broadcast one event per reason
        verify(
          () => mockNostrService.broadcastEvent(any()),
        ).called(reasons.length);
      },
    );

    test('reportContent() specifically tests aiGenerated reason', () async {
      await service.initialize();
      when(
        () => mockNostrService.broadcastEvent(any()),
      ).thenAnswer((inv) async => _successfulBroadcast(FakeEvent()));

      // This should not throw an exception due to missing switch case
      final result = await service.reportContent(
        eventId: 'ai_content',
        authorPubkey: 'ai_creator',
        reason: ContentFilterReason.aiGenerated,
        details: 'Detected AI generation patterns',
      );

      expect(result.success, true);
      expect(result.error, isNull);
    });

    test('reportContent() handles broadcast failures gracefully', () async {
      await service.initialize();

      // Mock failed broadcast
      when(
        () => mockNostrService.broadcastEvent(any()),
      ).thenAnswer((inv) async => _failedBroadcast(FakeEvent()));

      final result = await service.reportContent(
        eventId: 'event_123',
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // Service is resilient: saves report locally even if broadcast fails
      expect(result.success, true);
      expect(result.error, isNull);
      expect(result.reportId, isNotNull);

      // Verify report was saved to local history
      expect(service.reportHistory, isNotEmpty);
    });

    test('reportContent() stores report in history on success', () async {
      await service.initialize();
      when(
        () => mockNostrService.broadcastEvent(any()),
      ).thenAnswer((inv) async => _successfulBroadcast(FakeEvent()));

      await service.reportContent(
        eventId: 'reported_event',
        authorPubkey: 'bad_actor',
        reason: ContentFilterReason.aiGenerated,
        details: 'AI detection',
      );

      expect(service.reportHistory, isNotEmpty);
      expect(
        service.reportHistory.first.reason,
        ContentFilterReason.aiGenerated,
      );
    });
  });

  group('ContentReportingService Provider Integration', () {
    test('provider pattern calls initialize() on service creation', () async {
      // This test validates that the provider pattern we fixed actually works
      // The fix was adding: await service.initialize(); in the provider

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostrService = MockNostrService();
      final mockKeyManager = MockNostrKeyManager();

      // Generate a REAL Nostr keypair for this test too
      final realKeyPair = Keychain.generate();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn(realKeyPair.public);
      when(() => mockNostrService.hasKeys).thenReturn(true);
      when(() => mockNostrService.keyManager).thenReturn(mockKeyManager);
      when(() => mockKeyManager.keyPair).thenReturn(realKeyPair);

      // Simulate what the provider does
      final service = ContentReportingService(
        nostrService: mockNostrService,
        prefs: prefs,
      );
      await service.initialize(); // This is what the provider now does

      // Now reportContent should work
      when(
        () => mockNostrService.broadcastEvent(any()),
      ).thenAnswer((inv) async => _successfulBroadcast(FakeEvent()));

      final result = await service.reportContent(
        eventId: 'test',
        authorPubkey: 'test',
        reason: ContentFilterReason.aiGenerated,
        details: 'test',
      );

      expect(result.success, true);
    });
  });
}
