import 'package:material_ui/material_ui.dart';

/// A sliver that adds bottom padding equal to the system navigation bar
/// height, ensuring scroll content is not obscured on devices with gesture
/// navigation or a translucent nav bar.
///
/// Drop this as the **last sliver** in a [CustomScrollView]. Content still
/// scrolls *behind* the system UI (the modern Android/iOS effect), but the
/// final scroll position keeps everything visible above it.
class SliverBottomSafeArea extends StatelessWidget {
  /// Creates a [SliverBottomSafeArea].
  const SliverBottomSafeArea({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return SliverToBoxAdapter(child: SizedBox(height: bottom));
  }
}
