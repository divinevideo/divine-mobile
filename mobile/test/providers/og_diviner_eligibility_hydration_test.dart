// ABOUTME: Keeps mounted beta badges aligned with profile hydration.
// ABOUTME: Covers eligibility appearing and clearing without leaving the screen.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/og_diviner_eligibility_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:profile_repository/profile_repository.dart';

class _Api extends Mock implements FunnelcakeApiClient {}

class _Nostr extends Mock implements NostrClient {}

void main() {
  const key =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  group('ogDivinerEligibilityProvider hydration', () {
    for (final firstAnswer in <bool?>[null, true]) {
      test('mounted eligibility follows hydration from $firstAnswer', () async {
        final api = _Api();
        bool? answer = firstAnswer;
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getUserProfile(key)).thenAnswer(
          (_) async =>
              UserProfileNotPublished(pubkey: key, isOgDiviner: answer),
        );
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final http = MockClient((_) => throw StateError('unused'));
        addTearDown(http.close);
        final repo = ProfileRepository(
          nostrClient: _Nostr(),
          userProfilesDao: db.userProfilesDao,
          httpClient: http,
          funnelcakeApiClient: api,
        );
        final container = ProviderContainer(
          overrides: [profileReadRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final provider = ogDivinerEligibilityProvider(key);
        final sub = container.listen(provider, (_, _) {});
        addTearDown(sub.close);
        expect(await container.read(provider.future), firstAnswer == true);
        answer = firstAnswer == null ? true : null;
        await repo.getUserProfileFromApi(pubkey: key);
        final repositoryAnswer = await repo.isOgDiviner(key);
        expect(repositoryAnswer, answer == true);
        await container.pump();
        expect(
          await container.read(provider.future),
          repositoryAnswer,
          reason: 'Mounted badge must reflect the hydrated eligibility answer',
        );
      });
    }
  });
}
