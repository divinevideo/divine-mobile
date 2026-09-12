// ABOUTME: Tappable row used inside the add-people-to-list picker.
// ABOUTME: Shows avatar, display name, handle, and a selection checkbox.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// A presentational row representing a [PeopleListCandidate] for inclusion
/// in a people list. Purely display-and-callback — it holds no bloc or
/// provider references so it can be reused from any picker variant.
///
/// The row renders the user avatar, their display name, a secondary handle
/// line, and a trailing [DivineSpriteCheckbox] reflecting [isSelected]. When
/// [enabled] is `false` the row becomes non-interactive and the checkbox
/// renders in its disabled state — used to indicate a candidate that is
/// already a member of the target list.
class PersonPickableRow extends StatelessWidget {
  /// Creates a pickable-person row for the given [candidate].
  const PersonPickableRow({
    required this.candidate,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  /// Candidate whose metadata drives the row's display.
  final PeopleListCandidate candidate;

  /// Whether the candidate is currently selected for batch add.
  final bool isSelected;

  /// When `false`, the row is non-interactive and rendered greyed out. Used
  /// for candidates that are already members of the target list.
  final bool enabled;

  /// Called when the row is tapped. Ignored while [enabled] is `false`.
  final VoidCallback onTap;

  /// Full hex pubkey for this person. Never truncated.
  String get pubkey => candidate.pubkey;

  /// Effective display name: either the resolved Kind 0 name or a
  /// deterministic fallback derived from the pubkey.
  String get displayName =>
      candidate.displayName ?? UserProfile.defaultDisplayNameFor(pubkey);

  /// Effective handle line: either the resolved handle or the full pubkey
  /// as a stable fallback.
  String get handle => candidate.handle ?? pubkey;

  /// Optional avatar URL for the candidate.
  String? get avatarUrl => candidate.avatarUrl;

  DivineCheckboxState get _checkboxState {
    if (!enabled) {
      return DivineCheckboxState.disabled;
    }
    return isSelected
        ? DivineCheckboxState.selected
        : DivineCheckboxState.unselected;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? context.vineColors.onSurface
        : context.vineColors.secondaryText;
    return Semantics(
      identifier: 'person_pickable_row_$pubkey',
      button: true,
      enabled: enabled,
      selected: isSelected,
      label: displayName,
      container: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: Row(
                children: [
                  UserAvatar(imageUrl: avatarUrl, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: VineTheme.titleMediumFont(color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          handle,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  DivineSpriteCheckbox(state: _checkboxState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
