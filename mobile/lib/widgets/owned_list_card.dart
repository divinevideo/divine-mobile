// ABOUTME: Card for one of the viewer's own curated lists, wired to its feed
// ABOUTME: Shared by the profile Lists tab and the explore tab's My Lists block

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/widgets/list_card.dart';

/// A [CuratedListCard] for a list the viewer owns, wired to open its feed.
///
/// Both surfaces that show the viewer's own lists render the same card with
/// the same visibility badge and push the same route with the same extra.
/// Owning the tap target here keeps the route and its payload from drifting
/// apart between them — the surfaces differ in their chrome, not in what a
/// card does.
class OwnedListCard extends StatelessWidget {
  const OwnedListCard({required this.curatedList, this.onTap, super.key});

  /// The owned list this card represents.
  final CuratedList curatedList;

  /// Runs before navigating, for hosts that log the tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CuratedListCard(
      curatedList: curatedList,
      showVisibility: true,
      showAuthor: false,
      onTap: () {
        onTap?.call();
        context.push(
          CuratedListFeedScreen.pathForId(curatedList.id),
          extra: CuratedListRouteExtra(listName: curatedList.name),
        );
      },
    );
  }
}
