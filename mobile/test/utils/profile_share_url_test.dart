// ABOUTME: Verifies external profile sharing retains complete npub fallback under the creator gate.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    for (final enabled in [false, true]) {
      testWidgets('complete profile URL with shortening enabled=$enabled', (
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
            201,
          );
        });
        final client = ShortLinkClient(
          client: transport,
          enabled: enabled,
          authorize: (_, _) async => 'Nostr synthetic',
        );
        addTearDown(client.close);
        addTearDown(transport.close);
        late WidgetRef reference;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shortLinkClientProvider.overrideWithValue(
                enabled ? client : null,
              ),
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
          enabled ? 'https://divine.video/l/Abc12345' : canonical,
        );
        expect(requests, hasLength(enabled ? 1 : 0));
      });
    }
  });
}
