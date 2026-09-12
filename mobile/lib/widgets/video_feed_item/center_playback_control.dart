import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

enum CenterPlaybackControlState { play, pause }

/// Shared Figma-matched center control used for transient play/pause states.
///
/// Visually equivalent to a [DivineIconButton] in ghost style (scrim65
/// background + white glyph) but sized 64×64 with a 32 icon instead of
/// DivineIconButton's 40×40 (small) / 56×56 (base) presets, because the
/// Figma spec for the paused-video affordance (node 15314:53971) calls for
/// a larger tap target than any standard DivineIconButton size. Kept as a
/// bespoke widget rather than extending DivineIconButton with a third
/// size enum that only this surface would use.
class CenterPlaybackControl extends StatelessWidget {
  const CenterPlaybackControl({
    required this.state,
    this.semanticsLabel,
    super.key,
  });

  final CenterPlaybackControlState state;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final iconAsset = switch (state) {
      CenterPlaybackControlState.play => DivineIconName.playFill.assetPath,
      CenterPlaybackControlState.pause => DivineIconName.pauseFill.assetPath,
    };

    Widget icon = SvgPicture.asset(
      iconAsset,
      width: 32,
      height: 32,
      colorFilter: const ColorFilter.mode(VineTheme.whiteText, BlendMode.srcIn),
    );

    if (semanticsLabel != null) {
      icon = Semantics(
        identifier: 'play_button',
        container: true,
        explicitChildNodes: true,
        label: semanticsLabel,
        child: icon,
      );
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.4, sigmaY: 8.4),
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VineTheme.scrim65,
              borderRadius: BorderRadius.circular(24),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}
