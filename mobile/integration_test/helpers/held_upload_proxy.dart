// ABOUTME: Loopback HTTP proxy in front of a real Blossom server that holds
// ABOUTME: video uploads until the test releases them, one at a time.

import 'dart:async';
import 'dart:io';

import 'test_setup.dart';

/// A video upload the [HeldUploadProxy] is keeping from the server.
///
/// The request is accepted but its body is not read until [release], so to
/// the app the transfer is still in progress.
class HeldUpload {
  HeldUpload._(this.ordinal);

  /// Arrival order among video uploads: 0 for the first.
  final int ordinal;

  final _release = Completer<void>();
  final _answered = Completer<int>();

  /// Whether the test has let this upload through to the server.
  bool get isReleased => _release.isCompleted;

  /// Whether the server's response has been relayed back to the app.
  bool get isAnswered => _answered.isCompleted;

  /// Completes with the status the app received once the response is relayed.
  Future<int> get answered => _answered.future;

  /// Lets the upload through to the server.
  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}

/// Forwards every request to a real Blossom server unchanged, except that each
/// video upload (`PUT /upload` with a `video/*` body) waits for
/// [HeldUpload.release].
///
/// Thumbnails, blob lookups and everything else pass straight through, so the
/// only thing a test controls is when each video transfer reaches the server.
class HeldUploadProxy {
  HeldUploadProxy._(this._server, this._upstream);

  /// Binds a loopback port and forwards to [upstream].
  static Future<HeldUploadProxy> start({required Uri upstream}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = HeldUploadProxy._(server, upstream);
    server.listen((request) => unawaited(proxy._handle(request)));
    return proxy;
  }

  /// Headers that describe one hop rather than the request itself.
  static const Set<String> _hopHeaders = {
    HttpHeaders.hostHeader,
    HttpHeaders.connectionHeader,
    HttpHeaders.contentLengthHeader,
    HttpHeaders.transferEncodingHeader,
    HttpHeaders.expectHeader,
    'keep-alive',
  };

  final HttpServer _server;
  final Uri _upstream;

  // Raw pass-through: the app, not the proxy, decodes bodies and follows
  // redirects.
  final HttpClient _client = HttpClient()..autoUncompress = false;

  final List<HeldUpload> _uploads = [];
  final Map<int, Completer<HeldUpload>> _arrivals = {};
  var _closed = false;

  /// The base URL to configure as the app's Blossom server.
  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  /// Video uploads received so far, in arrival order.
  List<HeldUpload> get uploads => List.unmodifiable(_uploads);

  /// Completes when the video upload with [ordinal] (0-based) arrives.
  Future<HeldUpload> arrival(int ordinal) {
    if (ordinal < _uploads.length) return Future.value(_uploads[ordinal]);
    return (_arrivals[ordinal] ??= Completer<HeldUpload>()).future;
  }

  /// Stops accepting connections and fails every upload still held.
  ///
  /// Held uploads are answered 503 rather than forwarded: once the test is
  /// over, a transfer landing on the server during teardown only adds noise.
  Future<void> close() async {
    _closed = true;
    for (final upload in _uploads) {
      upload.release();
    }
    await _server.close(force: true);
    _client.close();
  }

  Future<void> _handle(HttpRequest request) async {
    HeldUpload? held;
    if (_isVideoUpload(request)) {
      held = HeldUpload._(_uploads.length);
      _uploads.add(held);
      logPhase('HeldUploadProxy: holding video upload #${held.ordinal}');
      if (_closed) held.release();
      _arrivals.remove(held.ordinal)?.complete(held);
      await held._release.future;
      logPhase('HeldUploadProxy: releasing video upload #${held.ordinal}');
    }

    if (_closed) {
      await _answer(request.response, HttpStatus.serviceUnavailable);
      held?._answered.complete(HttpStatus.serviceUnavailable);
      return;
    }

    final int status;
    try {
      status = await _forward(request);
    } on Object catch (error) {
      logPhase(
        'HeldUploadProxy: ${request.method} ${request.uri} failed: $error',
      );
      await _answer(request.response, HttpStatus.badGateway);
      held?._answered.complete(HttpStatus.badGateway);
      return;
    }
    if (held != null) {
      logPhase(
        'HeldUploadProxy: video upload #${held.ordinal} answered $status',
      );
      held._answered.complete(status);
    }
  }

  bool _isVideoUpload(HttpRequest request) =>
      request.method == 'PUT' &&
      request.uri.path == '/upload' &&
      request.headers.contentType?.primaryType == 'video';

  Future<int> _forward(HttpRequest request) async {
    final outgoing = await _client.openUrl(
      request.method,
      _upstream.replace(
        path: request.uri.path,
        query: request.uri.hasQuery ? request.uri.query : null,
      ),
    );
    outgoing.followRedirects = false;
    request.headers.forEach((name, values) {
      if (_hopHeaders.contains(name)) return;
      for (final value in values) {
        outgoing.headers.add(name, value);
      }
    });
    if (request.contentLength >= 0) {
      outgoing.contentLength = request.contentLength;
    }
    await outgoing.addStream(request);
    final incoming = await outgoing.close();

    final response = request.response..statusCode = incoming.statusCode;
    incoming.headers.forEach((name, values) {
      if (_hopHeaders.contains(name)) return;
      for (final value in values) {
        response.headers.add(name, value);
      }
    });
    if (incoming.contentLength >= 0) {
      response.contentLength = incoming.contentLength;
    }
    await response.addStream(incoming);
    await response.close();
    return incoming.statusCode;
  }

  Future<void> _answer(HttpResponse response, int status) async {
    try {
      response.statusCode = status;
      await response.close();
    } on Object catch (_) {
      // Headers were already sent or the connection is gone; either way the
      // app sees the transfer fail.
    }
  }
}
