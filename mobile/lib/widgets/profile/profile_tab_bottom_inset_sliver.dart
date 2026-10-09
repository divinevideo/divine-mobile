// ABOUTME: Bottom safe-area spacer that ends a profile tab's scroll view
// ABOUTME: so its last row stops above the home indicator, not under it

import 'package:flutter/widgets.dart';

/// Ends a profile tab's scroll view with the bottom safe area.
///
/// Without it the last row of a tab scrolls under the home indicator.
/// [ProfileTabLoadingMoreSliver] already includes the same inset, so a tab
/// shows one or the other.
class ProfileTabBottomInsetSliver extends StatelessWidget {
  const ProfileTabBottomInsetSliver({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
  );
}
