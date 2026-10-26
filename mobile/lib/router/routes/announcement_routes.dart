// ABOUTME: Full-screen official announcements resolved from the current catalog.
// ABOUTME: Route extras cannot impersonate or retain a withdrawn announcement.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/notification_item.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/cubit/announcement_detail_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/announcement_detail_screen.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:url_launcher/url_launcher.dart';

part 'announcement_routes.g.dart';

List<RouteBase> announcementRoutes() => $appRoutes;

@TypedGoRoute<AnnouncementDetailRouteData>(
  path: AnnouncementDetailScreen.path,
  name: AnnouncementDetailScreen.routeName,
)
class AnnouncementDetailRouteData extends GoRouteData
    with $AnnouncementDetailRouteData {
  const AnnouncementDetailRouteData({required this.id});

  final String id;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(
        state: state,
        child: _AnnouncementDetailPage(announcementId: id),
      );
}

class _AnnouncementDetailPage extends ConsumerWidget {
  const _AnnouncementDetailPage({required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref
        .watch(notificationRepositoryProvider)
        ?.announcementsRepository;
    if (repository == null) return const AnnouncementDetailScreen();
    return BlocProvider(
      key: ValueKey((repository, announcementId)),
      create: (_) => AnnouncementDetailCubit(
        announcementId: announcementId,
        initialItems: repository.items,
        snapshots: repository.watchSnapshot(),
      ),
      child: BlocBuilder<AnnouncementDetailCubit, AnnouncementNotification?>(
        builder: (context, announcement) => AnnouncementDetailScreen(
          announcement: announcement,
          onLearnMore: (url) => _openLearnMore(context, url),
        ),
      ),
    );
  }

  Future<void> _openLearnMore(BuildContext context, Uri url) async {
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Exception {
      // The same localized feedback covers unsupported and failed launches.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.relaySettingsFailedToOpenLink,
          error: true,
        ),
      );
    }
  }
}
