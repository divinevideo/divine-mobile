// ABOUTME: Locked "Uses a clip from {name}" rows shown in the post form for
// ABOUTME: every other creator whose clip is on the timeline; they can't be removed.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// One locked credit row per creator whose clip is on the timeline.
///
/// The credit is published from the clips themselves, so there is nothing for
/// the person posting to edit: the rows carry no remove control. The viewer's
/// own clips are not credited to themselves.
class VideoMetadataClipCredits extends ConsumerWidget {
  /// Creates the clip credit rows.
  const VideoMetadataClipCredits({super.key});

  /// The other creators credited by the clips on the timeline, each once.
  ///
  /// Watches the timeline, so a caller rebuilds when a clip is added or
  /// removed. The post form uses it to leave the row out entirely when nobody
  /// else is credited, so the empty row does not take a `spacing` gap.
  static List<String> creditedCreators(WidgetRef ref) {
    // The timeline is the source of truth; watching it rebuilds the rows when
    // a clip is added or removed.
    ref.watch(clipManagerProvider.select((state) => state.clips));
    final viewerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final pubkeys = <String>[];
    for (final credit
        in ref.read(videoEditorProvider.notifier).clipSourceCredits) {
      final author = credit.authorPubkey;
      if (viewerPubkey != null && pubkeysEqual(author, viewerPubkey)) continue;
      if (pubkeys.any((pubkey) => pubkeysEqual(pubkey, author))) continue;
      pubkeys.add(author);
    }
    return pubkeys;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkeys = creditedCreators(ref);
    if (pubkeys.isEmpty) return const SizedBox.shrink();

    // Inset like VideoMetadataSelectionTile, the other tiles in the form box.
    return Padding(
      padding: const .all(16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          for (final pubkey in pubkeys) _ClipCreditRow(pubkey: pubkey),
        ],
      ),
    );
  }
}

class _ClipCreditRow extends ConsumerWidget {
  const _ClipCreditRow({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(fetchUserProfileProvider(pubkey)).value;
    final hasName =
        (profile?.displayName?.isNotEmpty ?? false) ||
        (profile?.name?.isNotEmpty ?? false);
    final name = hasName
        ? profile!.bestDisplayName
        : NostrKeyUtils.encodePubKey(pubkey);
    final label = context.l10n.videoMetadataClipCreditRow(name);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        spacing: 8,
        children: [
          DivineIcon(
            icon: .lockSimple,
            size: 16,
            color: context.vineColors.onSurfaceMuted,
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
