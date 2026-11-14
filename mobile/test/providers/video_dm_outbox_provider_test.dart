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

/// Stands in for whatever makes the DM repository rebuild.
final _repositoryGeneration = StateProvider<int>((_) => 0);

void main() {
  final first = 'a' * 64;
  final second = 'b' * 64;

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        currentAccountIdProvider.overrideWith((ref) => ref.watch(_signedIn)),
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
