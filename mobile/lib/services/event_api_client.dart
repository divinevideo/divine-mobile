// ABOUTME: REST client for publishing signed Nostr events to the Divine events API
// ABOUTME: POSTs the signed event JSON to /api/events with NIP-98 auth, classifying outcomes

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/relay_rejection_classifier.dart';
import 'package:unified_logger/unified_logger.dart';

/// Outcome of a REST publish attempt against `POST {apiBaseUrl}/api/events`.
sealed class EventApiPublishResult {
  const EventApiPublishResult();
}

/// The API accepted the event (HTTP 200 `{accepted: true, event_id}`).
final class EventApiAccepted extends EventApiPublishResult {
  const EventApiAccepted(this.eventId);

  /// The `event_id` echoed back by the API.
  final String eventId;
}

/// The API rejected the event with an actionable status (401/403/422, a
/// client-side signer/identity mismatch, or an explicit restriction response).
final class EventApiRejected extends EventApiPublishResult {
  const EventApiRejected({required this.statusCode, required this.reason});

  /// HTTP status code, or `0` for a client-side rejection before the request.
  final int statusCode;

  /// Human-readable reason for logging.
  final String reason;
}

/// A transient failure (timeout, network error, 5xx, or a malformed/
/// non-accepting 200). Callers should fall back to WebSocket publish.
final class EventApiTransientFailure extends EventApiPublishResult {
  const EventApiTransientFailure(this.reason);

  /// Human-readable reason for logging.
  final String reason;
}

/// Publishes signed Nostr events to the first-party Divine events REST API.
///
/// The request body is the already-signed event JSON. Authorization is
/// NIP-98 (kind 27235) over the exact publish URL, `POST` method, and a
/// payload hash of the request body. Outcomes are classified so the caller
/// can treat acceptances as published, inspect explicit rejections, and
/// classify everything else (timeouts, 5xx, network errors) as transient.
class EventApiClient {
  EventApiClient({
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String Function() apiBaseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient,
       _nip98 = nip98AuthService,
       _apiBaseUrl = apiBaseUrl,
       _timeout = timeout;

  final http.Client _httpClient;
  final Nip98AuthService _nip98;
  final String Function() _apiBaseUrl;
  final Duration _timeout;

  /// Path of the events endpoint, appended to the resolved API base URL.
  static const eventsPath = '/api/events';

  static const _logName = 'EventApiClient';

  /// The fully-qualified publish URL for the current environment, e.g.
  /// `https://api.divine.video/api/events`.
  ///
  /// This is the string [publishEvent] signs its NIP-98 `u` tag against, so it
  /// is the `toString()` of the URI the request goes to rather than a separate
  /// composition. `Uri.parse` normalizes — host case, default port, dot
  /// segments — and the API compares the signed URL to the requested one
  /// exactly, so the two have to come from the same place.
  String get publishUrl => _publishUri.toString();

  /// The URI [publishEvent] posts to.
  Uri get _publishUri {
    final base = _apiBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$trimmed$eventsPath');
  }

  /// Publishes [event] (already signed) to the events API.
  Future<EventApiPublishResult> publishEvent(Event event) async {
    final uri = _publishUri;
    final url = uri.toString();
    final body = jsonEncode(event.toJson());

    final token = await _nip98.createAuthToken(
      url: url,
      method: HttpMethod.post,
      payload: body,
    );

    if (token == null) {
      Log.error(
        'Cannot publish event ${event.id} — NIP-98 token unavailable '
        '(not authenticated?)',
        name: _logName,
        category: LogCategory.video,
      );
      return const EventApiTransientFailure('nip98_token_unavailable');
    }

    // The signer that minted the auth token must be the same key that signed
    // the event; otherwise the API would attribute the publish to the wrong
    // author. Refuse before hitting the network.
    if (token.signedEvent.pubkey != event.pubkey) {
      Log.error(
        'NIP-98 signer pubkey ${pubkeyForLogs(token.signedEvent.pubkey)} does not match '
        'event pubkey ${pubkeyForLogs(event.pubkey)}; refusing to publish ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return const EventApiRejected(
        statusCode: 0,
        reason: 'signer_pubkey_mismatch',
      );
    }

    final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': token.authorizationHeader,
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      Log.warning(
        'REST publish timed out after ${_timeout.inSeconds}s for ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return const EventApiTransientFailure('timeout');
    } catch (e) {
      Log.warning(
        'REST publish network error for ${event.id}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return EventApiTransientFailure('network_error: $e');
    }

    return _classify(event, response);
  }

  EventApiPublishResult _classify(Event event, http.Response response) {
    final status = response.statusCode;

    if (status == 200) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final accepted = decoded['accepted'] == true;
        final eventId = decoded['event_id'] as String?;
        if (accepted && eventId != null && eventId == event.id) {
          Log.info(
            'REST publish accepted event $eventId',
            name: _logName,
            category: LogCategory.video,
          );
          return EventApiAccepted(eventId);
        }
        final reason = _rejectionReason(response.body);
        if (!accepted && isAccountRestrictedReason(reason)) {
          Log.error(
            'REST publish rejected account for event ${event.id} from '
            '${pubkeyForLogs(event.pubkey)}: $reason',
            name: _logName,
            category: LogCategory.video,
          );
          return EventApiRejected(statusCode: status, reason: reason);
        }
        Log.warning(
          'REST publish 200 without accepted:true and matching event_id '
          'for ${event.id}: '
          '${response.body}',
          name: _logName,
          category: LogCategory.video,
        );
        return EventApiTransientFailure('not_accepted: ${response.body}');
      } catch (e) {
        Log.warning(
          'REST publish 200 with unparseable body for ${event.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return EventApiTransientFailure('invalid_response: $e');
      }
    }

    // Authentication, authorization, and validation failures are real and
    // non-retryable — surface them with actionable logs.
    if (status == 401 || status == 403 || status == 422) {
      Log.error(
        'REST publish rejected ($status) for event ${event.id}: '
        '${response.body}',
        name: _logName,
        category: LogCategory.video,
      );
      return EventApiRejected(
        statusCode: status,
        reason: _rejectionReason(response.body),
      );
    }

    // 5xx and any other status: transient — caller falls back to WebSocket.
    Log.warning(
      'REST publish transient HTTP $status for ${event.id}: ${response.body}',
      name: _logName,
      category: LogCategory.video,
    );
    return EventApiTransientFailure('http_$status');
  }

  String _rejectionReason(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Plain-text rejection bodies are already the reason.
    }
    return body;
  }
}
