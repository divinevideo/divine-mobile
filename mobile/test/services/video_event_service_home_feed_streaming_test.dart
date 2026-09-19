// ABOUTME: Tests for streaming home feed seeding (Change 1 of EOSE fix)
// ABOUTME: Validates subscribeToHomeFeed returns without waiting for seed

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('seedHomeFeedFromFollowedUsers streaming', () {
    late _MockNostrClient mockNostrService;
    late VideoEventService service;

    setUp(() {
      mockNostrService = _MockNostrClient();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      service = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('returns early when followingPubkeys is empty', () async {
      await service.seedHomeFeedFromFollowedUsers([]);

      verifyNever(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      );
    });

    test('returns early when NostrService is not initialized', () async {
      when(() => mockNostrService.isInitialized).thenReturn(false);

      await service.seedHomeFeedFromFollowedUsers(['pubkey1']);

      verifyNever(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      );
    });

    test('uses subscribe instead of queryEvents for streaming', () async {
      final controller = StreamController<Event>.broadcast();

      when(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        // Fire onEose immediately to complete the seed
        final onEose =
            invocation.namedArguments[const Symbol('onEose')]
                as void Function()?;
        Future.microtask(() => onEose?.call());
        return controller.stream;
      });

      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      await service.seedHomeFeedFromFollowedUsers(['pubkey1']);

      // Verify subscribe was called (not queryEvents)
      verify(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).called(1);

      verifyNever(() => mockNostrService.queryEvents(any()));

      await controller.close();
    });

    test('cancels subscription on EOSE', () async {
      final controller = StreamController<Event>.broadcast();
      String? capturedSubscriptionId;

      when(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        capturedSubscriptionId =
            invocation.namedArguments[const Symbol('subscriptionId')]
                as String?;
        final onEose =
            invocation.namedArguments[const Symbol('onEose')]
                as void Function()?;
        // Fire EOSE after a microtask
        Future.microtask(() => onEose?.call());
        return controller.stream;
      });

      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      await service.seedHomeFeedFromFollowedUsers(['pubkey1']);

      // Verify unsubscribe was called with the seed subscription ID
      expect(capturedSubscriptionId, isNotNull);
      expect(
        RegExp(r'^seed_home_[0-9a-z]{16}$').hasMatch(capturedSubscriptionId!),
        isTrue,
      );
      verify(
        () => mockNostrService.unsubscribe(capturedSubscriptionId!),
      ).called(1);

      await controller.close();
    });

    test('handles stream errors gracefully', () async {
      final controller = StreamController<Event>.broadcast();

      when(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        // Add an error then close
        Future.microtask(() {
          controller.addError(Exception('Test error'));
        });
        return controller.stream;
      });

      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      // Should not throw
      await service.seedHomeFeedFromFollowedUsers(['pubkey1']);

      await controller.close();
    });
  });
}
