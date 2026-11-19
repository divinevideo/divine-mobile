// ABOUTME: Backend URLs, app name and people-list discovery policy
// ABOUTME: Centralizes build-time configuration shared across the app

import 'dart:convert';

class AppConfig {
  /// Public discovery policy supplied by release configuration as a JSON array.
  /// A missing or malformed input is reported by the repository provider.
  static final Set<String>? publicPeopleListExcludedDTags =
      parsePublicPeopleListExcludedDTags(
        const String.fromEnvironment(
          'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS',
        ),
      );

  /// Reads an immutable deployment policy without logging identifying values.
  /// Returns null when the build did not supply a valid policy. An explicit
  /// empty array deliberately enables no additional exclusions.
  static Set<String>? parsePublicPeopleListExcludedDTags(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(input);
      if (decoded is! List ||
          decoded.any((value) => value is! String || value.trim().isEmpty)) {
        return null;
      }
      return Set.unmodifiable(decoded.cast<String>());
    } on FormatException {
      return null;
    }
  }

  // Backend configuration

  /// Canonical Divine REST API base (funnelcake, `api.divine.video`).
  ///
  /// Single source of truth for the Divine backend host. Retained as the base
  /// for future `/api/*` calls; the `check_backend_host_defaults.sh` CI guard
  /// pins this (and the other `*BaseUrl` defaults below) to `*.divine.video`.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.divine.video',
  );

  static const String appsDirectoryBaseUrl = String.fromEnvironment(
    'APPS_DIRECTORY_URL',
    defaultValue: 'https://apps.divine.video',
  );

  static const String crossposterBaseUrl = String.fromEnvironment(
    'CROSSPOSTER_URL',
    defaultValue: 'https://crossposter.divine.video',
  );

  // App configuration
  static const String appName = 'Divine';
}
