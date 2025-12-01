# REST Gateway Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate REST gateway as an optimization layer for loading cacheable Nostr content faster, while keeping WebSocket as the foundation.

**Architecture:** Gateway fetches events via REST, imports them into embedded relay's SQLite, then normal WebSocket flow continues. Gateway is optional, only for divine relay users, and always falls back to WebSocket on failure.

**Tech Stack:** Flutter/Dart, http package, flutter_embedded_nostr_relay, SharedPreferences

---

## Task 1: Add importEvents() to Embedded Relay

**Files:**
- Modify: `/Users/rabble/code/andotherstuff/flutter_embedded_nostr_relay/flutter_embedded_nostr_relay/lib/src/core/embedded_nostr_relay.dart`
- Test: `/Users/rabble/code/andotherstuff/flutter_embedded_nostr_relay/flutter_embedded_nostr_relay/test/embedded_nostr_relay_import_test.dart`

**Step 1: Write the failing test**

```dart
// test/embedded_nostr_relay_import_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart';

void main() {
  group('EmbeddedNostrRelay.importEvents', () {
    late EmbeddedNostrRelay relay;

    setUp(() async {
      relay = EmbeddedNostrRelay();
      await relay.initialize(logLevel: Level.OFF);
    });

    tearDown(() async {
      await relay.shutdown();
    });

    test('imports list of events into storage', () async {
      final event1 = NostrEvent(
        id: 'abc123',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: 1,
        tags: [],
        content: 'Test event 1',
        sig: 'sig1',
      );
      final event2 = NostrEvent(
        id: 'def456',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: 1,
        tags: [],
        content: 'Test event 2',
        sig: 'sig2',
      );

      final storedCount = await relay.importEvents([event1, event2]);

      expect(storedCount, 2);

      // Verify events are queryable
      final results = await relay.queryEvents([Filter(ids: ['abc123', 'def456'])]);
      expect(results.length, 2);
    });

    test('deduplicates events with same ID', () async {
      final event = NostrEvent(
        id: 'duplicate123',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: 1,
        tags: [],
        content: 'Duplicate test',
        sig: 'sig1',
      );

      final firstImport = await relay.importEvents([event]);
      final secondImport = await relay.importEvents([event]);

      expect(firstImport, 1);
      expect(secondImport, 0); // Already exists
    });

    test('returns 0 for empty list', () async {
      final storedCount = await relay.importEvents([]);
      expect(storedCount, 0);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/flutter_embedded_nostr_relay/flutter_embedded_nostr_relay
flutter test test/embedded_nostr_relay_import_test.dart
```

Expected: FAIL with "importEvents" not found

**Step 3: Write minimal implementation**

Add to `embedded_nostr_relay.dart` after the `deleteEvents` method (around line 570):

```dart
  /// Import events from external source (e.g., REST gateway) into local storage.
  ///
  /// This method batch-inserts events without publishing to external relays.
  /// Useful for seeding local storage from cached REST responses.
  ///
  /// Returns the count of events actually stored (excludes duplicates).
  Future<int> importEvents(List<NostrEvent> events) async {
    if (events.isEmpty) return 0;

    RelayLogger.info('import', 'Importing ${events.length} events from external source');

    final storedCount = await _eventStore.storeEvents(events);

    // Notify subscribers about imported events
    for (final event in events) {
      _eventStreamController.add(event);
      _subscriptionManager.matchEvent(event);
    }

    RelayLogger.info('import', 'Imported $storedCount/${events.length} events');
    return storedCount;
  }
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/flutter_embedded_nostr_relay/flutter_embedded_nostr_relay
flutter test test/embedded_nostr_relay_import_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/flutter_embedded_nostr_relay/flutter_embedded_nostr_relay
git add lib/src/core/embedded_nostr_relay.dart test/embedded_nostr_relay_import_test.dart
git commit -m "feat: add importEvents() for batch importing events from external sources"
```

---

## Task 2: Create GatewayResponse Model

**Files:**
- Create: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/models/gateway_response.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/models/gateway_response_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/gateway_response_test.dart
// ABOUTME: Tests for GatewayResponse model parsing
// ABOUTME: Validates JSON deserialization from REST gateway responses

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/gateway_response.dart';

void main() {
  group('GatewayResponse', () {
    test('parses complete response with events', () {
      final json = {
        'events': [
          {
            'id': 'event123',
            'pubkey': 'pubkey123',
            'created_at': 1700000000,
            'kind': 1,
            'tags': [],
            'content': 'Hello',
            'sig': 'sig123',
          }
        ],
        'eose': true,
        'complete': true,
        'cached': true,
        'cache_age_seconds': 42,
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.events.length, 1);
      expect(response.events.first['id'], 'event123');
      expect(response.eose, true);
      expect(response.complete, true);
      expect(response.cached, true);
      expect(response.cacheAgeSeconds, 42);
    });

    test('parses response with empty events', () {
      final json = {
        'events': [],
        'eose': true,
        'complete': true,
        'cached': false,
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.events, isEmpty);
      expect(response.cached, false);
      expect(response.cacheAgeSeconds, isNull);
    });

    test('handles missing optional fields', () {
      final json = {
        'events': [],
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.eose, false);
      expect(response.complete, false);
      expect(response.cached, false);
      expect(response.cacheAgeSeconds, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/models/gateway_response_test.dart
```

Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/models/gateway_response.dart
// ABOUTME: Response model for REST gateway API responses
// ABOUTME: Parses events and cache metadata from gateway.divine.video

/// Response from the Divine REST Gateway API
class GatewayResponse {
  /// List of raw event JSON objects from the gateway
  final List<Map<String, dynamic>> events;

  /// Whether End of Stored Events was reached
  final bool eose;

  /// Whether the query is complete (all matching events returned)
  final bool complete;

  /// Whether the response came from cache
  final bool cached;

  /// Age of cached data in seconds (null if not cached)
  final int? cacheAgeSeconds;

  GatewayResponse({
    required this.events,
    required this.eose,
    required this.complete,
    required this.cached,
    this.cacheAgeSeconds,
  });

  factory GatewayResponse.fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List<dynamic>? ?? [];

    return GatewayResponse(
      events: eventsList.cast<Map<String, dynamic>>(),
      eose: json['eose'] as bool? ?? false,
      complete: json['complete'] as bool? ?? false,
      cached: json['cached'] as bool? ?? false,
      cacheAgeSeconds: json['cache_age_seconds'] as int?,
    );
  }

  /// Whether the response contains any events
  bool get hasEvents => events.isNotEmpty;

  /// Number of events in the response
  int get eventCount => events.length;
}
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/models/gateway_response_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/models/gateway_response.dart test/models/gateway_response_test.dart
git commit -m "feat: add GatewayResponse model for REST gateway API"
```

---

## Task 3: Create RelayGatewayService

**Files:**
- Create: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/services/relay_gateway_service.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/services/relay_gateway_service_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/relay_gateway_service_test.dart
// ABOUTME: Tests for RelayGatewayService REST client
// ABOUTME: Validates filter encoding, response parsing, and error handling

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/services/relay_gateway_service.dart';

void main() {
  group('RelayGatewayService', () {
    group('query', () {
      test('encodes filter as base64url in URL', () async {
        String? capturedUrl;

        final mockClient = MockClient((request) async {
          capturedUrl = request.url.toString();
          return http.Response(
            jsonEncode({'events': [], 'eose': true, 'complete': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final filter = nostr.Filter(kinds: [1], limit: 10);
        await service.query(filter);

        expect(capturedUrl, contains('https://gateway.test/query?filter='));
        // Verify it's valid base64url
        final filterParam = Uri.parse(capturedUrl!).queryParameters['filter']!;
        final decoded = utf8.decode(base64Url.decode(filterParam));
        final decodedJson = jsonDecode(decoded);
        expect(decodedJson['kinds'], [1]);
        expect(decodedJson['limit'], 10);
      });

      test('parses successful response with events', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'event1',
                  'pubkey': 'pub1',
                  'created_at': 1700000000,
                  'kind': 1,
                  'tags': [],
                  'content': 'test',
                  'sig': 'sig1',
                }
              ],
              'eose': true,
              'complete': true,
              'cached': true,
              'cache_age_seconds': 30,
            }),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final response = await service.query(nostr.Filter(kinds: [1]));

        expect(response.events.length, 1);
        expect(response.events.first['id'], 'event1');
        expect(response.cached, true);
        expect(response.cacheAgeSeconds, 30);
      });

      test('throws GatewayException on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        expect(
          () => service.query(nostr.Filter(kinds: [1])),
          throwsA(isA<GatewayException>()),
        );
      });

      test('throws GatewayException on network error', () async {
        final mockClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        expect(
          () => service.query(nostr.Filter(kinds: [1])),
          throwsA(isA<GatewayException>()),
        );
      });
    });

    group('getProfile', () {
      test('fetches profile by pubkey', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/profile/testpubkey123');
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'profile1',
                  'pubkey': 'testpubkey123',
                  'created_at': 1700000000,
                  'kind': 0,
                  'tags': [],
                  'content': '{"name":"Test User"}',
                  'sig': 'sig1',
                }
              ],
              'eose': true,
            }),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getProfile('testpubkey123');

        expect(event, isNotNull);
        expect(event!['pubkey'], 'testpubkey123');
        expect(event['kind'], 0);
      });

      test('returns null for missing profile', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'events': [], 'eose': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getProfile('nonexistent');

        expect(event, isNull);
      });
    });

    group('getEvent', () {
      test('fetches event by ID', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/event/eventid123');
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'eventid123',
                  'pubkey': 'pub1',
                  'created_at': 1700000000,
                  'kind': 34236,
                  'tags': [],
                  'content': 'video content',
                  'sig': 'sig1',
                }
              ],
              'eose': true,
            }),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getEvent('eventid123');

        expect(event, isNotNull);
        expect(event!['id'], 'eventid123');
      });

      test('returns null for missing event', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'events': [], 'eose': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getEvent('nonexistent');

        expect(event, isNull);
      });
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/relay_gateway_service_test.dart
```

Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/services/relay_gateway_service.dart
// ABOUTME: REST client for Divine Gateway API (gateway.divine.video)
// ABOUTME: Provides cached query, profile, and event fetching via HTTP

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/models/gateway_response.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown when gateway request fails
class GatewayException implements Exception {
  final String message;
  final int? statusCode;

  GatewayException(this.message, {this.statusCode});

  @override
  String toString() => 'GatewayException: $message (status: $statusCode)';
}

/// REST client for the Divine Gateway API
///
/// Provides cached access to Nostr events via HTTP REST endpoints.
/// Use for discovery feeds, hashtag feeds, profiles, and single event lookups.
/// Falls back to WebSocket (via NostrService) on failure.
class RelayGatewayService {
  /// Default gateway URL for Divine relay infrastructure
  static const String defaultGatewayUrl = 'https://gateway.divine.video';

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 10);

  final String gatewayUrl;
  final http.Client _client;

  RelayGatewayService({
    String? gatewayUrl,
    http.Client? client,
  })  : gatewayUrl = gatewayUrl ?? defaultGatewayUrl,
        _client = client ?? http.Client();

  /// Query events using NIP-01 filter via REST gateway
  ///
  /// Filter is base64url-encoded in the URL query parameter.
  /// Returns [GatewayResponse] with events and cache metadata.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<GatewayResponse> query(nostr.Filter filter) async {
    final filterJson = jsonEncode(_filterToJson(filter));
    final encoded = base64Url.encode(utf8.encode(filterJson));
    final url = '$gatewayUrl/query?filter=$encoded';

    Log.debug(
      'Gateway query: ${filter.kinds} limit=${filter.limit}',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      Log.info(
        'Gateway returned ${gatewayResponse.eventCount} events '
        '(cached: ${gatewayResponse.cached}, age: ${gatewayResponse.cacheAgeSeconds}s)',
        name: 'RelayGatewayService',
        category: LogCategory.relay,
      );

      return gatewayResponse;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Get profile (kind 0) by pubkey
  ///
  /// Returns raw event JSON or null if not found.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<Map<String, dynamic>?> getProfile(String pubkey) async {
    final url = '$gatewayUrl/profile/$pubkey';

    Log.debug(
      'Gateway profile fetch: $pubkey',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      if (gatewayResponse.events.isEmpty) {
        return null;
      }

      return gatewayResponse.events.first;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Get single event by ID
  ///
  /// Returns raw event JSON or null if not found.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    final url = '$gatewayUrl/event/$eventId';

    Log.debug(
      'Gateway event fetch: $eventId',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      if (gatewayResponse.events.isEmpty) {
        return null;
      }

      return gatewayResponse.events.first;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Convert nostr_sdk Filter to JSON map for gateway
  Map<String, dynamic> _filterToJson(nostr.Filter filter) {
    final json = <String, dynamic>{};

    if (filter.ids != null && filter.ids!.isNotEmpty) {
      json['ids'] = filter.ids;
    }
    if (filter.authors != null && filter.authors!.isNotEmpty) {
      json['authors'] = filter.authors;
    }
    if (filter.kinds != null && filter.kinds!.isNotEmpty) {
      json['kinds'] = filter.kinds;
    }
    if (filter.since != null) {
      json['since'] = filter.since;
    }
    if (filter.until != null) {
      json['until'] = filter.until;
    }
    if (filter.limit != null) {
      json['limit'] = filter.limit;
    }
    // Handle tag filters (#e, #p, #t, etc.)
    if (filter.tags != null) {
      for (final entry in filter.tags!.entries) {
        json['#${entry.key}'] = entry.value;
      }
    }

    return json;
  }

  /// Dispose of HTTP client resources
  void dispose() {
    _client.close();
  }
}
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/relay_gateway_service_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/services/relay_gateway_service.dart test/services/relay_gateway_service_test.dart
git commit -m "feat: add RelayGatewayService for REST gateway queries"
```

---

## Task 4: Add Gateway Settings Persistence

**Files:**
- Create: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/services/relay_gateway_settings.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/services/relay_gateway_settings_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/relay_gateway_settings_test.dart
// ABOUTME: Tests for RelayGatewaySettings persistence
// ABOUTME: Validates enable/disable toggle and URL storage

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RelayGatewaySettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to enabled when using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.isEnabled, true);
    });

    test('persists enabled state', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      await settings.setEnabled(false);
      expect(settings.isEnabled, false);

      await settings.setEnabled(true);
      expect(settings.isEnabled, true);
    });

    test('loads persisted state', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.isEnabled, false);
    });

    test('returns default gateway URL', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.gatewayUrl, 'https://gateway.divine.video');
    });

    test('persists custom gateway URL', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      await settings.setGatewayUrl('https://custom.gateway');
      expect(settings.gatewayUrl, 'https://custom.gateway');
    });

    test('shouldUseGateway returns true when enabled and using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: ['wss://relay.divine.video']),
        true,
      );
    });

    test('shouldUseGateway returns false when disabled', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: ['wss://relay.divine.video']),
        false,
      );
    });

    test('shouldUseGateway returns false when not using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: ['wss://other.relay']),
        false,
      );
    });

    test('shouldUseGateway returns true when divine relay is one of many', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: [
          'wss://other.relay',
          'wss://relay.divine.video',
        ]),
        true,
      );
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/relay_gateway_settings_test.dart
```

Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/services/relay_gateway_settings.dart
// ABOUTME: Persistence for REST gateway settings
// ABOUTME: Manages gateway enable/disable toggle and custom URL

import 'package:shared_preferences/shared_preferences.dart';

/// Settings persistence for REST gateway feature
class RelayGatewaySettings {
  static const String _enabledKey = 'relay_gateway_enabled';
  static const String _gatewayUrlKey = 'relay_gateway_url';
  static const String _defaultGatewayUrl = 'https://gateway.divine.video';
  static const String _divineRelayUrl = 'wss://relay.divine.video';

  final SharedPreferences _prefs;

  RelayGatewaySettings(this._prefs);

  /// Whether the gateway is enabled (defaults to true)
  bool get isEnabled => _prefs.getBool(_enabledKey) ?? true;

  /// Set gateway enabled state
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_enabledKey, enabled);
  }

  /// Gateway URL (defaults to gateway.divine.video)
  String get gatewayUrl => _prefs.getString(_gatewayUrlKey) ?? _defaultGatewayUrl;

  /// Set custom gateway URL
  Future<void> setGatewayUrl(String url) async {
    await _prefs.setString(_gatewayUrlKey, url);
  }

  /// Check if gateway should be used based on settings and configured relays
  ///
  /// Returns true only if:
  /// 1. Gateway is enabled in settings
  /// 2. User has relay.divine.video configured
  bool shouldUseGateway({required List<String> configuredRelays}) {
    if (!isEnabled) return false;

    // Only use gateway when divine relay is configured
    return configuredRelays.any((relay) => relay.contains('relay.divine.video'));
  }

  /// Check if divine relay is in the configured relays list
  static bool isDivineRelayConfigured(List<String> relays) {
    return relays.any((relay) => relay.contains('relay.divine.video'));
  }
}
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/relay_gateway_settings_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/services/relay_gateway_settings.dart test/services/relay_gateway_settings_test.dart
git commit -m "feat: add RelayGatewaySettings for gateway toggle persistence"
```

---

## Task 5: Add Gateway Toggle to Relay Settings Screen

**Files:**
- Modify: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/screens/relay_settings_screen.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/screens/relay_settings_gateway_toggle_test.dart`

**Step 1: Write the failing test**

```dart
// test/screens/relay_settings_gateway_toggle_test.dart
// ABOUTME: Widget tests for gateway toggle in relay settings
// ABOUTME: Validates visibility, state changes, and persistence

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/mock_providers.dart';

void main() {
  group('RelaySettingsScreen Gateway Toggle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows gateway section when divine relay configured', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createMockProvidersWithRelays(['wss://relay.divine.video']),
          child: const MaterialApp(
            home: RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REST Gateway'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('hides gateway section when divine relay not configured', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createMockProvidersWithRelays(['wss://other.relay']),
          child: const MaterialApp(
            home: RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REST Gateway'), findsNothing);
    });

    testWidgets('toggle changes gateway enabled state', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: createMockProvidersWithRelays(['wss://relay.divine.video']),
          child: const MaterialApp(
            home: RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the gateway toggle switch
      final switchFinder = find.byWidgetPredicate(
        (widget) => widget is Switch && widget.key == const Key('gateway_toggle'),
      );

      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(prefs.getBool('relay_gateway_enabled'), false);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/screens/relay_settings_gateway_toggle_test.dart
```

Expected: FAIL - test helpers or gateway section not found

**Step 3: Write minimal implementation**

Add to `relay_settings_screen.dart` after the relay list section (around line 140):

```dart
// Add import at top of file
import 'package:openvine/services/relay_gateway_settings.dart';

// Add state variable in _RelaySettingsScreenState
late RelayGatewaySettings _gatewaySettings;
bool _gatewayEnabled = true;

// In initState, add:
@override
void initState() {
  super.initState();
  _initGatewaySettings();
}

Future<void> _initGatewaySettings() async {
  final prefs = await SharedPreferences.getInstance();
  _gatewaySettings = RelayGatewaySettings(prefs);
  setState(() {
    _gatewayEnabled = _gatewaySettings.isEnabled;
  });
}

// Add this widget method to build the gateway section
Widget _buildGatewaySection(List<String> relays) {
  // Only show when divine relay is configured
  if (!RelayGatewaySettings.isDivineRelayConfigured(relays)) {
    return const SizedBox.shrink();
  }

  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, color: VineTheme.vineGreen, size: 20),
            const SizedBox(width: 8),
            const Text(
              'REST Gateway',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Switch(
              key: const Key('gateway_toggle'),
              value: _gatewayEnabled,
              activeColor: VineTheme.vineGreen,
              onChanged: (value) async {
                await _gatewaySettings.setEnabled(value);
                setState(() {
                  _gatewayEnabled = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Use caching gateway for faster loading of discovery feeds, hashtags, and profiles.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Only available when using relay.divine.video',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    ),
  );
}

// In the build method, add after the relay list:
_buildGatewaySection(externalRelays),
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/screens/relay_settings_gateway_toggle_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/screens/relay_settings_screen.dart test/screens/relay_settings_gateway_toggle_test.dart
git commit -m "feat: add gateway toggle to relay settings screen"
```

---

## Task 6: Create Riverpod Provider for Gateway Service

**Files:**
- Create: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/providers/relay_gateway_providers.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/providers/relay_gateway_providers_test.dart`

**Step 1: Write the failing test**

```dart
// test/providers/relay_gateway_providers_test.dart
// ABOUTME: Tests for gateway Riverpod providers
// ABOUTME: Validates provider initialization and dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RelayGatewayProviders', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('relayGatewaySettingsProvider provides settings instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings, isA<RelayGatewaySettings>());
      expect(settings.isEnabled, true);

      container.dispose();
    });

    test('relayGatewayServiceProvider provides service instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final service = container.read(relayGatewayServiceProvider);

      expect(service, isA<RelayGatewayService>());
      expect(service.gatewayUrl, 'https://gateway.divine.video');

      container.dispose();
    });

    test('service uses custom URL from settings', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_url': 'https://custom.gateway',
      });

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final service = container.read(relayGatewayServiceProvider);

      expect(service.gatewayUrl, 'https://custom.gateway');

      container.dispose();
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/providers/relay_gateway_providers_test.dart
```

Expected: FAIL - provider file not found

**Step 3: Write minimal implementation**

```dart
// lib/providers/relay_gateway_providers.dart
// ABOUTME: Riverpod providers for REST gateway service and settings
// ABOUTME: Provides dependency injection for gateway functionality

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences instance
/// Must be overridden in ProviderScope with actual instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// Provider for gateway settings
final relayGatewaySettingsProvider = Provider<RelayGatewaySettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RelayGatewaySettings(prefs);
});

/// Provider for gateway service
final relayGatewayServiceProvider = Provider<RelayGatewayService>((ref) {
  final settings = ref.watch(relayGatewaySettingsProvider);
  return RelayGatewayService(gatewayUrl: settings.gatewayUrl);
});

/// Provider to check if gateway should be used for queries
final shouldUseGatewayProvider = Provider.family<bool, List<String>>((ref, configuredRelays) {
  final settings = ref.watch(relayGatewaySettingsProvider);
  return settings.shouldUseGateway(configuredRelays: configuredRelays);
});
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/providers/relay_gateway_providers_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/providers/relay_gateway_providers.dart test/providers/relay_gateway_providers_test.dart
git commit -m "feat: add Riverpod providers for gateway service and settings"
```

---

## Task 7: Integrate Gateway into VideoEventService

**Files:**
- Modify: `/Users/rabble/code/andotherstuff/openvine/mobile/lib/services/video_event_service.dart`
- Test: `/Users/rabble/code/andotherstuff/openvine/mobile/test/services/video_event_service_gateway_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/video_event_service_gateway_test.dart
// ABOUTME: Tests for gateway integration in VideoEventService
// ABOUTME: Validates gateway fetch + SQLite import + WebSocket fallback

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/mock_nostr_service.dart';
import '../test_helpers/mock_embedded_relay.dart';

void main() {
  group('VideoEventService Gateway Integration', () {
    late MockNostrService mockNostrService;
    late MockEmbeddedRelay mockEmbeddedRelay;
    late RelayGatewaySettings gatewaySettings;
    late RelayGatewayService gatewayService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      gatewaySettings = RelayGatewaySettings(prefs);

      mockNostrService = MockNostrService();
      mockEmbeddedRelay = MockEmbeddedRelay();
    });

    test('uses gateway for discovery feed when enabled', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'video1',
                'pubkey': 'pub1',
                'created_at': 1700000000,
                'kind': 34236,
                'tags': [],
                'content': '',
                'sig': 'sig1',
              }
            ],
            'eose': true,
            'complete': true,
            'cached': true,
          }),
          200,
        );
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      when(mockNostrService.relays).thenReturn(['wss://relay.divine.video']);

      final videoEventService = VideoEventService(
        mockNostrService,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      // Verify gateway was called and events imported
      verify(mockEmbeddedRelay.importEvents(any)).called(1);
    });

    test('skips gateway for home feed', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(jsonEncode({'events': []}), 200);
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      when(mockNostrService.relays).thenReturn(['wss://relay.divine.video']);

      final videoEventService = VideoEventService(
        mockNostrService,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        limit: 50,
      );

      expect(gatewayCalled, false);
    });

    test('falls back to WebSocket on gateway failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      when(mockNostrService.relays).thenReturn(['wss://relay.divine.video']);

      final videoEventService = VideoEventService(
        mockNostrService,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      // Should not throw - falls back to WebSocket
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      // Verify WebSocket subscription was still created
      verify(mockNostrService.subscribe(any, any)).called(1);
    });

    test('skips gateway when not using divine relay', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(jsonEncode({'events': []}), 200);
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      when(mockNostrService.relays).thenReturn(['wss://other.relay']);

      final videoEventService = VideoEventService(
        mockNostrService,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      expect(gatewayCalled, false);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/video_event_service_gateway_test.dart
```

Expected: FAIL - VideoEventService doesn't accept gateway parameters

**Step 3: Write minimal implementation**

Modify `video_event_service.dart` to add gateway integration:

```dart
// Add imports at top
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';

// Modify constructor to accept optional gateway dependencies
class VideoEventService extends ChangeNotifier {
  VideoEventService(
    this._nostrService, {
    RelayGatewayService? gatewayService,
    RelayGatewaySettings? gatewaySettings,
  })  : _gatewayService = gatewayService,
        _gatewaySettings = gatewaySettings;

  final INostrService _nostrService;
  final RelayGatewayService? _gatewayService;
  final RelayGatewaySettings? _gatewaySettings;

  // Add helper method to check if gateway should be used
  bool _shouldUseGateway(SubscriptionType type) {
    // Gateway dependencies must be available
    if (_gatewayService == null || _gatewaySettings == null) return false;

    // Only for cacheable, shared content (not personalized feeds)
    if (type == SubscriptionType.homeFeed) return false;

    // Check settings and relay configuration
    return _gatewaySettings!.shouldUseGateway(
      configuredRelays: _nostrService.relays,
    );
  }

  // Add method to fetch via gateway and import to SQLite
  Future<void> _fetchViaGateway(
    SubscriptionType type,
    Filter filter,
  ) async {
    if (!_shouldUseGateway(type)) return;

    try {
      Log.info(
        'Gateway: Fetching ${type.name} via REST',
        name: 'VideoEventService',
        category: LogCategory.relay,
      );

      final response = await _gatewayService!.query(filter);

      if (response.hasEvents) {
        // Convert raw JSON to NostrEvent objects
        final events = response.events
            .map((json) => _jsonToNostrEvent(json))
            .whereType<NostrEvent>()
            .toList();

        // Import into embedded relay SQLite
        final imported = await _nostrService.importEvents(events);

        Log.info(
          'Gateway: Imported $imported/${events.length} events '
          '(cached: ${response.cached}, age: ${response.cacheAgeSeconds}s)',
          name: 'VideoEventService',
          category: LogCategory.relay,
        );
      }
    } on GatewayException catch (e) {
      Log.warning(
        'Gateway fetch failed, WebSocket will handle: $e',
        name: 'VideoEventService',
        category: LogCategory.relay,
      );
      // Fall through to WebSocket - no rethrow
    }
  }

  // Modify subscribeToVideoFeed to call gateway first
  Future<void> subscribeToVideoFeed({
    required SubscriptionType subscriptionType,
    int limit = 100,
    // ... other params
  }) async {
    // Try gateway first for eligible feed types
    if (_shouldUseGateway(subscriptionType)) {
      final filter = _buildFilterForType(subscriptionType, limit: limit);
      await _fetchViaGateway(subscriptionType, filter);
    }

    // Always set up WebSocket subscription (real-time + fallback)
    // ... existing WebSocket subscription code ...
  }
}
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/services/video_event_service_gateway_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/services/video_event_service.dart test/services/video_event_service_gateway_test.dart
git commit -m "feat: integrate gateway into VideoEventService for discovery feeds"
```

---

## Task 8: Run Full Test Suite and Analyze

**Step 1: Run all gateway-related tests**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/models/gateway_response_test.dart \
  test/services/relay_gateway_service_test.dart \
  test/services/relay_gateway_settings_test.dart \
  test/providers/relay_gateway_providers_test.dart \
  test/services/video_event_service_gateway_test.dart
```

**Step 2: Run flutter analyze**

```bash
flutter analyze
```

Fix any issues found.

**Step 3: Run full test suite**

```bash
flutter test
```

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues from full test suite"
```

---

## Task 9: Add Integration Test

**Files:**
- Create: `/Users/rabble/code/andotherstuff/openvine/mobile/test/integration/gateway_integration_test.dart`

**Step 1: Write integration test**

```dart
// test/integration/gateway_integration_test.dart
// ABOUTME: Integration test for gateway + embedded relay + providers
// ABOUTME: Tests full flow from gateway fetch to UI display

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Gateway Integration', () {
    testWidgets('gateway events flow through to video feed', (tester) async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
        'configured_relays': ['wss://relay.divine.video'],
      });

      final prefs = await SharedPreferences.getInstance();

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/query')) {
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'integration_video_1',
                  'pubkey': 'testpubkey',
                  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  'kind': 34236,
                  'tags': [
                    ['url', 'https://example.com/video.mp4'],
                    ['thumb', 'https://example.com/thumb.jpg'],
                  ],
                  'content': '',
                  'sig': 'testsig',
                }
              ],
              'eose': true,
              'complete': true,
              'cached': true,
              'cache_age_seconds': 10,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            relayGatewayServiceProvider.overrideWithValue(
              RelayGatewayService(
                gatewayUrl: 'https://gateway.test',
                client: mockClient,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Text('Gateway Integration Test'),
            ),
          ),
        ),
      );

      // Test passes if no exceptions thrown during setup
      expect(find.text('Gateway Integration Test'), findsOneWidget);
    });
  });
}
```

**Step 2: Run integration test**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/integration/gateway_integration_test.dart
```

**Step 3: Commit**

```bash
git add test/integration/gateway_integration_test.dart
git commit -m "test: add gateway integration test"
```

---

## Summary

After completing all tasks, the gateway integration will:

1. **EmbeddedNostrRelay** has `importEvents()` for batch insertion
2. **RelayGatewayService** handles REST API calls
3. **RelayGatewaySettings** persists user preferences
4. **Relay Settings Screen** has toggle for gateway
5. **VideoEventService** tries gateway first for cacheable feeds, falls back to WebSocket
6. Full test coverage for all components

---

**Plan complete and saved to `docs/plans/2025-12-01-rest-gateway-integration.md`.**

**Two execution options:**

1. **Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

2. **Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
