// ABOUTME: Regression tests for deepLinkServiceProvider lifecycle cleanup
// ABOUTME: Verifies late deep-link events stop flowing after disposal

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/services/deep_link_service.dart';

class _TrackingDeepLinkService extends DeepLinkService {
  _TrackingDeepLinkService(this._source) {
    _subscription = _source.stream.listen((deepLink) {
      if (_disposed) return;
      receivedDeepLinks.add(deepLink);
      _controller.add(deepLink);
    });
  }

  final StreamController<DeepLink> _source;
  final StreamController<DeepLink> _controller =
      StreamController<DeepLink>.broadcast(sync: true);
  late final StreamSubscription<DeepLink> _subscription;
  final List<DeepLink> receivedDeepLinks = [];
  bool _disposed = false;
  Future<void>? _disposal;

  bool get isDisposed => _disposed;
  Future<void> get disposal => _disposal ?? Future<void>.value();

  @override
  Stream<DeepLink> get linkStream => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {
    _disposed = true;
    _disposal ??= Future.wait<void>([
      _subscription.cancel(),
      _controller.close(),
    ]);
  }
}

void main() {
  group('deepLinkServiceProvider', () {
    test(
      'disposes the deep-link service between containers and ignores late events',
      () async {
        final deepLinkSource = StreamController<DeepLink>.broadcast(sync: true);
        addTearDown(deepLinkSource.close);

        late _TrackingDeepLinkService serviceA;
        late _TrackingDeepLinkService serviceB;

        ProviderContainer createContainer({
          required void Function(_TrackingDeepLinkService service)
          assignService,
        }) {
          return ProviderContainer(
            overrides: [
              deepLinkServiceProvider.overrideWith((ref) {
                final service = _TrackingDeepLinkService(deepLinkSource);
                // Overrides replace the production provider factory, so the test
                // must re-register the same disposal contract to observe it.
                ref.onDispose(service.dispose);
                assignService(service);
                return service;
              }),
            ],
          );
        }

        final receivedA = <DeepLink>[];
        final containerA = createContainer(
          assignService: (service) => serviceA = service,
        );
        final subscriptionA = containerA.listen<AsyncValue<DeepLink>>(
          deepLinksProvider,
          (previous, next) {
            final value = next.asData?.value;
            if (value != null) {
              receivedA.add(value);
            }
          },
        );
        addTearDown(subscriptionA.close);

        expect(serviceA.isDisposed, isFalse);

        containerA.dispose();
        await serviceA.disposal;
        expect(serviceA.isDisposed, isTrue);

        deepLinkSource.add(
          const DeepLink(type: DeepLinkType.video, videoRef: 'late-a'),
        );

        expect(serviceA.receivedDeepLinks, isEmpty);
        expect(receivedA, isEmpty);

        final receivedB = <DeepLink>[];
        final containerB = createContainer(
          assignService: (service) => serviceB = service,
        );
        addTearDown(() async {
          containerB.dispose();
          await serviceB.disposal;
        });
        final subscriptionB = containerB.listen<AsyncValue<DeepLink>>(
          deepLinksProvider,
          (previous, next) {
            final value = next.asData?.value;
            if (value != null) {
              receivedB.add(value);
            }
          },
        );
        addTearDown(subscriptionB.close);

        await pumpEventQueue();
        deepLinkSource.add(
          const DeepLink(type: DeepLinkType.video, videoRef: 'late-b'),
        );

        expect(serviceB.isDisposed, isFalse);
        expect(serviceB.receivedDeepLinks, hasLength(1));
        expect(receivedB, hasLength(1));
      },
    );
  });

  group('DeepLink.autoOpenComments', () {
    test('defaults to false', () {
      const link = DeepLink(type: DeepLinkType.video, videoRef: 'abc');
      expect(link.autoOpenComments, isFalse);
    });

    test('can be set to true', () {
      const link = DeepLink(
        type: DeepLinkType.video,
        videoRef: 'abc',
        autoOpenComments: true,
      );
      expect(link.autoOpenComments, isTrue);
    });

    test('toString includes autoOpenComments when true', () {
      const link = DeepLink(
        type: DeepLinkType.video,
        videoRef: 'abc',
        autoOpenComments: true,
      );
      expect(link.toString(), contains('autoOpenComments: true'));
    });

    test('toString omits autoOpenComments when false', () {
      const link = DeepLink(type: DeepLinkType.video, videoRef: 'abc');
      expect(link.toString(), isNot(contains('autoOpenComments')));
    });
  });

  group('DeepLinkService.pushLink', () {
    test('emits the link on linkStream', () async {
      final service = DeepLinkService();
      addTearDown(service.dispose);

      const link = DeepLink(
        type: DeepLinkType.video,
        videoRef: 'test-event-id',
        autoOpenComments: true,
      );
      final emission = expectLater(service.linkStream, emits(same(link)));
      service.pushLink(link);
      await emission;
    });
  });
}
