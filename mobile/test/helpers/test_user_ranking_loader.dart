import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:user_ranking/user_ranking.dart';

/// Equal local signals for widget tests that do not exercise ranking sources.
final _defaultLoader = _TestRankingLoader();
UserRankingSignalsLoader testUserRankingLoader() => _defaultLoader;

class _TestRankingLoader extends Fake implements UserRankingSignalsLoader {
  @override
  void refreshInBackground(List<String> rankedPubkeys) {}

  @override
  Future<Map<String, String>> loadCachedDisplayNames(
    Iterable<String> pubkeys,
  ) async => {};

  @override
  bool isEligible(String pubkey) => true;

  @override
  Future<Map<String, UserRankingSignals>> load(
    Iterable<String> pubkeys, {
    bool includeDmCounterparts = false,
  }) async => {for (final key in pubkeys) key: UserRankingSignals(pubkey: key)};
}
