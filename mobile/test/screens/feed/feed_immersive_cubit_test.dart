// ABOUTME: Unit tests for FeedImmersiveCubit.
// ABOUTME: Pins the idempotent enter/exit contract the several hold-release
// ABOUTME: paths in the feed rely on, and the independent pin a pinch toggles.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';

void main() {
  group(FeedImmersiveCubit, () {
    test('starts with the chrome visible', () {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isImmersive, isFalse);
    });

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'enter hides the chrome',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.enter(),
      expect: () => const [FeedImmersiveState(isHolding: true)],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'exit restores the chrome',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..enter()
        ..exit(),
      expect: () => const [
        FeedImmersiveState(isHolding: true),
        FeedImmersiveState(),
      ],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'repeated enter does not re-emit',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..enter()
        ..enter(),
      expect: () => const [FeedImmersiveState(isHolding: true)],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'exit without a preceding enter emits nothing',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.exit(),
      expect: () => const <FeedImmersiveState>[],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'pin hides the chrome and marks the state pinned',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.pin(),
      expect: () => const [
        FeedImmersiveState(isPinned: true),
      ],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'unpin restores the chrome',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..pin()
        ..unpin(),
      expect: () => const [
        FeedImmersiveState(isPinned: true),
        FeedImmersiveState(),
      ],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'a released hold does not clear a pin',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..pin()
        ..enter()
        ..exit(),
      expect: () => const [
        FeedImmersiveState(isPinned: true),
        FeedImmersiveState(isHolding: true, isPinned: true),
        FeedImmersiveState(isPinned: true),
      ],
      verify: (cubit) {
        expect(cubit.state.isImmersive, isTrue);
        expect(cubit.state.isPinned, isTrue);
      },
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'unpin keeps the chrome hidden while a hold is still down',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..enter()
        ..pin()
        ..unpin(),
      expect: () => const [
        FeedImmersiveState(isHolding: true),
        FeedImmersiveState(isHolding: true, isPinned: true),
        FeedImmersiveState(isHolding: true),
      ],
      verify: (cubit) {
        expect(cubit.state.isImmersive, isTrue);
        expect(cubit.state.isPinned, isFalse);
      },
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'repeated pin does not re-emit',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..pin()
        ..pin(),
      expect: () => const [
        FeedImmersiveState(isPinned: true),
      ],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'unpin without a pin emits nothing',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.unpin(),
      expect: () => const <FeedImmersiveState>[],
    );
  });
}
