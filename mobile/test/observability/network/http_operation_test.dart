// ABOUTME: Pins finite operation categories and identifier-free fallback.
// ABOUTME: Separates creator cleanup, moderation lookup, and feed browsing.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/network/http_operation.dart';

void main() {
  test('classifies actionable routes without exporting dynamic path text', () {
    const cases = {
      '/api/delete/private-id': 'creator_delete',
      '/api/delete-status/private-id': 'creator_delete_status',
      '/check-result/private-id': 'moderation_lookup',
      '/api/v2/search?q=secret': 'search',
      '/api/v2/videos/private-id/comments': 'comments',
      '/api/users/private-id/feed': 'profile_feed',
      '/api/users/private-id/notifications': 'notifications',
      '/api/unknown-private-word': 'other',
      '/api/v2/unknown-private-word': 'other',
      '/private-word': 'other',
    };
    for (final entry in cases.entries) {
      expect(
        httpOperation(Uri.parse('https://relay.divine.video${entry.key}')),
        entry.value,
        reason: entry.key,
      );
    }
  });
}
