// ABOUTME: Verifies the video DM outbox is one instance per signed-in account
// ABOUTME: and survives a rebuild of the services it sends through.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_send_service.dart';

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

/// Stands in for the signed-in account, so a test can switch it.
final _signedIn = StateProvider<String?>((_) => null);

/// Stands in for an auth state change that keeps the same account, such as
/// an OAuth signer refresh or the RPC capability coming up.
final _authStateTick = StateProvider<int>((_) => 0);

/// Stands in for whatever makes the DM repository rebuild.
final _repositoryGeneration = StateProvider<int>((_) => 0);

void main() {
  final first = 'a' * 64;
  final second = 'b' * 64;

  late int accountIdBuilds;

  ProviderContainer buildContainer() {
    accountIdBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        // Mirrors the real provider: rebuilt on every auth state change,
        // returning the signed-in pubkey.
        currentAccountIdProvider.overrideWith((ref) {
          ref.watch(_authStateTick);
          accountIdBuilds++;
          return ref.watch(_signedIn);
        }),
        dmVideoSendServiceProvider.overrideWith((ref) {
          ref.watch(_repositoryGeneration);
          return _MockDmVideoSendService();
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(_signedIn.notifier).state = first;
    return container;
  }

  group('videoDmOutboxProvider', () {
    test('keeps the same outbox when the DM repository rebuilds', () {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final serviceBefore = container.read(dmVideoSendServiceProvider);

      container.read(_repositoryGeneration.notifier).state++;

      expect(
        container.read(dmVideoSendServiceProvider),
        isNot(same(serviceBefore)),
      );
      expect(container.read(videoDmOutboxProvider), same(before));
    });

    test('keeps the same outbox across an auth state change that keeps the '
        'account', () {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final buildsBefore = accountIdBuilds;

      container.read(_authStateTick.notifier).state++;

      expect(container.read(currentAccountIdProvider), equals(first));
      expect(accountIdBuilds, greaterThan(buildsBefore));
      expect(container.read(videoDmOutboxProvider), same(before));
    });

    test('builds a new outbox and disposes the old one when the account '
        'changes', () async {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final done = before.watchConversation('c').toList();

      container.read(_signedIn.notifier).state = second;

      expect(container.read(videoDmOutboxProvider), isNot(same(before)));
      expect(await done, isNotEmpty);
    });
  });
}
