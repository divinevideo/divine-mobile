// ABOUTME: Loading widget shown when NostrClient doesn't have keys yet
// ABOUTME: Used as a placeholder while waiting for authentication to complete

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Widget displayed while something is loading.
///
/// Shows a loading indicator centered on screen.
class BrandedLoadingScaffold extends StatelessWidget {
  const BrandedLoadingScaffold({super.key, this.size = 60});

  /// The size (width and height) of the loading indicator.
  final double size;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vineColors.background,
    body: Center(child: BrandedLoadingIndicator(size: size)),
  );
}
