// ABOUTME: Tests for the local user-ranking loader providers.
// ABOUTME: Pins which session changes rebuild the account-scoped loaders.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockMyFollowersDao extends Mock implements MyFollowersDao {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _MockNip05VerificationsDao extends Mock
    implements Nip05VerificationsDao {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._initial);

  final NostrSessionReadiness _initial;

  @override
  NostrSessionReadiness build() => _initial;
}

void main() {
  // Built at runtime, so every readiness below is a distinct instance.
  final owner = 'a' * 64;
  final other = 'b' * 64;

  group('ranking loader providers', () {
    late ProviderContainer container;

    setUp(() {
      final database = _MockAppDatabase();
      when(() => database.myFollowersDao).thenReturn(_MockMyFollowersDao());
      when(() => database.profileStatsDao).thenReturn(_MockProfileStatsDao());
      when(() => database.nostrEventsDao).thenReturn(_MockNostrEventsDao());
      when(
        () => database.nip05VerificationsDao,
      ).thenReturn(_MockNip05VerificationsDao());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
          followRepositoryProvider.overrideWithValue(_MockFollowRepository()),
          profileRepositoryProvider.overrideWithValue(null),
          contentBlocklistRepositoryProvider.overrideWithValue(
            ContentBlocklistRepository(),
          ),
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              NostrSessionReadiness.identityKnown(pubkey: owner),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    void report(String pubkey) => container
        .read(nostrSessionProvider.notifier)
        .update(NostrSessionReadiness.identityKnown(pubkey: pubkey));

    for (final (name, provider) in [
      ('userRankingSignalsLoaderProvider', userRankingSignalsLoaderProvider),
      (
        'ownFollowListRankingSignalsLoaderProvider',
        ownFollowListRankingSignalsLoaderProvider,
      ),
    ]) {
      group(name, () {
        test('keeps its loader when the same identity is re-reported', () {
          final loader = container.listen<UserRankingSignalsLoader>(
            provider,
            (_, _) {},
          );
          final first = loader.read();
          expect(first.isEligible(owner), isFalse);
          report(owner);
          expect(loader.read(), same(first));
        });

        test('rebuilds for another identity', () {
          final loader = container.listen<UserRankingSignalsLoader>(
            provider,
            (_, _) {},
          );
          final first = loader.read();
          report(other);
          final next = loader.read();
          expect(next, isNot(same(first)));
          expect(next.isEligible(owner), isTrue);
          expect(next.isEligible(other), isFalse);
        });
      });
    }
  });
}
