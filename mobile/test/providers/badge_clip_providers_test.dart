import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/badge_clip_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';

class _Hidden extends Notifier<bool> {
  @override
  bool build() => false;
  void hide() => state = true;
}

final _hidden = NotifierProvider<_Hidden, bool>(_Hidden.new);

void main() {
  group('visibleBadgeClipsProvider', () {
    test(
      'reapplies the shared policy without changing the indexed snapshot',
      () {
        final clip = (
          id: 'a' * 64,
          pubkey: 'b' * 64,
          title: 'Clip',
          thumbnail: '',
          createdAt: 1700000000,
          kind: 34236,
          moderationLabels: const ['violence'],
          verifiedArchive: true,
          archiveProvenanceAvailable: true,
          tags: const [
            ['d', 'clip'],
            ['url', 'https://example.com/video.mp4'],
          ],
        );
        VideoEvent? inspected;
        final container = ProviderContainer(
          overrides: [
            profileVanishedProvider(clip.pubkey).overrideWithValue(false),
            curatedListThumbnailFilterProvider.overrideWith((ref) {
              final hidden = ref.watch(_hidden);
              return (video) {
                inspected = video;
                return hidden;
              };
            }),
          ],
        );
        addTearDown(container.dispose);
        final provider = visibleBadgeClipsProvider([clip]);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        expect(container.read(provider), [clip]);
        expect(inspected?.moderationLabels, ['violence']);
        expect(inspected?.isVerifiedArchive, isTrue);
        container.read(_hidden.notifier).hide();
        expect(container.read(provider), isEmpty);
      },
    );
  });
}
