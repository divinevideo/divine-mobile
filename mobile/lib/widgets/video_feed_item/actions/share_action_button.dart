// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Opens the unified share sheet for direct sends, optional messages,
// ABOUTME: and other ways to share a video.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';
import 'package:openvine/features/crossposting/crossposting_navigation.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/crosspost_sheet.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_share_prompt.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_feed_item/actions/owner_video_actions_setup.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_items.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_actions_scope.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';

part 'share_sheet_header.dart';
part 'share_sheet_message_input.dart';
part 'share_sheet_more_actions.dart';
part 'share_with_section.dart';

void _runShareDetached(Future<void> operation, String description) {
  runDetached(
    operation,
    description,
    logName: 'ShareActionButton',
    category: LogCategory.ui,
  );
}

/// Share action button for video overlay.
///
/// Shows a share icon that opens a unified share bottom sheet with:
/// - Video context/preview header
/// - "Share with" horizontal contact row with "Find people" search.
///   Tap a contact for a direct send, or long-press to start a selection.
///   While a selection is open, taps toggle recipients and the composer
///   sends the video to each selected person in a separate DM.
/// - Message composer shown while any recipient is selected (replaces
///   the actions row)
/// - "More actions" horizontal row (Save, download, Add to List, Copy,
///   Share via, debug tools)
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, this.onInteracted, super.key});

  final VideoEvent video;
  final VoidCallback? onInteracted;

  /// Opens the unified share sheet for the given [video].
  ///
  /// This is exposed as a static method so share entry points can reuse the
  /// same bottom-sheet wiring without duplicating setup logic.
  static void showShareSheet(BuildContext context, VideoEvent video) {
    // Read here so the sheet receives guaranteed non-null sharing dependencies.
    // Both are read-only handles, available once the identity is known — the
    // sheet no longer waits for relays to connect (#6423).
    final container = ProviderScope.containerOf(context);
    final profileRepository = container.read(profileReadRepositoryProvider);
    final videoSharingService = container.read(videoSharingServiceProvider);
    if (profileRepository == null || videoSharingService == null) return;

    _runShareDetached(
      context.showVideoPausingVineBottomSheet<void>(
        builder: (sheetContext) => _UnifiedShareSheet(
          video: video,
          profileRepository: profileRepository,
          videoSharingService: videoSharingService,
        ),
      ),
      'present share sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .shareFatDuo,
      semanticIdentifier: SemanticIds.shareButton,
      semanticLabel: context.l10n.shareVideoLabel,
      labelWhenZero: context.l10n.videoActionShareLabel,
      onPressed: () {
        onInteracted?.call();
        ShareActionButton.showShareSheet(context, video);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Share Sheet (Page — creates BLoC, handles side effects)
// ---------------------------------------------------------------------------

class _UnifiedShareSheet extends ConsumerStatefulWidget {
  const _UnifiedShareSheet({
    required this.video,
    required this.profileRepository,
    required this.videoSharingService,
  });

  final VideoEvent video;
  final ProfileReader profileRepository;
  final VideoSharingService videoSharingService;

  @override
  ConsumerState<_UnifiedShareSheet> createState() => _UnifiedShareSheetState();
}

class _UnifiedShareSheetState extends ConsumerState<_UnifiedShareSheet> {
  final TextEditingController _messageController = TextEditingController();
  late final ShareSheetBloc _shareSheetBloc;
  OwnerVideoActionsCubit? _ownerVideoActionsCubit;
  VideoCrosspostCubit? _crosspostCubit;
  bool _crosspostRowExposed = false;
  late final String? _owner;
  bool _findingPeople = false;

  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    if (isViewerOwnVideo(container, widget.video)) {
      _ownerVideoActionsCubit = createOwnerVideoActionsCubit(container);
      // Capture this owner's repository now; signing still waits for a tap.
      _crosspostCubit = VideoCrosspostCubit(
        repository: ref.read(crosspostingRepositoryProvider),
        eventId: widget.video.id,
      );
    }
    final auth = ref.read(authServiceProvider);
    final owner = _owner = auth.currentPublicKeyHex;
    final delivery = context.read<ShareDeliveryCubit?>();
    _shareSheetBloc = ShareSheetBloc(
      isOwnerCurrent: () => owner == auth.currentPublicKeyHex,
      onQueued: (outcome) {
        _runShareDetached(
          Future<void>.sync(
            () => delivery?.track(
              ownerPubkey: outcome.ownerPubkey,
              recipients: outcome.recipients,
            ),
          ),
          'track queued share',
        );
        _runShareDetached(HapticFeedback.lightImpact(), 'confirm queued share');
      },
      video: widget.video,
      videoSharingService: widget.videoSharingService,
      profileRepository: widget.profileRepository,
      followRepository: ref.read(followRepositoryProvider),
      rankingSignalsLoader: ref.read(userRankingSignalsLoaderProvider),
      eligibilityChanges: ref.read(contentBlocklistRepositoryProvider).changes,
      // Empty when signed out: no viewer to exclude, and an empty
      // string never matches a real pubkey (#8351).
      currentUserPubkey: owner ?? '',
      cacheManager: openVineImageCache,
    )..add(const ShareSheetContactsLoadRequested());
  }

  void _logCrosspostRowExposure() {
    if (!mounted || _crosspostRowExposed) return;
    _crosspostRowExposed = true;
    _runShareDetached(
      logCrosspostCtaShown(
        ref.read(analyticsEventSinkProvider),
        surface: CrosspostCtaSurface.shareSheet,
        cta: CrosspostCta.crosspostRow,
      ),
      'log crosspost row exposure',
    );
  }

  @override
  void dispose() {
    _closeCubitIfPresent(_crosspostCubit, 'crosspost');
    _closeCubitIfPresent(_ownerVideoActionsCubit, 'owner video actions');
    _runShareDetached(_shareSheetBloc.close(), 'close share sheet bloc');
    _messageController.dispose();
    super.dispose();
  }

  void _closeCubitIfPresent(BlocBase<Object?>? cubit, String name) {
    if (cubit == null) return;
    _runShareDetached(cubit.close(), 'close $name cubit');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nostrSessionProvider, (before, after) {
      if (after.pubkey != _owner ||
          after.phase == NostrSessionPhase.tearingDown) {
        _shareSheetBloc.add(const ShareSheetOwnerChanged());
      }
    });
    // Provider scope and owner actions must come from the same decision made
    // in initState. Auth can change while the sheet is open; recomputing here
    // could expose owner UI without installing its cubit.
    final isOwnContent = _ownerVideoActionsCubit != null;

    final sheetView = _UnifiedShareSheetView(
      video: widget.video,
      messageController: _messageController,
      isOwnContent: isOwnContent,
      onFindPeople: _handleFindPeople,
      onRecipientToggled: _toggleRecipient,
      onAddToList: () => openAddToList(context, widget.video),
      onEditVideo: switch (_ownerVideoActionsCubit) {
        null => null,
        final cubit => () => openOwnerVideoEditor(context, widget.video, cubit),
      },
      onDeleteVideo: switch (_ownerVideoActionsCubit) {
        null => null,
        final cubit => () => deleteOwnerVideoFromSheet(
          context,
          widget.video,
          cubit,
        ),
      },
      onSaveOriginal: isOwnContent ? _handleSaveOriginal : null,
      onSaveWithWatermark: _handleSaveWithWatermark,
      onCrosspost:
          isOwnContent &&
              ref.watch(crosspostingAvailabilityProvider) !=
                  CrosspostingAvailability.unavailable
          ? _handleCrosspost
          : null,
      onCrosspostShown: _logCrosspostRowExposure,
    );
    final ownerAwareSheetView = switch (_ownerVideoActionsCubit) {
      null => sheetView,
      final cubit => BlocProvider<OwnerVideoActionsCubit>.value(
        value: cubit,
        child: sheetView,
      ),
    };

    return BlocProvider.value(
      value: _shareSheetBloc,
      child: VideoContentActionsScope(
        video: widget.video,
        child: MultiBlocListener(
          listeners: [
            BlocListener<ShareSheetBloc, ShareSheetState>(
              listenWhen: (prev, curr) =>
                  curr.actionResult != null &&
                  prev.actionResult != curr.actionResult,
              listener: _handleActionResult,
            ),
            // Screen readers get no signal from the tick/composer swap when a
            // recipient is added — announce it.
            BlocListener<ShareSheetBloc, ShareSheetState>(
              listenWhen: (prev, curr) =>
                  curr.selectedRecipients.length >
                  prev.selectedRecipients.length,
              listener: (context, state) {
                _runShareDetached(
                  SemanticsService.sendAnnouncement(
                    View.of(context),
                    context.l10n.shareSelectedRecipientAnnouncement(
                      // Non-null for every selectable row: `_ContactItem` and
                      // `FindPeopleSheet` both resolve the name through
                      // `dmPeerDisplayName` before handing the recipient over.
                      state.selectedRecipients.last.displayName ??
                          UserProfile.defaultDisplayNameFor(
                            state.selectedRecipients.last.pubkey,
                          ),
                    ),
                    Directionality.of(context),
                  ),
                  'announce selected share recipient',
                );
              },
            ),
          ],
          child: VideoContentActionsFeedbackListener(
            child: switch (_crosspostCubit) {
              null => ownerAwareSheetView,
              final cubit => BlocProvider<VideoCrosspostCubit>.value(
                value: cubit,
                child: ownerAwareSheetView,
              ),
            },
          ),
        ),
      ),
    );
  }

  void _announceFailure(BuildContext context, String text) {
    _runShareDetached(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ),
      'announce share failure',
    );
  }

  void _handleActionResult(BuildContext context, ShareSheetState state) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    final result = state.actionResult;
    if (result == null || route?.isActive == false) return;
    if (route != null && !route.isCurrent) {
      // An owner switch retires both the share sheet and its open picker.
      // Late copy/send results must never pop the route on top.
      if (result is ShareSheetEnqueueResult &&
          result.recipients.any(
            (r) => r.outcome.delivery == ShareDelivery.queued,
          )) {
        route.navigator!.removeRoute(route);
        return;
      }
      if (result is! ShareSheetAccountChanged || !_findingPeople) return;
      Navigator.of(context).popUntil((candidate) => candidate == route);
    }

    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case ShareSheetEnqueueResult(:final recipients, :final noneQueued):
        if (noneQueued) {
          _announceFailure(
            context,
            recipients
                .map((r) => context.l10n.shareCouldNotSendTo(r.name))
                .join('\n'),
          );
          return;
        }
        dismissSheet(context);
      case ShareSheetAccountChanged():
        // Pop the same navigator that owns the share route, including when
        // the picker on that navigator has just begun its exit animation.
        if (route?.isCurrent ?? false) route!.navigator!.pop();
      case ShareSheetSendFailure():
        _announceFailure(context, context.l10n.shareFailedToSend);
      case ShareSheetCopiedToClipboard(:final kind, :final text):
        final snackText = switch (kind) {
          ShareSheetCopiedKind.postLink => context.l10n.shareCopiedPostLink,
        };
        _runShareDetached(
          Clipboard.setData(ClipboardData(text: text)),
          'copy share value to clipboard',
        );
        _warmShortLink(text);
        dismissSheet(context);
        messenger.showSnackBar(DivineSnackbarContainer.snackBar(snackText));
      case ShareSheetShareViaTriggered(
        :final shareUrl,
        :final thumbnailPath,
        :final title,
        :final subject,
      ):
        final files = thumbnailPath != null ? [XFile(thumbnailPath)] : null;
        _runShareDetached(
          showShareSheet(
            context,
            ShareParams(
              text: shareUrl,
              files: files,
              title: title,
              subject: subject,
            ),
          ),
          'present platform share sheet',
        );
        _warmShortLink(shareUrl);
      case ShareSheetActionFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareActionFailed,
            error: true,
          ),
        );
    }
  }

  // Called only after the clipboard/platform sheet handoff has started.
  void _warmShortLink(String url) {
    _runShareDetached(
      widget.videoSharingService.shortenExternalUrl(url).then<void>((_) {}),
      'warm external short link',
    );
  }

  Future<void> _handleFindPeople() async {
    _findingPeople = true;
    final selectedUser = await FindPeopleSheet.show(
      context,
      contacts: _shareSheetBloc.state.contacts,
      currentUserPubkey:
          ref.read(authServiceProvider).currentPublicKeyHex ?? '',
    );
    _findingPeople = false;
    if (selectedUser != null && mounted) {
      _toggleRecipient(selectedUser);
    }
  }

  void _toggleRecipient(ShareableUser user) {
    final state = _shareSheetBloc.state;
    if (state.isSending || state.ownerExpired) return;
    if (state.attemptedRecipients.length == 1 &&
        state.attemptedRecipients.single.pubkey == user.pubkey) {
      _messageController.clear();
    }
    _shareSheetBloc.add(ShareSheetRecipientToggled(user));
  }

  Future<void> _handleCrosspost() async {
    final cubit = _crosspostCubit;
    if (cubit == null) return;
    // A tap proves visibility even before the detector's batched callback.
    _logCrosspostRowExposure();
    _runShareDetached(
      logCrosspostCtaTapped(
        ref.read(analyticsEventSinkProvider),
        surface: CrosspostCtaSurface.shareSheet,
        cta: CrosspostCta.crosspostRow,
      ),
      'log crosspost row tap',
    );
    // Loading signs a request and may open an external signer. Defer it until
    // the creator explicitly chooses Crosspost rather than merely opening Share.
    if (cubit.state.status == VideoCrosspostStatus.initial) {
      final connectionsLoad = cubit.loadConnections();
      await connectionsLoad;
      if (!mounted) return;
    }
    // The row is offered before connections load; wait for them rather than
    // sending a creator who is already connected to setup.
    final state = cubit.state.status == VideoCrosspostStatus.loadingConnections
        ? await cubit.stream.firstWhere(
            (state) => state.status != VideoCrosspostStatus.loadingConnections,
            orElse: () => cubit.state,
          )
        : cubit.state;
    if (!mounted) return;
    final connections = state.connectedConnections;
    if (connections.isNotEmpty) {
      await presentAfterSheetDismiss<void>(context, (hostContext) {
        return showCrosspostSheet(
          context: hostContext,
          video: widget.video,
          connections: connections,
        );
      });
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);
    dismissSheet(context);
    await openCrosspostingSetup(container);
  }

  Future<void> _handleSaveOriginal() async {
    await presentAfterSheetDismiss<void>(context, (hostContext) {
      return showSaveOriginalSheet(
        context: hostContext,
        video: widget.video,
      );
    });
  }

  Future<void> _handleSaveWithWatermark() async {
    final profileRepo = ref.read(profileReadRepositoryProvider);
    final profile = await profileRepo?.getCachedProfile(
      pubkey: widget.video.pubkey,
    );
    final watermarkText = resolveWatermarkText(
      profile: profile,
      fallbackAuthorName: widget.video.displayAuthorName,
    );

    if (!mounted) return;
    await presentAfterSheetDismiss<void>(context, (hostContext) {
      return showWatermarkDownloadSheet(
        context: hostContext,
        video: widget.video,
        watermarkText: watermarkText,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Unified Share Sheet View (pure UI — reads BLoC state)
// ---------------------------------------------------------------------------

class _UnifiedShareSheetView extends StatelessWidget {
  const _UnifiedShareSheetView({
    required this.video,
    required this.messageController,
    required this.isOwnContent,
    required this.onFindPeople,
    required this.onRecipientToggled,
    required this.onAddToList,
    required this.onSaveWithWatermark,
    required this.onCrosspostShown,
    this.onEditVideo,
    this.onDeleteVideo,
    this.onSaveOriginal,
    this.onCrosspost,
  });

  final VideoEvent video;
  final TextEditingController messageController;
  final bool isOwnContent;
  final VoidCallback onFindPeople;
  final ValueChanged<ShareableUser> onRecipientToggled;
  final Future<void> Function() onAddToList;
  final Future<void> Function()? onEditVideo;
  final Future<void> Function()? onDeleteVideo;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final Future<void> Function()? onCrosspost;
  final VoidCallback onCrosspostShown;

  @override
  Widget build(BuildContext context) {
    final emailConfirmationRequired = context
        .select<EmailConfirmationCubit?, bool>(
          (cubit) => cubit?.state.isUnconfirmed ?? false,
        );
    final isDeletePending =
        isOwnContent &&
        context.select<OwnerVideoActionsCubit, bool>((cubit) {
          final operation = cubit.state.forVideo(video.id);
          return operation.deleteStatus == OwnerVideoDeleteStatus.deleting ||
              operation.cleanupStatus == OwnerVideoCleanupStatus.inProgress;
        });
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Material(
        color: context.vineColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          child: SingleChildScrollView(
            // Lift the content above the keyboard so the message TextField
            // stays visible when a recipient is selected. Without this the
            // sheet is anchored at the screen bottom and the field hides
            // behind the keyboard, as ClipTitleSheet does.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: BlocBuilder<ShareSheetBloc, ShareSheetState>(
              builder: (context, state) {
                final bloc = context.read<ShareSheetBloc>();
                final tapSends =
                    !emailConfirmationRequired &&
                    state.attemptedRecipients.isEmpty &&
                    messageController.text.isEmpty;

                // Read from lasting fields, not the one-off actionResult that
                // a background contact refresh clears.
                final error = state.sendFailed
                    ? context.l10n.shareFailedToSend
                    : state.refusedRecipients.isEmpty
                    ? null
                    : state.refusedRecipients
                          .map((r) => context.l10n.shareCouldNotSendTo(r.name))
                          .join('\n');
                final content = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragIndicator(),
                    _ShareSheetHeader(video: video),
                    Divider(color: context.vineColors.card, height: 1),
                    _ShareWithSection(
                      contacts: state.contacts,
                      contactsLoaded:
                          state.contactsLoaded || state.contacts.isNotEmpty,
                      disabledPubkeys: state.disabledPubkeys,
                      isSending: state.isSending,
                      tapSends: tapSends,
                      selectedPubkeys: {
                        for (final r in state.selectedRecipients) r.pubkey,
                      },
                      onFindPeople: onFindPeople,
                      // A tap sends to that person straight away. A
                      // long-press starts a selection for a message or more
                      // recipients; while one is open, taps toggle ticks and
                      // nothing sends until the composer's send button. The
                      // draft is dropped only when the last recipient is
                      // deselected.
                      onContactTapped: (user) => tapSends
                          ? bloc.add(ShareSheetSendRequested(only: user))
                          : onRecipientToggled(user),
                      onContactLongPressed: onRecipientToggled,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ColoredBox(
                          color: context.vineColors.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error,
                                style: VineTheme.bodyMediumFont(
                                  color: context.vineColors.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (state.attemptedRecipients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final user in state.attemptedRecipients)
                              InputChip(
                                selected: !state.disabledPubkeys.contains(
                                  user.pubkey,
                                ),
                                label: Text(
                                  user.displayName ??
                                      UserProfile.defaultDisplayNameFor(
                                        user.pubkey,
                                      ),
                                ),
                                onDeleted: state.isSending
                                    ? null
                                    : () => onRecipientToggled(user),
                              ),
                          ],
                        ),
                      ),
                    if (emailConfirmationRequired)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: EmailConfirmationSharePrompt(),
                      )
                    else if (state.attemptedRecipients.isNotEmpty)
                      _MessageInput(
                        controller: messageController,
                        isSending: state.isSending,
                        onSend: () => bloc.add(
                          ShareSheetSendRequested(
                            message: messageController.text,
                          ),
                        ),
                      ),
                    if (state.attemptedRecipients.isEmpty) ...[
                      Divider(color: context.vineColors.card, height: 1),
                      _MoreActionsSection(
                        video: video,
                        isOwnContent: isOwnContent,
                        isDeletePending: isDeletePending,
                        onCrosspost: onCrosspost,
                        onCrosspostShown: onCrosspostShown,
                        onSaveOriginal: onSaveOriginal,
                        onSaveWithWatermark: onSaveWithWatermark,
                        onEditVideo: onEditVideo,
                        onDeleteVideo: onDeleteVideo,
                        onAddToList: onAddToList,
                        onCopyLink: () =>
                            bloc.add(const ShareSheetCopyLinkRequested()),
                        onShareVia: () =>
                            bloc.add(const ShareSheetShareViaRequested()),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
                return ExcludeFocus(
                  excluding: state.isSending,
                  child: IgnorePointer(
                    ignoring: state.isSending,
                    child: content,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
