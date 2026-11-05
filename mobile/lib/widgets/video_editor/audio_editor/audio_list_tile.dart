import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/divine_sound_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_list_tile.dart';

/// A sound in the picker's lists.
class AudioListTile extends StatelessWidget {
  const AudioListTile({
    required this.audio,
    required this.isSelected,
    required this.onTap,
    this.displayTitle,
    this.cover,
    this.isCoverPending = false,
    this.isPlaying = false,
    this.isUnavailable = false,
    this.videoCount,
    this.semanticIdentifier,
    super.key,
  });

  final AudioEvent audio;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  /// Title to show instead of [AudioEvent.title].
  ///
  /// The saved-sounds list passes the private label the user gave the sound,
  /// so the row reads the way they filed it — the same name the Library shows
  /// and the one a search on that label just matched. It is display only: the
  /// [audio] handed to the editor keeps its published title, which is what
  /// gets credited.
  final String? displayTitle;

  /// See [SoundListTile.cover].
  final SoundCover? cover;

  /// See [SoundListTile.isCoverPending].
  final bool isCoverPending;

  /// Whether this sound cannot be attached because its device-local audio
  /// file is gone.
  ///
  /// The row stays listed and says why, rather than disappearing from a
  /// library the user knows they saved to — but it cannot be selected,
  /// because attaching it would put a dead source on the draft (#8023).
  final bool isUnavailable;

  /// How many published videos reuse this sound, or `null` when the count is
  /// unknown — still loading, unavailable, or a sound that has no relay event
  /// to count against. Zero and `null` both render nothing, so an empty sound
  /// never advertises its emptiness in a picker.
  final int? videoCount;

  /// Stable `Semantics(identifier:)` anchor for E2E tests. Never announced, so
  /// it carries no meaning for a screen-reader user — that is the title below.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    final videoCount = this.videoCount;
    return Semantics(
      identifier: semanticIdentifier,
      child: SoundListTile(
        title: displayTitle ?? _titleOf(context, audio),
        duration: audio.duration,
        details: [
          if (videoCount != null && videoCount > 0)
            context.l10n.soundVideoCount(videoCount),
          // Last, so a long source such as a URL is what the single line
          // cuts short, not the count.
          ?audio.source,
        ],
        cover: cover,
        isCoverPending: isCoverPending,
        colorSeed: audio.id,
        isCommunitySound: audio.isCommunitySound,
        isActive: isSelected,
        isPlaying: isPlaying,
        unavailableReason: isUnavailable
            ? context.l10n.videoEditorAudioFileMissing
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// [audio]'s title, naming the creator of an unnamed video sound so a list
/// of them does not read "Original sound" row after row.
String _titleOf(BuildContext context, AudioEvent audio) {
  final creator = audio.creatorName?.trim() ?? '';
  if (audio.hasDefaultTitle && creator.isNotEmpty) {
    return context.l10n.originalSoundByCreator(creator);
  }
  return audio.title ?? context.l10n.videoEditorAudioUntitledSound;
}
