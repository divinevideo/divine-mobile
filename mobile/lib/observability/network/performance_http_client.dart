// ABOUTME: http.Client decorator that reports Divine-host requests as
// ABOUTME: Firebase Performance network requests, one metric per request.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:openvine/observability/network/http_metric_recorder.dart';
import 'package:openvine/observability/network/http_operation.dart';
import 'package:openvine/observability/network/http_url_pattern.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

/// Wraps an [http.Client] and reports every request it sends to a
/// Divine-operated host (see [isInstrumentedHost]) to [HttpMetricRecorder].
///
/// One instrumentation point for the whole Dart HTTP surface: wire this in
/// where a client is constructed and every call the owning client makes is
/// covered, with no per-call-site bookkeeping.
///
/// The span ends when the response body ends — completed, failed, or the
/// subscription cancelled — so the reported duration covers the transfer, not
/// just time to first byte. A caller that takes a [http.StreamedResponse] and
/// never listens to its stream leaves the span open; that already leaks the
/// underlying connection, so it is a bug at the call site rather than
/// something this client papers over.
class PerformanceHttpClient extends http.BaseClient {
  PerformanceHttpClient({
    required http.Client inner,
    required HttpMetricRecorder recorder,
    PerformanceTraceMonitor performanceMonitor =
        const NoOpPerformanceTraceMonitor(),
  }) : _inner = inner,
       _recorder = recorder,
       _performanceMonitor = performanceMonitor;

  final http.Client _inner;
  final HttpMetricRecorder _recorder;
  final PerformanceTraceMonitor _performanceMonitor;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!isInstrumentedHost(request.url.host)) {
      return _inner.send(request);
    }

    final span = _recorder.start(
      urlPattern: httpMetricUrlPattern(request.url),
      method: request.method,
    );
    final operation = PerformanceOperation(
      _performanceMonitor,
      'http_operation',
    );
    final stopwatch = Stopwatch()..start();
    final attributes = {
      'operation': httpOperation(request.url),
      'method':
          const {
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'HEAD',
            'OPTIONS',
          }.contains(request.method)
          ? request.method
          : 'OTHER',
    };

    final requestPayloadSize = request.contentLength;
    if (requestPayloadSize != null) {
      span?.setRequestPayloadSize(requestPayloadSize);
    }

    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (_) {
      span?.complete();
      operation.finish(
        attributes: {...attributes, 'outcome': 'transport_error'},
        metrics: {'total_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    }

    return http.StreamedResponse(
      _trackBody(
        response,
        span,
        operation,
        stopwatch,
        stopwatch.elapsedMilliseconds,
        attributes,
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _trackBody(
    http.StreamedResponse response,
    HttpMetricSpan? span,
    PerformanceOperation operation,
    Stopwatch stopwatch,
    int headersMs,
    Map<String, String> attributes,
  ) {
    var received = 0;
    var finished = false;
    void finish(String outcome) {
      if (finished) return;
      finished = true;
      operation.finish(
        attributes: {
          ...attributes,
          'status': response.statusCode.toString(),
          'outcome': outcome,
        },
        metrics: {
          'headers_ms': headersMs,
          'total_ms': stopwatch.elapsedMilliseconds,
          'response_bytes': received,
        },
      );
      span?.complete(
        statusCode: response.statusCode,
        responsePayloadSize: received,
        responseContentType: response.headers['content-type'],
      );
    }

    StreamSubscription<List<int>>? upstream;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        upstream = response.stream.listen(
          (chunk) {
            received += chunk.length;
            controller.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            finish('body_error');
            controller.addError(error, stackTrace);
            unawaited(controller.close());
          },
          onDone: () {
            finish(
              response.statusCode >= 200 && response.statusCode < 400
                  ? 'success'
                  : 'http_error',
            );
            unawaited(controller.close());
          },
          cancelOnError: true,
        );
      },
      onPause: () => upstream?.pause(),
      onResume: () => upstream?.resume(),
      onCancel: () {
        finish('cancelled');
        return upstream?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
