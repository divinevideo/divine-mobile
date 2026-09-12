import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Feed-scoped Auto advance rail control.
class AutoActionButton extends StatelessWidget {
  const AutoActionButton({
    required this.isEnabled,
    required this.onPressed,
    super.key,
  });

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = isEnabled ? VineTheme.vineGreen : VineTheme.whiteText;
    final label = context.l10n.videoActionAutoLabel;

    return Semantics(
      identifier: 'auto_button',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: isEnabled
          ? context.l10n.videoActionDisableAutoAdvance
          : context.l10n.videoActionEnableAutoAdvance,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 72,
          height: 48,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: VineTheme.backgroundColor.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 30,
                    height: 20,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: DivineIcon(
                            icon: DivineIconName.play,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 0,
                          child: DivineIcon(
                            icon: DivineIconName.play,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: VineTheme.labelSmallFont(color: VineTheme.whiteText)
                        .copyWith(
                          shadows: VineTheme.buttonShadows,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
