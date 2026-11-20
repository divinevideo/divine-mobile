// ABOUTME: Verifies profile sharing shortens automatically and retains the complete fallback on failure.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/short_link_provider.dart';
import 'package:openvine/services/short_link_client.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/profile_share_url.dart';

void main() {
  const pubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  final canonical =
      'https://divine.video/profile/${NostrKeyUtils.encodePubKey(pubkey)}';
  group('profile external sharing', () {
    for (final succeeds in [false, true]) {
      final outcome = succeeds
          ? 'shares the short link when the gateway creates one'
          : 'shares the complete npub URL when the gateway fails';
      testWidgets(outcome, (
        tester,
      ) async {
        final requests = <http.Request>[];
        final transport = MockClient((request) async {
          requests.add(request);
          expect(jsonDecode(request.body), {'url': canonical});
          return http.Response(
            jsonEncode({
              'url': canonical,
              'code': 'Abc12345',
              'short_url': 'https://divine.video/l/Abc12345',
            }),
            succeeds ? 201 : 503,
          );
        });
        final client = ShortLinkClient(
          client: transport,
        );
        addTearDown(client.close);
        addTearDown(transport.close);
        late WidgetRef reference;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileReadRepositoryProvider.overrideWithValue(null),
              shortLinkClientProvider.overrideWithValue(client),
            ],
            child: Consumer(
              builder: (_, ref, _) {
                reference = ref;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(
          await resolveProfileShareUrl(
            reference,
            pubkey: pubkey,
            profile: null,
          ),
          succeeds ? 'https://divine.video/l/Abc12345' : canonical,
        );
        expect(requests, hasLength(1));
      });
    }

    testWidgets('shares the complete npub URL when no shortener exists', (
      tester,
    ) async {
      late WidgetRef reference;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileReadRepositoryProvider.overrideWithValue(null),
            shortLinkClientProvider.overrideWithValue(null),
          ],
          child: Consumer(
            builder: (_, ref, _) {
              reference = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        await resolveProfileShareUrl(
          reference,
          pubkey: pubkey,
          profile: null,
        ),
        canonical,
      );
    });
  });
}
