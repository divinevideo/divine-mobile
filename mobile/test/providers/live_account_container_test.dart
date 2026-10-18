// ABOUTME: Tests liveAccountContainer resolves the account container that is
// ABOUTME: live when called, following an in-place account switch.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/live_account_container.dart';

class _MockDeviceScope extends Mock implements DeviceScope {}

final _valueProvider = Provider<String>((_) => 'default');

void main() {
  late AccountSwitchController controller;

  ProviderContainer startupContainer() {
    final scope = _MockDeviceScope();
    when(() => scope.switchController).thenReturn(controller);
    return ProviderContainer(
      overrides: [deviceScopeProvider.overrideWithValue(scope)],
    );
  }

  setUp(() => controller = AccountSwitchController());

  group('liveAccountContainer', () {
    test('returns the startup container before the swap host mounts', () {
      final startup = startupContainer();
      addTearDown(startup.dispose);

      expect(liveAccountContainer(startup)(), same(startup));
    });

    testWidgets('follows the container a committed switch mounts', (
      tester,
    ) async {
      final startup = startupContainer();
      final next = ProviderContainer();
      final resolve = liveAccountContainer(startup);
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: startup,
          controller: controller,
          child: const SizedBox(),
        ),
      );
      expect(resolve(), same(startup));

      await controller.swapTo(next);
      await tester.pump();

      // A disposed container throws when read: the old one is gone, and the
      // resolver must already have moved on.
      expect(() => startup.read(_valueProvider), throwsStateError);
      expect(resolve(), same(next));
    });
  });
}
