// ABOUTME: Input widget for setting "Inspired By" attribution on videos
// ABOUTME: Supports two modes: reference a specific video (a-tag) or
// ABOUTME: reference a creator (NIP-27 npub in content)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
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

/// Preserves credited creators whose profiles were unavailable when the
/// picker opened, so they are not silently dropped on Done.
///
/// The picker is seeded only with profiles that resolved, and Done returns
/// exactly what it was seeded with plus the author's toggles. A creator it
/// never showed cannot have been deselected there, so dropping them would
/// remove a credit the tile still lists and the author never touched.
///
/// The author's order leads: position 0 is the creator the NIP-27 content
/// line names, so crediting someone new must not promote them past the first
/// pick. New picks are appended, and the result is capped at [maxCount]
/// because reconciling can otherwise exceed what the picker itself allows.
@visibleForTesting
List<String> computeEffectiveInspiredByNpubs({
  required List<String> confirmedNpubs,
  required List<String> preselectedNpubs,
  required List<String> pickerResultNpubs,
  int maxCount = VideoEditorConstants.maxInspiredByCreators,
}) {
  String keyOf(String npub) =>
      npubToHexOrNull(npub) ?? npub.trim().toLowerCase();

  final preselected = preselectedNpubs.map(keyOf).toSet();
  final picked = pickerResultNpubs.map(keyOf).toSet();

  final effective = <String>[];
  final seen = <String>{};
  void add(String npub) {
    if (seen.add(keyOf(npub))) effective.add(npub);
  }

  for (final npub in confirmedNpubs) {
    final key = keyOf(npub);
    if (picked.contains(key) || !preselected.contains(key)) add(npub);
  }
  pickerResultNpubs.forEach(add);

  return effective.length <= maxCount
      ? effective
      : effective.sublist(0, maxCount);
}

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

    // Deduplicated: editing a published video seeds the a-tag creator into
    // both [inspiredByVideo] and [inspiredByNpubs], because that creator is
    // carried by an inspired-by p-tag too. Naming them twice would also cost
    // them a second slot in the picker.
    final resolvedPubkeys = <String>[];
    for (final candidate in <String>[
      ?inspiredByVideo?.creatorPubkey,
      for (final npub in inspiredByNpubs) ?npubToHexOrNull(npub),
    ]) {
      final normalized = candidate.trim().toLowerCase();
      if (normalized.isNotEmpty && !resolvedPubkeys.contains(normalized)) {
        resolvedPubkeys.add(normalized);
      }
    }
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

    // Convert hex pubkeys to npubs for the NIP-27 content reference.
    ref
        .read(videoEditorProvider.notifier)
        .setInspiredByPeople(
          computeEffectiveInspiredByNpubs(
            confirmedNpubs: ref.read(videoEditorProvider).inspiredByNpubs,
            preselectedNpubs: [
              for (final profile in currentProfiles)
                NostrKeyUtils.encodePubKey(profile.pubkey),
            ],
            pickerResultNpubs: [
              for (final profile in creditable)
                NostrKeyUtils.encodePubKey(profile.pubkey),
            ],
          ),
        );
  }
}
