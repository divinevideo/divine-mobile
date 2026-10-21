// ABOUTME: Tests Funnelcake enforcement mapping and unavailable request handling.
// ABOUTME: Transport failures remain distinct from successful unrestricted responses.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/services/account_status_api_client.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AccountEnforcementRepository _repository(String body, {int statusCode = 200}) {
  return AccountEnforcementRepository(
    apiClient: AccountStatusApiClient(
      baseUri: Uri.parse('https://api.divine.video'),
      authHeaderProvider: ({required url, required method}) async =>
          'Nostr token',
      httpClient: MockClient((_) async => http.Response(body, statusCode)),
    ),
  );
}

void main() {
  group('AccountEnforcementRepository.fetchCurrentStatus', () {
    test('maps active, suspended, and banned values', () async {
      for (final entry in {
        'active': AccountEnforcementKind.noRestrictionReported,
        'suspended': AccountEnforcementKind.suspended,
        'banned': AccountEnforcementKind.banned,
      }.entries) {
        final repository = _repository(
          '{"pubkey":"$_pubkey","status":"${entry.key}"}',
        );
        final result = await repository.fetchCurrentStatus(pubkey: _pubkey);
        expect(result.kind, entry.value);
      }
    });

    // Funnelcake names why an account is banned only through a closed set of
    // categories, so the app can explain an age-review closure without ever
    // seeing a moderator's free-text reason (support-trust-safety#260).
    test('carries the age-review category on a ban', () async {
      final result = await _repository(
        '{"pubkey":"$_pubkey","status":"banned","category":"age_review"}',
      ).fetchCurrentStatus(pubkey: _pubkey);

      expect(result.kind, AccountEnforcementKind.banned);
      expect(result.category, AccountEnforcementCategory.ageReview);
      expect(result.isAgeReviewClosure, isTrue);
    });

    test('leaves a ban without a category uncategorized', () async {
      final result = await _repository(
        '{"pubkey":"$_pubkey","status":"banned"}',
      ).fetchCurrentStatus(pubkey: _pubkey);

      expect(result.kind, AccountEnforcementKind.banned);
      expect(result.category, isNull);
    });

    // A category this version does not know must still read as the ban it
    // accompanies, or a new server category would hide the existing ban
    // screen from every installed app.
    test('keeps the ban when the category is unrecognized', () async {
      for (final category in ['"future_category"', '7', 'null', '{}']) {
        final result = await _repository(
          '{"pubkey":"$_pubkey","status":"banned","category":$category}',
        ).fetchCurrentStatus(pubkey: _pubkey);

        expect(result.kind, AccountEnforcementKind.banned, reason: category);
        expect(result.category, isNull, reason: category);
      }
    });

    test('maps request and response failures to unavailable', () async {
      for (final repository in [
        _repository('{}'),
        _repository('{"pubkey":"$_pubkey","status":"future"}'),
        _repository('unavailable', statusCode: 503),
      ]) {
        await expectLater(
          repository.fetchCurrentStatus(pubkey: _pubkey),
          throwsA(isA<AccountStatusUnavailable>()),
        );
      }
    });
  });
}
