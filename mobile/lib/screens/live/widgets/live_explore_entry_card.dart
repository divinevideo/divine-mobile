import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class LiveExploreEntryCard extends StatelessWidget {
  const LiveExploreEntryCard({
    required this.onTap,
    super.key,
  });

  static const Key entryKey = Key('explore-live-entry');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: InkWell(
        key: entryKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: <Color>[
                context.vineColors.surfaceContainerHigh,
                context.vineColors.surfaceContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: context.vineColors.outlineMuted),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: VineTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const DivineIcon(
                    icon: DivineIconName.waveform,
                    color: VineTheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.liveTabLabel,
                        style: VineTheme.titleLargeFont(
                          color: context.vineColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.liveDiscoveryDescription,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const DivineIcon(
                  icon: DivineIconName.arrowRight,
                  color: VineTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
