// ABOUTME: Real-network acceptance test for the product analytics ingest API.
// ABOUTME: Pins each HTTP status the endpoint returns to the client's retry class.
//
// Runs against staging by default; point it at another host with
//   flutter test test/manual/analytics_ingest_staging_acceptance_test.dart \
//     --dart-define=ANALYTICS_INGEST_BASE_URL=https://api.divine.video
//
// Covers issue #7983: the queue dead-letters a batch on a permanent rejection
// and retries it on a transient failure, so a status the endpoint returns in
// the wrong class either loses events for good or retries them forever. Every
// case below sends a real request through `AnalyticsIngestClient` — the same
// URL building, NIP-98 signing contract and response classification the app
// uses — and asserts both the raw status the server returned and the class the
// client put it in.
//
// Each run signs with a fresh throwaway key and labels its rows with a
// `staging-smoke-<hex>` release, which is the marker staging smoke builds
// already use, so the stored rows are recognisable as test traffic.
//
// Not covered here: 429, 5xx and 408 cannot be provoked on demand from a
// client, so their classification stays pinned by the unit test in
// test/services/analytics_ingest_client_test.dart.

// Permanent: a manual real-network acceptance test that nulls
// HttpOverrides.global; VGV merged-isolate tests must keep flutter_test's HTTP
// mock intact.
@Tags(['skip_very_good_optimization', 'integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:uuid/uuid.dart';

const _baseUrl = String.fromEnvironment(
  'ANALYTICS_INGEST_BASE_URL',
  defaultValue: 'https://relay.staging.divine.video',
);

void main() {
  late final HttpOverrides? previousHttpOverrides;
  late String release;
  late _RecordingClient httpClient;
  late _ThrowawayKeyNip98AuthService nip98;
  late AnalyticsIngestClient client;
  final observations = <String>[];

  setUpAll(() {
    previousHttpOverrides = HttpOverrides.current;
    // flutter_test's binding stubs every HttpClient request to status 400 (to
    // catch accidental network use in unit tests). This is an intentional
    // real-network acceptance test, so opt out and let HttpClient do real I/O.
    HttpOverrides.global = null;
    release = 'staging-smoke-${_randomHex(32)}';
  });

  tearDownAll(() {
    HttpOverrides.global = previousHttpOverrides;
    stdout.writeln(
      'Ingest classification against $_baseUrl (release $release)',
    );
    observations.forEach(stdout.writeln);
  });

  setUp(() {
    httpClient = _RecordingClient(http.Client());
    nip98 = _ThrowawayKeyNip98AuthService(generatePrivateKey());
    client = AnalyticsIngestClient(
      httpClient: httpClient,
      nip98AuthService: nip98,
      apiBaseUrl: () => _baseUrl,
    );
  });

  tearDown(() => httpClient.close());

  /// Records the raw response and the client's class for the summary, and
  /// asserts the status the server actually returned.
  void observe(
    String label,
    AnalyticsIngestResult result, {
    required int expectedStatus,
  }) {
    final response = httpClient.responses.single;
    observations.add(
      '$label: HTTP ${response.statusCode} ${_boundedBody(response)} '
      '-> ${result.runtimeType}',
    );
    expect(
      response.statusCode,
      expectedStatus,
      reason: '$label returned ${_boundedBody(response)}',
    );
  }

  Map<String, Object?> impression() => _impression(release);

  group('signed endpoint', () {
    test('a valid batch is accepted with 200', () async {
      final result = await client.publishBatch(
        [impression()],
        subjectPubkey: nip98.pubkey,
      );

      observe('signed valid', result, expectedStatus: HttpStatus.ok);
      expect(result, isA<AnalyticsIngestAccepted>());
      expect(httpClient.responses.single.json, {
        'accepted': true,
        'stored': 1,
        'disabled': false,
      });
    });

    test('resending an accepted batch is accepted again, not 409', () async {
      final batch = [impression()];
      final first = await client.publishBatch(
        batch,
        subjectPubkey: nip98.pubkey,
      );
      expect(first, isA<AnalyticsIngestAccepted>());
      httpClient.responses.clear();

      final again = await client.publishBatch(
        batch,
        subjectPubkey: nip98.pubkey,
      );

      // Event IDs are content addresses, so a retry after a lost response
      // carries the same ID and the server stores it idempotently. There is
      // no duplicate status for the client to classify.
      observe('signed duplicate', again, expectedStatus: HttpStatus.ok);
      expect(again, isA<AnalyticsIngestAccepted>());
      expect(httpClient.responses.single.json['accepted'], isTrue);
    });

    test('a schema mismatch is rejected for good with 400', () async {
      final event = impression();
      (event['properties']! as Map<String, Object?>)['not_in_contract'] = 'x';

      final result = await client.publishBatch(
        [event],
        subjectPubkey: nip98.pubkey,
      );

      observe(
        'signed unknown field',
        result,
        expectedStatus: HttpStatus.badRequest,
      );
      expect(result, isA<AnalyticsIngestRejected>());
      expect(httpClient.responses.single.json['retryable'], isFalse);
    });

    test('a retry whose content no longer matches its ID is rejected for good '
        'with 400', () async {
      final event = impression();
      (event['properties']! as Map<String, Object?>)['position'] = 7;

      final result = await client.publishBatch(
        [event],
        subjectPubkey: nip98.pubkey,
      );

      observe(
        'signed event_id mismatch',
        result,
        expectedStatus: HttpStatus.badRequest,
      );
      expect(result, isA<AnalyticsIngestRejected>());
      expect(httpClient.responses.single.json['error'], 'event_id_mismatch');
    });

    test('a corrupted signature is rejected for good with 401', () async {
      nip98.tamper = _corruptSignature;

      final result = await client.publishBatch(
        [impression()],
        subjectPubkey: nip98.pubkey,
      );

      observe(
        'signed bad signature',
        result,
        expectedStatus: HttpStatus.unauthorized,
      );
      expect(result, isA<AnalyticsIngestRejected>());
      expect(httpClient.responses.single.json['retryable'], isFalse);
    });

    test(
      'a subject that is not the signer is rejected for good with 403',
      () async {
        final result = await client.publishBatch(
          [impression()],
          subjectPubkey: getPublicKey(generatePrivateKey()),
        );

        observe(
          'signed subject mismatch',
          result,
          expectedStatus: HttpStatus.forbidden,
        );
        expect(result, isA<AnalyticsIngestRejected>());
        expect(httpClient.responses.single.json['error'], 'subject_mismatch');
      },
    );
  });

  group('anonymous endpoint', () {
    test('a valid acquisition batch is accepted with 200', () async {
      final result = await client.publishAnonymousBatch([
        _landingViewed(release),
      ]);

      observe('anonymous valid', result, expectedStatus: HttpStatus.ok);
      expect(result, isA<AnalyticsIngestAccepted>());
      expect(httpClient.responses.single.json, {
        'accepted': true,
        'stored': 1,
        'disabled': false,
      });
    });

    test('resending an accepted batch is accepted again, not 409', () async {
      final batch = [_landingViewed(release)];
      final first = await client.publishAnonymousBatch(batch);
      expect(first, isA<AnalyticsIngestAccepted>());
      httpClient.responses.clear();

      final again = await client.publishAnonymousBatch(batch);

      observe('anonymous duplicate', again, expectedStatus: HttpStatus.ok);
      expect(again, isA<AnalyticsIngestAccepted>());
      expect(httpClient.responses.single.json['accepted'], isTrue);
    });

    test('a schema mismatch is rejected for good with 400', () async {
      final event = _landingViewed(release)..remove('session_id');

      final result = await client.publishAnonymousBatch([event]);

      observe(
        'anonymous invalid event',
        result,
        expectedStatus: HttpStatus.badRequest,
      );
      expect(result, isA<AnalyticsIngestRejected>());
      expect(httpClient.responses.single.json['retryable'], isFalse);
    });

    test(
      'account activity sent anonymously is rejected for good with 401',
      () async {
        final result = await client.publishAnonymousBatch([impression()]);

        observe(
          'anonymous account activity',
          result,
          expectedStatus: HttpStatus.unauthorized,
        );
        expect(result, isA<AnalyticsIngestRejected>());
        expect(
          httpClient.responses.single.json['error'],
          'authentication_required',
        );
      },
    );
  });
}

/// Signs NIP-98 tokens with a throwaway key so the request carries a real
/// signature without an `AuthService`.
class _ThrowawayKeyNip98AuthService extends Fake implements Nip98AuthService {
  _ThrowawayKeyNip98AuthService(this._privateKey)
    : pubkey = getPublicKey(_privateKey);

  final String _privateKey;
  final String pubkey;

  /// Rewrites each token after signing; set to corrupt what is sent.
  String Function(String token)? tamper;

  @override
  Future<Nip98Token?> createAuthToken({
    required String url,
    required HttpMethod method,
    String? payload,
    bool reuseCached = true,
  }) async {
    final now = DateTime.now();
    final createdAt = now.millisecondsSinceEpoch ~/ 1000;
    final event = Event(
      pubkey,
      27235,
      [
        ['u', url],
        ['method', method.value],
        ['created_at', '$createdAt'],
        ['payload', sha256.convert(utf8.encode(payload ?? '')).toString()],
      ],
      '',
      createdAt: createdAt,
    )..sign(_privateKey);
    final token = base64Encode(utf8.encode(jsonEncode(event.toJson())));
    return Nip98Token(
      token: tamper?.call(token) ?? token,
      signedEvent: event,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 45)),
    );
  }
}

/// Buffers every response so a test can assert on the raw status and body
/// the server returned, next to the class the client derived from it.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._inner);

  final http.Client _inner;
  final responses = <http.Response>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await http.Response.fromStream(await _inner.send(request));
    responses.add(response);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }

  @override
  void close() => _inner.close();
}

extension on http.Response {
  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

Map<String, Object?> _impression(String release) => _withContentAddress(
  ProductAnalyticsV2ContentImpressionRecordedEvent(
    envelope: _envelope(release),
    properties: ProductAnalyticsV2ContentImpressionRecordedProperties(
      contentId: _randomHex(64),
      surface: ProductAnalyticsV2Surface.feed,
      position: 1,
      visibleMs: 1500,
    ),
  ),
);

Map<String, Object?> _landingViewed(String release) => _withContentAddress(
  ProductAnalyticsV2LandingViewedEvent(
    envelope: _envelope(release),
    properties: const ProductAnalyticsV2LandingViewedProperties(
      landingPage: ProductAnalyticsV2LandingPage.home,
      referrerClass: ProductAnalyticsV2ReferrerClass.direct,
    ),
  ),
);

ProductAnalyticsV2Envelope _envelope(String release) =>
    ProductAnalyticsV2Envelope(
      eventId: '',
      schemaVersion: productAnalyticsV2SchemaVersion,
      occurredAt: DateTime.now().toUtc(),
      anonymousId: const Uuid().v4(),
      sessionId: const Uuid().v4(),
      source: ProductAnalyticsV2Source.mobile,
      platform: ProductAnalyticsV2Platform.android,
      release: release,
      consentCategory: ProductAnalyticsV2ConsentCategory.productAnalytics,
    );

/// Stamps the event with the ID the app computes, so the server's RFC 8785
/// recomputation is checked against the client's implementation too.
Map<String, Object?> _withContentAddress(ProductAnalyticsV2Event event) {
  final json = event.toJson();
  return {
    ...json,
    'event_id': AnalyticsService.computeProductAnalyticsEventId(json),
  };
}

String _randomHex(int length) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
}

/// Flips one hex character of the Schnorr signature so verification fails
/// while the event is otherwise well-formed.
String _corruptSignature(String token) {
  final event = jsonDecode(utf8.decode(base64Decode(token))) as Map;
  final sig = event['sig'] as String;
  final last = sig[sig.length - 1] == 'a' ? 'b' : 'a';
  event['sig'] = '${sig.substring(0, sig.length - 1)}$last';
  return base64Encode(utf8.encode(jsonEncode(event)));
}

String _boundedBody(http.Response response) {
  final body = response.body.replaceAll('\n', ' ');
  return body.length <= 120 ? body : '${body.substring(0, 120)}…';
}
