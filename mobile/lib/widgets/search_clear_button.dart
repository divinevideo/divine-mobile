// ABOUTME: An x at the end of a search field that empties it, shown while the
// ABOUTME: field holds text.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';

/// Empties the search field [controller] drives, so a search can be reset
/// in one tap rather than by deleting it letter by letter.
///
/// Shows only while the field holds text, and takes no room otherwise.
class SearchClearButton extends StatelessWidget {
  const SearchClearButton({
    required this.controller,
    required this.onCleared,
    super.key,
  });

  final TextEditingController controller;

  /// Runs once the field is empty. [TextEditingController.clear] does not
  /// fire [TextField.onChanged], so the search has to be reset from here.
  final VoidCallback onCleared;

  /// A quick fade, so the x does not pop in under the first letter.
  static const _fadeDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => AnimatedSwitcher(
        duration: _fadeDuration.autoReduceMotion(context),
        child: value.text.isEmpty
            ? const SizedBox.shrink()
            : DivineIconButton(
                key: const Key('search_clear_button'),
                icon: DivineIconName.x,
                size: DivineIconButtonSize.small,
                backgroundColor: VineTheme.transparent,
                foregroundColor: context.vineColors.onSurfaceMuted,
                semanticLabel: context.l10n.userPickerClearSearchSemantics,
                onPressed: () {
                  controller.clear();
                  onCleared();
                },
              ),
      ),
    );
  }
}
