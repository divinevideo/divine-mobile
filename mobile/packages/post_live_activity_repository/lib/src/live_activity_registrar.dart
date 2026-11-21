import 'package:post_live_activity_repository/src/models/models.dart';

/// The outcome of registering an activity with the push service.
enum LiveActivityRegistrarResult {
  /// The service accepted the registration.
  published,

  /// The registration was not sent; try again later.
  retryLater,

  /// Try again later, but the relay may already have stored it, so the
  /// activity counts as registered.
  uncertain,

  /// Not this account's to send; silent and never retried.
  skipped,

  /// The registration failed and will not be retried.
  failed,
}

/// Sends activity registrations to the push service.
// A port: the app's push service implements it, and tests fake it.
// ignore: one_member_abstracts, a single-method port is the intended shape.
abstract interface class LiveActivityRegistrar {
  /// Registers [registration] with the push service.
  Future<LiveActivityRegistrarResult> register(
    LiveActivityRegistration registration,
  );
}

/// Reports an unexpected error from [site] to crash reporting.
typedef PostLiveActivityErrorReporter =
    void Function(Object error, StackTrace stack, {required String site});
