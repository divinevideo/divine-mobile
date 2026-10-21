// ABOUTME: Tests the NIP-98 Funnelcake account status HTTP contract.
// ABOUTME: Ensures only a valid account-bound 200 response becomes status state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/account_status_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AccountStatusApiClient _client({
  required Future<http.Response> Function(http.Request) handler,
  Future<String?> Function({required String url, required HttpMethod method})?
  auth,
  Duration timeout = const Duration(seconds: 30),
}) {
  return AccountStatusApiClient(
    baseUri: Uri.parse('https://api.divine.video/base'),
    authHeaderProvider:
        auth ??
        ({required url, required method}) async {
          expect(url, 'https://api.divine.video/api/users/$_pubkey/status');
          expect(method, HttpMethod.get);
          return 'Nostr signed-token';
        },
    httpClient: MockClient(handler),
    timeout: timeout,
  );
}

void main() {
  group('AccountStatusApiClient.fetchStatus', () {
    test('signs and sends the exact API URL', () async {
      final client = _client(
        handler: (request) async {
          expect(request.headers['Authorization'], 'Nostr signed-token');
          return http.Response('{"pubkey":"$_pubkey","status":"active"}', 200);
        },
      );

      expect(
        (await client.fetchStatus(expectedPubkey: _pubkey)).status,
        FunnelcakeAccountStatus.active,
      );
    });

    test('maps all recognized status strings', () async {
      for (final entry in {
        'active': FunnelcakeAccountStatus.active,
        'suspended': FunnelcakeAccountStatus.suspended,
        'banned': FunnelcakeAccountStatus.banned,
      }.entries) {
        final client = _client(
          handler: (_) async => http.Response(
            '{"pubkey":"$_pubkey","status":"${entry.key}"}',
            200,
          ),
        );
        expect(
          (await client.fetchStatus(expectedPubkey: _pubkey)).status,
          entry.value,
        );
      }
    });

    test('keeps an unknown future status indeterminate', () async {
      final client = _client(
        handler: (_) async =>
            http.Response('{"pubkey":"$_pubkey","status":"future"}', 200),
      );
      await expectLater(
        client.fetchStatus(expectedPubkey: _pubkey),
        throwsA(
          isA<AccountStatusApiException>().having(
            (error) => error.kind,
            'kind',
            AccountStatusApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('accepts matching pubkey case-insensitively', () async {
      final client = _client(
        handler: (_) async => http.Response(
          '{"pubkey":"${_pubkey.toUpperCase()}","status":"active"}',
          200,
        ),
      );
      expect(
        (await client.fetchStatus(expectedPubkey: _pubkey)).status,
        FunnelcakeAccountStatus.active,
      );
    });

    test('rejects a response for another account', () async {
      final other = List.filled(64, 'b').join();
      final client = _client(
        handler: (_) async =>
            http.Response('{"pubkey":"$other","status":"active"}', 200),
      );
      await expectLater(
        client.fetchStatus(expectedPubkey: _pubkey),
        throwsA(
          isA<AccountStatusApiException>().having(
            (error) => error.kind,
            'kind',
            AccountStatusApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects malformed and incomplete 200 responses', () async {
      for (final body in ['not-json', '{}', '[]', '{"pubkey":"$_pubkey"}']) {
        final client = _client(handler: (_) async => http.Response(body, 200));
        await expectLater(
          client.fetchStatus(expectedPubkey: _pubkey),
          throwsA(isA<AccountStatusApiException>()),
        );
      }
    });

    test('does not map non-2xx responses to active', () async {
      for (final code in [401, 404, 500, 503]) {
        final client = _client(
          handler: (_) async => http.Response('unavailable', code),
        );
        await expectLater(
          client.fetchStatus(expectedPubkey: _pubkey),
          throwsA(isA<AccountStatusApiException>()),
        );
      }
    });

    // Guards the trust boundary PR #7839 established and PR #8161 removed as
    // collateral of moving the source of truth from Keycast to Funnelcake. The
    // rationale outlived that move and is not specific to either backend:
    // stored moderation reasons are internal operational metadata, not reviewed
    // or localised user copy, so they must never reach state that copy or
    // logging could render (support-trust-safety#200 R-7). Funnelcake omits a
    // reason today and asserts that omission in its own suite; this pins the
    // client side, so a server that starts sending one cannot silently make it
    // renderable here.
    test('ignores moderation metadata a 200 response might carry', () async {
      // Everything the client keeps from a response, so any field leaking
      // through from moderation metadata shows up as a difference.
      Future<(FunnelcakeAccountStatus, FunnelcakeEnforcementCategory?)>
      statusFor(String body) async {
        final response = await _client(
          handler: (_) async => http.Response(body, 200),
        ).fetchStatus(expectedPubkey: _pubkey);
        return (response.status, response.category);
      }

      const plain = '{"pubkey":"$_pubkey","status":"suspended"}';
      const withReason =
          '{"pubkey":"$_pubkey","status":"suspended",'
          '"reason":"moderation","suspended_at":"2026-08-24T00:00:00Z",'
          '"suspended_by":"a-moderator"}';
      const withOtherReason =
          '{"pubkey":"$_pubkey","status":"suspended",'
          '"reason":"policy_violation"}';
      // The raw reason relay-manager stores for an age-review closure. Only
      // Funnelcake's closed `category` may select copy, never the reason.
      const withAgeReviewReason =
          '{"pubkey":"$_pubkey","status":"suspended",'
          '"reason":"age_review_denied"}';

      expect(await statusFor(withReason), await statusFor(plain));
      expect(await statusFor(withOtherReason), await statusFor(plain));
      expect(await statusFor(withAgeReviewReason), await statusFor(plain));
      expect(await statusFor(withReason), (
        FunnelcakeAccountStatus.suspended,
        null,
      ));
    });

    test('reports missing signer, transport failure, and timeout', () async {
      final unsigned = _client(
        auth: ({required url, required method}) async => null,
        handler: (_) async => http.Response('', 500),
      );
      await expectLater(
        unsigned.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );

      final transportFailure = _client(
        handler: (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        transportFailure.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );

      final timedOut = _client(
        timeout: Duration.zero,
        handler: (_) => Completer<http.Response>().future,
      );
      await expectLater(
        timedOut.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );
    });
  });
}
