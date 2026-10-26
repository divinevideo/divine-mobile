import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Lets the creator allow others to add this post to their clips.
///
/// Off by default. Locked off when the post's sound is licensed without
/// derivatives, since a reused clip carries that sound along.
class VideoMetadataVideoReuseToggle extends ConsumerWidget {
  /// Creates the video reuse toggle.
  const VideoMetadataVideoReuseToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (allowVideoReuse, soundForbidsDerivatives) = ref.watch(
      videoEditorProvider.select(
        (state) => (state.allowVideoReuse, state.soundForbidsDerivatives),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: DivineSwitchTile(
        value: allowVideoReuse && !soundForbidsDerivatives,
        title: context.l10n.videoMetadataVideoReuseTitle,
        subtitle: soundForbidsDerivatives
            ? context.l10n.videoMetadataVideoReuseSoundLicenseSubtitle
            : context.l10n.videoMetadataVideoReuseSubtitle,
        onChanged: soundForbidsDerivatives
            ? null
            : ref.read(videoEditorProvider.notifier).setAllowVideoReuse,
      ),
    );
  }
}
