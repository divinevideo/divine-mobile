// ABOUTME: Drives the moderation-check gate during video loading.
// ABOUTME: Emits blocked/quarantined and age-restricted results separately.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

/// Performs a moderation check during the video loading phase.
///
/// Fetches the moderation status for the video's sha256. If the content is
/// blocked/quarantined, emits [FeedLoadingModerationStatus.restricted]. If the
/// content is age-restricted, emits [FeedLoadingModerationStatus.ageRestricted].
/// Otherwise the state remains [FeedLoadingModerationStatus.loading] for the
/// lifetime of the cubit.
///
/// Call [start] immediately after the cubit is constructed.
class FeedLoadingModerationCubit extends Cubit<FeedLoadingModerationState> {
  /// Creates the cubit and resolves the video's sha256 from [explicitSha256]
  /// or [videoUrl]. No request is started until [start] is called.
  ///
  /// When [VideoModerationStatusService.shouldCheckModeration] returns
  /// `false` for [videoUrl], or when no sha256 can be resolved, [start]
  /// is a no-op and the cubit stays in the [FeedLoadingModerationStatus.loading]
  /// state forever (meaning no moderation overlay is shown).
  /// Default delay before hitting the moderation API while a video is loading.
  ///
  /// Cached and fast-starting videos unmount the loading overlay well before
  /// this threshold, avoiding a wasted HTTP round-trip on every swipe.
  static const defaultCheckDelay = Duration(milliseconds: 1200);

  FeedLoadingModerationCubit({
    required VideoModerationStatusService service,
    required String? explicitSha256,
    required String? videoUrl,
    Duration checkDelay = defaultCheckDelay,
  }) : _service = service,
       _checkDelay = checkDelay,
       _sha256 = VideoModerationStatusService.shouldCheckModeration(videoUrl)
           ? VideoModerationStatusService.resolveSha256(
               explicitSha256: explicitSha256,
               videoUrl: videoUrl,
             )
           : null,
       super(const FeedLoadingModerationState());

  final VideoModerationStatusService _service;
  final Duration _checkDelay;

  /// The resolved, normalised sha256 for this video, or `null` when the
  /// moderation check is not applicable.
  final String? _sha256;

  Timer? _delayTimer;
  bool _started = false;

  /// Starts the moderation check after [_checkDelay].
  ///
  /// No-ops when there is no resolvable sha256 for this video, or when already
  /// started or closed.
  void start() {
    final sha256 = _sha256;
    if (sha256 == null || _started || isClosed) return;
    _started = true;
    if (_checkDelay <= Duration.zero) {
      unawaited(_checkModeration(sha256));
      return;
    }
    _delayTimer = Timer(_checkDelay, () {
      _delayTimer = null;
      unawaited(_checkModeration(sha256));
    });
  }

  @override
  Future<void> close() {
    _delayTimer?.cancel();
    _delayTimer = null;
    return super.close();
  }

  Future<void> _checkModeration(String sha256) async {
    if (isClosed) return;
    try {
      final status = await _service.fetchStatus(sha256);
      if (isClosed) return;
      if (status == null) return;
      if (status.blocked || status.quarantined) {
        emit(state.copyWith(status: FeedLoadingModerationStatus.restricted));
      } else if (status.ageRestricted) {
        emit(state.copyWith(status: FeedLoadingModerationStatus.ageRestricted));
      }
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }
}
