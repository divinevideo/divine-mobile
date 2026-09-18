// ABOUTME: The name prompt every saved video-editor style goes through when
// ABOUTME: it is saved or renamed: caption styles and title styles alike.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/saved_style_name.dart';

/// Key of the name field, for tests that type into it.
const Key savedStyleNameFieldKey = Key('saved_style_name_field');

/// Asks for a style name; resolves with the entered text, or `null` when the
/// prompt is dismissed. The cubit still sanitizes it.
///
/// Shared by the saved caption styles sheet, the caption custom style editor
/// and the saved title styles sheet, which all ask the same question.
Future<String?> showSavedStyleNamePrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String initialName,
}) {
  return VineBottomSheet.show<String>(
    context: context,
    scrollable: false,
    expanded: false,
    isScrollControlled: true,
    title: Text(
      title,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    body: _StyleNameForm(confirmLabel: confirmLabel, initialName: initialName),
  );
}

class _StyleNameForm extends StatefulWidget {
  const _StyleNameForm({required this.confirmLabel, required this.initialName});

  final String confirmLabel;
  final String initialName;

  @override
  State<_StyleNameForm> createState() => _StyleNameFormState();
}

class _StyleNameFormState extends State<_StyleNameForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-selected so the suggested name is one keystroke from replaced, and
    // one tap on the button from kept.
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (sanitizeSavedStyleName(value) == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return VineKeyboardAwareFooter(
      includeSafeArea: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            DivineTextField(
              key: savedStyleNameFieldKey,
              controller: _controller,
              labelText: context.l10n.videoEditorCaptionsSavedStyleNameLabel,
              // Sits directly on the sheet surface, so it needs its own fill
              // to have a visible edge at all.
              filled: true,
              primaryWhenFilled: true,
              autofocus: true,
              maxLength: savedStyleMaxNameLength,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              onSubmitted: _submit,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSubmit = sanitizeSavedStyleName(value.text) != null;
                return DivineButton(
                  expanded: true,
                  label: widget.confirmLabel,
                  onPressed: canSubmit ? () => _submit(_controller.text) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
