// ABOUTME: Support form text field that reports rejected text and image input
// ABOUTME: Keeps dropped keyboard content from looking like accepted evidence

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// A [DivineTextField] with a hard character cap that tells the user when the
/// cap dropped what they pasted.
///
/// The cap exists because sanitization runs on the main isolate and its cost
/// scales with field size; without it a large paste freezes submission. It is
/// applied as an input formatter rather than `maxLength` so the form does not
/// grow a Material character counter under every field, in styling the design
/// system does not own.
///
/// The formatter alone would drop the tail of a pasted crash log without
/// saying so, and that tail can be the exception the user meant to report -
/// nothing else in the payload carries it, since attachments are images only
/// and the log summary comes from in-app logs. So the field reports when the
/// formatter actually rejected characters.
///
/// The notice is driven by a rejection the formatter reports, not by comparing
/// the text length to the cap. Those are different questions and, before they
/// were separated, different units: [LengthLimitingTextInputFormatter] counts
/// grapheme clusters while `String.length` counts UTF-16 code units, so a
/// field of emoji claimed to be full at half its real capacity.
class SupportCappedTextField extends StatefulWidget {
  const SupportCappedTextField({
    required this.controller,
    required this.maxLength,
    super.key,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.imageInsertionNotice,
  });

  final TextEditingController controller;
  final int maxLength;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final bool? enabled;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Feedback shown when the keyboard tries to insert unsupported rich media.
  ///
  /// Null leaves rich-content insertion disabled without changing existing
  /// callers.
  final String? imageInsertionNotice;

  @override
  State<SupportCappedTextField> createState() => _SupportCappedTextFieldState();
}

class _SupportCappedTextFieldState extends State<SupportCappedTextField> {
  bool _truncated = false;
  bool _imageInsertionRejected = false;

  void _onTruncated() {
    if (_truncated || !mounted) return;
    setState(() => _truncated = true);
    // The notice sits beside the field rather than inside its decoration, so
    // it is outside the field's semantics node and a screen reader would not
    // otherwise announce that the paste was cut.
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.l10n.supportFieldLimitReached,
      Directionality.of(context),
    );
  }

  void _onChanged(String value) {
    final clearsTruncation =
        _truncated && value.characters.length < widget.maxLength;
    if (!clearsTruncation && !_imageInsertionRejected) return;
    setState(() {
      if (clearsTruncation) _truncated = false;
      _imageInsertionRejected = false;
    });
  }

  void _onImageInserted() {
    final notice = widget.imageInsertionNotice;
    if (notice == null || !mounted) return;
    if (!_imageInsertionRejected) {
      setState(() => _imageInsertionRejected = true);
    }
    // Each insertion is a separate action, so announce every attempt even
    // while the visual notice is already present.
    SemanticsService.sendAnnouncement(
      View.of(context),
      notice,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageInsertionNotice = widget.imageInsertionNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        if (_imageInsertionRejected && imageInsertionNotice != null)
          // Keep this above the field: the keyboard's media panel covers the
          // space below it at the exact moment insertion feedback appears.
          Text(
            imageInsertionNotice,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        DivineTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          enabled: widget.enabled,
          filled: true,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          onChanged: _onChanged,
          contentInsertionConfiguration: imageInsertionNotice == null
              ? null
              : ContentInsertionConfiguration(
                  onContentInserted: (_) => _onImageInserted(),
                ),
          inputFormatters: [
            ReportingLengthLimiter(widget.maxLength, _onTruncated),
          ],
        ),
        if (_truncated)
          // Its own widget rather than `helperText`: a helper line is capped at
          // one line and ellipsized, which would cut off the message
          // explaining that text was cut off.
          // Not the brand green: this reports that something the user typed
          // was dropped, and green reads as success.
          Text(
            context.l10n.supportFieldLimitReached,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Caps length exactly like [LengthLimitingTextInputFormatter] and reports
/// when it actually dropped something.
///
/// Public because the content report form has its own field layout and needs
/// the same "did it actually truncate" signal, which cannot be derived by
/// comparing `String.length` to the cap: the limiter counts grapheme clusters,
/// so a field of emoji looks full at half its real capacity.
class ReportingLengthLimiter extends TextInputFormatter {
  ReportingLengthLimiter(this.maxLength, this.onTruncated)
    : _limiter = LengthLimitingTextInputFormatter(maxLength);

  final int maxLength;
  final VoidCallback onTruncated;
  final LengthLimitingTextInputFormatter _limiter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limited = _limiter.formatEditUpdate(oldValue, newValue);
    if (limited.text.characters.length < newValue.text.characters.length) {
      onTruncated();
    }
    return limited;
  }
}
