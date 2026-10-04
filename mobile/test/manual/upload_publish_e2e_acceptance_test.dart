// ABOUTME: Full upload + publish E2E pipeline acceptance test against the local
// ABOUTME: stack — Blossom upload -> kind-34236 publish -> relay/REST query.
//
// Requires the local Docker stack (relay 47777, blossom 43003).
// Run:         flutter test test/manual/upload_publish_e2e_acceptance_test.dart
// Start stack: mise run local_up (from repo root)
//
// Covers issue #3056 (and subsumes #3053's Blossom-upload-E2E intent): a real
// video blob + thumbnail are uploaded to Blossom (kind-24242 auth), referenced
// by their content-addressed URLs in a kind-34236 event, published to the
// funnelcake relay, and then read back on both the relay WebSocket and the REST
// API. Also asserts per-stage failure surfaces a clear error.
//
// Deliberately OUT OF LOCAL SCOPE for this local-stack manual test:
//   - Real GPU transcode quality — local blossom (Viceroy) has no transcoder;
//     the .hls path is a byte-copy stub of the production readiness state
//     machine, exercised here only as a readiness probe.
//   - Latency/throughput SLOs — no SLO budget is defined and local infra is not
//     representative; timings are logged on failure for triage only, not asserted.
//   - Orphan-blob GC — the app does not delete an uploaded blob when publish
//     fails; that gap is documented, not asserted (it would assert behaviour the
//     app does not implement).
//
// This is a client-perspective raw-protocol acceptance test (the client signs
// and publishes the event — no server publishes kind-34236 in the first-party
// flow). It speaks raw HTTP + raw WS, matching the sibling tests
// nip98_relay_acceptance_test.dart (#3052) and the #3054 relay test, and uses
// the single legacy `PUT /upload` (the resumable `/upload/init` path forwards to
// the production data host and is not reachable locally).

// Permanent: a manual, Docker-dependent real-network acceptance test that nulls
// the global HttpOverrides in setUpAll. It must stay out of the VGV merged
// optimizer isolate — otherwise setUpAll runs even when the stack is absent and
// leaks the un-stubbed HttpOverrides into every later merged test (real sockets,
// order-dependent "pending timers" flakes). Matches nip98_relay_acceptance_test.
@Tags(['skip_very_good_optimization', 'integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/observe_until.dart';

const _localHost = 'localhost';
const _relayPort = 47777;
const _blossomPort = 43003;
const _relayBase = 'http://$_localHost:$_relayPort';
const _relayWs = 'ws://$_localHost:$_relayPort';
const _blossomBase = 'http://$_localHost:$_blossomPort';

// The relay acknowledges OK on receipt but indexes events to ClickHouse
// asynchronously, so a stored-events query becomes consistent a short time after
// publish. Poll within a bounded window rather than sleeping a fixed amount.
const _consistencyTimeout = Duration(seconds: 20);
const _pollInterval = Duration(milliseconds: 400);
const _frameTimeout = Duration(seconds: 10);

const _stackUnavailableMessage =
    'Local stack is not running. Start with `mise run local_up`, then rerun '
    '`flutter test test/manual/upload_publish_e2e_acceptance_test.dart`.';

const _videoFixturePath = 'assets/videos/default_intro.mp4';
const _thumbnailFixturePath = 'test/fixtures/test_thumbnail.jpg';

final _rng = Random();

void main() {
  late bool stackAvailable;

  setUpAll(() async {
    // flutter_test's binding installs an HttpOverrides that stubs every
    // HttpClient request to status 400 (to catch accidental network use in unit
    // tests). This is an intentional real-network acceptance test, so opt out
    // and let HttpClient perform real I/O against the local stack. (Raw Socket /
    // WebSocket are not affected by the override.)
    HttpOverrides.global = null;

    final relayUp = await _isPortOpen(_localHost, _relayPort);
    final blossomUp = await _isPortOpen(_localHost, _blossomPort);
    stackAvailable = relayUp && blossomUp;
  });

  group('full pipeline (upload -> publish -> query)', () {
    test(
      'uploads a real video + thumbnail, publishes a kind-34236 referencing '
      'them, and the event is queryable on the relay WS and REST API',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubKey = getPublicKey(privKey);
        final unique = DateTime.now().microsecondsSinceEpoch;
        final dTag = 'e2e-$unique';
        final tTag = 'vine-e2e-$unique';

        final sw = Stopwatch()..start();

        // 1. Upload a real video blob (kind-24242 auth, legacy PUT).
        final videoBytes = _readFixtureBytes(_videoFixturePath);
        final (videoStatus, videoBody) = await _putBlob(
          bytes: videoBytes,
          contentType: 'video/mp4',
          authHeader: _blossomAuthHeader(privKey),
        );
        final uploadMs = sw.elapsedMilliseconds;
        expect(
          videoStatus,
          equals(HttpStatus.ok),
          reason: 'Authenticated video upload must succeed.',
        );
        final videoSha = videoBody?['sha256'] as String?;
        expect(videoSha, isNotNull, reason: 'Upload must return a sha256.');
        expect(
          videoSha,
          equals(sha256.convert(videoBytes).toString()),
          reason:
              'Server sha256 must equal the client-computed hash '
              '(content-addressed storage).',
        );

        // 2. Upload a real thumbnail blob (the relay requires a thumbnail).
        final thumbBytes = _readFixtureBytes(_thumbnailFixturePath);
        final (thumbStatus, thumbBody) = await _putBlob(
          bytes: thumbBytes,
          contentType: 'image/jpeg',
          authHeader: _blossomAuthHeader(privKey),
        );
        expect(thumbStatus, equals(HttpStatus.ok));
        final thumbSha = thumbBody?['sha256'] as String?;
        expect(thumbSha, isNotNull);

        // 3. Read the video blob back and verify content-addressing end to end.
        final (getStatus, gotBytes) = await _getBlob(videoSha!);
        expect(getStatus, equals(HttpStatus.ok));
        expect(gotBytes.length, equals(videoBytes.length));
        expect(sha256.convert(gotBytes).toString(), equals(videoSha));

        // Build the public URLs from the sha256 — the upload descriptor's own
        // `url` reflects the request Host and is not host-reachable.
        final videoUrl = '$_blossomBase/$videoSha';
        final thumbUrl = '$_blossomBase/$thumbSha';

        // 4. Publish the kind-34236 referencing the real blobs.
        final event = _buildVideoEvent(
          privKey: privKey,
          dTag: dTag,
          title: 'diVine E2E acceptance',
          videoUrl: videoUrl,
          videoSha: videoSha,
          thumbUrl: thumbUrl,
          tTag: tTag,
        );
        final eventJson = event.toJson();
        final eventId = eventJson['id'] as String;
        final (accepted, reason) = await _publishEvent(event);
        final publishMs = sw.elapsedMilliseconds;
        expect(
          accepted,
          isTrue,
          reason:
              'Relay must accept the well-formed kind-34236 '
              '(rejection reason: "$reason").',
        );

        // 5. Read-after-write on the relay WebSocket.
        final relayEvents = await _queryRelayUntil(
          {
            'kinds': [34236],
            'authors': [pubKey],
          },
          (events) => events.any((e) => e['id'] == eventId),
        );
        expect(
          relayEvents.any((e) => e['id'] == eventId),
          isTrue,
          reason:
              'Published event must be queryable on the relay WS within '
              'the consistency window.',
        );

        // 6. Read-after-write on the REST API — scoped per-user (deterministic
        // for a fresh author) and on the global feed.
        final userVideos = await _getVideosUntil(
          '/api/users/$pubKey/videos',
          (list) => list.any((v) => v is Map && v['d_tag'] == dTag),
        );
        final ours = userVideos.whereType<Map<String, dynamic>>().firstWhere(
          (v) => v['d_tag'] == dTag,
          orElse: () => <String, dynamic>{},
        );
        expect(
          ours['d_tag'],
          equals(dTag),
          reason: 'Published video must appear on /api/users/<pubkey>/videos.',
        );
        expect(
          ours['video_url'],
          equals(videoUrl),
          reason: 'REST video_url must equal the uploaded blob URL.',
        );
        expect(ours['thumbnail'], equals(thumbUrl));

        final globalVideos = await _getVideosUntil(
          '/api/videos',
          (list) => list.any((v) => v is Map && v['id'] == eventId),
        );
        expect(
          globalVideos.any((v) => v is Map && v['id'] == eventId),
          isTrue,
          reason: 'Published video must appear on /api/videos.',
        );

        // SLO is out of scope (no budget; local infra unrepresentative); surface
        // stage timings only when the test fails, to aid triage.
        printOnFailure(
          'stage timings: upload=${uploadMs}ms publish_total=${publishMs}ms',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('transcode/store readiness (synthetic local stub)', () {
    test(
      'a freshly uploaded video exposes an HLS readiness manifest '
      '(202 processing, then 200)',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        // NOTE: local blossom (Viceroy) has no real transcoder. The .hls path is
        // a byte-copy stub of the production readiness state machine — this
        // asserts the readiness contract (poll-until-200), not transcode quality.
        final privKey = generatePrivateKey();
        final videoBytes = _readFixtureBytes(_videoFixturePath);
        final (status, body) = await _putBlob(
          bytes: videoBytes,
          contentType: 'video/mp4',
          authHeader: _blossomAuthHeader(privKey),
        );
        expect(status, equals(HttpStatus.ok));
        final sha = body?['sha256'] as String?;
        expect(sha, isNotNull);

        final first = await _getHlsStatus(sha!);
        expect(
          first,
          anyOf(equals(HttpStatus.accepted), equals(HttpStatus.ok)),
          reason:
              'First .hls GET should report processing (202) or ready (200).',
        );

        // No Retry-After header is sent — poll on a fixed small interval.
        expect(
          await _pollHlsReady(sha),
          isTrue,
          reason:
              'HLS master manifest must become available (200) within the '
              'consistency window.',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('per-stage failure surfaces a clear error', () {
    test('unauthenticated upload is rejected with 401', () async {
      if (_skipIfStackUnavailable(stackAvailable)) return;

      final (status, _) = await _putBlob(
        bytes: _randomBytes(1024),
        contentType: 'video/mp4',
      );
      expect(status, equals(HttpStatus.unauthorized));
    });

    // A wrong Content-Length is intentionally NOT asserted: it does not surface
    // a clean 400 through a normal HTTP client (over-declaring stalls the
    // connection until timeout; under-declaring is accepted as a smaller blob).

    test(
      'kind-34236 missing a thumbnail is rejected with a clear reason',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        // Placeholder URLs are fine — the relay validates structure, not blob
        // reachability.
        final event = _buildVideoEvent(
          privKey: generatePrivateKey(),
          dTag: 'e2e-nothumb-${DateTime.now().microsecondsSinceEpoch}',
          title: 'missing thumbnail',
          videoUrl: 'https://example.invalid/video.mp4',
          videoSha: 'a' * 64,
        );
        final (accepted, reason) = await _publishEvent(event);
        expect(accepted, isFalse);
        expect(reason, contains('thumbnail'), reason: 'reason was: "$reason"');
      },
    );

    test(
      "kind-34236 missing the 'd' tag is rejected with a clear reason",
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final event = _buildVideoEvent(
          privKey: generatePrivateKey(),
          dTag: 'unused',
          title: 'missing d tag',
          videoUrl: 'https://example.invalid/video.mp4',
          videoSha: 'a' * 64,
          thumbUrl: 'https://example.invalid/thumb.jpg',
          includeDTag: false,
        );
        final (accepted, reason) = await _publishEvent(event);
        expect(accepted, isFalse);
        expect(reason, contains("'d' tag"), reason: 'reason was: "$reason"');
      },
    );

    test(
      "kind-34236 missing the 'title' tag is rejected with a clear reason",
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final event = _buildVideoEvent(
          privKey: generatePrivateKey(),
          dTag: 'e2e-notitle-${DateTime.now().microsecondsSinceEpoch}',
          title: 'unused',
          videoUrl: 'https://example.invalid/video.mp4',
          videoSha: 'a' * 64,
          thumbUrl: 'https://example.invalid/thumb.jpg',
          includeTitle: false,
        );
        final (accepted, reason) = await _publishEvent(event);
        expect(accepted, isFalse);
        expect(
          reason,
          contains("'title' tag"),
          reason: 'reason was: "$reason"',
        );
      },
    );
  });
}

bool _skipIfStackUnavailable(bool stackAvailable) {
  if (stackAvailable) return false;
  markTestSkipped(_stackUnavailableMessage);
  return true;
}

// ---------------------------------------------------------------------------
// Nostr signing helpers
// ---------------------------------------------------------------------------

/// Builds a `Nostr <base64>` Blossom (kind-24242) upload authorization header.
String _blossomAuthHeader(String privateKey) {
  final pubKey = getPublicKey(privateKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final tags = <List<String>>[
    ['t', 'upload'],
    ['expiration', '${now + 300}'],
  ];
  final event = Event(pubKey, 24242, tags, '', createdAt: now);
  event.sign(privateKey);
  final token = base64Encode(utf8.encode(jsonEncode(event.toJson())));
  return 'Nostr $token';
}

/// Builds and signs a kind-34236 addressable video event referencing the
/// uploaded blob(s). Set [includeDTag]/[includeTitle] false or [thumbUrl] null
/// to produce the malformed variants the relay must reject.
Event _buildVideoEvent({
  required String privKey,
  required String dTag,
  required String title,
  required String videoUrl,
  required String videoSha,
  String? thumbUrl,
  String? tTag,
  bool includeDTag = true,
  bool includeTitle = true,
}) {
  final pubKey = getPublicKey(privKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final imeta = <String>[
    'imeta',
    'url $videoUrl',
    'm video/mp4',
    if (thumbUrl != null) 'image $thumbUrl',
    'x $videoSha',
    'dim 720x1280',
  ];

  final tags = <List<String>>[
    if (includeDTag) ['d', dTag],
    if (includeTitle) ['title', title],
    imeta,
    ['duration', '6'],
    if (tTag != null) ['t', tTag],
    ['published_at', '$now'],
    ['alt', 'diVine E2E acceptance video'],
    ['client', 'diVine-e2e-acceptance'],
  ];

  final event = Event(pubKey, 34236, tags, '', createdAt: now);
  event.sign(privKey);
  return event;
}

// ---------------------------------------------------------------------------
// Blossom (HTTP) helpers
// ---------------------------------------------------------------------------

Future<(int, Map<String, dynamic>?)> _putBlob({
  required Uint8List bytes,
  required String contentType,
  String? authHeader,
}) async {
  final client = HttpClient();
  try {
    final request = await client.putUrl(Uri.parse('$_blossomBase/upload'));
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    if (authHeader != null) {
      request.headers.set(HttpHeaders.authorizationHeader, authHeader);
    }
    request.add(bytes);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    Map<String, dynamic>? json;
    if (body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    return (response.statusCode, json);
  } finally {
    client.close();
  }
}

Future<(int, Uint8List)> _getBlob(String sha256Hex) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_blossomBase/$sha256Hex'));
    final response = await request.close();
    final builder = BytesBuilder();
    await response.forEach(builder.add);
    return (response.statusCode, builder.toBytes());
  } finally {
    client.close();
  }
}

Future<int> _getHlsStatus(String sha256Hex) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('$_blossomBase/$sha256Hex.hls'),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close();
  }
}

Future<bool> _pollHlsReady(String sha256Hex) async {
  return observeUntil<bool>(
    probe: () async => await _getHlsStatus(sha256Hex) == HttpStatus.ok,
    ready: (value) => value,
    initialValue: false,
    interval: _pollInterval,
    timeout: _consistencyTimeout,
  );
}

// ---------------------------------------------------------------------------
// REST query helpers
// ---------------------------------------------------------------------------

Future<(int, dynamic)> _getJson(String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_relayBase$path'));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    dynamic json;
    if (body.isNotEmpty) {
      json = jsonDecode(body);
    }
    return (response.statusCode, json);
  } finally {
    client.close();
  }
}

/// Polls [path] until [found] is satisfied by the returned list or the
/// consistency window elapses. Returns the last list seen.
Future<List<dynamic>> _getVideosUntil(
  String path,
  bool Function(List<dynamic>) found,
) async {
  var lastList = const <dynamic>[];
  return observeUntil<List<dynamic>>(
    probe: () async {
      final (status, json) = await _getJson(path);
      if (status == HttpStatus.ok && json is List) lastList = json;
      return lastList;
    },
    ready: found,
    initialValue: lastList,
    interval: _pollInterval,
    timeout: _consistencyTimeout,
  );
}

// ---------------------------------------------------------------------------
// Relay WebSocket helpers
// ---------------------------------------------------------------------------

/// Publishes [event] and returns the relay's NIP-20 OK decision and message.
Future<(bool, String)> _publishEvent(Event event) async {
  final json = event.toJson();
  final eventId = json['id'] as String;
  final channel = WebSocketChannel.connect(Uri.parse(_relayWs));
  await channel.ready;
  final completer = Completer<(bool, String)>();
  final subscription = channel.stream.listen(
    (raw) {
      final frame = _decodeFrame(raw);
      if (frame == null || frame.isEmpty) return;
      if (frame[0] == 'OK' && frame[1] == eventId && !completer.isCompleted) {
        final ok = frame[2] as bool;
        final message = frame.length > 3 ? frame[3] as String : '';
        completer.complete((ok, message));
      }
    },
    onError: (Object error) {
      if (!completer.isCompleted) completer.completeError(error);
    },
  );
  channel.sink.add(jsonEncode(['EVENT', json]));
  try {
    return await completer.future.timeout(_frameTimeout);
  } on TimeoutException {
    return (false, 'no OK frame received within ${_frameTimeout.inSeconds}s');
  } finally {
    await subscription.cancel();
    await channel.sink.close();
  }
}

/// Polls a stored-events REQ until [found] is satisfied or the window elapses.
Future<List<Map<String, dynamic>>> _queryRelayUntil(
  Map<String, dynamic> filter,
  bool Function(List<Map<String, dynamic>>) found,
) async {
  return observeUntil<List<Map<String, dynamic>>>(
    probe: () => _queryRelayOnce(filter),
    ready: found,
    initialValue: const [],
    interval: _pollInterval,
    timeout: _consistencyTimeout,
  );
}

/// Sends a single REQ, collects EVENTs until EOSE (or timeout), then CLOSEs.
Future<List<Map<String, dynamic>>> _queryRelayOnce(
  Map<String, dynamic> filter,
) async {
  const subId = 'e2e-sub';
  final events = <Map<String, dynamic>>[];
  final channel = WebSocketChannel.connect(Uri.parse(_relayWs));
  await channel.ready;
  final done = Completer<void>();
  final subscription = channel.stream.listen(
    (raw) {
      final frame = _decodeFrame(raw);
      if (frame == null || frame.length < 2 || frame[1] != subId) return;
      if (frame[0] == 'EVENT' && frame.length >= 3) {
        events.add(frame[2] as Map<String, dynamic>);
      } else if (frame[0] == 'EOSE' && !done.isCompleted) {
        done.complete();
      }
    },
    onError: (Object error) {
      if (!done.isCompleted) done.completeError(error);
    },
  );
  channel.sink.add(jsonEncode(['REQ', subId, filter]));
  try {
    await done.future.timeout(_frameTimeout);
  } on TimeoutException {
    // Return whatever arrived before the timeout.
  } finally {
    try {
      channel.sink.add(jsonEncode(['CLOSE', subId]));
    } catch (_) {
      // Channel may already be closing.
    }
    await subscription.cancel();
    await channel.sink.close();
  }
  return events;
}

List<dynamic>? _decodeFrame(dynamic raw) {
  if (raw is! String) return null;
  final decoded = jsonDecode(raw);
  return decoded is List ? decoded : null;
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

Uint8List _randomBytes(int length) =>
    Uint8List.fromList(List<int>.generate(length, (_) => _rng.nextInt(256)));

/// Reads fixture files from either `mobile/` or the repository root.
Uint8List _readFixtureBytes(String path) {
  final mobileRelative = File(path);
  if (mobileRelative.existsSync()) return mobileRelative.readAsBytesSync();
  return File('mobile/$path').readAsBytesSync();
}

/// Returns `true` when [host]:[port] accepts a TCP connection within 2 s.
Future<bool> _isPortOpen(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
