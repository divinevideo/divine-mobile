// ABOUTME: Collaborator avatar row for video feed overlay
// ABOUTME: Status-aware: hides current user's avatar when ignored locally,
// ABOUTME: greys pending avatars on the inviter's own video, otherwise
// ABOUTME: renders only confirmed collaborators to third-party viewers.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

const _pickerBaseChildSize = 0.24;
const _pickerChildSizePerCollaborator = 0.08;
const _pickerMinInitialChildSize = 0.36;
const _pickerMaxInitialChildSize = 0.68;
const _pickerMinChildSize = 0.28;
const _pickerMaxChildSize = 0.8;

/// Displays collaborator avatars on a video feed item.
///
/// Hides the current user's own avatar when their local invite store says
/// `ignored` for this video. On the inviter's own video, pending
/// collaborator avatars render greyed until a kind-34238 acceptance flips
/// them to confirmed. Third-party viewers only see confirmed collaborators
/// after the acceptance query resolves.
///
/// Returns [SizedBox.shrink] if the video has no collaborators after the
/// status-aware filter.
class CollaboratorAvatarRow extends ConsumerWidget {
  /// Creates a CollaboratorAvatarRow.
  const CollaboratorAvatarRow({required this.video, super.key});

  /// The video event to display collaborators for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasCollaborators) {
      return const SizedBox.shrink();
    }

    final pubkeys = video.collaboratorPubkeys;
    final repo = ref.watch(collaboratorConfirmationRepositoryProvider);
    final currentUserPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';
    final videoAddress = video.addressableId;

    // Fallback: render the raw p-tag list (current behaviour) when the
    // status pipeline is not available (repo gated on isNostrReady, or
    // the video has no addressable id).
    if (repo == null || videoAddress == null || currentUserPubkey.isEmpty) {
      return CollaboratorAvatarRowBody(
        visibility: CollaboratorVisibility.fallback(taggedPubkeys: pubkeys),
      );
    }

    return BlocProvider<VideoCollaboratorStatusCubit>(
      key: ValueKey((repo, videoAddress, Object.hashAll(pubkeys))),
      create: (_) => VideoCollaboratorStatusCubit(
        repository: repo,
        videoAddress: videoAddress,
        creatorPubkey: video.pubkey,
        taggedPubkeys: pubkeys,
      ),
      child: _StatusAwareRow(
        video: video,
        pubkeys: pubkeys,
        currentUserPubkey: currentUserPubkey,
      ),
    );
  }
}

class _StatusAwareRow extends StatelessWidget {
  const _StatusAwareRow({
    required this.video,
    required this.pubkeys,
    required this.currentUserPubkey,
  });

  final VideoEvent video;
  final List<String> pubkeys;
  final String currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    final statusByPubkey = context.select(
      (VideoCollaboratorStatusCubit c) => c.state.statusByPubkey,
    );
    final isResolved = context.select(
      (VideoCollaboratorStatusCubit c) => c.state.isResolved,
    );
    return CollaboratorAvatarRowBody(
      visibility: CollaboratorVisibility(
        taggedPubkeys: pubkeys,
        statusByPubkey: statusByPubkey,
        currentUserPubkey: currentUserPubkey,
        creatorPubkey: video.pubkey,
        isResolved: isResolved,
      ),
    );
  }
}

/// Renders the avatar row from a [CollaboratorVisibility].
///
/// Promoted to a top-level class with [visibleForTesting] so widget tests
/// can exercise every render branch without standing up a Riverpod
/// container, a `BlocProvider`, or a mock repository.
@visibleForTesting
class CollaboratorAvatarRowBody extends StatelessWidget {
  const CollaboratorAvatarRowBody({required this.visibility, super.key});

  final CollaboratorVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final visible = visibility.visiblePubkeys;
    if (visible.isEmpty) return const SizedBox.shrink();

    final pendingCount = visibility.pendingCount;

    return GestureDetector(
      onTap: () => _handleTap(context, visible),
      child: Semantics(
        identifier: 'collaborator_avatar_row',
        button: true,
        label: _semanticsLabel(context, visible.length),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineIcon(
                icon: DivineIconName.users,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 4),
              _CollaboratorAvatarStack(
                entries: [
                  for (final pubkey in visible.take(3))
                    _AvatarEntry(
                      pubkey: pubkey,
                      isPending: visibility.isPendingForInviter(pubkey),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _CollaboratorLabel(
                  pubkeys: visible,
                  pendingCount: pendingCount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, List<String> pubkeys) {
    if (pubkeys.length == 1) {
      _navigateToCollaborator(context, pubkeys.first);
      return;
    }

    _showCollaboratorPicker(context, pubkeys);
  }

  Future<void> _showCollaboratorPicker(
    BuildContext context,
    List<String> pubkeys,
  ) {
    return context.showVideoPausingVineBottomSheet<void>(
      title: Text(
        context.l10n.metadataCollaboratorsLabel,
        style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      ),
      buildScrollBody: (scrollController) => _CollaboratorPickerList(
        pubkeys: pubkeys,
        visibility: visibility,
        scrollController: scrollController,
      ),
      initialChildSize: _initialPickerSize(pubkeys.length),
      minChildSize: _pickerMinChildSize,
      maxChildSize: _pickerMaxChildSize,
    );
  }

  double _initialPickerSize(int count) {
    final size =
        _pickerBaseChildSize + (count * _pickerChildSizePerCollaborator);
    if (size < _pickerMinInitialChildSize) return _pickerMinInitialChildSize;
    if (size > _pickerMaxInitialChildSize) return _pickerMaxInitialChildSize;
    return size;
  }

  String _semanticsLabel(BuildContext context, int count) {
    if (count == 1) return context.l10n.videoCollaboratorCountLabel(count);
    return '${context.l10n.metadataCollaboratorsLabel}: $count';
  }

  void _navigateToCollaborator(BuildContext context, String pubkey) {
    Log.info(
      'Navigating to collaborator profile: ${pubkeyForLogs(pubkey)}',
      name: 'CollaboratorAvatarRow',
      category: LogCategory.ui,
    );

    final npub = normalizeToNpub(pubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}

class _CollaboratorPickerList extends StatelessWidget {
  const _CollaboratorPickerList({
    required this.pubkeys,
    required this.visibility,
    required this.scrollController,
  });

  final List<String> pubkeys;
  final CollaboratorVisibility visibility;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: pubkeys.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: context.vineColors.outlineDisabled,
      ),
      itemBuilder: (context, index) {
        final pubkey = pubkeys[index];
        return _CollaboratorPickerTile(
          pubkey: pubkey,
          isPending: visibility.isPendingForInviter(pubkey),
        );
      },
    );
  }
}

class _CollaboratorPickerTile extends ConsumerWidget {
  const _CollaboratorPickerTile({
    required this.pubkey,
    required this.isPending,
  });

  final String pubkey;
  final bool isPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));
    final name =
        profileAsync.value?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkey);

    final tile = Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: UserAvatar(
          imageUrl: profileAsync.value?.picture,
          name: name,
          size: 40,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VineTheme.titleSmallFont(color: context.vineColors.onSurface),
        ),
        subtitle: isPending
            ? Text(
                context.l10n.videoCollaboratorPendingDecoration,
                style: VineTheme.labelSmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              )
            : null,
        trailing: DivineIcon(
          icon: DivineIconName.caretRight,
          size: 18,
          color: context.vineColors.onSurfaceVariant,
        ),
        onTap: () => _navigateToProfile(context),
      ),
    );

    return Semantics(
      button: true,
      label: context.l10n.profileChipTapHint(name),
      child: isPending ? Opacity(opacity: 0.7, child: tile) : tile,
    );
  }

  void _navigateToProfile(BuildContext context) {
    final npub = normalizeToNpub(pubkey);
    if (npub == null) return;

    // Dismiss the sheet first, then navigate from the root navigator context.
    // GoRouter extensions can throw when called from inside a modal bottom
    // sheet (the router is not in the modal's widget tree).
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    // Defer to the next frame so the modal route's pop has settled in the
    // route stack before we push the destination route from the root
    // navigator's context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(OtherProfileScreen.pathForNpub(npub));
    });
  }
}

class _AvatarEntry {
  const _AvatarEntry({required this.pubkey, required this.isPending});

  final String pubkey;
  final bool isPending;
}

/// Small overlapping avatar circles.
class _CollaboratorAvatarStack extends StatelessWidget {
  const _CollaboratorAvatarStack({required this.entries});

  final List<_AvatarEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20.0 + (entries.length - 1) * 12.0,
      height: 20,
      child: Stack(
        children: [
          for (var i = 0; i < entries.length; i++)
            Positioned(
              left: i * 12.0,
              child: _SmallAvatar(
                pubkey: entries[i].pubkey,
                isPending: entries[i].isPending,
              ),
            ),
        ],
      ),
    );
  }
}

/// A small 20px avatar with white border.
class _SmallAvatar extends ConsumerWidget {
  const _SmallAvatar({required this.pubkey, required this.isPending});

  final String pubkey;
  final bool isPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    final avatar = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VineTheme.whiteText, width: 1.5),
      ),
      child: ClipOval(
        child: UserAvatar(
          imageUrl: profileAsync.value?.picture,
          name: profileAsync.value?.bestDisplayName,
          size: 17,
        ),
      ),
    );

    if (!isPending) return avatar;

    return Semantics(
      label: context.l10n.videoCollaboratorPendingSemanticLabel,
      child: Opacity(opacity: 0.55, child: avatar),
    );
  }
}

/// Text label showing collaborator name(s).
class _CollaboratorLabel extends ConsumerWidget {
  const _CollaboratorLabel({required this.pubkeys, required this.pendingCount});

  final List<String> pubkeys;
  final int pendingCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstProfile = ref.watch(fetchUserProfileProvider(pubkeys.first));

    final firstName =
        firstProfile.value?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkeys.first);

    final base = pubkeys.length == 1
        ? context.l10n.videoCollaboratorWithOne(firstName)
        : context.l10n.videoCollaboratorWithMore(firstName, pubkeys.length - 1);

    final label = pendingCount > 0
        ? context.l10n.videoCollaboratorWithPendingSuffix(base, pendingCount)
        : base;

    return Text(
      label,
      style: VineTheme.labelMediumFont(
        color: VineTheme.whiteText,
      ).copyWith(shadows: const [Shadow(blurRadius: 4)]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
