import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:unified_logger/unified_logger.dart';

// ABOUTME: Mobile-only image attachment picker for bug reports.
// ABOUTME: Limits the selection count, announces changes for accessibility,
// ABOUTME: and keeps interactions aligned with the Divine design system.

class ImageAttachmentPicker extends StatefulWidget {
  const ImageAttachmentPicker({
    required this.onChanged,
    super.key,
    this.maxImages = 3,
    this.enabled = true,
  });

  final int maxImages;
  final ValueChanged<List<XFile>> onChanged;
  final bool enabled;

  @visibleForTesting
  static ImagePicker imagePicker = ImagePicker();

  /// Strips EXIF (including GPS) from a picked attachment before it is handed
  /// back to the caller. Injectable so tests can drive the fail-closed path
  /// without a platform channel. Defaults to the fail-closed stripper.
  @visibleForTesting
  static Future<File> Function(File file) stripAttachmentMetadata =
      ImageMetadataStripper.stripMetadataInPlaceOrThrow;

  @override
  State<ImageAttachmentPicker> createState() => _ImageAttachmentPickerState();
}

class _ImageAttachmentPickerState extends State<ImageAttachmentPicker> {
  final List<XFile> _images = [];

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _pickImages() async {
    if (!widget.enabled) return;

    final remaining = widget.maxImages - _images.length;
    if (remaining <= 0) return;

    List<XFile> picked;
    try {
      picked = await ImageAttachmentPicker.imagePicker.pickMultiImage(
        maxWidth: 1920,
        imageQuality: 80,
      );
    } catch (error, stackTrace) {
      _showPickFailure(error, stackTrace);
      return;
    }

    if (!mounted) return;
    if (picked.isEmpty) return;

    // `image_picker` does not strip EXIF on every platform and plugin version:
    // Android's multi-image path drops `requestFullMetadata` before the native
    // call, and the iOS 16+ PHPicker path rebuilds the image from the original
    // bytes. Strip explicitly and fail closed, because a bug-report attachment
    // is uploaded to Zendesk and a GPS tag would leave the device (#8850, D3).
    final sanitized = <XFile>[];
    var stripFailed = false;
    for (final file in picked.take(remaining)) {
      try {
        final stripped = await ImageAttachmentPicker.stripAttachmentMetadata(
          File(file.path),
        );
        sanitized.add(XFile(stripped.path));
      } catch (error, stackTrace) {
        stripFailed = true;
        Log.error(
          'Failed to strip metadata from a bug report attachment; dropping it',
          category: LogCategory.storage,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (!mounted) return;
    if (sanitized.isEmpty) {
      if (stripFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.bugReportUploadFailed),
            backgroundColor: VineTheme.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _images.addAll(sanitized);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        Directionality.of(context),
      );
    }
  }

  void _showPickFailure(Object error, StackTrace stackTrace) {
    Log.error(
      'Failed to pick bug report attachments: $error',
      category: LogCategory.ui,
      error: error,
      stackTrace: stackTrace,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.bugReportUploadFailed),
        backgroundColor: VineTheme.error,
      ),
    );
  }

  void _removeImage(int index) {
    if (!widget.enabled) return;

    setState(() {
      _images.removeAt(index);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const SizedBox.shrink();

    final l10n = context.l10n;
    final showAddButton = _images.length < widget.maxImages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _images.length; i++)
          _Thumbnail(
            file: _images[i],
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportRemoveImage,
            onRemove: () => _removeImage(i),
          ),
        if (showAddButton)
          _AddButton(
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportAttachImages,
            onTap: _pickImages,
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.file,
    required this.enabled,
    required this.semanticsLabel,
    required this.onRemove,
  });

  final XFile file;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              semanticLabel: file.name,
              errorBuilder: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: context.vineColors.card,
                child: DivineIcon(
                  icon: DivineIconName.image,
                  color: context.vineColors.mutedText,
                ),
              ),
            ),
          ),
          if (enabled)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: semanticsLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: ExcludeSemantics(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: context.vineColors.card,
                            shape: BoxShape.circle,
                          ),
                          child: DivineIcon(
                            icon: DivineIconName.x,
                            size: 14,
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? context.vineColors.accentPositive.withValues(alpha: 0.7)
                    : context.vineColors.mutedText.withValues(alpha: 0.7),
              ),
            ),
            child: Center(
              child: DivineIcon(
                icon: DivineIconName.imagesSquare,
                color: enabled
                    ? context.vineColors.accentPositive
                    : context.vineColors.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
