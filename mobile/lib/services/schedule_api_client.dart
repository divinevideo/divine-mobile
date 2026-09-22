// ABOUTME: REST client for the relay's scheduled-post hold queue (#3538).
// ABOUTME: Submits, lists and cancels pre-signed future-dated events with NIP-98.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Why the relay refused to hold a post. Mirrors the intake rules of
/// `POST /api/schedule`; none of these are worth retrying unchanged.
enum ScheduleRejectionKind {
  /// Wrong kind, oversized, or otherwise malformed (400).
  invalidRequest,

  /// `created_at` is inside the relay's drift window: publish it now (400).
  notFutureEnough,

  /// `created_at` is beyond the scheduling horizon (400).
  beyondHorizon,

  /// NIP-98 authentication failed (401).
  unauthorized,

  /// The NIP-98 signer is not the event author (403, or refused locally).
  forbidden,

  /// Scheduling is not enabled for this account (402).
  notEntitled,

  /// The account already has the maximum number of pending posts (429).
  overCap,

  /// Too many scheduling requests from this account (429).
  rateLimited,
}

/// Outcome of `POST /api/schedule`.
sealed class ScheduleSubmitResult {
  const ScheduleSubmitResult();
}

/// The relay holds the event (202), or already held this exact event (409).
final class ScheduleSubmitAccepted extends ScheduleSubmitResult {
  const ScheduleSubmitAccepted({
    required this.eventId,
    required this.publishAt,
  });

  final String eventId;

  /// Unix seconds; the event's `created_at` as the relay read it.
  final int publishAt;
}

/// The relay refused the event for a reason that will not change on retry.
final class ScheduleSubmitRejected extends ScheduleSubmitResult {
  const ScheduleSubmitRejected({
    required this.statusCode,
    required this.kind,
    required this.message,
  });

  /// HTTP status code, or `0` for a client-side rejection before the request.
  final int statusCode;
  final ScheduleRejectionKind kind;

  /// The relay's own wording, for logs and the failure reason.
  final String message;
}

/// The request did not reach a verdict: timeout, network error, 5xx, an
/// unparseable body, no NIP-98 token — or the endpoint is not served yet.
/// The caller keeps the post locally and retries later.
final class ScheduleSubmitTransientFailure extends ScheduleSubmitResult {
  const ScheduleSubmitTransientFailure(this.reason, {this.unavailable = false});

  final String reason;

  /// The relay answered 404 (the gateway does not route the endpoint yet)
  /// or 503 (scheduling not enabled). Retried, but at a slower pace.
  final bool unavailable;
}

/// One of the caller's posts as the relay reports it in `GET /api/schedule`.
final class ScheduledPostServerEntry {
  const ScheduledPostServerEntry({
    required this.eventId,
    required this.kind,
    required this.publishAt,
    required this.state,
    required this.failureReason,
  });

  final String eventId;
  final int kind;

  /// Unix seconds.
  final int publishAt;
  final ScheduledPostServerState state;

  /// Empty unless [state] is [ScheduledPostServerState.failed].
  final String failureReason;
}

/// Resolved state of a post in the relay's hold queue.
enum ScheduledPostServerState { schedule, cancel, published, failed }

/// Outcome of `GET /api/schedule`.
sealed class ScheduleListResult {
  const ScheduleListResult();
}

final class ScheduleListLoaded extends ScheduleListResult {
  const ScheduleListLoaded(this.entries);

  final List<ScheduledPostServerEntry> entries;
}

final class ScheduleListFailure extends ScheduleListResult {
  const ScheduleListFailure(this.reason, {this.statusCode});

  final String reason;
  final int? statusCode;
}

/// Outcome of `DELETE /api/schedule/{event_id}`.
sealed class ScheduleCancelResult {
  const ScheduleCancelResult();
}

/// The relay wrote a cancel row (200).
final class ScheduleCancelled extends ScheduleCancelResult {
  const ScheduleCancelled();
}

/// The relay holds no such post for this account (404 with a JSON body).
final class ScheduleCancelNotFound extends ScheduleCancelResult {
  const ScheduleCancelNotFound();
}

/// The post is no longer pending: already published or cancelled (409).
final class ScheduleCancelConflict extends ScheduleCancelResult {
  const ScheduleCancelConflict(this.message);

  final String message;
}

/// See [ScheduleSubmitTransientFailure].
final class ScheduleCancelTransientFailure extends ScheduleCancelResult {
  const ScheduleCancelTransientFailure(this.reason, {this.unavailable = false});

  final String reason;
  final bool unavailable;
}

/// Talks to the relay's scheduled-post endpoints.
///
/// Every call is NIP-98 authenticated over the exact request URL and method
/// (a payload hash is added for the POST), so the relay can scope the queue
/// to the signing account. The relay's own limits — schedulable kinds, a
/// minimum lead of 60 s, a 90-day horizon, 100 pending posts per account —
/// come back as [ScheduleSubmitRejected] with the relay's wording.
class ScheduleApiClient {
  ScheduleApiClient({
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

  /// Path of the schedule endpoint, appended to the resolved API base URL.
  static const schedulePath = '/api/schedule';

  static const _logName = 'ScheduleApiClient';

  /// The fully-qualified schedule URL for the current environment.
  ///
  /// Every request signs its NIP-98 `u` tag against the `toString()` of the
  /// URI it goes to, and the relay compares the two exactly, so both come
  /// from the same place.
  String get scheduleUrl => _scheduleUri.toString();

  Uri get _scheduleUri {
    final base = _apiBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$trimmed$schedulePath');
  }

  Uri _cancelUri(String eventId) => Uri.parse('$scheduleUrl/$eventId');

  /// Hands the signed, future-dated [event] to the relay's hold queue.
  Future<ScheduleSubmitResult> schedule(Event event) async {
    final uri = _scheduleUri;
    final body = jsonEncode(event.toJson());

    final token = await _nip98.createAuthToken(
      url: uri.toString(),
      method: HttpMethod.post,
      payload: body,
    );
    if (token == null) {
      Log.error(
        'Cannot schedule event ${event.id} — NIP-98 token unavailable '
        '(not authenticated?)',
        name: _logName,
        category: LogCategory.video,
      );
      return const ScheduleSubmitTransientFailure('nip98_token_unavailable');
    }

    // The relay refuses a schedule request whose signer is not the author.
    // Refuse before hitting the network so the mismatch is logged here.
    if (token.signedEvent.pubkey != event.pubkey) {
      Log.error(
        'NIP-98 signer pubkey ${pubkeyForLogs(token.signedEvent.pubkey)} does '
        'not match event pubkey ${pubkeyForLogs(event.pubkey)}; refusing to '
        'schedule ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return const ScheduleSubmitRejected(
        statusCode: 0,
        kind: ScheduleRejectionKind.forbidden,
        message: 'signer_pubkey_mismatch',
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
        'Schedule request timed out after ${_timeout.inSeconds}s for '
        '${event.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return const ScheduleSubmitTransientFailure('timeout');
    } catch (e) {
      Log.warning(
        'Schedule request network error for ${event.id}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return ScheduleSubmitTransientFailure('network_error: $e');
    }

    return _classifySubmit(event, response);
  }

  ScheduleSubmitResult _classifySubmit(Event event, http.Response response) {
    final status = response.statusCode;
    final body = response.body;

    if (status == 202) {
      final decoded = _decodeMap(body);
      final eventId = decoded?['event_id'];
      final publishAt = decoded?['publish_at'];
      if (decoded?['scheduled'] == true &&
          eventId == event.id &&
          publishAt is int) {
        Log.info(
          'Relay holds scheduled event $eventId until $publishAt',
          name: _logName,
          category: LogCategory.video,
        );
        return ScheduleSubmitAccepted(eventId: event.id, publishAt: publishAt);
      }
      Log.warning(
        'Schedule 202 without a matching acceptance for ${event.id}: $body',
        name: _logName,
        category: LogCategory.video,
      );
      return ScheduleSubmitTransientFailure('invalid_response: $body');
    }

    if (status == 409) {
      // The relay already holds this exact event: a retry after a lost
      // acknowledgement. Its publish time is the event's own created_at.
      Log.info(
        'Relay already holds scheduled event ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return ScheduleSubmitAccepted(
        eventId: event.id,
        publishAt: event.createdAt,
      );
    }

    final message = _message(body);
    final kind = switch (status) {
      400 => _classify400(message),
      401 => ScheduleRejectionKind.unauthorized,
      403 => ScheduleRejectionKind.forbidden,
      402 => ScheduleRejectionKind.notEntitled,
      429 =>
        message.contains('pending')
            ? ScheduleRejectionKind.overCap
            : ScheduleRejectionKind.rateLimited,
      _ => null,
    };
    if (kind != null) {
      Log.error(
        'Relay rejected scheduling of ${event.id} ($status, ${kind.name}): '
        '$message',
        name: _logName,
        category: LogCategory.video,
      );
      return ScheduleSubmitRejected(
        statusCode: status,
        kind: kind,
        message: message,
      );
    }

    final unavailable = _isUnavailable(status, body);
    Log.warning(
      'Schedule request transient HTTP $status for ${event.id}: $body',
      name: _logName,
      category: LogCategory.video,
    );
    return ScheduleSubmitTransientFailure(
      'http_$status',
      unavailable: unavailable,
    );
  }

  ScheduleRejectionKind _classify400(String message) {
    if (message.contains('in the future')) {
      return ScheduleRejectionKind.notFutureEnough;
    }
    if (message.contains('horizon')) {
      return ScheduleRejectionKind.beyondHorizon;
    }
    return ScheduleRejectionKind.invalidRequest;
  }

  /// Lists the caller's own scheduled posts, pending ones first.
  Future<ScheduleListResult> list() async {
    final uri = _scheduleUri;
    final token = await _nip98.createAuthToken(
      url: uri.toString(),
      method: HttpMethod.get,
    );
    if (token == null) {
      return const ScheduleListFailure('nip98_token_unavailable');
    }

    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': token.authorizationHeader,
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const ScheduleListFailure('timeout');
    } catch (e) {
      return ScheduleListFailure('network_error: $e');
    }

    final status = response.statusCode;
    if (status != 200) {
      Log.warning(
        'Schedule list failed with HTTP $status: ${response.body}',
        name: _logName,
        category: LogCategory.video,
      );
      return ScheduleListFailure('http_$status', statusCode: status);
    }

    final decoded = _decodeMap(response.body);
    final raw = decoded?['scheduled'];
    if (raw is! List) {
      return ScheduleListFailure('invalid_response: ${response.body}');
    }
    final entries = <ScheduledPostServerEntry>[];
    for (final item in raw) {
      final entry = _parseEntry(item);
      if (entry != null) entries.add(entry);
    }
    return ScheduleListLoaded(entries);
  }

  ScheduledPostServerEntry? _parseEntry(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final eventId = item['event_id'];
    final kind = item['kind'];
    final publishAt = item['publish_at'];
    final rawState = item['state'];
    if (eventId is! String ||
        kind is! int ||
        publishAt is! int ||
        rawState is! String) {
      return null;
    }
    final state = ScheduledPostServerState.values
        .where((s) => s.name == rawState)
        .firstOrNull;
    if (state == null) {
      Log.warning(
        'Unknown scheduled-post state "$rawState" for $eventId',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    final failureReason = item['failure_reason'];
    return ScheduledPostServerEntry(
      eventId: eventId,
      kind: kind,
      publishAt: publishAt,
      state: state,
      failureReason: failureReason is String ? failureReason : '',
    );
  }

  /// Withdraws a post the relay still holds.
  Future<ScheduleCancelResult> cancel(String eventId) async {
    final uri = _cancelUri(eventId);
    final token = await _nip98.createAuthToken(
      url: uri.toString(),
      method: HttpMethod.delete,
    );
    if (token == null) {
      return const ScheduleCancelTransientFailure('nip98_token_unavailable');
    }

    final http.Response response;
    try {
      response = await _httpClient
          .delete(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': token.authorizationHeader,
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const ScheduleCancelTransientFailure('timeout');
    } catch (e) {
      return ScheduleCancelTransientFailure('network_error: $e');
    }

    final status = response.statusCode;
    final body = response.body;
    switch (status) {
      case 200:
        Log.info(
          'Relay cancelled scheduled event $eventId',
          name: _logName,
          category: LogCategory.video,
        );
        return const ScheduleCancelled();
      case 404 when _decodeMap(body) != null:
        // The relay answers 404 with its JSON error body; the gateway's own
        // 404 for an unrouted path has none and is classified below.
        return const ScheduleCancelNotFound();
      case 409:
        return ScheduleCancelConflict(_message(body));
      default:
        Log.warning(
          'Schedule cancel transient HTTP $status for $eventId: $body',
          name: _logName,
          category: LogCategory.video,
        );
        return ScheduleCancelTransientFailure(
          'http_$status',
          unavailable: _isUnavailable(status, body),
        );
    }
  }

  /// A 503 is the relay saying scheduling is not enabled; a 404 without the
  /// relay's JSON error body is the gateway not routing the endpoint at all.
  bool _isUnavailable(int status, String body) =>
      status == 503 || (status == 404 && _decodeMap(body) == null);

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String _message(String body) {
    final message = _decodeMap(body)?['message'];
    if (message is String && message.isNotEmpty) return message;
    return body;
  }
}
