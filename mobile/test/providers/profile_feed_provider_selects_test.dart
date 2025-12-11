// ABOUTME: Provider test proving videosForProfileRouteProvider selects from service by npub
// ABOUTME: Tests pure provider selection logic without UI

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Helper to wait for pageContext to emit a value
Future<void> waitForPageContext(ProviderContainer container) async {
  final completer = Completer<void>();
  final sub = container.listen(pageContextProvider, (prev, next) {
    if (next.hasValue) {
      completer.complete();
    }
  });
  // Start listening
  container.read(pageContextProvider);
  await completer.future.timeout(const Duration(milliseconds: 100));
  sub.close();
}

void main() {
  test('selects author videos when profile route active', () async {
    // Test fixture
    final testNpub =
        'npub1l5sga6xg72phsz5422ykujprejwud075ggrr3z2hwyrfgr7eylqstegx9z';
    final testHex = npubToHexOrNull(testNpub)!;

    final testVideo = VideoEvent(
      id: 'test-video-1',
      pubkey: testHex,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Test Content',
      title: 'Test Title',
      videoUrl: 'https://example.com/test.mp4',
      timestamp: DateTime.now(),
    );

    // Create fake service with test videos
    final fakeService = _FakeVideoEventService(
      authorVideos: {
        testHex: [testVideo],
      },
    );

    final container = ProviderContainer(
      overrides: [
        videoEventServiceProvider.overrideWithValue(fakeService),
        routerLocationStreamProvider.overrideWithValue(
          Stream.value('/profile/$testNpub/0'),
        ),
      ],
    );

    // Wait for pageContext to emit using proper listener
    await waitForPageContext(container);

    // Read the provider under test
    final result = container.read(videosForProfileRouteProvider);

    // Assertions
    expect(result.hasValue, isTrue, reason: 'Provider should have data');
    expect(
      result.value!.videos.length,
      1,
      reason: 'Should select 1 video from author',
    );
    expect(
      result.value!.videos.first.id,
      'test-video-1',
      reason: 'Should select correct video',
    );

    container.dispose();
  });

  test('returns empty when npub not in route', () async {
    final container = ProviderContainer(
      overrides: [
        routerLocationStreamProvider.overrideWithValue(
          Stream.value('/home/0'), // Not a profile route
        ),
      ],
    );

    // Wait for pageContext to emit using proper listener
    await waitForPageContext(container);

    final result = container.read(videosForProfileRouteProvider);

    expect(result.hasValue, isTrue);
    expect(
      result.value!.videos,
      isEmpty,
      reason: 'Should return empty for non-profile routes',
    );

    container.dispose();
  });
}

/// Fake VideoEventService for testing
class _FakeVideoEventService extends VideoEventService {
  _FakeVideoEventService({required Map<String, List<VideoEvent>> authorVideos})
    : _authorVideos = authorVideos,
      super(
        _FakeNostrService(),
        subscriptionManager: _FakeSubscriptionManager(),
      );

  final Map<String, List<VideoEvent>> _authorVideos;

  @override
  List<VideoEvent> authorVideos(String pubkeyHex) {
    return _authorVideos[pubkeyHex] ?? const [];
  }

  @override
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    // No-op for test - videos already populated
    return Future.value();
  }
}

class _FakeNostrService implements NostrClient {
  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptionManager extends SubscriptionManager {
  _FakeSubscriptionManager() : super(_FakeNostrService());
}
