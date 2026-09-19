import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:unified_logger/unified_logger.dart';

/// Result of a cancellable HTTP download.
class CancellableDownloadResult {
  /// Creates a download result.
  const CancellableDownloadResult({
    required this.file,
    this.statusCode,
    this.headers = const {},
  });

  /// The completed file, or `null` when the download failed or was cancelled.
  final File? file;

  /// HTTP response status when headers were received.
  final int? statusCode;

  /// HTTP response headers, lower-cased by `package:http`.
  final Map<String, String> headers;
}

/// Handle to an in-progress HTTP download writing to a single target file.
///
/// Cancelling tears down the underlying HTTP socket immediately and removes
/// any partial bytes written so far.
abstract class CancellableDownload {
  /// Resolves to the downloaded file when complete, or `null` on failure
  /// or cancellation.
  Future<File?> get file async => (await result).file;

  /// Resolves to the completed download result.
  Future<CancellableDownloadResult> get result;

  /// Cumulative response-body bytes received while the download is active.
  Stream<int> get progressBytes;

  /// Whether this download has been cancelled.
  bool get isCancelled;

  /// Tears down the underlying HTTP connection and removes the partial file.
  void cancel();
}

/// Strategy for performing cancellable file downloads.
///
/// Default implementation uses an [http.Client]. Tests inject a fake to
/// drive completion deterministically.
abstract class CancellableDownloader {
  /// Starts a cancellable download of [url] into [targetFile].
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  });

  /// Cancels every in-flight download without releasing the downloader.
  ///
  /// Unlike [close], the downloader stays usable afterwards — new [download]
  /// calls still work. Used to tear down in-flight requests when the app is
  /// backgrounded: on Apple platforms the native NSURLSession stack
  /// (`cupertino_http`) delivers delegate callbacks through a Dart FFI
  /// trampoline that aborts the process if the isolate is suspended while a
  /// request is still in flight.
  void cancelActiveDownloads();

  /// Releases any resources owned by this downloader.
  Future<void> close();
}

/// Default [CancellableDownloader] backed by an [http.Client].
///
/// Once the response stream has started, cancelling unsubscribes from it,
/// which `dart:io` interprets as a signal to release the underlying socket
/// back to the pool. This sidesteps the connection-pool starvation problem
/// that occurs when stalled `flutter_cache_manager` downloads cannot be torn
/// down and continue to occupy `maxConnectionsPerHost` slots until their
/// `connectionTimeout` (often >> our stall window) trips.
///
/// Note: if `cancel()` is called while the initial request is still in
/// flight (before headers arrive), the socket cannot be interrupted and
/// remains in use until the response headers are received.
class HttpCancellableDownloader implements CancellableDownloader {
  /// Creates a downloader that issues requests on the given [http.Client].
  HttpCancellableDownloader(this._client);

  final http.Client _client;
  final Set<_HttpDownload> _activeDownloads = {};
  bool _isClosed = false;

  @override
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  }) {
    if (_isClosed) return _CompletedDownload(null);

    final dl = _HttpDownload(
      _client,
      url,
      targetFile,
      headers,
      onComplete: _activeDownloads.remove,
    );
    _activeDownloads.add(dl);
    unawaited(dl._start());
    return dl;
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    final activeDownloads = _activeDownloads.toList(growable: false);
    for (final download in activeDownloads) {
      download.cancel();
    }
    await Future.wait<File?>(activeDownloads.map((download) => download.file));
    _client.close();
  }

  @override
  void cancelActiveDownloads() {
    if (_isClosed) return;
    // Copy first: cancel() settles each download and removes it from the set
    // via its onComplete callback, which would mutate _activeDownloads mid
    // iteration. The client is left open so the downloader keeps working.
    for (final download in _activeDownloads.toList(growable: false)) {
      download.cancel();
    }
  }
}

class _HttpDownload implements CancellableDownload {
  _HttpDownload(
    this._client,
    this._url,
    this._file,
    this._headers, {
    required this.onComplete,
  });

  final http.Client _client;
  final String _url;
  final File _file;
  final Map<String, String>? _headers;
  final void Function(_HttpDownload download) onComplete;

  final _completer = Completer<CancellableDownloadResult>();
  final _abortCompleter = Completer<void>();
  final _progressController = StreamController<int>.broadcast(sync: true);

  /// Owned across the cancel / write-failure / stream lifecycle methods.
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  bool _isCancelled = false;
  bool _isDone = false;
  bool _hasWriteFailure = false;
  int _receivedBytes = 0;

  @override
  Future<CancellableDownloadResult> get result => _completer.future;

  @override
  Stream<int> get progressBytes => _progressController.stream;

  @override
  Future<File?> get file async => (await result).file;

  @override
  bool get isCancelled => _isCancelled;

  Future<void> _start() async {
    try {
      final uri = Uri.parse(_url);
      if (uri.scheme.toLowerCase() != 'https') {
        Log.warning(
          'CancellableDownload: rejected non-https URL',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        _safeComplete(const CancellableDownloadResult(file: null));
        return;
      }

      final req = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: _abortCompleter.future,
      );
      if (_headers != null) {
        req.headers.addAll(_headers);
      }
      final response = await _client.send(req);
      if (_isCancelled) {
        _discardBody(response);
        _safeComplete(
          CancellableDownloadResult(
            file: null,
            statusCode: response.statusCode,
            headers: response.headers,
          ),
        );
        return;
      }
      if (response.statusCode != HttpStatus.ok) {
        Log.warning(
          'CancellableDownload: request returned HTTP ${response.statusCode}',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        _discardBody(response);
        _safeComplete(
          CancellableDownloadResult(
            file: null,
            statusCode: response.statusCode,
            headers: response.headers,
          ),
        );
        return;
      }

      final parent = _file.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      final sink = _file.openWrite();
      _sink = sink;
      // `openWrite()` opens the file lazily and nothing observes that open
      // until the first write, so a failure — an over-long cache filename
      // (ENAMETOOLONG), a purged or read-only directory — escapes to the
      // enclosing zone and is reported as a crash. Watch `done` and then
      // engage the sink immediately, which hands the pending open a listener
      // before the first response chunk can arrive. The zero-length write
      // leaves the file itself untouched.
      unawaited(sink.done.then<void>((_) {}, onError: _failWithWriteError));
      sink.add(const <int>[]);
      _subscription = response.stream.listen(
        (chunk) {
          if (_isCancelled) return;
          try {
            _sink?.add(chunk);
            if (chunk.isNotEmpty) {
              _receivedBytes += chunk.length;
              _progressController.add(_receivedBytes);
            }
          } on Object catch (_) {
            // Only guards the StateError from adding to a sink a
            // concurrent cancel already closed. A failed write surfaces
            // on the sink's `done` future instead.
          }
        },
        onError: (Object error) async {
          // A stream error that races with our own cancel() is expected
          // teardown, not a download failure — only warn for real errors.
          if (!_isCancelled) {
            Log.warning(
              'CancellableDownload: response stream failed '
              '(${error.runtimeType})',
              name: 'MediaCache',
              category: LogCategory.video,
            );
          }
          await _cleanupPartial();
          _safeComplete(const CancellableDownloadResult(file: null));
        },
        onDone: () async {
          // Mark as done before async finalization so cancel() cannot race
          // into this window and delete a successfully written file.
          _isDone = true;
          try {
            // `close()` flushes the buffered writes and returns `done`, so a
            // failed open or write surfaces here. `flush()` must not be used:
            // once the sink has already reported its failure, it never
            // completes and would strand this download forever.
            await _sink?.close();
          } on Object catch (error) {
            await _failWithWriteError(error);
            return;
          }
          _sink = null;
          if (_hasWriteFailure) return;
          // coverage:ignore-start
          if (_isCancelled) {
            await _safeDelete();
            _safeComplete(
              CancellableDownloadResult(
                file: null,
                statusCode: response.statusCode,
                headers: response.headers,
              ),
            );
            return;
          }
          // coverage:ignore-end
          _safeComplete(
            CancellableDownloadResult(
              file: _file,
              statusCode: response.statusCode,
              headers: response.headers,
            ),
          );
        },
        cancelOnError: true,
      );
    } on Object catch (error) {
      // cancel() fires the abort trigger, so a pending request surfaces here
      // as RequestAbortedException — that is intentional teardown, not a
      // failure, and must not pollute bug-report logs with false warnings.
      if (!_isCancelled) {
        Log.warning(
          'CancellableDownload: request failed (${error.runtimeType})',
          name: 'MediaCache',
          category: LogCategory.video,
        );
      }
      await _cleanupPartial();
      _safeComplete(const CancellableDownloadResult(file: null));
    }
  }

  /// Discards a response body this download will not consume.
  ///
  /// A `cancel()` that lands once the headers have arrived is delivered by
  /// `package:http` as a `RequestAbortedException` on the body stream rather
  /// than thrown out of `send()`. This drain is the only consumer of such a
  /// body, so left unhandled, that intentional teardown reached the
  /// uncaught-zone reporter as a crash (#9339).
  void _discardBody(http.StreamedResponse response) {
    // Nothing is actionable if the drain fails: the body is unwanted whether
    // the failure is our own abort or a dropped connection.
    response.stream.drain<void>().ignore();
  }

  /// Settles this download as a failure after the target file could not be
  /// opened or written, discarding any partial bytes. Idempotent, and safe to
  /// call from both the sink's `done` handler and the response stream's
  /// `onDone` handler.
  Future<void> _failWithWriteError(Object error) async {
    final alreadyFailed = _hasWriteFailure;
    _hasWriteFailure = true;
    // Drop the sink before anything else can await it: a sink that has
    // already reported its failure never completes `flush()`.
    _sink = null;
    if (!alreadyFailed && !_isCancelled) {
      Log.warning(
        'CancellableDownload: cache write failed (${error.runtimeType})',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    }
    await _subscription?.cancel();
    _subscription = null;
    await _safeDelete();
    _safeComplete(const CancellableDownloadResult(file: null));
  }

  Future<void> _cleanupPartial() async {
    try {
      await _sink?.close();
    } on Object catch (_) {
      // Best-effort.
    }
    _sink = null;
    await _safeDelete();
  }

  Future<void> _safeDelete() async {
    try {
      if (_file.existsSync()) await _file.delete();
    } on Object catch (_) {
      // Best-effort.
    }
  }

  void _safeComplete(CancellableDownloadResult result) {
    if (_completer.isCompleted) return;
    _completer.complete(result);
    unawaited(_progressController.close());
    onComplete(this);
  }

  @override
  void cancel() {
    if (_isCancelled || _isDone) return;
    _isCancelled = true;
    if (!_abortCompleter.isCompleted) {
      _abortCompleter.complete();
    }
    final subscription = _subscription;
    if (subscription == null) {
      unawaited(_cleanupPartial());
      return;
    }
    unawaited(
      subscription.cancel().whenComplete(() async {
        await _cleanupPartial();
        _safeComplete(const CancellableDownloadResult(file: null));
      }),
    );
  }
}

class _CompletedDownload implements CancellableDownload {
  _CompletedDownload(File? file)
    : result = Future<CancellableDownloadResult>.value(
        CancellableDownloadResult(file: file),
      );

  @override
  final Future<CancellableDownloadResult> result;

  @override
  Stream<int> get progressBytes => const Stream.empty();

  @override
  Future<File?> get file async => (await result).file;

  @override
  bool get isCancelled => false;

  @override
  void cancel() {}
}
