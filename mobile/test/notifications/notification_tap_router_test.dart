// ABOUTME: Tests routeBackgroundPushTap routes a tapped push through the
// ABOUTME: account container that is live when the tap arrives.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/notification_helpers.dart';

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  const destination = '/following/new';
  const campaignTap = <String, dynamic>{
    NotificationPayloadKeys.wireType: NotificationWireValues.campaign,
    NotificationPayloadKeys.tapTargetType: 'app_route',
    NotificationPayloadKeys.tapTargetValue: destination,
  };

  late _MockGoRouter routerA;
  late _MockGoRouter routerB;
  late ProviderContainer containerA;
  late ProviderContainer containerB;

  setUp(() {
    routerA = _MockGoRouter();
    routerB = _MockGoRouter();
    containerA = ProviderContainer(
      overrides: [goRouterProvider.overrideWithValue(routerA)],
    );
    containerB = ProviderContainer(
      overrides: [goRouterProvider.overrideWithValue(routerB)],
    );
  });

  tearDown(() => containerB.dispose());

  group('routeBackgroundPushTap', () {
    test(
      'routes a background tap through the container that is live when it '
      'arrives',
      () async {
        var live = containerA;
        ProviderContainer resolve() => live;

        await routeBackgroundPushTap(campaignTap, liveContainer: resolve);
        verify(() => routerA.go(destination)).called(1);

        // An in-place account switch: the new container goes live and the
        // one the listener was registered with is disposed.
        live = containerB;
        containerA.dispose();
        await routeBackgroundPushTap(campaignTap, liveContainer: resolve);

        verify(() => routerB.go(destination)).called(1);
        verifyNever(() => routerA.go(destination));
      },
    );
  });
}
