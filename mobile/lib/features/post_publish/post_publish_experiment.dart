// ABOUTME: Deterministically assigns the post-publish confirmation experiment.
// ABOUTME: Assignment is local: sha256 over the pubkey, no remote input.

import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:unified_logger/unified_logger.dart';

enum PostPublishVariant {
  control('control'),
  viewShare('view_share');

  const PostPublishVariant(this.analyticsName);

  final String analyticsName;
}

typedef RecordPostPublishExposure = Future<void> Function(
  PostPublishVariant variant,
);

/// Marks a publish that should get the full confirmation — a sheet offering
/// View and Share — rather than the bare snackbar the control arm sees.
///
/// Deliberately carries no video identity: the listener already holds the
/// [PublishedVideo] this belongs to, and threading it through here would
/// couple the experiment to the publish bloc's state model.
class PostPublishConfirmationOffer {
  const PostPublishConfirmationOffer({required this.publishedAt});

  final DateTime publishedAt;
}

class PostPublishExperiment {
  PostPublishExperiment({
    required AnalyticsEventSink analytics,
    bool Function()? isEnabled,
    bool Function()? isTreatmentEnabled,
    RecordPostPublishExposure? recordExposure,
    DateTime Function()? now,
  }) : _analytics = analytics,
       _isEnabled = isEnabled ?? _alwaysEnabled,
       _isTreatmentEnabled = isTreatmentEnabled ?? _alwaysEnabled,
       _recordExposure = recordExposure,
       _now = now ?? DateTime.now;

  final AnalyticsEventSink _analytics;
  final bool Function() _isEnabled;
  final bool Function() _isTreatmentEnabled;
  final RecordPostPublishExposure? _recordExposure;
  final DateTime Function() _now;

  /// Pending assignments, oldest first. A publish that neither succeeds nor
  /// fails in this app session (a vanished background entry, a kill before
  /// the upload resolves) never reaches [completed] or [failed], so the map
  /// is capped and evicts its oldest entry instead of growing for the
  /// lifetime of the process.
  final Map<String, PostPublishVariant> _publishVariants = {};

  static const _maxPendingVariants = 32;
  static bool _alwaysEnabled() => true;

  PostPublishVariant variantForUser(String? pubkeyHex) {
    if (!_isEnabled() || pubkeyHex == null) return PostPublishVariant.control;
    // Lowercased so a signer that returns uppercase hex cannot move the same
    // account between buckets.
    final assignmentByte = sha256
        .convert(utf8.encode(pubkeyHex.toLowerCase()))
        .bytes
        .first;
    return assignmentByte < 128
        ? PostPublishVariant.control
        : PostPublishVariant.viewShare;
  }

  Future<void> screenShown({
    required String publishId,
    required String destination,
    required PostPublishVariant variant,
    bool isExperimentExposure = false,
  }) async {
    final enabled = _isEnabled();
    final activeVariant = enabled ? variant : PostPublishVariant.control;
    _publishVariants
      ..remove(publishId)
      ..[publishId] = activeVariant;
    while (_publishVariants.length > _maxPendingVariants) {
      _publishVariants.remove(_publishVariants.keys.first);
    }
    if (enabled && isExperimentExposure && _recordExposure != null) {
      try {
        await _recordExposure(activeVariant);
      } catch (error) {
        Log.warning(
          'Post-publish experiment exposure failed: $error',
          name: 'PostPublishExperiment',
          category: LogCategory.system,
        );
      }
    }
    await _logEvent(
      name: 'post_publish_screen_shown',
      parameters: {
        'destination': destination,
        'variant': activeVariant.analyticsName,
      },
    );
  }

  PostPublishConfirmationOffer? completed(Set<String> publishIds) {
    var assignedToTreatment = false;
    for (final publishId in publishIds) {
      final assignedVariant = _publishVariants.remove(publishId);
      assignedToTreatment =
          assignedVariant == PostPublishVariant.viewShare ||
          assignedToTreatment;
    }
    // The master switch is re-read here, not just at assignment time, so
    // flipping it off also drops a publish that was already in flight.
    final showConfirmation =
        assignedToTreatment && _isEnabled() && _isTreatmentEnabled();
    return showConfirmation
        ? PostPublishConfirmationOffer(publishedAt: _now())
        : null;
  }

  void failed(Set<String> publishIds) {
    publishIds.forEach(_publishVariants.remove);
  }

  Future<void> viewTapped(PostPublishConfirmationOffer offer) =>
      _logTap('post_publish_view_tapped', offer);

  Future<void> shareTapped(PostPublishConfirmationOffer offer) =>
      _logTap('post_publish_share_tapped', offer);

  Future<void> _logTap(String name, PostPublishConfirmationOffer offer) async {
    final elapsed = _now().difference(offer.publishedAt).inSeconds;
    await _logEvent(
      name: name,
      parameters: {'seconds_since_publish': elapsed < 0 ? 0 : elapsed},
    );
  }

  Future<void> _logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      Log.warning(
        'Post-publish analytics event $name failed: $error',
        name: 'PostPublishExperiment',
        category: LogCategory.system,
      );
    }
  }
}
