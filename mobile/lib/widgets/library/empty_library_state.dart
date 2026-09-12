// ABOUTME: Reusable empty state widget for library tabs
// ABOUTME: Shows icon, title, subtitle, and optional action button

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/camera_permission_check.dart';

/// Empty state widget for library tabs (clips, drafts).
class EmptyLibraryState extends StatelessWidget {
  /// Creates an empty library state widget.
  const EmptyLibraryState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showRecordButton = true,
    this.scrollController,
    super.key,
  });

  /// Icon to display in the center circle.
  final DivineIconName icon;

  /// Title text (e.g., "No Clips Yet").
  final String title;

  /// Subtitle text describing what will appear here.
  final String subtitle;

  /// Whether to show the "Record a Video" button.
  final bool showRecordButton;

  /// Scroll controller for the slot this empty state fills, e.g. the one a
  /// [DraggableScrollableSheet] hands its body so drags resize the sheet.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: scrollController,
        // The column mixes a fixed icon circle with text that grows on the
        // raw text scaler, and the toolbar and chip row above it grow at the
        // same time — so past the accessibility sizes it is taller than the
        // slot it gets. Scrolling keeps it centred while it fits and reaches
        // the rest once it does not, rather than clipping the subtitle (#7242).
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: .min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.vineColors.card,
                    ),
                    child: Center(
                      child: DivineIcon(
                        icon: icon,
                        size: 48,
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: VineTheme.headlineSmallFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.secondaryText,
                    ),
                    textAlign: .center,
                  ),
                  if (showRecordButton) ...[
                    const SizedBox(height: 32),
                    DivineButton(
                      label: context.l10n.libraryRecordVideo,
                      leadingIcon: .videoCamera,
                      type: .secondary,
                      onPressed: () => context.pushToCameraWithPermission(
                        entryPoint: CreationEntryPoint.library,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
