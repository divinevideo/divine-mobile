// ABOUTME: The filled name and description inputs shared by the list info
// ABOUTME: sheets, styled to the design's input cards.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Corner radius of the form's input cards.
const double _fieldRadius = 24;

/// Space between an input card's edge and its text.
const EdgeInsets _fieldPadding = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 16,
);

/// Most lines the description shows before it scrolls.
const int _descriptionMaxLines = 4;

/// The list name input, first in the form's focus chain.
class ListNameField extends StatelessWidget {
  /// Creates the name input.
  const ListNameField({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Holds the typed name.
  final TextEditingController controller;

  /// Called with the name as typed.
  final ValueChanged<String> onChanged;

  /// Whether the field takes input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DivineTextField(
      controller: controller,
      labelText: context.l10n.listNameLabel,
      filled: true,
      fillColor: context.vineColors.surfaceContainer,
      fillBorderRadius: _fieldRadius,
      contentPadding: _fieldPadding,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      // Focus moves on to the description, which is where the chain ends: a
      // multiline field keeps its return key for line breaks.
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
    );
  }
}

/// The optional description input, last in the form.
class ListDescriptionField extends StatelessWidget {
  /// Creates the description input.
  const ListDescriptionField({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Holds the typed description.
  final TextEditingController controller;

  /// Called with the description as typed.
  final ValueChanged<String> onChanged;

  /// Whether the field takes input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DivineTextField(
      controller: controller,
      labelText: context.l10n.listDescriptionLabel,
      filled: true,
      fillColor: context.vineColors.surfaceContainer,
      fillBorderRadius: _fieldRadius,
      contentPadding: _fieldPadding,
      enabled: enabled,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      minLines: 1,
      maxLines: _descriptionMaxLines,
      onChanged: onChanged,
    );
  }
}
