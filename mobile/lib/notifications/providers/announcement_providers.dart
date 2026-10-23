// ABOUTME: Cleanup ports for official-message account state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/notifications/services/announcement_store.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';

final announcementSessionsProvider = Provider<AnnouncementSessions>(
  (_) => AnnouncementSessions(),
);

/// Captures only device storage and the registry, avoiding auth-provider cycles.
final announcementOwnerCleanupProvider =
    Provider<Future<void> Function(String)>((ref) {
      final sessions = ref.watch(announcementSessionsProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      return (owner) => sessions.clearOwner(prefs, owner);
    });

/// Separate anonymous transport; never reuse the account's signed API client.
final announcementHttpClientFactoryProvider = Provider<http.Client Function()>(
  (_) => http.Client.new,
);
