// ABOUTME: Exception classes for the Funnelcake API client.
// ABOUTME: Provides typed exceptions for HTTP API operations.

/// Base exception for all Funnelcake API errors.
class FunnelcakeException implements Exception {
  /// Creates a new Funnelcake exception.
  const FunnelcakeException(this.message, {this.cause});

  /// The error message describing what went wrong.
  final String message;

  /// The lower-level error that caused this exception, when one was wrapped.
  ///
  /// Contract: only some wrap sites populate this today — currently the
  /// author-videos and user-sounds fetches. A wrap site that does not pass
  /// `cause:` leaves it null, and callers classifying failures by cause (for
  /// example creator analytics' connection-vs-server copy) silently fall back
  /// to their generic verdict for those endpoints. Populate the field before
  /// relying on it for a new call site.
  final Object? cause;

  @override
  String toString() {
    final wrapped = cause;
    if (wrapped == null) return 'FunnelcakeException: $message';
    return 'FunnelcakeException: $message (cause: $wrapped)';
  }
}

/// Exception thrown when the Funnelcake API is not configured.
///
/// This occurs when the client is instantiated with an empty base URL.
class FunnelcakeNotConfiguredException extends FunnelcakeException {
  /// Creates a new not configured exception.
  const FunnelcakeNotConfiguredException()
    : super('Funnelcake API not configured');

  @override
  String toString() => 'FunnelcakeNotConfiguredException: $message';
}

/// Exception thrown when an API request fails.
///
/// Includes the HTTP status code and optionally the URL that was requested.
class FunnelcakeApiException extends FunnelcakeException {
  /// Creates a new API exception.
  const FunnelcakeApiException({
    required String message,
    required this.statusCode,
    this.url,
    this.responseBody,
    this.diagnosticHeaders = const {},
  }) : super(message);

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The URL that was requested (if available).
  final String? url;

  /// Raw response body returned by the server, when available.
  final String? responseBody;

  /// Low-cardinality response headers useful for correlating client logs with
  /// edge/backend logs. Does not include request headers or auth material.
  final Map<String, String> diagnosticHeaders;

  /// Best available request/correlation id returned by the server or edge.
  String? get requestId =>
      diagnosticHeaders['x-request-id'] ??
      diagnosticHeaders['x-correlation-id'] ??
      diagnosticHeaders['traceparent'];

  @override
  String toString() {
    final details = <String>['status: $statusCode'];
    final requestUrl = url;
    if (requestUrl != null && requestUrl.isNotEmpty) {
      details.add('url: $requestUrl');
    }

    final id = requestId;
    if (id != null && id.isNotEmpty) {
      details.add('requestId: $id');
    }

    final cfRay = diagnosticHeaders['cf-ray'];
    if (cfRay != null && cfRay.isNotEmpty) {
      details.add('cf-ray: $cfRay');
    }

    final body = responseBody;
    if (body != null && body.isNotEmpty) {
      details.add('body: ${_truncateDiagnosticValue(body)}');
    }

    return 'FunnelcakeApiException: $message (${details.join(', ')})';
  }
}

String _truncateDiagnosticValue(String value) {
  const maxLength = 1000;
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}...';
}

/// Exception thrown when a resource is not found (HTTP 404).
class FunnelcakeNotFoundException extends FunnelcakeApiException {
  /// Creates a new not found exception.
  FunnelcakeNotFoundException({required String resource, super.url})
    : super(message: '$resource not found', statusCode: 404);

  @override
  String toString() => 'FunnelcakeNotFoundException: $message';
}

/// Exception thrown when a request times out.
class FunnelcakeTimeoutException extends FunnelcakeException {
  /// Creates a new timeout exception.
  const FunnelcakeTimeoutException([this.url])
    : super('Request timed out${url != null ? ' for $url' : ''}');

  /// The URL that was requested (if available).
  final String? url;

  @override
  String toString() => 'FunnelcakeTimeoutException: $message';
}
