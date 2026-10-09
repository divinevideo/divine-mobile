// ABOUTME: Tests ContainerSwapHost swaps the live container in place and
// ABOUTME: disposes the previous one after the frame.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/container_swap_host.dart';

final _valueProvider = Provider<String>((_) => 'default');

void main() {
  ProviderContainer containerWith(String value) =>
      ProviderContainer(overrides: [_valueProvider.overrideWithValue(value)]);

  group('renders', () {
    testWidgets('renders the initial container', (tester) async {
      final controller = AccountSwitchController();
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: containerWith('A'),
          controller: controller,
          child: const _ValueText(),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });
  });

  group('swap', () {
    testWidgets('swap mounts the new container in place', (tester) async {
      final controller = AccountSwitchController();
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: containerWith('A'),
          controller: controller,
          child: const _ValueText(),
        ),
      );
      expect(find.text('A'), findsOneWidget);

      await controller.swapTo(containerWith('B'));
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('the previous container is disposed after the swap', (
      tester,
    ) async {
      final controller = AccountSwitchController();
      final first = containerWith('A');
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: first,
          controller: controller,
          child: const _ValueText(),
        ),
      );

      await controller.swapTo(containerWith('B'));
      await tester.pump();

      // A disposed container throws when read.
      expect(() => first.read(_valueProvider), throwsStateError);
    });

    testWidgets('retains the previous container until cleanup settles', (
      tester,
    ) async {
      final controller = AccountSwitchController();
      final first = containerWith('A');
      final cleanupCompleter = Completer<void>();
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: first,
          controller: controller,
          child: const _ValueText(),
        ),
      );

      await controller.swapTo(
        containerWith('B'),
        beforePreviousContainerDispose: () => cleanupCompleter.future,
      );
      await tester.pump();

      expect(first.read(_valueProvider), 'A');

      cleanupCompleter.complete();
      await tester.pump();

      expect(() => first.read(_valueProvider), throwsStateError);
    });

    testWidgets('swap remounts container-owned child state', (tester) async {
      final controller = AccountSwitchController();
      var initStateCount = 0;
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: containerWith('A'),
          controller: controller,
          child: _LifecycleProbe(onInitState: () => initStateCount += 1),
        ),
      );
      expect(initStateCount, equals(1));

      await controller.swapTo(containerWith('B'));
      await tester.pump();

      expect(initStateCount, equals(2));
    });
  });

  group('controller lifecycle', () {
    testWidgets(
      'receipt waits for a frame and expires at the next generation',
      (tester) async {
        final controller = AccountSwitchController();
        await tester.pumpWidget(
          ContainerSwapHost(
            initialContainer: containerWith('A'),
            controller: controller,
            child: const _ValueText(),
          ),
        );
        final outgoing = controller.currentCommit!;
        var delivered = false;
        final pending = controller.swapToAndCommit(containerWith('B')).then((
          receipt,
        ) {
          delivered = true;
          return receipt;
        });
        expect(delivered, isFalse);
        expect(outgoing.isCurrent, isFalse);
        expect(controller.currentCommit, isNull);
        await tester.pump();
        final receipt = await pending;
        expect(receipt.isCurrent, isTrue);
        expect(find.text('B'), findsOneWidget);
        await controller.swapTo(containerWith('C'));
        expect(receipt.isCurrent, isFalse);
        await tester.pump();
        expect(controller.currentCommit!.isCurrent, isTrue);
        await tester.pumpWidget(const SizedBox());
        expect(receipt.isCurrent, isFalse);
      },
    );

    testWidgets('retiring the host before its frame rejects the receipt', (
      tester,
    ) async {
      final controller = AccountSwitchController();
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: containerWith('A'),
          controller: controller,
          child: const _ValueText(),
        ),
      );
      final pending = controller.swapToAndCommit(containerWith('B'));
      final assertion = expectLater(pending, throwsStateError);
      await tester.pumpWidget(const SizedBox());
      await assertion;
      expect(controller.currentCommit, isNull);
    });

    testWidgets('runExclusive rejects overlapping switches', (tester) async {
      final controller = AccountSwitchController();
      final completer = Completer<void>();

      final first = controller.runExclusive(() => completer.future);
      await expectLater(
        controller.runExclusive(() async {}),
        throwsA(isA<StateError>()),
      );

      completer.complete();
      await first;

      await controller.runExclusive(() async {});
    });

    testWidgets('swapTo before mount throws', (tester) async {
      final controller = AccountSwitchController();
      expect(controller.isReady, isFalse);
      expect(() => controller.swapTo(containerWith('X')), throwsStateError);
    });

    testWidgets('controller detaches when the host is disposed', (
      tester,
    ) async {
      final controller = AccountSwitchController();
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: containerWith('A'),
          controller: controller,
          child: const _ValueText(),
        ),
      );
      expect(controller.isReady, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(controller.isReady, isFalse);
    });
  });
}

class _ValueText extends ConsumerWidget {
  const _ValueText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(ref.watch(_valueProvider)),
    );
  }
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInitState});

  final VoidCallback onInitState;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInitState();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
