import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  final owner = 'a' * 64;
  final candidate = 'b' * 64;
  Map<String, Object?> suggestion(String key, {bool classic = false}) => {
    'pubkey': key,
    'profile': {'display_name': 'A creator'},
    'reason': classic ? 'classic' : 'personalized',
    'is_classic': classic,
  };

  test(
    'filters self, follows, hidden accounts and duplicate suggestions',
    () async {
      final client = FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'suggestions': [
                suggestion(owner),
                suggestion(candidate),
                suggestion(candidate),
                suggestion('c' * 64),
                suggestion('d' * 64),
              ],
              'next_cursor': 'opaque +/?',
            }),
            200,
          ),
        ),
      );
      final repository = FindPeopleRepository(
        apiClient: client,
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (key) => key == 'c' * 64 || key == 'd' * 64,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final page = await repository.load();
      expect(page.suggestions.map((item) => item.pubkey), [candidate]);
      expect(page.nextCursor, 'opaque +/?');
      await repository.dispose();
    },
  );

  test('dismissal persists and disappears from another surface', () async {
    var stored = <String>[];
    final repository = FindPeopleRepository(
      apiClient: FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'suggestions': [suggestion(candidate)],
            }),
            200,
          ),
        ),
      ),
      accountPubkey: owner,
      currentPubkey: () => owner,
      isExcluded: (_) => false,
      readDismissed: () => stored,
      writeDismissed: (keys) async {
        stored = keys;
      },
    );
    final page = await repository.load();
    await repository.dismiss(candidate);
    expect(stored, [candidate]);
    expect(repository.filter(page.suggestions), isEmpty);
    expect((await repository.load()).suggestions, isEmpty);
    await repository.dispose();
  });

  test('ignores a response after account switch', () async {
    var current = owner;
    final response = Completer<http.Response>();
    final repository = FindPeopleRepository(
      apiClient: FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) => response.future),
      ),
      accountPubkey: owner,
      currentPubkey: () => current,
      isExcluded: (_) => false,
      readDismissed: () => [],
      writeDismissed: (_) async {},
    );
    final pending = repository.load();
    current = 'e' * 64;
    response.complete(
      http.Response(
        jsonEncode({
          'suggestions': [suggestion(candidate)],
        }),
        200,
      ),
    );
    expect((await pending).suggestions, isEmpty);
    await repository.dispose();
  });

  test('retains cursor when a whole page was excluded', () async {
    final repository = FindPeopleRepository(
      apiClient: FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'suggestions': [suggestion(owner)],
              'next_cursor': 'next',
            }),
            200,
          ),
        ),
      ),
      accountPubkey: owner,
      currentPubkey: () => owner,
      isExcluded: (_) => false,
      readDismissed: () => [],
      writeDismissed: (_) async {},
    );
    final page = await repository.load();
    expect(page.suggestions, isEmpty);
    expect(page.nextCursor, 'next');
    await repository.dispose();
  });
  test(
    'concurrent dismissals persist in order without losing either person',
    () async {
      var stored = <String>[];
      final firstWrite = Completer<void>();
      var writes = 0;
      final repo = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(baseUrl: 'https://example.test'),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (keys) async {
          writes++;
          if (writes == 1) await firstWrite.future;
          stored = keys;
        },
      );
      final first = repo.dismiss(candidate);
      final second = repo.dismiss('c' * 64);
      await Future<void>.delayed(Duration.zero);
      firstWrite.complete();
      await Future.wait([first, second]);
      expect(stored.toSet(), {candidate, 'c' * 64});
      await repo.dispose();
    },
  );

  test(
    'a server safety refusal never returns previously fetched people',
    () async {
      var unavailable = false;
      final repo = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          retryBaseDelay: Duration.zero,
          httpClient: MockClient(
            (_) async => unavailable
                ? http.Response('{}', 503)
                : http.Response(
                    jsonEncode({
                      'suggestions': [suggestion(candidate)],
                    }),
                    200,
                  ),
          ),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      expect((await repo.load()).suggestions.single.pubkey, candidate);
      unavailable = true;
      await expectLater(repo.load(), throwsA(anything));
      await repo.dispose();
    },
  );
}
