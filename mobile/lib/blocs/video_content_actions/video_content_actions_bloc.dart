// ABOUTME: BLoC for per-video content actions (save, add to clips, remix, copy)
// ABOUTME: Shared by sheets that act on one video's bookmark, clip, and event

import 'dart:convert';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/video_content_actions/reportable_sites.dart';
import 'package:openvine/blocs/video_content_actions/video_content_action_rules.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/remix_consent_repository.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_content_actions_event.dart';
part 'video_content_actions_state.dart';

/// BLoC for the per-video content actions: save to bookmarks, add to the clip
/// library, get a remix ready, and copy the event JSON or event ID.
///
/// Emits [VideoContentActionResult] as one-shot side effects for the UI to
/// handle (snackbars, clipboard).
class VideoContentActionsBloc
    extends Bloc<VideoContentActionsEvent, VideoContentActionsState> {
  VideoContentActionsBloc({
    required VideoEvent video,
    required String relayUrl,
    BookmarksRepository? bookmarksRepository,
    VideoClipImportService? videoClipImportService,
    RemixConsentRepository? remixConsentRepository,
    String? viewerPubkey,
  }) : _video = video,
       _relayUrl = relayUrl,
       _bookmarksRepository = bookmarksRepository,
       _videoClipImportService = videoClipImportService,
       _remixConsentRepository = remixConsentRepository,
       _viewerPubkey = viewerPubkey,
       super(const VideoContentActionsState()) {
    on<VideoContentSaveRequested>(_onSaveRequested, transformer: droppable());
    on<VideoContentBookmarkStatusRequested>(
      _onBookmarkStatusRequested,
      transformer: droppable(),
    );
    on<VideoContentAddToClipsRequested>(
      _onAddToClipsRequested,
      transformer: droppable(),
    );
    on<VideoContentRemixRequested>(
      _onRemixRequested,
      transformer: droppable(),
    );
    on<VideoContentRemixLaunchFinished>(_onRemixLaunchFinished);
    on<VideoContentCopyEventJsonRequested>(_onCopyEventJsonRequested);
    on<VideoContentCopyEventIdRequested>(_onCopyEventIdRequested);
  }

  final VideoEvent _video;
  final String _relayUrl;
  final BookmarksRepository? _bookmarksRepository;
  final VideoClipImportService? _videoClipImportService;
  final RemixConsentRepository? _remixConsentRepository;

  /// The signed-in viewer, or null when signed out. A viewer may always use
  /// their own videos, so only someone else's video needs the creator's
  /// consent.
  final String? _viewerPubkey;

  /// Default library title for adding this video to clips, so widgets do not
  /// need to import the import service.
  String get defaultClipTitle =>
      VideoClipImportService.defaultLibraryTitleFor(_video);

  void _addUnexpectedError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    addError(Reportable(error, context: context), stackTrace);
  }

  /// Resolves [VideoContentActionsState.bookmarkStatus] from a relay-reconciled read.
  ///
  /// Uses the non-authoritative [BookmarksRepository.syncGlobalBookmarks] rather
  /// than the full-settlement form the toggle pays for. `requireAuthoritative`
  /// exists to stop a partially-read list from becoming the base of a
  /// replacing publish; a label publishes nothing, and the toggle reconciles
  /// authoritatively again before it acts. `ProfileSavedVideosBloc` reads
  /// bookmark state for display the same way.
  ///
  /// The status is left [VideoBookmarkStatus.unknown] when the read is
  /// inconclusive. Claiming "not saved" on a failed read is the mislabel this
  /// handler exists to remove.
  Future<void> _onBookmarkStatusRequested(
    VideoContentBookmarkStatusRequested event,
    Emitter<VideoContentActionsState> emit,
  ) async {
    final bookmarksRepository = _bookmarksRepository;
    if (bookmarksRepository == null || isClosed) return;

    try {
      final reconciled = await bookmarksRepository.syncGlobalBookmarks();
      if (isClosed ||
          !reconciled ||
          state.bookmarkStatus != VideoBookmarkStatus.unknown) {
        return;
      }

      // A list whose private items stayed encrypted cannot answer this: the
      // video may well be bookmarked inside `content`. Leaving the status
      // unresolved is the same call the inconclusive-read path makes above.
      if (bookmarksRepository.hasUnreadablePrivateItems) return;

      emit(
        state.copyWith(
          bookmarkStatus:
              bookmarksRepository.isVideoBookmarkedGlobally(
                _video.id,
                addressableId: _video.addressableId,
              )
              ? VideoBookmarkStatus.saved
              : VideoBookmarkStatus.notSaved,
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onBookmarkStatusRequested,
      );
      Log.warning(
        'Could not resolve bookmark status: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      Log.debug(
        'Bookmark status stack trace: $stackTrace',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
    }
  }

  Future<void> _onSaveRequested(
    VideoContentSaveRequested event,
    Emitter<VideoContentActionsState> emit,
  ) async {
    if (state.isActionInFlight) return;
    // Emitted before the toggle deliberately: it is a relay reconcile + sign
    // + publish, and emitting after it would leave the sheet inert for the
    // whole window, which is the bug (#7073).
    emit(state.copyWith(isSaving: true, clearActionResult: true));

    final bookmarksRepository = _bookmarksRepository;
    if (bookmarksRepository == null) {
      Log.warning(
        'Bookmark service unavailable — cannot save',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          isSaving: false,
          actionResult: VideoContentSaveResult(succeeded: false),
        ),
      );
      return;
    }

    // Best-effort guess, used only to word the message if the toggle throws
    // before it can report the reconciled state.
    var wasBookmarked = bookmarksRepository.isVideoBookmarkedGlobally(
      _video.id,
      addressableId: _video.addressableId,
    );
    try {
      // On the success path the direction comes from the toggle's own
      // reconciled read rather than the guess above — the two disagree when
      // the video was bookmarked on another device, and the sheet would then
      // claim the wrong outcome.
      // The coordinate keeps the bookmark on the video across edits, which
      // republish it under a new event id (#7135).
      final result = await bookmarksRepository.toggleVideoInGlobalBookmarks(
        _video.id,
        addressableId: _video.addressableId,
      );
      if (isClosed) return;

      wasBookmarked = result.wasBookmarked;
      emit(
        state.copyWith(
          isSaving: false,
          // Only a succeeded toggle reconciled with the relay. On failure
          // `isBookmarked` falls back to the pre-toggle guess, so adopting it
          // would launder a stale local read into a confident label.
          bookmarkStatus: result.succeeded
              ? (result.isBookmarked
                    ? VideoBookmarkStatus.saved
                    : VideoBookmarkStatus.notSaved)
              : state.bookmarkStatus,
          actionResult: VideoContentSaveResult(
            succeeded: result.succeeded,
            removed: result.succeeded && result.wasBookmarked,
            wasBookmarkedBeforeToggle: result.wasBookmarked,
            failure: result.failure,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onSaveRequested,
      );
      Log.error(
        'Failed to toggle bookmark: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      if (isClosed) return;

      emit(
        state.copyWith(
          isSaving: false,
          actionResult: VideoContentSaveResult(
            succeeded: false,
            wasBookmarkedBeforeToggle: wasBookmarked,
          ),
        ),
      );
    }
  }

  Future<void> _onAddToClipsRequested(
    VideoContentAddToClipsRequested event,
    Emitter<VideoContentActionsState> emit,
  ) async {
    if (state.isActionInFlight) return;
    // Emitted before the import so the action shows progress while the video
    // downloads.
    emit(state.copyWith(isImportingClip: true, clearActionResult: true));

    final importer = _videoClipImportService;
    if (importer == null) {
      Log.warning(
        'Video clip importer unavailable',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          isImportingClip: false,
          actionResult: VideoContentClipImportResult(succeeded: false),
        ),
      );
      return;
    }

    final consent = await _remixConsent();
    if (isClosed) return;
    if (consent != RemixConsent.allowed) {
      emit(
        state.copyWith(
          isImportingClip: false,
          actionResult: VideoContentRemixRefused(consent: consent),
        ),
      );
      return;
    }

    try {
      final result = await importer.importToLibrary(
        _video,
        libraryTitle: event.libraryTitle,
      );
      if (isClosed) return;

      emit(
        state.copyWith(
          isImportingClip: false,
          actionResult: VideoContentClipImportResult(
            succeeded: result is VideoClipImportSuccess,
            libraryTitle: result is VideoClipImportSuccess
                ? result.clip.libraryTitle
                : null,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onAddToClipsRequested,
      );
      Log.error(
        'Failed to import video clip: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      if (isClosed) return;

      emit(
        state.copyWith(
          isImportingClip: false,
          actionResult: VideoContentClipImportResult(succeeded: false),
        ),
      );
    }
  }

  /// Checks consent as Add to clips does, then emits [VideoContentRemixReady]
  /// with the clip the editor opens with. An import that fails reports as a
  /// failed Add to clips would.
  ///
  /// [VideoContentActionsState.isPreparingRemix] stays set with the ready
  /// result, holding the sheet's actions while the UI opens the editor, until
  /// [VideoContentRemixLaunchFinished]. Like every action, a request arriving
  /// while any action is in flight is ignored.
  Future<void> _onRemixRequested(
    VideoContentRemixRequested event,
    Emitter<VideoContentActionsState> emit,
  ) async {
    if (state.isActionInFlight) return;
    emit(state.copyWith(isPreparingRemix: true, clearActionResult: true));

    final consent = await _remixConsent();
    if (isClosed) return;
    if (consent != RemixConsent.allowed) {
      emit(
        state.copyWith(
          isPreparingRemix: false,
          actionResult: VideoContentRemixRefused(consent: consent),
        ),
      );
      return;
    }

    final clip = await _remixClip();
    if (isClosed) return;
    emit(
      state.copyWith(
        isPreparingRemix: clip != null,
        actionResult: clip == null
            ? VideoContentClipImportResult(succeeded: false)
            : VideoContentRemixReady(clip: clip),
      ),
    );
  }

  void _onRemixLaunchFinished(
    VideoContentRemixLaunchFinished event,
    Emitter<VideoContentActionsState> emit,
  ) {
    emit(state.copyWith(isPreparingRemix: false));
  }

  /// The clip a remix of this video opens with: the one an earlier import
  /// left in the library, or else a fresh import under [defaultClipTitle].
  ///
  /// Returns null when the video could not be imported.
  Future<DivineVideoClip?> _remixClip() async {
    final importer = _videoClipImportService;
    if (importer == null) {
      Log.warning(
        'Video clip importer unavailable — cannot remix',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      return null;
    }

    try {
      final earlierImport = await importer.findImportedClipOf(_video);
      if (earlierImport != null) return earlierImport;

      final result = await importer.importToLibrary(
        _video,
        libraryTitle: defaultClipTitle,
      );
      return result is VideoClipImportSuccess ? result.clip : null;
    } on Exception catch (e, stackTrace) {
      // A storage or platform failure is expected, not a defect, so it stays
      // out of crash reports.
      addError(e, stackTrace);
      Log.warning(
        'Could not prepare the remix clip: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      return null;
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onRemixRequested,
      );
      Log.error(
        'Failed to prepare the remix clip: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      return null;
    }
  }

  /// Whether the creator lets the viewer use this video as a clip.
  ///
  /// The viewer's own video skips the check. A video whose creator declined
  /// reuse ([canRemixVideo]) is [RemixConsent.blocked] without reading the
  /// account. Anything that prevents a confident answer — no repository
  /// wired, a failed read, an unexpected throw — comes back
  /// [RemixConsent.unknown], so the import fails closed.
  Future<RemixConsent> _remixConsent() async {
    final viewerPubkey = _viewerPubkey;
    if (viewerPubkey != null && pubkeysEqual(viewerPubkey, _video.pubkey)) {
      return RemixConsent.allowed;
    }
    if (!canRemixVideo(video: _video, isOwnContent: false)) {
      return RemixConsent.blocked;
    }

    final repository = _remixConsentRepository;
    if (repository == null) {
      Log.warning(
        'Remix consent repository unavailable — refusing the import',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      return RemixConsent.unknown;
    }

    try {
      return await repository.consentFor(_video.pubkey);
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.remixConsent,
      );
      Log.error(
        'Remix consent check failed: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      return RemixConsent.unknown;
    }
  }

  void _onCopyEventJsonRequested(
    VideoContentCopyEventJsonRequested event,
    Emitter<VideoContentActionsState> emit,
  ) {
    try {
      final json = const JsonEncoder.withIndent('  ').convert(_video.toJson());
      emit(
        state.copyWith(
          actionResult: VideoContentCopiedToClipboard(
            kind: VideoContentCopiedKind.eventJson,
            text: json,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onCopyEventJsonRequested,
      );
      Log.error(
        'Failed to generate event JSON: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: VideoContentActionFailure()));
    }
  }

  void _onCopyEventIdRequested(
    VideoContentCopyEventIdRequested event,
    Emitter<VideoContentActionsState> emit,
  ) {
    try {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: _video.id, author: _video.pubkey, relays: [_relayUrl]),
      );
      emit(
        state.copyWith(
          actionResult: VideoContentCopiedToClipboard(
            kind: VideoContentCopiedKind.eventId,
            text: nevent,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        VideoContentActionsReportableSites.onCopyEventIdRequested,
      );
      Log.error(
        'Failed to generate event ID: $e',
        name: 'VideoContentActionsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: VideoContentActionFailure()));
    }
  }
}
