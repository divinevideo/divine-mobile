// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Opens unified share sheet: tap a contact to select it (never an
// ABOUTME: instant send), compose an optional message, send explicitly.

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/delete_result_localization.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/crosspost_sheet.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:unified_logger/unified_logger.dart';

part 'share_sheet_header.dart';
part 'share_sheet_message_input.dart';
part 'share_sheet_more_actions.dart';
part 'share_with_section.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a unified share bottom sheet with:
/// - Video context/preview header
/// - "Share with" horizontal contact row with "Find people" search.
///   Tapping contacts toggles their selection (tick on the avatar) —
///   nothing is sent until the explicit send button, which fans the
///   video out to every selected person as separate DMs.
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

    context.showVideoPausingVineBottomSheet<void>(
      builder: (sheetContext) => _UnifiedShareSheet(
        video: video,
        profileRepository: profileRepository,
        videoSharingService: videoSharingService,
      ),
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
        Log.info(
          'Share button tapped for ${video.id}',
          name: 'ShareActionButton',
          category: LogCategory.ui,
        );
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

  @override
  void initState() {
    super.initState();
    if (_isUserOwnContent()) {
      _ownerVideoActionsCubit = OwnerVideoActionsCubit(
        contentDeletionService: () =>
            ref.read(contentDeletionServiceProvider.future),
        videoEventService: () => ref.read(videoEventServiceProvider),
        enforcementRepository: () =>
            ref.read(creatorDeleteEnforcementRepositoryProvider),
      );
      _crosspostCubit = VideoCrosspostCubit(
        client: ref.read(crossposterApiClientProvider),
        eventId: widget.video.id,
      )..loadConnections();
    }
    _shareSheetBloc =
        ShareSheetBloc(
            video: widget.video,
            relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
            videoSharingService: widget.videoSharingService,
            profileRepository: widget.profileRepository,
            followRepository: ref.read(followRepositoryProvider),
            // Empty when signed out: no viewer to exclude, and an empty
            // string never matches a real pubkey (#8351).
            currentUserPubkey:
                ref.read(authServiceProvider).currentPublicKeyHex ?? '',
            bookmarksRepositoryFuture: ref.read(
              bookmarksRepositoryProvider.future,
            ),
            cacheManager: openVineImageCache,
            videoClipImportService: ref.read(videoClipImportServiceProvider),
          )
          ..add(const ShareSheetContactsLoadRequested())
          ..add(const ShareSheetBookmarkStatusRequested());
  }

  @override
  void dispose() {
    _crosspostCubit?.close();
    _ownerVideoActionsCubit?.close();
    _shareSheetBloc.close();
    _messageController.dispose();
    super.dispose();
  }

  /// Dismisses the share sheet from a context inside it.
  ///
  /// Not `popModalIfMounted`: this sheet is dismissed from bloc listeners
  /// rather than from a button, so it has to survive being reached while
  /// GoRouter is out of the tree. It shares that helper's mounted guard —
  /// `canPop` reads an inherited widget and `Navigator.of` walks ancestors,
  /// and both throw on a context whose route is already gone (#6512).
  void _safePop(BuildContext ctx) {
    if (!ctx.mounted) {
      return;
    }
    try {
      if (ctx.canPop()) {
        ctx.pop();
        return;
      }
    } catch (_) {
      // GoRouter context extensions throw when the router is not in the
      // widget tree (e.g., inside modal bottom sheets). Fall through to
      // the standard Navigator as a safe fallback.
    }
    Navigator.of(ctx).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Provider scope and owner actions must come from the same decision made
    // in initState. Auth can change while the sheet is open; recomputing here
    // could expose owner UI without installing its cubit.
    final isOwnContent = _ownerVideoActionsCubit != null;
    final canAddVideoToClips =
        (widget.video.isOriginalVine || isOwnContent) && !kIsWeb;

    final sheetView = _UnifiedShareSheetView(
      video: widget.video,
      messageController: _messageController,
      isOwnContent: isOwnContent,
      onFindPeople: _handleFindPeople,
      onAddToList: _handleAddToList,
      onEditVideo: isOwnContent ? _handleEditVideo : null,
      onDeleteVideo: isOwnContent ? _handleDeleteVideo : null,
      onSaveOriginal: isOwnContent ? _handleSaveOriginal : null,
      onSaveWithWatermark: _handleSaveWithWatermark,
      onAddVideoToClips: canAddVideoToClips ? _handleAddVideoToClips : null,
      onCrosspost: _crosspostCubit != null ? _handleCrosspost : null,
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
                curr.selectedRecipients.length > prev.selectedRecipients.length,
            listener: (context, state) {
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
              );
            },
          ),
        ],
        child: switch (_crosspostCubit) {
          null => ownerAwareSheetView,
          final cubit => BlocProvider<VideoCrosspostCubit>.value(
            value: cubit,
            child: ownerAwareSheetView,
          ),
        },
      ),
    );
  }

  void _handleActionResult(BuildContext context, ShareSheetState state) {
    final result = state.actionResult;
    if (result == null) return;

    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case ShareSheetSendSuccess(
        :final recipientNames,
        :final recipientPubkey,
        :final conversationId,
      ):
        final sharedWithText = recipientNames.length == 1
            ? context.l10n.sharePostSharedWith(recipientNames.single)
            : context.l10n.sharePostSharedWithCount(recipientNames.length);
        final viewChatLabel = context.l10n.dmReelReplyViewChat;
        // "View chat" only when there is a single thread to open.
        final showViewChat = conversationId != null && recipientPubkey != null;
        // The snackbar action outlives the sheet, so capture a context that
        // survives the pop for the conversation push.
        final hostContext = Navigator.of(context, rootNavigator: true).context;
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            sharedWithText,
            actionLabel: showViewChat ? viewChatLabel : null,
            onActionPressed: showViewChat
                ? () {
                    if (!hostContext.mounted) return;
                    hostContext.push(
                      ConversationPage.pathForId(conversationId),
                      extra: [recipientPubkey],
                    );
                  }
                : null,
          ),
        );
      case ShareSheetSendFailure():
        // Dismiss too: the send is durably queued and retried in the
        // background, so there is no in-sheet manual retry to keep open for.
        _safePop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.shareFailedToSend,
              error: true,
            ),
          );
      case ShareSheetSaveResult(
        :final succeeded,
        :final removed,
        :final wasBookmarkedBeforeToggle,
        :final failure,
      ):
        // "Failed to add bookmark" names no recovery for the state the user is
        // almost certainly in, and after a long blocking wait that matters
        // more, not less. Both network-shaped failures are worded that way:
        // the read runs with requireAllRelaysSettled, so a single slow relay
        // reports timedOut while the device is merely degraded, not offline.
        // Everything else keeps today's copy.
        final snackText = succeeded
            ? (removed
                  ? context.l10n.shareRemovedFromBookmarks
                  : context.l10n.shareAddedToBookmarks)
            : switch (failure) {
                BookmarkToggleFailure.couldNotReachRelays ||
                BookmarkToggleFailure.timedOut =>
                  context.l10n.profileSetupNoRelaysConnected,
                _ =>
                  wasBookmarkedBeforeToggle
                      ? context.l10n.shareFailedToRemoveBookmark
                      : context.l10n.shareFailedToAddBookmark,
              };
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(snackText, error: !succeeded),
        );
      case ShareSheetVideoClipImportResult(
        :final succeeded,
        :final libraryTitle,
      ):
        final snackText = succeeded
            ? context.l10n.shareSheetSavedClipToClips(
                libraryTitle ?? context.l10n.shareSheetUntitledClip,
              )
            : context.l10n.shareSheetAddToClipsFailed;
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(snackText, error: !succeeded),
        );
      case ShareSheetCopiedToClipboard(:final kind, :final text):
        final snackText = switch (kind) {
          ShareSheetCopiedKind.postLink => context.l10n.shareCopiedPostLink,
          ShareSheetCopiedKind.eventJson => context.l10n.shareCopiedEventJson,
          ShareSheetCopiedKind.eventId => context.l10n.shareCopiedEventId,
        };
        Clipboard.setData(ClipboardData(text: text));
        _safePop(context);
        messenger.showSnackBar(DivineSnackbarContainer.snackBar(snackText));
      case ShareSheetShareViaTriggered(
        :final shareUrl,
        :final thumbnailPath,
        :final title,
        :final subject,
      ):
        final files = thumbnailPath != null ? [XFile(thumbnailPath)] : null;
        showShareSheet(
          context,
          ShareParams(
            text: shareUrl,
            files: files,
            title: title,
            subject: subject,
          ),
        );
      case ShareSheetActionFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareActionFailed,
            error: true,
          ),
        );
    }
  }

  Future<void> _handleAddVideoToClips() async {
    final initialTitle = VideoClipImportService.defaultLibraryTitleFor(
      widget.video,
    );
    final libraryTitle = await _ClipTitleSheet.show(
      context: context,
      initialTitle: initialTitle,
    );
    if (!mounted || libraryTitle == null) return;

    _shareSheetBloc.add(
      ShareSheetAddVideoToClipsRequested(libraryTitle: libraryTitle),
    );
  }

  Future<void> _handleFindPeople() async {
    final selectedUser = await FindPeopleSheet.show(
      context,
      contacts: _shareSheetBloc.state.contacts,
      currentUserPubkey:
          ref.read(authServiceProvider).currentPublicKeyHex ?? '',
    );
    if (selectedUser != null && mounted) {
      _shareSheetBloc.add(ShareSheetRecipientToggled(selectedUser));
    }
  }

  void _handleAddToList() {
    _presentAfterDismiss<void>((hostContext) {
      return showDialog<void>(
        context: hostContext,
        builder: (context) => SelectListDialog(video: widget.video),
      );
    });
  }

  void _handleEditVideo() {
    if (_ownerVideoActionsCubit?.isDeleteInProgress(widget.video.id) ?? false) {
      return;
    }
    _presentAfterDismiss<void>((hostContext) async {
      hostContext.push(
        VideoMetadataEditScreen.pathFor(widget.video.id),
        extra: widget.video,
      );
    });
  }

  Future<void> _handleDeleteVideo() async {
    final confirmed = await showOwnerVideoDeleteConfirmationDialog(context);
    if (confirmed && mounted) {
      await _deleteVideo();
    }
  }

  Future<void> _deleteVideo() async {
    final ownerVideoActionsCubit = _ownerVideoActionsCubit;
    if (ownerVideoActionsCubit == null) return;
    final start = await ownerVideoActionsCubit.deleteVideo(widget.video);
    if (start == OwnerVideoDeleteStart.busy) return;

    if (!mounted) return;

    final operation = ownerVideoActionsCubit.state.forVideo(widget.video.id);
    if (operation.deleteStatus == OwnerVideoDeleteStatus.success) {
      showOwnerVideoCleanupCompletion(
        context,
        ownerVideoActionsCubit,
        widget.video.id,
      );
      final messenger = ScaffoldMessenger.of(context);
      final snackBar = DivineSnackbarContainer.snackBar(
        localizedOwnerVideoDeleteSuccessMessage(context, operation),
        error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
      );
      _safePop(context);
      messenger.showSnackBar(snackBar);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          operation.deleteResult == null
              ? context.l10n.shareMenuDeleteFailedGeneric
              : localizedDeleteFailureMessage(context, operation.deleteResult!),
          error: true,
        ),
      );
    }
  }

  bool _isUserOwnContent() {
    try {
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) return false;

      final userPubkey = authService.currentPublicKeyHex;
      if (userPubkey == null) return false;

      return widget.video.pubkey == userPubkey;
    } catch (e) {
      Log.error(
        'Error checking content ownership: $e',
        name: 'ShareActionButton',
        category: LogCategory.ui,
      );
      return false;
    }
  }

  Future<void> _handleCrosspost() async {
    final connections = _crosspostCubit?.state.connectedConnections;
    if (connections == null || connections.isEmpty) return;
    await _presentAfterDismiss<void>((hostContext) {
      return showCrosspostSheet(
        context: hostContext,
        ref: ref,
        video: widget.video,
        connections: connections,
      );
    });
  }

  Future<void> _handleSaveOriginal() async {
    await _presentAfterDismiss<void>((hostContext) {
      return showSaveOriginalSheet(
        context: hostContext,
        ref: ref,
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

    await _presentAfterDismiss<void>((hostContext) {
      return showWatermarkDownloadSheet(
        context: hostContext,
        ref: ref,
        video: widget.video,
        watermarkText: watermarkText,
      );
    });
  }

  Future<T?> _presentAfterDismiss<T>(
    Future<T?> Function(BuildContext hostContext) presenter,
  ) async {
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    _safePop(context);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !hostContext.mounted) return null;
    return presenter(hostContext);
  }
}

class _ClipTitleSheet extends StatefulWidget {
  const _ClipTitleSheet({required this.initialTitle});

  final String initialTitle;

  static Future<String?> show({
    required BuildContext context,
    required String initialTitle,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      showHeaderDivider: false,
      body: _ClipTitleSheet(initialTitle: initialTitle),
    );
  }

  @override
  State<_ClipTitleSheet> createState() => _ClipTitleSheetState();
}

class _ClipTitleSheetState extends State<_ClipTitleSheet> {
  late final TextEditingController _controller;

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle)
      ..addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.shareSheetNameClipTitle,
                textAlign: TextAlign.center,
                style: VineTheme.headlineSmallFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.shareSheetNameClipSubtitle,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              DivineTextField(
                controller: _controller,
                labelText: context.l10n.shareSheetClipTitleLabel,
                maxLength: 80,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                onSubmitted: (_) => _save(),
                primaryWhenFilled: true,
              ),
              const SizedBox(height: 24),
              DivineButton(
                label: context.l10n.shareSheetSaveClip,
                onPressed: _canSave ? _save : null,
                expanded: true,
              ),
              const SizedBox(height: 12),
              DivineButton(
                label: context.l10n.commonCancel,
                type: DivineButtonType.secondary,
                onPressed: () => Navigator.of(context).pop(),
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
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
    required this.onAddToList,
    required this.onSaveWithWatermark,
    this.onAddVideoToClips,
    this.onEditVideo,
    this.onDeleteVideo,
    this.onSaveOriginal,
    this.onCrosspost,
  });

  final VideoEvent video;
  final TextEditingController messageController;
  final bool isOwnContent;
  final VoidCallback onFindPeople;
  final VoidCallback onAddToList;
  final VoidCallback? onEditVideo;
  final Future<void> Function()? onDeleteVideo;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final VoidCallback? onAddVideoToClips;
  final Future<void> Function()? onCrosspost;

  @override
  Widget build(BuildContext context) {
    final isDeletePending =
        isOwnContent &&
        context.select<OwnerVideoActionsCubit, bool>((cubit) {
          final operation = cubit.state.forVideo(video.id);
          return operation.deleteStatus == OwnerVideoDeleteStatus.deleting ||
              operation.cleanupStatus == OwnerVideoCleanupStatus.inProgress;
        });
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
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
            // behind the keyboard. Mirrors _ClipTitleSheet below.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: BlocBuilder<ShareSheetBloc, ShareSheetState>(
              builder: (context, state) {
                final bloc = context.read<ShareSheetBloc>();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragIndicator(),
                    _ShareSheetHeader(video: video),
                    Divider(color: context.vineColors.card, height: 1),
                    _ShareWithSection(
                      contacts: state.contacts,
                      contactsLoaded: state.contactsLoaded,
                      selectedPubkeys: {
                        for (final r in state.selectedRecipients) r.pubkey,
                      },
                      onFindPeople: onFindPeople,
                      // Select-then-send, multi-select: each tap toggles a
                      // recipient's tick. Nothing sends until the explicit
                      // send button. The draft survives selection changes
                      // and is dropped only when the last recipient is
                      // deselected.
                      onContactTapped: (user) {
                        final deselectingLast =
                            state.selectedRecipients.length == 1 &&
                            state.isSelected(user);
                        if (deselectingLast) messageController.clear();
                        bloc.add(ShareSheetRecipientToggled(user));
                      },
                    ),
                    if (state.selectedRecipients.isNotEmpty)
                      _MessageInput(
                        controller: messageController,
                        isSending: state.isSending,
                        onSend: () => bloc.add(
                          ShareSheetSendRequested(
                            message: messageController.text,
                          ),
                        ),
                      ),
                    if (state.selectedRecipients.isEmpty) ...[
                      Divider(color: context.vineColors.card, height: 1),
                      _MoreActionsSection(
                        video: video,
                        isOwnContent: isOwnContent,
                        isSavePending: state.isSaving,
                        isDeletePending: isDeletePending,
                        bookmarkStatus: state.bookmarkStatus,
                        onCrosspost: onCrosspost,
                        onSave: () => bloc.add(const ShareSheetSaveRequested()),
                        onSaveOriginal: onSaveOriginal,
                        onSaveWithWatermark: onSaveWithWatermark,
                        onAddVideoToClips: onAddVideoToClips,
                        onEditVideo: onEditVideo,
                        onDeleteVideo: onDeleteVideo,
                        onAddToList: onAddToList,
                        onCopyLink: () =>
                            bloc.add(const ShareSheetCopyLinkRequested()),
                        onShareVia: () =>
                            bloc.add(const ShareSheetShareViaRequested()),
                        onCopyEventJson: () =>
                            bloc.add(const ShareSheetCopyEventJsonRequested()),
                        onCopyEventId: () =>
                            bloc.add(const ShareSheetCopyEventIdRequested()),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
