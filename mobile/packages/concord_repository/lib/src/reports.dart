// MPL-2.0
import 'dart:convert';
import 'dart:math';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/sealed_transport.dart';

/// HTTP port; the app supplies its client without coupling protocol to IO.
typedef ConcordReportPost =
    Future<Map<String, dynamic>> Function(
      Uri url,
      String body,
      Map<String, String> headers,
    );

class ConcordReports {
  ConcordReports({
    required this.url,
    required this.signer,
    required this.post,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000) {
    if (url.scheme != 'https' ||
        url.path != '/v1/reports' ||
        url.hasFragment ||
        url.userInfo.isNotEmpty) {
      throw ArgumentError(
        'Reports require the configured HTTPS reports endpoint',
      );
    }
  }
  final Uri url;
  final SealSigner signer;
  final ConcordReportPost post;
  final int Function() _now;

  Future<String> submit({
    required String communityId,
    required String channelId,
    required String rumorId,
    required String reason,
  }) async {
    if (![
          communityId,
          channelId,
          rumorId,
        ].every(RegExp(r'^[0-9a-f]{64}$').hasMatch) ||
        reason.trim().isEmpty ||
        reason.length > 2048) {
      throw ArgumentError('Invalid community report');
    }
    final body = jsonEncode({
      'target': {
        'communityId': communityId,
        'channelId': channelId,
        'rumorId': rumorId,
      },
      'reason': reason,
    });
    // A retry in the same second still needs a fresh NIP-98 event id: the
    // service rejects replay even when the first HTTP reply was lost.
    final random = Random.secure();
    final nonce = bytesToB64url(List.generate(16, (_) => random.nextInt(256)));
    final authentication = await signer({
      'kind': 27235,
      'created_at': _now(),
      'content': '',
      'tags': [
        ['u', url.toString()],
        ['method', 'POST'],
        ['payload', sha256Hex(body)],
        ['nonce', nonce],
      ],
    });
    final response = await post(url, body, {
      'content-type': 'application/json',
      'authorization':
          'Nostr ${base64Encode(utf8.encode(jsonEncode(authentication)))}',
    });
    final caseId = response['caseId'];
    if (caseId is! String || caseId.isEmpty) {
      throw const FormatException('Report was not accepted');
    }
    return caseId;
  }
}
