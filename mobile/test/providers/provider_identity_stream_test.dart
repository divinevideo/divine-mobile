// ABOUTME: Pins the seeded-replay contract of identityStreamOf (#6480) — the
// ABOUTME: behaviour app-shell blocs rely on to re-point captured dependencies.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/provider_identity_stream.dart';

/// Identity-only dependency, standing in for a repository. Deliberately does
/// not override `==`, which is what makes a rebuild observable.
class _Dep {
  _Dep(this.label);
  final String label;
}

void main() {
  group('identityStreamOf', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    test('delivers the current value to a late subscriber', () async {
      final source = Provider<_Dep>((ref) => _Dep('first'));
      final stream = identityStreamOf(source);
      container = ProviderContainer();

      final identityStream = container.read(stream);

      // Subscribe well after the provider was created — a plain broadcast
      // controller would have dropped the seed here.
      await pumpEventQueue();

      final first = await identityStream.first;
      expect(first.label, equals('first'));
    });

    test('emits the new instance when the source rebuilds', () async {
      var label = 'first';
      final source = Provider<_Dep>((ref) => _Dep(label));
      final stream = identityStreamOf(source);
      container = ProviderContainer();

      final seen = <String>[];
      final subscription = container.read(stream).listen((d) {
        seen.add(d.label);
      });
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      label = 'second';
      container.invalidate(source);
      await pumpEventQueue();

      expect(seen, equals(['first', 'second']));
    });

    test(
      'does not emit when the source rebuilds to the same instance',
      () async {
        final stable = _Dep('stable');
        final source = Provider<_Dep>((ref) => stable);
        final stream = identityStreamOf(source);
        container = ProviderContainer();

        final seen = <String>[];
        final subscription = container.read(stream).listen((d) {
          seen.add(d.label);
        });
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        container.invalidate(source);
        container.read(source);
        await pumpEventQueue();

        // Seed only. Riverpod compares with `==`, which for an identity-only
        // class is identity, so re-yielding the same instance is not a change.
        expect(seen, equals(['stable']));
      },
    );

    test(
      'two subscribers each get the value current at their subscribe time',
      () async {
        var label = 'first';
        final source = Provider<_Dep>((ref) => _Dep(label));
        final stream = identityStreamOf(source);
        container = ProviderContainer();

        final early = <String>[];
        final earlySub = container
            .read(stream)
            .listen((d) => early.add(d.label));
        addTearDown(earlySub.cancel);
        await pumpEventQueue();

        label = 'second';
        container.invalidate(source);
        await pumpEventQueue();

        final late_ = <String>[];
        final lateSub = container
            .read(stream)
            .listen((d) => late_.add(d.label));
        addTearDown(lateSub.cancel);
        await pumpEventQueue();

        expect(early, equals(['first', 'second']));
        expect(late_, equals(['second']));
      },
    );

    test('closes the stream when the container is disposed', () async {
      final source = Provider<_Dep>((ref) => _Dep('first'));
      final stream = identityStreamOf(source);
      final localContainer = ProviderContainer();

      final closed = Completer<void>();
      final subscription = localContainer
          .read(stream)
          .listen((_) {}, onDone: closed.complete);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      localContainer.dispose();
      await closed.future;
      container = ProviderContainer();
    });
  });
}
