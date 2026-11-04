// ABOUTME: Sends signed room reports using the existing Divine identity.
import 'dart:convert';

import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/chat/room_catalog_provider.dart';
import 'package:openvine/providers/auth_providers.dart';

const concordReportsUrl = String.fromEnvironment(
  'CONCORD_REPORTS_URL',
  defaultValue: 'https://chat-reports.divine.video/v1/reports',
);
final concordReportsProvider = Provider<ConcordReports?>((ref) {
  final catalog = currentConcordCatalog(ref);
  if (catalog == null ||
      !catalog.isReal ||
      !catalog.ready ||
      concordReportsUrl.isEmpty) {
    return null;
  }
  final auth = ref.watch(authServiceProvider);
  final account = auth.currentPublicKeyHex;
  if (account == null) return null;
  var active = true;
  ref.onDispose(() {
    active = false;
  });
  bool canSubmit() =>
      active &&
      catalog.ready &&
      auth.isAuthenticated &&
      auth.currentPublicKeyHex == account;
  void requireCurrentSession() {
    if (!canSubmit()) throw StateError('Room session changed');
  }

  return ConcordReports(
    canSubmit: canSubmit,
    url: Uri.parse(concordReportsUrl),
    signer: (template) async {
      requireCurrentSession();
      final signer = auth.currentIdentity;
      if (signer == null) throw StateError('Room signer unavailable');
      final signed = await signer.signEvent(
        Event(
          account,
          template['kind'] as int,
          (template['tags'] as List)
              .map((t) => (t as List).cast<String>())
              .toList(),
          template['content'] as String,
          createdAt: template['created_at'] as int,
        ),
      );
      // An external signer can finish after logout or provider teardown.
      requireCurrentSession();
      if (signed == null) throw StateError('Report signature was declined');
      return signed.toJson();
    },
    post: (url, body, headers) async {
      requireCurrentSession();
      final client = http.Client();
      try {
        final request = http.Request('POST', url)
          ..followRedirects = false
          ..headers.addAll(headers)
          ..body = body;
        // Keep the final lifetime check beside dispatch, without an await.
        requireCurrentSession();
        final response = await http.Response.fromStream(
          await client.send(request),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 202) {
          throw StateError('Room report could not be submitted');
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    },
  );
});
