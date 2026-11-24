// ABOUTME: Reads the error a native Zendesk bridge raises for a failed ticket:
// ABOUTME: whether to retry it, with which identity, and what to report.

import 'package:flutter/services.dart';
import 'package:openvine/observability/reportable_error.dart';

/// A ticket the native Zendesk SDK failed to create, read through the
/// `details` the iOS and Android bridges attach to their error.
///
/// Both bridges send `status`, `networkError`, `authFailed` and, when they
/// know it, `expectedAuth`. iOS adds `errorDomain`, `errorCode` and
/// `identity`, because its SDK gives no reason as specific as Android's.
class ZendeskNativeTicketFailure {
  ZendeskNativeTicketFailure(this.error)
    : _details = error.details is Map ? error.details as Map : const {};

  /// The error the bridge raised.
  final PlatformException error;
  final Map<dynamic, dynamic> _details;

  /// HTTP 4xx statuses that do not mean Zendesk refused the ticket: an
  /// identity to authenticate again, a timeout, and throttling.
  static const Set<int> _retryableClientErrorStatuses = {401, 408, 429};

  /// How much of the SDK reason [reportedMessage] carries.
  static const int _maxReportedReasonLength = 200;

  /// The device was offline, including while exchanging the token.
  bool get isNetworkError => _details['networkError'] == true;

  /// Whether another identity can make the ticket succeed: the bridge found
  /// none on the SDK, or the SDK could not authenticate the one it had.
  ///
  /// Neither SDK says the latter in a way Dart could read from the message:
  /// Android reports a failed token exchange as a 400, and iOS reports it, and
  /// an identity of the wrong type, without an HTTP status at all. So both
  /// bridges flag it in `authFailed`.
  bool get needsAnotherIdentity =>
      error.code == 'NO_IDENTITY' ||
      (error.code == 'CREATE_FAILED' && _details['authFailed'] == true);

  /// The identity type the SDK app is set up for, `jwt` or `anonymous`, when
  /// the bridge knows it.
  String? get expectedAuth => _stringDetail('expectedAuth');

  /// Whether Zendesk refused the ticket itself, so sending it again gets the
  /// same answer: an HTTP 4xx other than 401, 408 and 429.
  ///
  /// Android answers a failed authentication with a synthetic 400, and iOS
  /// passes the status of a failed token exchange, so a 4xx flagged as an
  /// authentication or network failure is no refusal.
  bool get isRefusal {
    if (isNetworkError || _details['authFailed'] == true) return false;
    final status = _details['status'];
    return status is int &&
        status >= 400 &&
        status < 500 &&
        !_retryableClientErrorStatuses.contains(status);
  }

  /// Names the error code, HTTP status, iOS error domain and code, and the
  /// identity type the SDK held and the one the app expects. Never the ticket.
  String get summary {
    final status = _details['status'];
    final errorDomain = _details['errorDomain'];
    final errorCode = _details['errorCode'];
    final identity = _stringDetail('identity');
    final context = [
      if (status is int && status > 0) 'HTTP $status',
      if (errorDomain is String && errorCode is int) '$errorDomain $errorCode',
      if (identity != null) 'identity $identity',
      if (expectedAuth != null) 'expects $expectedAuth',
    ];
    return 'Zendesk SDK could not create ticket: ${error.code}'
        '${context.isEmpty ? '' : ' (${context.join(', ')})'}';
  }

  /// The SDK's reason, without npubs or email addresses.
  String? get reason {
    final message = error.message;
    if (message == null || message.isEmpty) return null;
    return sanitizeForCrashReport(message);
  }

  /// [summary] with the start of [reason], for the recorded error.
  String get reportedMessage {
    final reason = this.reason;
    if (reason == null) return summary;
    if (reason.length <= _maxReportedReasonLength) return '$summary: $reason';
    return '$summary: ${reason.substring(0, _maxReportedReasonLength)}...';
  }

  String? _stringDetail(String key) {
    final value = _details[key];
    return value is String ? value : null;
  }
}
