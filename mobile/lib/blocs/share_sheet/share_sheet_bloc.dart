// ABOUTME: BLoC for the unified share sheet
// ABOUTME: Manages contact loading, recipient selection, video sharing,
// ABOUTME: and one-shot actions (save, copy, share via)

import 'dart:convert';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/share_sheet/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';

/// BLoC for the unified share bottom sheet.
///
/// Manages:
/// - Contact loading (recent + followed users)
/// - Recipient selection (select-then-send: tapping a contact only selects;
///   the DM goes out on an explicit [ShareSheetSendRequested])
/// - One-shot actions (save, copy link, copy JSON, copy event ID, share via)
///
/// Emits [ShareSheetActionResult] as one-shot side effects for the UI
/// to handle (snackbars, clipboard, sheet dismissal).
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  ShareSheetBloc({
    required VideoEvent video,
    required String relayUrl,
    required VideoSharingService videoSharingService,
    required ProfileReader profileRepository,
    required FollowRepository followRepository,
    required String currentUserPubkey,
    Future<BookmarksRepository?>? bookmarksRepositoryFuture,
    BaseCacheManager? cacheManager,
    VideoClipImportService? videoClipImportService,
  }) : _video = video,
       _relayUrl = relayUrl,
       _videoSharingService = videoSharingService,
       _profileRepository = profileRepository,
       _followRepository = followRepository,
       _currentUserPubkey = currentUserPubkey,
       _bookmarksRepositoryFuture = bookmarksRepositoryFuture,
       _cacheManager = cacheManager,
       _videoClipImportService = videoClipImportService,
       super(const ShareSheetState()) {
    on<ShareSheetContactsLoadRequested>(_onContactsLoadRequested);
    on<ShareSheetRecipientToggled>(_onRecipientToggled);
    on<ShareSheetSendRequested>(_onSendRequested, transformer: droppable());
    on<ShareSheetSaveRequested>(_onSaveRequested, transformer: droppable());
    on<ShareSheetBookmarkStatusRequested>(
      _onBookmarkStatusRequested,
      transformer: droppable(),
    );
    on<ShareSheetAddVideoToClipsRequested>(
      _onAddVideoToClipsRequested,
      transformer: droppable(),
    );
    on<ShareSheetCopyLinkRequested>(_onCopyLinkRequested);
    on<ShareSheetShareViaRequested>(_onShareViaRequested);
    on<ShareSheetCopyEventJsonRequested>(_onCopyEventJsonRequested);
    on<ShareSheetCopyEventIdRequested>(_onCopyEventIdRequested);
  }

  final VideoEvent _video;
  final String _relayUrl;
  final VideoSharingService _videoSharingService;
  final ProfileReader _profileRepository;
  final FollowRepository _followRepository;
  final String _currentUserPubkey;
  final Future<BookmarksRepository?>? _bookmarksRepositoryFuture;
  final BaseCacheManager? _cacheManager;
  final VideoClipImportService? _videoClipImportService;

  void _addUnexpectedError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    addError(Reportable(error, context: context), stackTrace);
  }

  // --------------------------------------------------------------------------
  // Contact loading
  // --------------------------------------------------------------------------

  Future<void> _onContactsLoadRequested(
    ShareSheetContactsLoadRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    emit(
      state.copyWith(status: ShareSheetStatus.loading, clearActionResult: true),
    );

    try {
      // Divine does not support a self-addressed conversation (#8351), so
      // the viewer is never a share target. Both sources can carry them: a
      // contact list written by another Nostr client can self-follow, and
      // recents accumulate whoever a share was sent to.
      final recentUsers = _videoSharingService.recentlySharedWith
          .where((user) => !_isSelf(user.pubkey))
          .toList();
      final followList = _followRepository.followingPubkeys.where(
        (pubkey) => !_isSelf(pubkey),
      );
      final recentPubkeys = recentUsers.map((u) => u.pubkey).toSet();

      final remainingFollows = followList
          .where((pk) => !recentPubkeys.contains(pk))
          .toList();

      ShareableUser? identifiedContact(
        String pubkey,
        UserProfile? profile,
      ) {
        final contact = ShareableUser.fromProfile(pubkey, profile);
        return contact.hasVisibleIdentity ? contact : null;
      }

      List<ShareableUser> buildContacts(
        Map<String, UserProfile> profiles, {
        required bool includeMisses,
      }) => [
        ...recentUsers,
        for (final pubkey in remainingFollows)
          if (identifiedContact(pubkey, profiles[pubkey]) case final contact?)
            contact
          else if (includeMisses)
            ShareableUser.fromProfile(pubkey, null),
      ];

      List<ShareableUser> mergeVisibleExtras(List<ShareableUser> base) {
        final basePubkeys = {for (final contact in base) contact.pubkey};
        return [
          for (final contact in state.contacts)
            if (contact.hasVisibleIdentity &&
                !basePubkeys.contains(contact.pubkey))
              contact,
          ...base,
        ];
      }

      // Cache-first: one batched Drift read already covers what the visible
      // row needs, so the sheet renders now instead of shimmering through
      // the network batch. Recents already carry their display data
      // snapshotted at last-send time. Staleness is session-bounded:
      // VideoSharingService._recentlySharedWith is in-memory only and resets
      // to empty on app restart, so a stale avatar or name is visible at most
      // within the same session until the user shares with that contact
      // again. See #5391.
      final cached = remainingFollows.isEmpty
          ? const <UserProfile>[]
          : await _profileRepository.getCachedProfiles(
              pubkeys: remainingFollows,
            );
      final cachedByPubkey = {
        for (final profile in cached)
          if (identifiedContact(profile.pubkey, profile) != null)
            profile.pubkey: profile,
      };
      final cacheFirstContacts = buildContacts(
        cachedByPubkey,
        includeMisses: true,
      );

      emit(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: mergeVisibleExtras(cacheFirstContacts),
          clearActionResult: true,
        ),
      );

      if (remainingFollows.isEmpty) return;
      final cacheMisses = [
        for (final pubkey in remainingFollows)
          if (!cachedByPubkey.containsKey(pubkey)) pubkey,
      ];
      if (cacheMisses.isEmpty) return;

      // Hydrate the misses in the background and re-emit only when the row
      // would actually change. A failure here must not erase the cache-first
      // render already on screen.
      try {
        final profiles = await _profileRepository.fetchBatchProfiles(
          pubkeys: cacheMisses,
        );
        if (isClosed) return;

        final hydrated = buildContacts(
          {...cachedByPubkey, ...profiles},
          includeMisses: false,
        );
        // A recipient picked via Find People mid-hydration was prepended to
        // the row by the toggle handler; keep any still-visible extra contacts
        // in their current order through the swap.
        final merged = mergeVisibleExtras(hydrated);
        emit(
          state.copyWith(
            status: ShareSheetStatus.ready,
            contacts: merged,
            clearActionResult: true,
          ),
        );
      } catch (e, stackTrace) {
        _addUnexpectedError(
          e,
          stackTrace,
          ShareSheetBlocReportableSites.onContactsLoadRequested,
        );
        Log.warning(
          'Background contact hydration failed: $e',
          name: 'ShareSheetBloc',
          category: LogCategory.ui,
        );
      }
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onContactsLoadRequested,
      );
      Log.error(
        'Error loading contacts: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: [],
          clearActionResult: true,
        ),
      );
    }
  }

  /// Whether [pubkey] addresses the viewer.
  ///
  /// Case-insensitive, because a pubkey that reaches Divine from another
  /// client may be upper-case hex.
  bool _isSelf(String pubkey) => pubkeysEqual(pubkey, _currentUserPubkey);

  // --------------------------------------------------------------------------
  // Recipient selection
  // --------------------------------------------------------------------------

  void _onRecipientToggled(
    ShareSheetRecipientToggled event,
    Emitter<ShareSheetState> emit,
  ) {
    final recipient = event.recipient;
    // Find People searches all users, so it can surface the viewer even
    // though neither contact source offers them (#8351).
    if (_isSelf(recipient.pubkey)) return;

    final updatedSelection = state.isSelected(recipient)
        ? [
            for (final r in state.selectedRecipients)
              if (r.pubkey != recipient.pubkey) r,
          ]
        : [...state.selectedRecipients, recipient];

    // Find People can pick someone who isn't in the contacts row yet —
    // surface them at the front so their selection tick is visible.
    // Existing contacts stay in place: reordering under the user's
    // finger while multi-selecting is disorienting.
    final inContacts = state.contacts.any((c) => c.pubkey == recipient.pubkey);
    final updatedContacts = inContacts
        ? state.contacts
        : [recipient, ...state.contacts];

    emit(
      state.copyWith(
        selectedRecipients: updatedSelection,
        contacts: updatedContacts,
        clearActionResult: true,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Send with optional message
  // --------------------------------------------------------------------------

  Future<void> _onSendRequested(
    ShareSheetSendRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    if (state.selectedRecipients.isEmpty || state.isSending) return;

    // Deliberate compose-then-send: the awaited flow keeps a visible
    // "sending" spinner (isSending) and reports the outcome in-sheet.
    emit(state.copyWith(isSending: true, clearActionResult: true));

    try {
      final recipients = state.selectedRecipients;
      final message = event.message?.trim();

      // Fans out one DM per recipient (each gets its own gift wrap).
      final results = await _videoSharingService.shareVideoWithMultipleUsers(
        video: _video,
        recipientPubkeys: [for (final r in recipients) r.pubkey],
        personalMessage: message?.isEmpty == true ? null : message,
      );

      if (isClosed) return;

      final delivered = [
        for (final r in recipients)
          if (results[r.pubkey]?.success ?? false) r,
      ];
      final failedCount = recipients.length - delivered.length;

      // The send is dismiss-and-forget: a recipient publish that fails is
      // already durably enqueued (VideoSharingService -> DmRepository.
      // sendMessage enqueues before publish) and OutgoingDmRetryService
      // replays the SAME rumor id on the next app-foreground. Re-sending from
      // the sheet would mint a NEW rumor id the receiver can't dedup against
      // that replay, double-delivering — so we never keep recipients selected
      // for a manual retry. We report what was delivered and let the queue
      // finish the rest.
      if (delivered.isNotEmpty) {
        if (failedCount > 0) {
          Log.warning(
            'Partial share: ${delivered.length} delivered, $failedCount '
            'queued for background retry',
            name: 'ShareSheetBloc',
            category: LogCategory.ui,
          );
        }
        final single = delivered.length == 1 && recipients.length == 1
            ? delivered.single
            : null;
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendSuccess(
              recipientNames: [
                // Non-null for every selectable row — both pickers resolve the
                // name through `dmPeerDisplayName` before selection. The
                // generated fallback is the naming chain's own floor for a
                // peer with no profile, and unlike a bare 'user' it is neither
                // English nor a second answer to "who is this".
                for (final r in delivered)
                  r.displayName ?? UserProfile.defaultDisplayNameFor(r.pubkey),
              ],
              recipientPubkey: single?.pubkey,
              conversationId: single == null
                  ? null
                  : results[single.pubkey]?.conversationId,
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendFailure(),
          ),
        );
      }
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onSendRequested,
      );
      Log.error(
        'Failed to send video: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          selectedRecipients: const [],
          actionResult: ShareSheetSendFailure(),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Bookmark status (picks the save/remove row before it is tapped)
  // --------------------------------------------------------------------------

  /// Resolves [ShareSheetState.bookmarkStatus] from a relay-reconciled read.
  ///
  /// Uses the non-authoritative [BookmarksRepository.syncGlobalBookmarks] rather
  /// than the full-settlement form the toggle pays for. `requireAuthoritative`
  /// exists to stop a partially-read list from becoming the base of a
  /// replacing publish; a label publishes nothing, and the toggle reconciles
  /// authoritatively again before it acts. `ProfileSavedVideosBloc` reads
  /// bookmark state for display the same way.
  ///
  /// The status is left [ShareSheetBookmarkStatus.unknown] when the read is
  /// inconclusive. Claiming "not saved" on a failed read is the mislabel this
  /// handler exists to remove.
  Future<void> _onBookmarkStatusRequested(
    ShareSheetBookmarkStatusRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    final bookmarksRepository = await _bookmarksRepositoryFuture;
    if (bookmarksRepository == null || isClosed) return;

    try {
      final reconciled = await bookmarksRepository.syncGlobalBookmarks();
      if (isClosed ||
          !reconciled ||
          state.bookmarkStatus != ShareSheetBookmarkStatus.unknown) {
        return;
      }

      // A list whose private items stayed encrypted cannot answer this: the
      // video may well be bookmarked inside `content`. Leaving the status
      // unresolved is the same call the inconclusive-read path makes above.
      if (bookmarksRepository.hasUnreadablePrivateItems) return;

      emit(
        state.copyWith(
          bookmarkStatus:
              bookmarksRepository.isVideoBookmarkedGlobally(_video.id)
              ? ShareSheetBookmarkStatus.saved
              : ShareSheetBookmarkStatus.notSaved,
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onBookmarkStatusRequested,
      );
      Log.warning(
        'Could not resolve bookmark status: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      Log.debug(
        'Bookmark status stack trace: $stackTrace',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
    }
  }

  // --------------------------------------------------------------------------
  // Save to bookmarks
  // --------------------------------------------------------------------------

  Future<void> _onSaveRequested(
    ShareSheetSaveRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    // Emitted above the await deliberately: resolving the bookmark service is
    // itself a wait on a cold start, and the toggle below is a relay
    // reconcile + sign + publish. Emitting after it would leave the sheet
    // inert for the whole window, which is the bug (#7073).
    emit(state.copyWith(isSaving: true, clearActionResult: true));

    final bookmarksRepository = await _bookmarksRepositoryFuture;
    if (isClosed) return;

    if (bookmarksRepository == null) {
      Log.warning(
        'Bookmark service unavailable — cannot save',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          isSaving: false,
          actionResult: ShareSheetSaveResult(succeeded: false),
        ),
      );
      return;
    }

    // Best-effort guess, used only to word the message if the toggle throws
    // before it can report the reconciled state.
    var wasBookmarked = bookmarksRepository.isVideoBookmarkedGlobally(
      _video.id,
    );
    try {
      // On the success path the direction comes from the toggle's own
      // reconciled read rather than the guess above — the two disagree when
      // the video was bookmarked on another device, and the sheet would then
      // claim the wrong outcome.
      final result = await bookmarksRepository.toggleVideoInGlobalBookmarks(
        _video.id,
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
                    ? ShareSheetBookmarkStatus.saved
                    : ShareSheetBookmarkStatus.notSaved)
              : state.bookmarkStatus,
          actionResult: ShareSheetSaveResult(
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
        ShareSheetBlocReportableSites.onSaveRequested,
      );
      Log.error(
        'Failed to toggle bookmark: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      if (isClosed) return;

      emit(
        state.copyWith(
          isSaving: false,
          actionResult: ShareSheetSaveResult(
            succeeded: false,
            wasBookmarkedBeforeToggle: wasBookmarked,
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Add video to clips
  // --------------------------------------------------------------------------

  Future<void> _onAddVideoToClipsRequested(
    ShareSheetAddVideoToClipsRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    final importer = _videoClipImportService;
    if (importer == null) {
      Log.warning(
        'Video clip importer unavailable',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(succeeded: false),
        ),
      );
      return;
    }

    try {
      final result = await importer.importToLibrary(
        _video,
        libraryTitle: event.libraryTitle,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(
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
        ShareSheetBlocReportableSites.onAddVideoToClipsRequested,
      );
      Log.error(
        'Failed to import video clip: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(succeeded: false),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Copy / Share actions (BLoC generates data, UI handles platform calls)
  // --------------------------------------------------------------------------

  void _onCopyLinkRequested(
    ShareSheetCopyLinkRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final url = _videoSharingService.generateShareUrl(_video);
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.postLink,
            text: url,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyLinkRequested,
      );
      Log.error(
        'Failed to generate share link: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  Future<void> _onShareViaRequested(
    ShareSheetShareViaRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    try {
      final shareData = _videoSharingService.generateShareData(_video);

      // Download thumbnail if available and a cache manager was provided.
      // Copy to a temp file with a .jpg extension so iOS recognises it as
      // an image rather than a generic document.
      String? thumbnailPath;
      final thumbUrl = shareData.thumbnailUrl;
      if (thumbUrl != null && _cacheManager != null) {
        try {
          final file = await _cacheManager
              .getSingleFile(thumbUrl)
              .timeout(const Duration(seconds: 5));
          final tmpDir = Directory.systemTemp;
          final tmpFile = File('${tmpDir.path}/divine_share_thumb.jpg');
          await file.copy(tmpFile.path);
          thumbnailPath = tmpFile.path;
        } catch (e) {
          // Intentional silent fallback (no addError): sharing proceeds
          // without a thumbnail attachment. No caller-visible failure —
          // the share sheet still opens with the URL + title.
          Log.warning(
            'Thumbnail download failed, sharing without image: $e',
            name: 'ShareSheetBloc',
            category: LogCategory.ui,
          );
        }
      }

      final title = shareData.title;
      emit(
        state.copyWith(
          actionResult: ShareSheetShareViaTriggered(
            shareUrl: shareData.shareUrl,
            thumbnailPath: thumbnailPath,
            title: title,
            subject: title,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onShareViaRequested,
      );
      Log.error(
        'Failed to generate share data: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  void _onCopyEventJsonRequested(
    ShareSheetCopyEventJsonRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final json = const JsonEncoder.withIndent('  ').convert(_video.toJson());
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.eventJson,
            text: json,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyEventJsonRequested,
      );
      Log.error(
        'Failed to generate event JSON: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  void _onCopyEventIdRequested(
    ShareSheetCopyEventIdRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: _video.id, author: _video.pubkey, relays: [_relayUrl]),
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.eventId,
            text: nevent,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyEventIdRequested,
      );
      Log.error(
        'Failed to generate event ID: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }
}
