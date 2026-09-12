// ABOUTME: Compact badge for accounts that beta-tested Divine before launch.
// ABOUTME: Render-only widget used beside names after a roster lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class OgBetaBadge extends StatelessWidget {
  const OgBetaBadge({
    super.key,
    this.size = 14,
    this.leadingGap = 4,
    this.onTap,
  });

  final double size;
  final double leadingGap;

  /// Opens the badge explainer.
  ///
  /// Inline name rows pass this so the "not an account verification badge"
  /// disclaimer is reachable everywhere the chit appears, not only from the
  /// profile header. Null leaves the chit inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dimension = DivineIcon.scaleSize(context, size);
    return Semantics(
      label: context.l10n.ogBetaTesterBadgeLabel,
      button: onTap != null,
      onTap: onTap,
      container: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          // Deliberately below the 48dp minimum touch target from
          // accessibility.md. Padding the chit out to 48dp grows an inline
          // name row from 14dp to 48dp, but only for rows that carry a
          // badge, so comment threads and search results render ragged and
          // the chit floats detached from the name. The compliant
          // affordance is the profile header, which is a full route with
          // room for a real target and renders the same explainer; this is
          // a convenience path to it, not the only way to reach it.
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
            // again would square the factor. `FittedBox` keeps the two letters
            // inside the circle whatever the font fallback metrics turn out to
            // be, and the inset stops them touching the rim.
            child: Padding(
              padding: EdgeInsets.all(dimension * 0.16),
              child: FittedBox(
                child: Text(
                  'OG',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  // Bricolage Grotesque ExtraBold, the only 800 face in the
                  // bundle. Inter ships at 400/600 only, so asking
                  // labelSmallFont for w800 gets synthetic bold instead:
                  // thickened strokes with the O and G counters closed up.
                  style: VineTheme.titleTinyFont(color: VineTheme.onPrimary)
                      .copyWith(
                        fontSize: dimension * 0.6,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
