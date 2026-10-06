import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

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
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF0F1B17),
                Color(0xFF1B2D22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: VineTheme.outlineMuted),
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
                  child: const Icon(
                    Icons.podcasts_rounded,
                    color: VineTheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'See who is live right now or start your own room.',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
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
