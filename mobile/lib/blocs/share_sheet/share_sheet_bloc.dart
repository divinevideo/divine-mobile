// ABOUTME: BLoC for the unified share sheet
// ABOUTME: Manages contact loading, recipient selection, video sharing,
// ABOUTME: and one-shot actions (copy link, share via)

import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/share_sheet/reportable_sites.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';

/// BLoC for the unified share bottom sheet.
///
/// Manages:
/// - Contact loading (recent recipients, then followed and previously
///   messaged users in closeness order)
/// - Recipient selection (select-then-send: tapping a contact only selects;
///   the DM goes out on an explicit [ShareSheetSendRequested])
/// - One-shot actions (copy link, share via)
///
/// Emits [ShareSheetActionResult] as one-shot side effects for the UI
/// to handle (snackbars, clipboard, sheet dismissal).
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState>
    with CloseGuardedEmit<ShareSheetState> {
  ShareSheetBloc({
    required VideoEvent video,
    required VideoSharingService videoSharingService,
    required ProfileReader profileRepository,
    required FollowRepository followRepository,
    required UserRankingSignalsLoader rankingSignalsLoader,
    required String currentUserPubkey,
    BaseCacheManager? cacheManager,
  }) : _video = video,
       _videoSharingService = videoSharingService,
       _profileRepository = profileRepository,
       _followRepository = followRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _currentUserPubkey = currentUserPubkey,
       _cacheManager = cacheManager,
       super(const ShareSheetState()) {
    on<ShareSheetContactsLoadRequested>(_onContactsLoadRequested);
    on<ShareSheetRecipientToggled>(_onRecipientToggled);
    on<ShareSheetSendRequested>(_onSendRequested, transformer: droppable());
    on<ShareSheetCopyLinkRequested>(
      _onCopyLinkRequested,
      transformer: droppable(),
    );
    on<ShareSheetShareViaRequested>(
      _onShareViaRequested,
      transformer: droppable(),
    );
  }

  final VideoEvent _video;
  final VideoSharingService _videoSharingService;
  final ProfileReader _profileRepository;
  final FollowRepository _followRepository;
  final UserRankingSignalsLoader _rankingSignalsLoader;
  final String _currentUserPubkey;
  final BaseCacheManager? _cacheManager;

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
      // recents accumulate whoever a share was sent to. Retired moderation
      // accounts refuse sends, so they cannot be offered as recipients either.
      var recentUsers = _videoSharingService.recentlySharedWith
          .where((user) => _isSupportedRecipient(user.pubkey))
          .toList();
      final followList = _followRepository.followingPubkeys
          .where(_isSupportedRecipient)
          .toSet();
      final candidates = {
        ...followList,
        for (final user in recentUsers) user.pubkey,
      };
      Map<String, UserRankingSignals>? signals;
      try {
        signals = await _rankingSignalsLoader.load(
          candidates,
          includeDmCounterparts: true,
        );
      } catch (error, stackTrace) {
        // An unavailable local snapshot preserves the pre-ranking order. A
        // successful snapshot, including an empty one, is authoritative for
        // eligibility so excluded contacts cannot return through recents.
        addError(
          asReportableError(
                error,
                context: ShareSheetBlocReportableSites.onContactsLoadRequested,
              ) ??
              error,
          stackTrace,
        );
      }
      if (isClosed) return;
      final snapshot = signals;
      if (snapshot != null) {
        recentUsers = recentUsers
            .where((user) => snapshot.containsKey(user.pubkey))
            .toList();
      } else {
        recentUsers = recentUsers
            .where((user) => _rankingSignalsLoader.isEligible(user.pubkey))
            .toList();
        followList.removeWhere(
          (pubkey) => !_rankingSignalsLoader.isEligible(pubkey),
        );
      }
      final recentPubkeys = recentUsers.map((u) => u.pubkey).toSet();
      var remainingPubkeys = (snapshot?.keys ?? followList)
          .where(
            (pk) => _isSupportedRecipient(pk) && !recentPubkeys.contains(pk),
          )
          .toList();
      final excludedPubkeys = snapshot == null
          ? <String>{}
          : candidates.difference(snapshot.keys.toSet());

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
        for (final pubkey in remainingPubkeys)
          if (identifiedContact(pubkey, profiles[pubkey]) case final contact?)
            contact
          else if (includeMisses)
            ShareableUser.fromProfile(pubkey, null),
      ];

      List<ShareableUser> mergeVisibleContacts(List<ShareableUser> base) {
        final updates = {
          for (final contact in base)
            if (snapshot != null ||
                _rankingSignalsLoader.isEligible(contact.pubkey))
              contact.pubkey: contact,
        };
        final loadedPubkeys = {...recentPubkeys, ...remainingPubkeys};
        return [
          // Preserve the first visible order, including recipients selected
          // while the cache read or hydration was in flight. Identity-less
          // misses disappear after hydration; a miss that hydration identifies
          // keeps its place, and only rows not shown before append.
          for (final contact in state.contacts)
            if (_isSupportedRecipient(contact.pubkey) &&
                !excludedPubkeys.contains(contact.pubkey) &&
                (snapshot != null ||
                    _rankingSignalsLoader.isEligible(contact.pubkey)))
              if (updates.remove(contact.pubkey) case final updated?)
                updated
              else if (!loadedPubkeys.contains(contact.pubkey) &&
                  contact.hasVisibleIdentity)
                contact,
          ...updates.values,
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
      final cached = remainingPubkeys.isEmpty
          ? const <UserProfile>[]
          : await _profileRepository.getCachedProfiles(
              pubkeys: remainingPubkeys,
            );
      final cachedByPubkey = {
        for (final profile in cached)
          if (identifiedContact(profile.pubkey, profile) != null)
            profile.pubkey: profile,
      };
      if (snapshot != null) {
        remainingPubkeys = rankUsers(
          remainingPubkeys.map((pubkey) => snapshot[pubkey]!),
          now: DateTime.now(),
          nameOf: (pubkey) {
            final name = ShareableUser.fromProfile(
              pubkey,
              cachedByPubkey[pubkey],
            ).displayName?.trim();
            return name == null || name.isEmpty ? pubkey : name;
          },
          interactionTierFirst: true,
        );
      }
      final cacheFirstContacts = buildContacts(
        cachedByPubkey,
        includeMisses: true,
      );

      if (!emitIfOpen(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: mergeVisibleContacts(cacheFirstContacts),
          clearActionResult: true,
        ),
      )) {
        return;
      }
      _rankingSignalsLoader.refreshInBackground([
        for (final contact in state.contacts) contact.pubkey,
      ]);

      if (remainingPubkeys.isEmpty) return;
      // Sorted so the lookup carries which contacts are uncached, not how
      // close each one is: the ranked order comes from message history.
      final cacheMisses = [
        for (final pubkey in remainingPubkeys)
          if (!cachedByPubkey.containsKey(pubkey)) pubkey,
      ]..sort();
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
        final merged = mergeVisibleContacts(hydrated);
        emitIfOpen(
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
      emitIfOpen(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: [],
          clearActionResult: true,
        ),
      );
    }
  }

  /// Whether [pubkey] can receive a share through Divine.
  ///
  /// Compare the viewer case-insensitively because other clients may supply
  /// upper-case hex. Retired moderation accounts follow the shared send policy.
  bool _isSupportedRecipient(String pubkey) =>
      !pubkeysEqual(pubkey, _currentUserPubkey) &&
      !isRetiredModerationAccount(pubkey);

  // --------------------------------------------------------------------------
  // Recipient selection
  // --------------------------------------------------------------------------

  void _onRecipientToggled(
    ShareSheetRecipientToggled event,
    Emitter<ShareSheetState> emit,
  ) {
    final recipient = event.recipient;
    // Find People already leaves these out (#8351, #9711). Refused here too,
    // so no caller can select one.
    if (!_isSupportedRecipient(recipient.pubkey)) return;

    final updatedSelection = state.isSelected(recipient)
        ? [
            for (final r in state.selectedRecipients)
              if (r.pubkey != recipient.pubkey) r,
          ]
        : [...state.selectedRecipients, recipient];

    // Find People can pick someone who isn't in the contacts row yet —
    // prepend them so the selected contact is visible when the picker closes.
    // Keep every existing contact in its current relative order.
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

    // Wait only for local validation and durable enqueue. Relay discovery,
    // publishing and retries belong to the repository after the sheet closes.
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

      final sent = <ShareableUser>[];
      final retrying = <ShareableUser>[];
      final notSent = <ShareableUser>[];
      for (final r in recipients) {
        switch (results[r.pubkey]?.delivery) {
          case ShareDelivery.sent:
            sent.add(r);
          case ShareDelivery.retrying:
            retrying.add(r);
          case ShareDelivery.notSent || null:
            notSent.add(r);
        }
      }

      // Non-null for every selectable row — both pickers resolve the name
      // through `dmPeerDisplayName` before selection. The generated fallback
      // is the naming chain's own floor for a peer with no profile, and unlike
      // a bare 'user' it is neither English nor a second answer to "who is
      // this".
      List<String> namesOf(List<ShareableUser> users) => [
        for (final r in users)
          r.displayName ?? UserProfile.defaultDisplayNameFor(r.pubkey),
      ];

      // The send is dismiss-and-forget, so the selection is always cleared.
      // A queued recipient is replayed by OutgoingDmRetryService with the
      // SAME rumor id; re-sending from the sheet would mint a NEW one the
      // receiver can't dedup, delivering twice. A refused recipient was never
      // queued and a re-send is refused again. Neither is kept selected; the
      // result names both instead (#8672).
      if (retrying.isEmpty && notSent.isEmpty) {
        final single = recipients.length == 1 ? sent.single : null;
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendSuccess(
              recipientNames: namesOf(sent),
              recipientPubkey: single?.pubkey,
              conversationId: single == null
                  ? null
                  : results[single.pubkey]?.conversationId,
            ),
          ),
        );
      } else {
        Log.warning(
          'Share incomplete: ${sent.length} sent, ${retrying.length} queued '
          'for background retry, ${notSent.length} not sent',
          name: 'ShareSheetBloc',
          category: LogCategory.ui,
        );
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendIncomplete(
              sentNames: namesOf(sent),
              retryingNames: namesOf(retrying),
              notSentNames: namesOf(notSent),
            ),
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
  // Copy / Share actions (BLoC generates data, UI handles platform calls)
  // --------------------------------------------------------------------------

  Future<void> _onCopyLinkRequested(
    ShareSheetCopyLinkRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    try {
      final canonical = _videoSharingService.generateShareUrl(_video);
      final url = await _videoSharingService.shortenExternalUrl(canonical);
      if (isClosed || emit.isDone) return;
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
      if (isClosed || emit.isDone) return;
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  Future<void> _onShareViaRequested(
    ShareSheetShareViaRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    try {
      final shareData = _videoSharingService.generateShareData(_video);
      final shareUrl = await _videoSharingService.shortenExternalUrl(
        shareData.shareUrl,
      );
      if (isClosed || emit.isDone) return;

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

      if (isClosed || emit.isDone) return;
      final title = shareData.title;
      emit(
        state.copyWith(
          actionResult: ShareSheetShareViaTriggered(
            shareUrl: shareUrl,
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
      if (isClosed || emit.isDone) return;
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }
}
