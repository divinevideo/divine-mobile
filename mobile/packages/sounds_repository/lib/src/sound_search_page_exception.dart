import 'package:meta/meta.dart';

/// A later page of a sound search that could not be loaded.
///
/// Carries only why, as a status code or an error type. The exceptions of
/// the request itself name its URL, and a search URL holds the words the
/// user typed, which stay out of logs.
@immutable
class SoundSearchPageException implements Exception {
  /// Creates a [SoundSearchPageException] for [reason].
  const SoundSearchPageException(this.reason);

  /// Why the page could not be loaded: `status 503`, or the type of the
  /// error, such as `FunnelcakeTimeoutException`.
  final String reason;

  @override
  String toString() => 'SoundSearchPageException: $reason';
}
