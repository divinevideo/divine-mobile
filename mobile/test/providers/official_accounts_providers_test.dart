// ABOUTME: Tests the providers that present a DM peer by moderation-key
// ABOUTME: custody. The family holds one entry per peer pubkey, so an entry
// ABOUTME: must not outlive the widgets watching it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/official_accounts_providers.dart';

void main() {
  group('moderationPresentationProvider', () {
    final archivedKey = 'c' * 64;

    test('drops a peer once nothing watches it', () async {
      final container = ProviderContainer(
        overrides: [
          retiredModerationKeysProvider.overrideWithValue([
            RetiredModerationKey(
              pubkeyHex: archivedKey,
              custody: RetiredKeyCustody.archived,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        moderationPresentationProvider(archivedKey),
        (_, _) {},
        fireImmediately: true,
      );

      expect(subscription.read(), equals(ModerationPresentation.former));
      expect(
        container.exists(moderationPresentationProvider(archivedKey)),
        isTrue,
      );

      subscription.close();
      await container.pump();

      expect(
        container.exists(moderationPresentationProvider(archivedKey)),
        isFalse,
      );
    });
  });
}
