import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas.dart';
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
import 'package:openvine/widgets/video_metadata/video_metadata_schedule_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class VideoMetadataFormFields extends ConsumerStatefulWidget {
  const VideoMetadataFormFields({
    super.key,
    this.enableIdeas = false,
    this.enableTags = true,
    this.enableExpiration = true,
    this.enableSchedule = true,
    this.enableContentWarning = true,
    this.enableCollaborators = true,
    this.enableInspiredBy = true,
    this.enableAudioReuse = true,
    this.enableVideoReply = true,
    this.enableCaptionMentionAutocomplete = true,
  });

  final bool enableIdeas;
  final bool enableTags;
  final bool enableExpiration;

  /// Whether the "Post time" tile is offered. Off when editing a published
  /// video; a video reply hides it too.
  final bool enableSchedule;
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

  void _applyIdea(PublishingIdea idea, IdeaField field) {
    final before = ref.read(videoEditorProvider);
    final notifier = ref.read(videoEditorProvider.notifier);
    final changeTitle = field != IdeaField.description;
    final changeDescription = field != IdeaField.title;
    notifier.updateMetadata(
      title: changeTitle ? idea.title : null,
      description: changeDescription ? idea.description : null,
      tags: before.tags,
    );
    final applied = ref.read(videoEditorProvider);
    if (applied.metadataLimitReached) return;
    if (changeTitle) _titleController.text = applied.title;
    if (changeDescription) _descriptionController.text = applied.description;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.ideasApplied),
        action: SnackBarAction(
          label: context.l10n.ideasUndo,
          onPressed: () {
            if (!mounted) return;
            final current = ref.read(videoEditorProvider);
            final restoreTitle = changeTitle && current.title == applied.title;
            final restoreDescription =
                changeDescription && current.description == applied.description;
            notifier.updateMetadata(
              title: restoreTitle ? before.title : null,
              description: restoreDescription ? before.description : null,
              tags: current.tags,
            );
            if (restoreDescription) {
              notifier.restoreIdeasMentions(before.captionMentions);
            }
            final restored = ref.read(videoEditorProvider);
            if (restoreTitle) _titleController.text = restored.title;
            if (restoreDescription) {
              _descriptionController.text = restored.description;
            }
          },
        ),
      ),
    );
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

          if (widget.enableIdeas)
            FeatureFlagWidget(
              flag: FeatureFlag.publishingIdeas,
              child: PublishingIdeas(onApply: _applyIdea),
            ),

          if (widget.enableTags)
            const _InputWrapper(child: VideoMetadataTagsSelector()),

          if (widget.enableExpiration)
            const _InputWrapper(child: VideoMetadataExpirationSelector()),

          if (widget.enableSchedule)
            const _InputWrapper(child: _ScheduleSelectorGate()),

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

/// Shows the "Post time" tile unless the recording is a video reply — a
/// reply belongs to its thread now, and scheduled replies are out of scope
/// (#3538).
class _ScheduleSelectorGate extends ConsumerWidget {
  const _ScheduleSelectorGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyContext = ref.watch(videoReplyContextProvider);
    if (replyContext != null) return const SizedBox.shrink();
    return const VideoMetadataScheduleSelector();
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
