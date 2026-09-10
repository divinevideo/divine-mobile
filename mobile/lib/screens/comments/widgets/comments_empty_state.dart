import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Empty state widget displayed when there are no comments.
///
/// Shows a special "Classic Vine" notice for archived videos where
/// original comments haven't been imported yet.
class CommentsEmptyState extends StatelessWidget {
  const CommentsEmptyState({required this.isClassicVine, super.key});

  /// Whether this video is a classic vine from the archive.
  /// Shows additional context about pending comment import.
  final bool isClassicVine;

  @override
  Widget build(BuildContext context) => Center(
    // Scrollable so the empty state shrinks gracefully when the open
    // keyboard squeezes the sheet's list area to near zero; a fixed Column
    // overflows in that space (debug overflow banner, clipped copy in
    // release).
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isClassicVine) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VineTheme.accentOrange.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VineTheme.accentOrange.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.history,
                    color: VineTheme.contentWarningAmber,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.commentsEmptyClassicVineTitle,
                    style: const TextStyle(
                      color: VineTheme.contentWarningAmber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.commentsEmptyClassicVineMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.vineColors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.commentsEmptyTitle,
                textAlign: TextAlign.center,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.commentsEmptySubtitle,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
