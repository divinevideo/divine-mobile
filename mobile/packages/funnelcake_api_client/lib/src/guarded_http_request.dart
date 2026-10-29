// ABOUTME: Carries request-local validity through HTTP transport middleware.
// ABOUTME: Keeps superseded work out of initial and retried transmissions.

import 'package:http/http.dart' as http;

/// An HTTP request whose caller can retire it before transport or retry.
///
/// The guard is local metadata and is never included in headers or body bytes.
/// Middleware supporting this request must check it immediately before sending.
class GuardedHttpRequest extends http.Request {
  /// Creates a request with a caller-owned validity check.
  GuardedHttpRequest(super.method, super.url, {required this.isCurrent});

  /// Whether this request still represents the caller's current work.
  final bool Function() isCurrent;
}
