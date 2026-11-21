import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/badge_clip_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends Mock implements FunnelcakeApiClient {}

class _Client extends Mock implements NostrClient {}

class _Hidden extends Notifier<bool> {
  @override
  bool build() => false;
  void hide() => state = true;
}

final _hidden = NotifierProvider<_Hidden, bool>(_Hidden.new);

void main() {
  group('visibleBadgeClipsProvider', () {
    for (final (name, publishedTags, effectiveTimestamp) in [
      (
        'out-of-range positive',
        [
          ['published_at', '8640000000001'],
        ],
        null,
      ),
      (
        'out-of-range negative',
        [
          ['published_at', '-8640000000001'],
        ],
        null,
      ),
      (
        'last duplicate is invalid',
        [
          ['published_at', '1700000001'],
          ['published_at', '8640000000001'],
        ],
        null,
      ),
      (
        'last duplicate is valid',
        [
          ['published_at', '8640000000001'],
          ['published_at', '1700000001'],
        ],
        1700000001,
      ),
      (
        'empty duplicate uses created_at',
        [
          ['published_at', '8640000000001'],
          ['published_at'],
        ],
        1700000000,
      ),
      (
        'nonnumeric uses created_at',
        [
          ['published_at', 'not-a-timestamp'],
        ],
        1700000000,
      ),
      (
        'maximum supported',
        [
          ['published_at', '8640000000000'],
        ],
        8640000000000,
      ),
      (
        'minimum supported',
        [
          ['published_at', '-8640000000000'],
        ],
        -8640000000000,
      ),
    ]) {
      test(
        'signed indexed badge safely handles $name clip timestamps',
        () async {
          final signingKey = '1'.padLeft(64, '0');
          final issuer = getPublicKey(signingKey);
          final definition = Event(
            issuer,
            EventKind.badgeDefinition,
            [
              ['d', 'synthetic-timestamps'],
            ],
            '',
            createdAt: 1700000000,
          )..sign(signingKey);
          final suspectId = 'a' * 64;
          final neighborId = 'c' * 64;
          final author = 'b' * 64;
          final cards = parseBadgeDiscoveryResponse({
            'badges': [
              {
                'definition': definition.toJson(),
                'holder_count': 1,
                'follower_count': 0,
                'videos': [
                  for (final id in [suspectId, neighborId])
                    {
                      'id': id,
                      'pubkey': author,
                      'title': 'Synthetic clip',
                      'thumbnail': '',
                      'created_at': 1700000000,
                      'kind': 34236,
                      'tags': [
                        ['d', id],
                        ['url', 'https://example.com/clip.mp4'],
                        if (id == suspectId) ...publishedTags,
                      ],
                      'moderation_labels': <String>[],
                      'verified_archive': false,
                      'archive_provenance_available': true,
                    },
                ],
              },
            ],
          });
          final api = _Api();
          when(api.getBadgeDiscovery).thenAnswer((_) async => cards);
          SharedPreferences.setMockInitialValues({});
          final repository = BadgeRepository(
            nostrClient: _Client(),
            sharedPreferences: await SharedPreferences.getInstance(),
            currentPubkey: () => null,
            signer: () => const UnauthenticatedSigner(),
            signEvent: ({
              required kind,
              required content,
              required tags,
              createdAt,
            }) async => null,
            funnelcakeApiClient: api,
          );
          addTearDown(repository.dispose);
          final indexed = await repository.loadIndexedDiscovery();
          expect(indexed.single.definition.event.isSigned, isTrue);
          final timestamps = <String, int>{};
          final container = ProviderContainer(
            overrides: [
              profileVanishedProvider(author).overrideWithValue(false),
              curatedListThumbnailFilterProvider.overrideWith(
                (ref) => (video) {
                  timestamps[video.id] = video.createdAt;
                  return false;
                },
              ),
            ],
          );
          addTearDown(container.dispose);
          final visible = container.read(
            visibleBadgeClipsProvider(indexed.single.videos),
          );
          expect(visible.map((clip) => clip.id), [
            if (effectiveTimestamp != null) suspectId,
            neighborId,
          ]);
          expect(timestamps, {
            suspectId: ?effectiveTimestamp,
            neighborId: 1700000000,
          });
        },
      );
    }

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

    BadgeVideoPreview clipBy(String pubkey, {int kind = 34236}) => (
      id: 'a' * 64,
      pubkey: pubkey,
      title: 'Clip',
      thumbnail: '',
      createdAt: 1700000000,
      kind: kind,
      moderationLabels: const <String>[],
      verifiedArchive: false,
      archiveProvenanceAvailable: true,
      tags: const [
        ['d', 'clip'],
        ['url', 'https://example.com/video.mp4'],
      ],
    );

    test('drops a clip whose author has vanished', () {
      final vanished = clipBy('b' * 64);
      final present = clipBy('c' * 64);
      final container = ProviderContainer(
        overrides: [
          profileVanishedProvider(vanished.pubkey).overrideWithValue(true),
          profileVanishedProvider(present.pubkey).overrideWithValue(false),
          curatedListThumbnailFilterProvider.overrideWith(
            (ref) =>
                (_) => false,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(visibleBadgeClipsProvider([vanished, present])), [
        present,
      ]);
    });

    test('drops a clip that is not a video kind', () {
      final note = clipBy('b' * 64, kind: EventKind.textNote);
      final container = ProviderContainer(
        overrides: [
          profileVanishedProvider(note.pubkey).overrideWithValue(false),
          curatedListThumbnailFilterProvider.overrideWith(
            (ref) =>
                (_) => false,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(visibleBadgeClipsProvider([note])), isEmpty);
    });
  });
}
