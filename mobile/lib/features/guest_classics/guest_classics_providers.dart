// ABOUTME: Build-only opt-in for an account-free fresh-install Classics pilot.
// ABOUTME: Uses the public edge without account identity or consumption uploads.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/features/guest_classics/guest_classics_manifest.dart';
import 'package:openvine/providers/feed_viewer_preference_hints.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/locale_preference_service.dart';

@visibleForTesting
Uri? resolveGuestClassicsBase({
  required String configured,
  required bool isWeb,
  required TargetPlatform platform,
  required int? sessionCount,
}) {
  if (configured.isEmpty ||
      isWeb ||
      !const {
        TargetPlatform.iOS,
        TargetPlatform.android,
      }.contains(platform)) {
    return null;
  }
  final base = Uri.tryParse(configured);
  if (base == null ||
      !base.isScheme('https') ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    return null;
  }
  if (sessionCount != 1) return null;
  return base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
}

final guestClassicsBaseProvider = Provider<Uri?>((ref) {
  const configured = String.fromEnvironment('GUEST_CLASSICS_MANIFEST_BASE_URL');
  if (configured.isEmpty) return null;
  final preferences = ref.read(sharedPreferencesProvider);
  return resolveGuestClassicsBase(
    configured: configured,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    sessionCount: preferences.getInt(AppEngagementStore.sessionCountKey),
  );
});

/// A fresh client per request permits cancellation on expiry, background or
/// route disposal, without sharing account cookies, headers or stale results.
final guestClassicsManifestProvider =
    Provider<
      Future<GuestClassicsManifest?> Function(
        http.Client, {
        required bool muted,
      })
    >((ref) {
      final base = ref.watch(guestClassicsBaseProvider);
      if (base == null) return (_, {required muted}) async => null;
      final prefs = ref.read(sharedPreferencesProvider);
      final languages = buildPreferredFeedLanguages(
        contentLanguage:
            prefs.getString(LanguagePreferenceService.prefsKey) ?? '',
        appLocale: prefs.getString(LocalePreferenceService.prefsKey),
        deviceLocales: PlatformDispatcher.instance.locales,
      );
      return (client, {required muted}) => fetchGuestClassics(
        muted: muted,
        base: base,
        client: client,
        languages: languages,
        now: DateTime.now,
      ).timeout(const Duration(seconds: 3));
    });

enum GuestClassicsObservation { firstFrame, swipe }

/// Local QA probe. Guest consumption has no analytics uploader.
final guestClassicsObserverProvider =
    Provider<ValueChanged<GuestClassicsObservation>?>((_) => null);
