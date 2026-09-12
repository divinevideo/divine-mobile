// ABOUTME: Compact badge for accounts known locally as original Viners.
// ABOUTME: Render-only widget used beside names after cache lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class OgVinerBadge extends StatelessWidget {
  const OgVinerBadge({super.key, this.size = 14, this.leadingGap = 4});

  final double size;
  final double leadingGap;

  @override
  Widget build(BuildContext context) {
    final dimension = DivineIcon.scaleSize(context, size);
    return Semantics(
      label: context.l10n.ogVinerBadgeLabel,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsetsDirectional.only(start: leadingGap),
          width: dimension,
          height: dimension,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: VineTheme.primary,
            shape: BoxShape.circle,
          ),
          // The glyph is a logo mark sized off the circle, not readable text:
          // `dimension` already carries the text scale, so scaling the font
          // again would square the factor. `FittedBox` stays as a guard
          // against font-fallback metrics overflowing the circle.
          child: FittedBox(
            child: Text(
              'V',
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: VineTheme.onPrimary,
                fontFamily: 'Pacifico',
                fontSize: dimension * 0.85,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
