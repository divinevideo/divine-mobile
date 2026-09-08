import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_audio_sharing_section.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_caption_field.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_limit_warning_banner.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';

class VideoMetadataFormFields extends ConsumerStatefulWidget {
  const VideoMetadataFormFields({
    super.key,
    this.enableTags = true,
    this.enableExpiration = true,
    this.enableContentWarning = true,
    this.enableCollaborators = true,
    this.enableInspiredBy = true,
    this.enableAudioReuse = true,
    this.enableVideoReply = true,
    this.enableCaptionMentionAutocomplete = true,
  });

  final bool enableTags;
  final bool enableExpiration;
  final bool enableContentWarning;
  final bool enableCollaborators;
  final bool enableInspiredBy;
  final bool enableAudioReuse;
  final bool enableVideoReply;
  final bool enableCaptionMentionAutocomplete;

  @override
  ConsumerState<VideoMetadataFormFields> createState() =>
      _VideoMetadataFormFieldsState();
}

class _VideoMetadataFormFieldsState
    extends ConsumerState<VideoMetadataFormFields> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorState = ref.read(videoEditorProvider);
      _titleController.text = editorState.title;
      _descriptionController.text = editorState.description;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reusing another creator's audio isn't the user's to offer for reuse, and
    // the publisher skips the reuse tag in that case, so hide the toggle
    // entirely rather than showing a control that does nothing.
    final reusesExternalAudio = ref.watch(
      videoEditorProvider.select((state) => state.reusesExternalAudio),
    );

    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          const VideoMetadataLimitWarningBanner(),

          // Title input field
          _InputWrapper(
            child: DivineTextField(
              controller: _titleController,
              labelText: context.l10n.videoMetadataTitleLabel,
              focusNode: _titleFocusNode,
              textInputAction: .next,
              primaryWhenFilled: true,
              minLines: 1,
              maxLines: 5,
              onChanged: (value) {
                ref
                    .read(videoEditorProvider.notifier)
                    .updateMetadata(title: value);
              },
              onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
            ),
          ),

          // Description input field
          _InputWrapper(
            child: VideoMetadataCaptionField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              enableMentionAutocomplete:
                  widget.enableCaptionMentionAutocomplete,
            ),
          ),

          if (widget.enableTags)
            const _InputWrapper(child: VideoMetadataTagsSelector()),

          if (widget.enableExpiration)
            const _InputWrapper(child: VideoMetadataExpirationSelector()),

          if (widget.enableCollaborators)
            const _InputWrapper(child: VideoMetadataCollaboratorsInput()),

          if (widget.enableInspiredBy)
            const _InputWrapper(child: VideoMetadataInspiredByInput()),

          if (widget.enableContentWarning)
            const _InputWrapper(child: VideoMetadataContentWarningSelector()),

          if (widget.enableAudioReuse && !reusesExternalAudio)
            const _InputWrapper(child: VideoMetadataAudioSharingSection()),

          if (widget.enableVideoReply)
            const _InputWrapper(child: _VideoReplyVisibilityToggle()),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _VideoReplyVisibilityToggle extends ConsumerWidget {
  const _VideoReplyVisibilityToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyContext = ref.watch(videoReplyContextProvider);
    if (replyContext == null) return const SizedBox.shrink();

    final shareReplyToFeed = ref.watch(
      videoEditorProvider.select((state) => state.shareReplyToFeed),
    );

    return Material(
      type: MaterialType.transparency,
      child: DivineSwitchTile(
        value: shareReplyToFeed,
        title: context.l10n.videoMetadataShareReplyToFeedTitle,
        subtitle: context.l10n.videoMetadataShareReplyToFeedSubtitle,
        onChanged: (value) {
          ref.read(videoEditorProvider.notifier).setShareReplyToFeed(value);
        },
      ),
    );
  }
}

class _InputWrapper extends StatelessWidget {
  const _InputWrapper({required this.child});

  final Widget child;

  static const _borderRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .circular(_borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surface,
          borderRadius: .circular(_borderRadius),
        ),
        child: child,
      ),
    );
  }
}
