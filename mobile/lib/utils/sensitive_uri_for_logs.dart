// ABOUTME: Redacts secrets and PII from URIs and free-form text before
// ABOUTME: writing them to diagnostic logs (URIs, email addresses, Nostr keys
// ABOUTME: are handled here; Nostr key stripping for crash reports lives in
// ABOUTME: lib/observability/reportable_error.dart).

/// Placeholder for secrets in free-form log text or HTTP headers.
const redactedSensitiveLogPlaceholder = '[REDACTED]';

/// Value used inside [Uri] path and query fragments so `Uri.toString()` does
/// not percent-encode bracket punctuation.
const redactedUriComponentForLogs = 'REDACTED';

/// Returns a URI string safe for logs: clears [userInfo] and redacts query and
/// fragment values while keeping path segments verbatim.
///
/// On parse failure, returns `[invalid-uri]` without echoing [uriString].
String redactUriStringForLogs(String uriString) {
  final trimmed = uriString.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || trimmed.isEmpty) {
    return '[invalid-uri]';
  }

  final Map<String, dynamic>? qp;
  if (uri.query.isEmpty) {
    qp = null;
  } else {
    qp = {
      for (final e in uri.queryParametersAll.entries)
        e.key: e.value.length == 1
            ? redactedUriComponentForLogs
            : List<String>.filled(e.value.length, redactedUriComponentForLogs),
    };
  }

  var redactedUri = uri.replace(userInfo: '', queryParameters: qp);
  if (uri.fragment.isNotEmpty) {
    redactedUri = redactedUri.replace(fragment: redactedUriComponentForLogs);
  }
  var out = redactedUri.toString();
  // `Uri.replace(pathSegments: ...)` drops the leading "/" on scheme-less
  // absolute paths used as GoRouter locations. Restore it for readable logs.
  if (!uri.hasScheme && uri.hasAbsolutePath && !out.startsWith('/')) {
    out = '/$out';
  }
  return out;
}

/// Returns an email address safe for diagnostic logs.
///
/// - `user@example.com` → `u***@example.com`
/// - `a@b.co`           → `a***@b.co`   (single-char local-part still gets
///                                       a fixed-width mask so the original
///                                       length is not leaked)
/// - empty input or input missing `@` or with no `.` in the domain →
///   [redactedSensitiveLogPlaceholder]
///
/// The domain is preserved verbatim so ops can correlate failure patterns
/// across the same provider (e.g. "all gmail.com users are timing out")
/// without identifying individual accounts. Local-part collapses to a
/// fixed 4-character mask (`x***`) regardless of length.
String redactEmailForLogs(String email) {
  if (email.isEmpty) return redactedSensitiveLogPlaceholder;
  final atIndex = email.indexOf('@');
  // No `@`, or `@` at position 0 (empty local-part) → not a usable email.
  if (atIndex <= 0) return redactedSensitiveLogPlaceholder;
  final domain = email.substring(atIndex + 1);
  // Domain must contain at least one `.` to be a routable host.
  if (!domain.contains('.')) return redactedSensitiveLogPlaceholder;
  final firstChar = email.substring(0, 1);
  return '$firstChar***@$domain';
}
