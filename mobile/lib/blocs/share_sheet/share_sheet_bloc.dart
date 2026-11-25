// ABOUTME: BLoC for the unified share sheet
// ABOUTME: Manages contact loading, recipient selection, video sharing,
// ABOUTME: and one-shot actions (copy link, share via)

import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
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
    this.isOwnerCurrent,
    Stream<void>? eligibilityChanges,
    BaseCacheManager? cacheManager,
  }) : _video = video,
       _videoSharingService = videoSharingService,
       _profileRepository = profileRepository,
       _followRepository = followRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _currentUserPubkey = currentUserPubkey,
       _cacheManager = cacheManager,
       super(
         ShareSheetState(
           contacts: [
             for (final user in videoSharingService.recentlySharedWith)
               if (!pubkeysEqual(user.pubkey, currentUserPubkey) &&
                   !isRetiredModerationAccount(user.pubkey) &&
                   rankingSignalsLoader.isEligible(user.pubkey))
                 user,
           ],
         ),
       ) {
    on<ShareSheetOwnerChanged>((_, emit) {
      _ownerExpired = true;
      emit(ShareSheetState(actionResult: ShareSheetAccountChanged()));
    });
    on<ShareSheetEligibilityChanged>((event, emit) {
      if (!_checkOwner()) return;
      emit(state.copyWith(disabledPubkeys: _disabled(state.contacts)));
    });
    _eligibility = eligibilityChanges?.listen((_) {
      addIfOpen(const ShareSheetEligibilityChanged());
    });
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

  StreamSubscription<void>? _eligibility;

  @override
  Future<void> close() async {
    await _eligibility?.cancel();
    return super.close();
  }

  bool _ownerExpired = false;
  bool _checkOwner() {
    if (isClosed) return false;
    if (!_ownerExpired && isOwnerCurrent?.call() != false) return true;
    _ownerExpired = true;
    emitIfOpen(ShareSheetState(actionResult: ShareSheetAccountChanged()));
    return false;
  }

  Set<String> _disabled(Iterable<ShareableUser> contacts) => {
    for (final contact in contacts)
      if (!_rankingSignalsLoader.isEligible(contact.pubkey)) contact.pubkey,
  };

  final VideoEvent _video;
  final VideoSharingService _videoSharingService;
  final ProfileReader _profileRepository;
  final FollowRepository _followRepository;
  final UserRankingSignalsLoader _rankingSignalsLoader;
  final String _currentUserPubkey;
  final bool Function()? isOwnerCurrent;
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
      try {
        await _videoSharingService.warmRecents(_currentUserPubkey);
      } on Object catch (error, stackTrace) {
        _addUnexpectedError(
          error,
          stackTrace,
          ShareSheetBlocReportableSites.onContactsLoadRequested,
        );
      }
      if (!_checkOwner()) return;
      var recentUsers = _videoSharingService.recentlySharedWith
          .where((user) => _isSupportedRecipient(user.pubkey))
          .toList();
      final visibleKeys = state.contacts.map((u) => u.pubkey).toSet();
      final newlyWarm = recentUsers
          .where(
            (u) =>
                u.hasVisibleIdentity &&
                _rankingSignalsLoader.isEligible(u.pubkey) &&
                visibleKeys.add(u.pubkey),
          )
          .toList();
      if (newlyWarm.isNotEmpty) {
        emitIfOpen(
          state.copyWith(contacts: [...state.contacts, ...newlyWarm]),
        );
      }
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
      if (!_checkOwner()) return;
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

      List<ShareableUser> mergeVisibleContacts(
        List<ShareableUser> base, {
        bool finished = false,
      }) {
        final updates = {
          for (final contact in base)
            if (_rankingSignalsLoader.isEligible(contact.pubkey))
              contact.pubkey: contact,
        };
        final merged = [
          for (final contact in state.contacts)
            updates.remove(contact.pubkey) ?? contact,
          ...updates.values,
        ];
        // Removing an unresolved slot ahead of a visible person would move
        // that person's Send button. Only trailing empty slots can disappear.
        if (finished) {
          while (merged.isNotEmpty && !merged.last.hasVisibleIdentity) {
            merged.removeLast();
          }
        }
        return merged;
      }

      // Read identities in one local batch before hydrating misses.
      final cached = remainingPubkeys.isEmpty
          ? const <UserProfile>[]
          : await _profileRepository.getCachedProfiles(
              pubkeys: remainingPubkeys,
            );
      if (!_checkOwner()) return;
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

      final visible = mergeVisibleContacts(cacheFirstContacts);
      if (!emitIfOpen(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: visible,
          disabledPubkeys: {..._disabled(visible), ...excludedPubkeys},
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
        if (!_checkOwner()) return;

        final hydrated = buildContacts(
          {...cachedByPubkey, ...profiles},
          includeMisses: false,
        );
        final merged = mergeVisibleContacts(hydrated, finished: true);
        emitIfOpen(
          state.copyWith(
            status: ShareSheetStatus.ready,
            contacts: merged,
            disabledPubkeys: {
              ..._disabled(merged),
              ...excludedPubkeys,
              for (final contact in merged)
                if (!contact.hasVisibleIdentity) contact.pubkey,
            },
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
      if (!_checkOwner()) return;
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
          contacts: state.contacts,
          disabledPubkeys: _disabled(state.contacts),
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
    if (!_checkOwner() || state.isSending) return;
    final alreadyPicked = state.attemptedRecipients.any(
      (r) => r.pubkey == recipient.pubkey,
    );
    if (!alreadyPicked &&
        (!_isSupportedRecipient(recipient.pubkey) ||
            !_rankingSignalsLoader.isEligible(recipient.pubkey) ||
            state.disabledPubkeys.contains(recipient.pubkey))) {
      return;
    }

    final updatedSelection = alreadyPicked
        ? [
            for (final r in state.attemptedRecipients)
              if (r.pubkey != recipient.pubkey) r,
          ]
        : [...state.attemptedRecipients, recipient];

    // Find People can pick someone who isn't in the contacts row yet —
    // append them so existing contacts retain their positions.
    // Keep every existing contact in its current relative order.
    final inContacts = state.contacts.any((c) => c.pubkey == recipient.pubkey);
    final updatedContacts = inContacts
        ? state.contacts
        : [...state.contacts, recipient];

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
    final only = event.only;
    if (only != null &&
        (state.attemptedRecipients.isNotEmpty ||
            (event.message?.trim().isNotEmpty ?? false))) {
      return;
    }
    final recipients = only == null ? state.attemptedRecipients : [only];
    if (recipients.isEmpty || state.isSending) return;
    if (_ownerExpired || isOwnerCurrent?.call() == false) {
      emit(state.copyWith(actionResult: ShareSheetAccountChanged()));
      return;
    }

    // Wait only for local validation and durable enqueue. Relay discovery,
    // publishing and retries belong to the repository after the sheet closes.
    emit(state.copyWith(isSending: true, clearActionResult: true));

    try {
      final message = event.message?.trim();

      // Fans out one DM per recipient (each gets its own gift wrap).
      final eligible = [
        for (final recipient in recipients)
          if (_isSupportedRecipient(recipient.pubkey) &&
              !state.disabledPubkeys.contains(recipient.pubkey) &&
              _rankingSignalsLoader.isEligible(recipient.pubkey))
            recipient.pubkey,
      ];
      final results = eligible.isEmpty
          ? const <String, ShareResult>{}
          : await _videoSharingService.shareVideoWithMultipleUsers(
              video: _video,
              recipientPubkeys: eligible,
              personalMessage: message?.isEmpty == true ? null : message,
            );

      if (isClosed) return;

      if (_ownerExpired || isOwnerCurrent?.call() == false) {
        emit(
          state.copyWith(
            isSending: false,
            actionResult: ShareSheetAccountChanged(),
          ),
        );
        return;
      }
      final attempted = [
        for (final r in recipients)
          (
            pubkey: r.pubkey,
            name: r.displayName ?? UserProfile.defaultDisplayNameFor(r.pubkey),
            outcome:
                results[r.pubkey.trim().toLowerCase()] ??
                const ShareResult.failure('Recipient unavailable'),
          ),
      ];
      final queued = attempted.any(
        (r) => r.outcome.delivery == ShareDelivery.queued,
      );
      emit(
        state.copyWith(
          isSending: false,
          selectedRecipients: queued ? const [] : recipients,
          actionResult: ShareSheetEnqueueResult(_currentUserPubkey, attempted),
        ),
      );
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
          actionResult: _ownerExpired || isOwnerCurrent?.call() == false
              ? ShareSheetAccountChanged()
              : ShareSheetSendFailure(),
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
