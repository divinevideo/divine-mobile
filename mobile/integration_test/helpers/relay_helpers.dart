// ABOUTME: Relay helpers for E2E integration tests
// ABOUTME: Publish test Nostr events directly to the local FunnelCake relay

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'constants.dart';

/// Result of publishing a test video event.
typedef PublishedVideo = ({String eventId, String pubkey, String privateKey});

/// Result of publishing a test profile event.
typedef PublishedProfile = ({String pubkey, String privateKey});

/// Publish a kind 34236 video event to the local relay.
///
/// Creates a new keypair (or uses [privateKey] if provided), builds a minimal
/// video event with [title], signs it, and sends it via WebSocket.
///
/// Returns the event ID, author pubkey, and private key so callers can
/// follow the author or publish more events from the same identity.
///
/// Throws if the relay rejects the event or connection fails.
Future<PublishedVideo> publishTestVideoEvent({
  required String title,
  String? privateKey,
}) async {
  final privKey = privateKey ?? generatePrivateKey();
  final pubKey = getPublicKey(privKey);
  final dTag = 'e2e-${DateTime.now().millisecondsSinceEpoch}';

  // Upload real blobs to blossom so the app can fetch valid URLs
  final blossomBase = 'http://$localHost:$localBlossomPort';
  final blobs = await _ensureTestBlobs();

  final event = Event(
    pubKey,
    34236,
    [
      ['d', dTag],
      ['title', title],
      [
        'imeta',
        'url $blossomBase/${blobs.videoHash}',
        'm video/mp4',
        'image $blossomBase/${blobs.thumbHash}',
        'x ${blobs.videoHash}',
      ],
      ['duration', '6'],
      ['alt', 'E2E test video: $title'],
      ['client', 'diVine-e2e'],
    ],
    '',
  );
  event.sign(privKey);

  final eventId = await _publishEvent(event);
  debugPrint('Published test video event: $eventId (author: $pubKey)');
  return (eventId: eventId, pubkey: pubKey, privateKey: privKey);
}

/// Publish a kind 0 profile event to the local relay.
///
/// Creates a new keypair (or uses [privateKey] if provided), builds a
/// profile metadata event, signs it, and sends it via WebSocket.
///
/// Returns the pubkey and private key so callers can reuse the identity.
///
/// Throws if the relay rejects the event or connection fails.
Future<PublishedProfile> publishTestProfileEvent({
  required String name,
  String? displayName,
  String? about,
  String? privateKey,
}) async {
  final privKey = privateKey ?? generatePrivateKey();
  final pubKey = getPublicKey(privKey);

  final content = jsonEncode({
    'name': name,
    'display_name': displayName ?? name,
    'about': ?about,
  });

  final event = Event(pubKey, 0, [], content);
  event.sign(privKey);

  final eventId = await _publishEvent(event);
  debugPrint('Published test profile event: $eventId (pubkey: $pubKey)');
  return (pubkey: pubKey, privateKey: privKey);
}

/// Build a kind 24242 Nostr auth header for blossom uploads.
String _buildUploadAuth(String privateKey) {
  final pubKey = getPublicKey(privateKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expiration = now + 300;

  final event = Event(
    pubKey,
    24242,
    [
      ['t', 'upload'],
      ['expiration', '$expiration'],
    ],
    '',
    createdAt: now,
  );
  event.sign(privateKey);

  final eventJson = jsonEncode(event.toJson());
  return 'Nostr ${base64Encode(utf8.encode(eventJson))}';
}

/// Upload a small test blob to the local blossom server.
///
/// Returns the sha256 hash of the uploaded file. Blossom serves the file
/// at `http://{host}:{port}/{sha256}`.
///
/// Sends a kind 24242 Nostr auth header as required by divine-blossom.
Future<String> _uploadTestBlob({
  required Uint8List data,
  String contentType = 'video/mp4',
}) async {
  final client = HttpClient();
  try {
    final privKey = _uploadPrivateKey ??= generatePrivateKey();
    final auth = _buildUploadAuth(privKey);

    final uri = Uri.parse('http://$localHost:$localBlossomPort/upload');
    final request = await client.openUrl('PUT', uri);
    request.headers.set('Content-Type', contentType);
    request.headers.set('Authorization', auth);
    request.contentLength = data.length;
    request.add(data);
    final response = await request.close().timeout(
      const Duration(seconds: 10),
    );
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw HttpException(
        'Blossom upload failed (${response.statusCode}): $body',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['sha256'] as String;
  } finally {
    client.close();
  }
}

/// Reusable private key for test uploads (generated once per test run).
String? _uploadPrivateKey;

/// Cached sha256 hashes for test blobs so we only upload once per test run.
String? _cachedVideoHash;
String? _cachedThumbHash;

/// Get or create a test video blob on the local blossom server.
///
/// Uploads a minimal MP4-like blob on first call, then reuses the hash.
Future<({String videoHash, String thumbHash})> _ensureTestBlobs() async {
  if (_cachedVideoHash != null && _cachedThumbHash != null) {
    return (videoHash: _cachedVideoHash!, thumbHash: _cachedThumbHash!);
  }

  // Minimal MP4-like blob for video (not playable but unique per run)
  final videoData = Uint8List.fromList(
    utf8.encode('e2e-test-video-${DateTime.now().millisecondsSinceEpoch}'),
  );
  // Generate a real PNG thumbnail so the app can decode it
  final thumbData = await _generateTestThumbnail();

  _cachedVideoHash = await _uploadTestBlob(data: videoData);
  _cachedThumbHash = await _uploadTestBlob(
    data: thumbData,
    contentType: 'image/png',
  );

  debugPrint(
    'Uploaded test blobs: video=$_cachedVideoHash, '
    'thumb=$_cachedThumbHash',
  );
  return (videoHash: _cachedVideoHash!, thumbHash: _cachedThumbHash!);
}

/// Generate a real 360x640 PNG thumbnail with a colored gradient.
///
/// Uses dart:ui Canvas to paint a valid image that Flutter can decode,
/// avoiding "Invalid image data" errors in the app's thumbnail loader.
Future<Uint8List> _generateTestThumbnail() async {
  const width = 360;
  const height = 640;
  const rect = Rect.fromLTWH(0, 0, 360, 640);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, rect);

  // Dark gradient background (matches app aesthetic)
  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
    ).createShader(rect);
  canvas.drawRect(rect, bgPaint);

  // Accent circle
  final circlePaint = Paint()..color = const Color(0xFF0f3460);
  canvas.drawCircle(
    const Offset(width / 2, height / 2),
    80,
    circlePaint,
  );

  // Encode to PNG
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  return byteData!.buffer.asUint8List();
}

/// Query the local relay for events matching [filter].
///
/// Opens a WebSocket, sends a REQ, collects EVENT messages until EOSE,
/// then closes the connection. Returns all matching events.
Future<List<Event>> queryRelay(Map<String, dynamic> filter) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$localHost:$localRelayPort'),
  );

  final subId = 'query-${DateTime.now().millisecondsSinceEpoch}';
  final events = <Event>[];
  final completer = Completer<List<Event>>();

  final subscription = channel.stream.listen((message) {
    final decoded = jsonDecode(message as String) as List<dynamic>;
    if (decoded[0] == 'EVENT' && decoded[1] == subId) {
      events.add(Event.fromJson(decoded[2] as Map<String, dynamic>));
    } else if (decoded[0] == 'EOSE' && decoded[1] == subId) {
      completer.complete(events);
    }
  });

  channel.sink.add(jsonEncode(['REQ', subId, filter]));

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    channel.sink.add(jsonEncode(['CLOSE', subId]));
    await subscription.cancel();
    await channel.sink.close();
  }
}

/// Publish a NIP-09 kind 5 deletion event targeting [eventId].
///
/// Signs with [privateKey] (must be the same author as the target event).
/// Returns the deletion event ID.
///
/// Throws if the relay rejects the event or connection fails.
Future<String> publishDeleteEvent({
  required String eventId,
  required int kind,
  required String privateKey,
}) async {
  final pubKey = getPublicKey(privateKey);

  final deleteEvent = Event(pubKey, 5, [
    ['e', eventId],
    ['k', kind.toString()],
  ], '');
  deleteEvent.sign(privateKey);

  final deletionId = await _publishEvent(deleteEvent);
  debugPrint('Published delete event: $deletionId (target: $eventId)');
  return deletionId;
}

/// Send an event to the local relay and wait for OK confirmation.
Future<String> _publishEvent(Event event) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$localHost:$localRelayPort'),
  );

  final completer = Completer<String>();
  final subscription = channel.stream.listen((message) {
    final decoded = jsonDecode(message as String) as List<dynamic>;
    if (decoded[0] == 'OK' && decoded[1] == event.id) {
      if (decoded[2] == true) {
        completer.complete(event.id);
      } else {
        completer.completeError(
          Exception('Relay rejected event: ${decoded[3]}'),
        );
      }
    }
  });

  channel.sink.add(jsonEncode(['EVENT', event.toJson()]));

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    await subscription.cancel();
    await channel.sink.close();
  }
}
