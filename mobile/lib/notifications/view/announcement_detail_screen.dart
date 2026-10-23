// ABOUTME: Full-screen official announcement, with plain selectable body text.
// ABOUTME: Withdrawn or missing announcements render a safe unavailable state.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';

/// Displays a current, validated catalog announcement.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({
    this.announcement,
    this.onLearnMore,
    super.key,
  });

  static const routeName = 'announcement-detail';
  static const path = '/announcements/:id';

  final AnnouncementNotification? announcement;
  final Future<void> Function(Uri url)? onLearnMore;

  static String pathForId(String id) =>
      '/announcements/${Uri.encodeComponent(id)}';

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final l10n = context.l10n;
    final item = announcement;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DiVineAppBar(
        title: l10n.notificationFromDivine,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: RoutePaths.notificationsForIndex(0)),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: item == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.announcementUnavailable,
                      style: VineTheme.bodyMediumFont(color: colors.onSurface),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      SelectableText(
                        item.title,
                        style: VineTheme.titleLargeFont(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        item.body,
                        style: VineTheme.bodyLargeFont(color: colors.onSurface),
                      ),
                      if (item.learnMoreUrl case final Uri url) ...[
                        const SizedBox(height: 24),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: DivineButton(
                            label: l10n.profileLearnMore,
                            onPressed: onLearnMore == null
                                ? null
                                : () => onLearnMore!(url),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
