// ABOUTME: Reads subscription IDs and their readiness from one guarded record.
// ABOUTME: Retains malformed storage evidence and never exposes a partial decode.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reads a paired snapshot without modifying the stored subscription record.
///
/// Missing metadata is known empty. Unreadable metadata yields an immutable
/// [fallback] and remains incomplete, even if its first IDs could be decoded.
/// [onMissing] lets the cache writer retire a baseline removed by account cleanup.
({Set<String> ids, bool isReadable}) readCuratedListSubscriptionSnapshot({
  required SharedPreferences preferences,
  required String storageKey,
  Set<String> fallback = const {},
  void Function()? onMissing,
  void Function(Object error, StackTrace stackTrace)? onUnreadable,
}) {
  try {
    final raw = preferences.getString(storageKey);
    if (raw == null) {
      onMissing?.call();
      return (ids: const <String>{}, isReadable: true);
    }
    final ids = List<String>.from(jsonDecode(raw) as List<dynamic>);
    return (ids: Set<String>.unmodifiable(ids), isReadable: true);
  } on Object catch (error, stackTrace) {
    if (onUnreadable != null) {
      onUnreadable(error, stackTrace);
    } else {
      // FormatException.toString() may quote the stored record.
      Log.error(
        'Stored curated subscriptions cannot be read (${error.runtimeType})',
        name: 'CuratedListSubscriptionMetadata',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
    }
    return (ids: Set<String>.unmodifiable(fallback), isReadable: false);
  }
}
