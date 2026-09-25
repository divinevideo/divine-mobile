// ABOUTME: Tests for the creator analytics repository provider wiring.
// ABOUTME: Covers the deletion history filter and where sound counts come from.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sounds_repository/sounds_repository.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockSoundsRepository extends Mock implements SoundsRepository {}

final String _pubkey = 'a' * 64;

SoundStats _sound(String id, int usageCount) => SoundStats(
  id: id,
  pubkey: _pubkey,
  title: id,
  createdAt: DateTime.utc(2026, 9),
  usageCount: usageCount,
);

String _historyWith(String originalEventId) => jsonEncode([
  ContentDeletion(
    deleteEventId: 'delete-event',
    originalEventId: originalEventId,
    reason: 'user request',
    deletedAt: DateTime.utc(2026, 9, 2),
  ).toJson(),
]);

void main() {
  group('creatorAnalyticsRepositoryProvider', () {
    late _MockFunnelcakeApiClient client;
    late _MockSoundsRepository soundsRepository;
    late SharedPreferences prefs;

    setUp(() async {
      client = _MockFunnelcakeApiClient();
      when(
        () => client.getUserSounds(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => [_sound('kept', 3), _sound('deleted', 9)]);
      soundsRepository = _MockSoundsRepository();
      when(
        () => soundsRepository.fetchVideosUsingSoundCount(any()),
      ).thenAnswer((_) async => 1);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    CreatorAnalyticsRepository readRepository() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          funnelcakeApiClientProvider.overrideWithValue(client),
          soundsRepositoryProvider.overrideWithValue(soundsRepository),
        ],
      );
      addTearDown(container.dispose);
      return container.read(creatorAnalyticsRepositoryProvider);
    }

    group('fetchCreatorSounds', () {
      test('drops a sound in the persisted deletion history', () async {
        await prefs.setString(
          ContentDeletionService.deletionsStorageKey,
          _historyWith('deleted'),
        );

        final sounds = await readRepository().fetchCreatorSounds(_pubkey);

        expect(sounds.map((sound) => sound.id), equals(['kept']));
      });

      test('lists every sound when nothing has been deleted', () async {
        final sounds = await readRepository().fetchCreatorSounds(_pubkey);

        expect(sounds.map((sound) => sound.id), equals(['deleted', 'kept']));
      });

      test('counts videos the way the sound page does', () async {
        when(
          () => soundsRepository.fetchVideosUsingSoundCount('kept'),
        ).thenAnswer((_) async => 4);
        when(
          () => soundsRepository.fetchVideosUsingSoundCount('deleted'),
        ).thenAnswer((_) async => 2);

        final sounds = await readRepository().fetchCreatorSounds(_pubkey);

        expect(
          sounds.map((sound) => (sound.id, sound.videoCount)),
          equals([('kept', 4), ('deleted', 2)]),
        );
      });

      test('honors a deletion made after the repository was built', () async {
        final repository = readRepository();
        final before = await repository.fetchCreatorSounds(_pubkey);

        await prefs.setString(
          ContentDeletionService.deletionsStorageKey,
          _historyWith('deleted'),
        );
        final after = await repository.fetchCreatorSounds(_pubkey);

        expect(before, hasLength(2));
        expect(after.map((sound) => sound.id), equals(['kept']));
      });

      test(
        'lists every sound when the deletion history is unreadable',
        () async {
          await prefs.setString(
            ContentDeletionService.deletionsStorageKey,
            'not json',
          );

          final sounds = await readRepository().fetchCreatorSounds(_pubkey);

          expect(sounds.map((sound) => sound.id), equals(['deleted', 'kept']));
        },
      );
    });
  });
}
