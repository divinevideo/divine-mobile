// ABOUTME: Input widget for setting "Inspired By" attribution on videos
// ABOUTME: Supports two modes: reference a specific video (a-tag) or
// ABOUTME: reference a creator (NIP-27 npub in content)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Input widget for setting "Inspired By" attribution.
///
/// Two modes:
/// - **Inspired by a creator**: stores npub, appended to content
///   as NIP-27 on publish.
/// - **Inspired by a video**: stores [InspiredByInfo] with
///   addressable event ID. (Future: video picker after creator
///   selection.)
class VideoMetadataInspiredByInput extends ConsumerWidget {
  /// Creates a video metadata inspired-by input widget.
  const VideoMetadataInspiredByInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspiredByNpubs = ref.watch(
      videoEditorProvider.select((s) => s.inspiredByNpubs),
    );
    final inspiredByVideo = ref.watch(
      videoEditorProvider.select((s) => s.inspiredByVideo),
    );

    final resolvedPubkeys = <String>[
      ?inspiredByVideo?.creatorPubkey,
      for (final npub in inspiredByNpubs) ?npubToHexOrNull(npub),
    ];
    final profiles = <UserProfile>[];
    final names = <String>[];
    for (final pubkey in resolvedPubkeys) {
      final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
      if (profile != null) profiles.add(profile);
      // Named even while the profile is still uncached: a credited creator
      // must never silently disappear from the tile, or the author cannot see
      // — or undo — who they picked.
      names.add(
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
      );
    }

    return VideoMetadataSelectionTile(
      onTap: () => _selectInspiredByPeople(context, ref, profiles),
      semanticsLabel: context.l10n.videoMetadataSetInspiredBySemanticLabel,
      labelText: context.l10n.videoMetadataInspiredByLabel,
      value: names.join(', '),
    );
  }

  Future<void> _selectInspiredByPeople(
    BuildContext context,
    WidgetRef ref,
    List<UserProfile> currentProfiles,
  ) async {
    final result = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.allUsers,
      autoFocus: true,
      title: context.l10n.videoMetadataInspiredByLabel,
      maxCount: VideoEditorConstants.maxInspiredByCreators,
      initialSelectedProfiles: currentProfiles,
    );
    if (result == null || !context.mounted) return;

    if (result.isEmpty) {
      ref.read(videoEditorProvider.notifier).clearInspiredBy();
      return;
    }

    // Someone who muted us cannot be credited, but that is no reason to drop
    // the others the author picked — skip them and say so once.
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final creditable = result
        .where((profile) => !blocklistRepository.hasMutedUs(profile.pubkey))
        .toList();

    if (creditable.length != result.length) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoMetadataCreatorCannotBeReferencedSnackbar,
        ),
      );
    }

    if (creditable.isEmpty) return;

    // Convert hex pubkeys to npubs for the NIP-27 content reference.
    ref.read(videoEditorProvider.notifier).setInspiredByPeople([
      for (final profile in creditable)
        NostrKeyUtils.encodePubKey(profile.pubkey),
    ]);
  }
}
