// ABOUTME: Bottom sheet prompting for a clip title before saving it to the library.
// ABOUTME: Resolves with the trimmed title, or null when cancelled.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class ClipTitleSheet extends StatefulWidget {
  const ClipTitleSheet({required this.initialTitle, super.key});

  final String initialTitle;

  static Future<String?> show({
    required BuildContext context,
    required String initialTitle,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      showHeaderDivider: false,
      body: ClipTitleSheet(initialTitle: initialTitle),
    );
  }

  @override
  State<ClipTitleSheet> createState() => ClipTitleSheetState();
}

class ClipTitleSheetState extends State<ClipTitleSheet> {
  late final TextEditingController _controller;

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle)
      ..addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.shareSheetNameClipTitle,
                textAlign: TextAlign.center,
                style: VineTheme.headlineSmallFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.shareSheetNameClipSubtitle,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              DivineTextField(
                controller: _controller,
                labelText: context.l10n.shareSheetClipTitleLabel,
                maxLength: 80,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                onSubmitted: (_) => _save(),
                primaryWhenFilled: true,
              ),
              const SizedBox(height: 24),
              DivineButton(
                label: context.l10n.shareSheetSaveClip,
                onPressed: _canSave ? _save : null,
                expanded: true,
              ),
              const SizedBox(height: 12),
              DivineButton(
                label: context.l10n.commonCancel,
                type: DivineButtonType.secondary,
                onPressed: () => Navigator.of(context).pop(),
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
