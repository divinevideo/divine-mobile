// ABOUTME: Shared loading-more sliver for profile tab grids
// ABOUTME: Shows a spinner at the bottom of the grid during pagination

import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// A [SliverToBoxAdapter] spinner displayed at the bottom of a profile
/// tab grid while more items are being fetched.
class ProfileTabLoadingMoreSliver extends StatelessWidget {
  const ProfileTabLoadingMoreSliver({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: .fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: const Center(child: BrandedLoadingIndicator(size: 64)),
    ),
  );
}
