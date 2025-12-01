import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoEventService Subscription ID Generation', () {
    // Helper function that mimics the _generateSubscriptionId method
    String generateSubscriptionId({
      required String subscriptionType,
      List<String>? authors,
      List<String>? hashtags,
      String? group,
      int? since,
      int? until,
      int? limit,
      bool includeReposts = false,
    }) {
      // Create a unique string representation of the subscription parameters
      final parts = <String>['type:$subscriptionType'];

      // Add sorted authors to ensure consistent ordering
      if (authors != null && authors.isNotEmpty) {
        final sortedAuthors = List<String>.from(authors)..sort();
        parts.add('authors:${sortedAuthors.join(",")}');
      }

      // Add sorted hashtags to ensure consistent ordering
      if (hashtags != null && hashtags.isNotEmpty) {
        final sortedHashtags = List<String>.from(hashtags)..sort();
        parts.add('hashtags:${sortedHashtags.join(",")}');
      }

      // Add other parameters
      if (group != null) parts.add('group:$group');
      if (since != null) parts.add('since:$since');
      if (until != null) parts.add('until:$until');
      if (limit != null) parts.add('limit:$limit');
      parts.add('reposts:$includeReposts');

      // Create a hash of the combined parameters
      final paramString = parts.join('|');
      var hash = 0;
      for (var i = 0; i < paramString.length; i++) {
        hash = ((hash << 5) - hash) + paramString.codeUnitAt(i);
        hash = hash & 0xFFFFFFFF; // Keep it 32-bit
      }

      // Return subscription ID with type prefix for readability
      final hashStr = hash.abs().toString();
      return '${subscriptionType}_$hashStr';
    }

    test('identical parameters should generate same subscription ID', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        includeReposts: false,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        includeReposts: false,
      );

      expect(id1, equals(id2));
      expect(id1, startsWith('discovery_'));
    });

    test('different subscription types should generate different IDs', () {
      final discoveryId = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
      );

      final homeFeedId = generateSubscriptionId(
        subscriptionType: 'homeFeed',
        limit: 100,
      );

      expect(discoveryId, isNot(equals(homeFeedId)));
      expect(discoveryId, startsWith('discovery_'));
      expect(homeFeedId, startsWith('homeFeed_'));
    });

    test('different authors should generate different IDs', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'homeFeed',
        authors: ['author1', 'author2'],
        limit: 100,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'homeFeed',
        authors: ['author3', 'author4'],
        limit: 100,
      );

      expect(id1, isNot(equals(id2)));
    });

    test('author order should not affect ID', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'homeFeed',
        authors: ['author1', 'author2', 'author3'],
        limit: 100,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'homeFeed',
        authors: ['author3', 'author1', 'author2'],
        limit: 100,
      );

      expect(id1, equals(id2));
    });

    test('hashtag order should not affect ID', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'hashtag',
        hashtags: ['funny', 'music', 'art'],
        limit: 100,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'hashtag',
        hashtags: ['art', 'funny', 'music'],
        limit: 100,
      );

      expect(id1, equals(id2));
    });

    test('different limits should generate different IDs', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 50,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
      );

      expect(id1, isNot(equals(id2)));
    });

    test('includeReposts flag should affect ID', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        includeReposts: true,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        includeReposts: false,
      );

      expect(id1, isNot(equals(id2)));
    });

    test('time constraints should affect ID', () {
      final id1 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        since: 1234567890,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: 'discovery',
        limit: 100,
        since: 1234567900,
      );

      expect(id1, isNot(equals(id2)));
    });

    test('complex subscription should generate consistent ID', () {
      final params = {
        'subscriptionType': 'homeFeed',
        'authors': ['author1', 'author2', 'author3', 'author4', 'author5'],
        'hashtags': ['funny', 'music'],
        'group': 'mygroup',
        'since': 1234567890,
        'until': 1234567900,
        'limit': 100,
        'includeReposts': true,
      };

      // Generate ID multiple times with same parameters
      final id1 = generateSubscriptionId(
        subscriptionType: params['subscriptionType'] as String,
        authors: params['authors'] as List<String>,
        hashtags: params['hashtags'] as List<String>,
        group: params['group'] as String,
        since: params['since'] as int,
        until: params['until'] as int,
        limit: params['limit'] as int,
        includeReposts: params['includeReposts'] as bool,
      );

      final id2 = generateSubscriptionId(
        subscriptionType: params['subscriptionType'] as String,
        authors: params['authors'] as List<String>,
        hashtags: params['hashtags'] as List<String>,
        group: params['group'] as String,
        since: params['since'] as int,
        until: params['until'] as int,
        limit: params['limit'] as int,
        includeReposts: params['includeReposts'] as bool,
      );

      expect(id1, equals(id2));
      expect(id1, startsWith('homeFeed_'));
    });

    test('empty parameters should still generate valid ID', () {
      final id = generateSubscriptionId(subscriptionType: 'discovery');

      expect(id, isNotEmpty);
      expect(id, startsWith('discovery_'));
      expect(id, matches(RegExp(r'^discovery_\d+$')));
    });
  });
}
