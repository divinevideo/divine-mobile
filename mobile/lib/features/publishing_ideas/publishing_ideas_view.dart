import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_cubit.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_media.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_source.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/ideas_transcript.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

/// The specific metadata fields the creator chose to replace.
enum IdeaField { title, description, both }

/// Presentation and controller lifecycle for the inline ideas panel.
class PublishingIdeasView extends StatefulWidget {
  const PublishingIdeasView({
    required this.editor,
    required this.clips,
    required this.language,
    required this.media,
    required this.onApply,
    required this.onSaveTranscript,
    required this.onAddTag,
    super.key,
  });
  final VideoEditorProviderState editor;
  final List<DivineVideoClip> clips;
  final String language;
  final PublishingIdeasMedia Function() media;
  final void Function(PublishingIdea idea, IdeaField field) onApply;
  final ValueChanged<IdeasTranscript> onSaveTranscript;
  final ValueChanged<String> onAddTag;

  @override
  State<PublishingIdeasView> createState() => _PublishingIdeasViewState();
}

class _PublishingIdeasViewState extends State<PublishingIdeasView> {
  final _transcript = TextEditingController();
  PublishingIdeasCubit get cubit => context.read<PublishingIdeasCubit>();

  @override
  void initState() {
    super.initState();
    _syncSource();
    _transcript.text = cubit.state.transcript;
  }

  @override
  void didUpdateWidget(covariant PublishingIdeasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSource();
  }

  void _syncSource() => cubit.updateSource(
    PublishingIdeasSource.fromEditor(
      widget.editor,
      widget.clips,
      widget.language,
    ),
  );

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _generate(List<PublishingIdea> deck) async {
    final clip = widget.editor.finalRenderedClip;
    await cubit.generate(
      SuggestionRequest(
        language: cubit.state.source!.language,
        transcript: cubit.state.transcript,
        existingTags: widget.editor.tags,
      ),
      fallback: deck,
      loadFrames: clip == null || widget.editor.isProcessing
          ? null
          : () => widget.media().frames(clip),
    );
  }

  Future<void> _transcribe() async {
    final clip = widget.editor.finalRenderedClip;
    if (clip == null) return;
    final language = cubit.state.source!.language;
    final text = await cubit.transcribe(
      () => widget.media().transcript(clip, language),
    );
    if (!mounted || text == null) return;
    _saveTranscript(text);
  }

  void _saveTranscript(String text) {
    final source = cubit.state.source!;
    widget.onSaveTranscript(
      IdeasTranscript(
        revision: source.revision,
        language: source.language,
        text: text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final l10n = context.l10n;
    final deck = [
      PublishingIdea(
        title: l10n.ideasTitleOne,
        description: l10n.ideasDescriptionOne,
      ),
      PublishingIdea(
        title: l10n.ideasTitleTwo,
        description: l10n.ideasDescriptionTwo,
      ),
      PublishingIdea(
        title: l10n.ideasTitleThree,
        description: l10n.ideasDescriptionThree,
      ),
      PublishingIdea(
        title: l10n.ideasTitleFour,
        description: l10n.ideasDescriptionFour,
      ),
      PublishingIdea(
        title: l10n.ideasTitleFive,
        description: l10n.ideasDescriptionFive,
      ),
      PublishingIdea(
        title: l10n.ideasTitleSix,
        description: l10n.ideasDescriptionSix,
      ),
    ];
    return BlocConsumer<PublishingIdeasCubit, PublishingIdeasState>(
      listenWhen: (previous, current) =>
          previous.transcript != current.transcript,
      listener: (context, state) {
        if (_transcript.text != state.transcript) {
          _transcript.value = TextEditingValue(
            text: state.transcript,
            selection: TextSelection.collapsed(offset: state.transcript.length),
          );
        }
      },
      builder: (context, state) {
        final ideas = state.result?.ideas ?? const <PublishingIdea>[];
        final idea = ideas.isEmpty
            ? null
            : ideas[state.selected % ideas.length];
        final canTranscribe = state.source!.canTranscribe;
        return Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            DivineButton(
              type: DivineButtonType.link,
              size: DivineButtonSize.small,
              maxLines: 20,
              onPressed: () {
                cubit.toggleExpanded();
                if (cubit.state.expanded) {
                  unawaited(_generate(deck));
                }
              },
              label: state.expanded ? l10n.ideasHide : l10n.ideasNeedIdeas,
            ),
            if (state.expanded) ...[
              Wrap(
                spacing: 8,
                children: [
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: state.busy ? null : () => _generate(deck),
                    label: l10n.ideasFromVideo,
                  ),
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: () {
                      cubit.surprise(deck);
                    },
                    label: l10n.ideasSurprise,
                  ),
                  if (state.busy)
                    DivineButton(
                      type: DivineButtonType.link,
                      size: DivineButtonSize.small,
                      maxLines: 20,
                      onPressed: cubit.cancel,
                      label: l10n.settingsCancel,
                    ),
                ],
              ),
              if (state.busy) const DivineLinearProgressIndicator(),
              if (state.capabilities?.availability ==
                  ModelAvailability.downloadable)
                DivineButton(
                  type: DivineButtonType.link,
                  size: DivineButtonSize.small,
                  maxLines: 20,
                  onPressed: state.busy ? null : cubit.prepare,
                  label: l10n.ideasPrepare,
                ),
              if (state.capabilities?.availability ==
                      ModelAvailability.unavailable ||
                  state.capabilities?.availability ==
                      ModelAvailability.preparing ||
                  state.failed ||
                  state.result?.source == SuggestionSource.premade &&
                      ideas.isEmpty)
                Text(l10n.ideasUnavailable),
              if (idea != null) ...[
                Text(
                  switch (state.result!.source) {
                    SuggestionSource.video => l10n.ideasSourceVideo,
                    SuggestionSource.transcript => l10n.ideasSourceTranscript,
                    SuggestionSource.premade => l10n.ideasSourcePremade,
                  },
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                // Text itself is tappable, keeping the suggestions next to the form.
                DivineButton(
                  type: DivineButtonType.link,
                  size: DivineButtonSize.small,
                  maxLines: 20,
                  onPressed: () => widget.onApply(idea, IdeaField.title),
                  label: idea.title,
                ),
                DivineButton(
                  type: DivineButtonType.link,
                  size: DivineButtonSize.small,
                  maxLines: 20,
                  onPressed: () => widget.onApply(idea, IdeaField.description),
                  label: idea.description,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    DivineButton(
                      type: DivineButtonType.link,
                      size: DivineButtonSize.small,
                      maxLines: 20,
                      onPressed: () => widget.onApply(idea, IdeaField.both),
                      label: l10n.ideasUseBoth,
                    ),
                    DivineButton(
                      type: DivineButtonType.link,
                      size: DivineButtonSize.small,
                      maxLines: 20,
                      onPressed: () {
                        if (state.selected + 1 < ideas.length) {
                          cubit.nextIdea();
                        } else if (state.result!.source ==
                            SuggestionSource.premade) {
                          cubit.surprise(deck);
                        } else {
                          unawaited(_generate(deck));
                        }
                      },
                      label: l10n.ideasMore,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in state.result!.hashtags)
                      if (!editor.tags.any(
                        (existing) =>
                            existing.toLowerCase() == tag.toLowerCase(),
                      ))
                        DivineButton(
                          type: DivineButtonType.secondary,
                          size: DivineButtonSize.small,
                          label: '#$tag',
                          onPressed: () {
                            widget.onAddTag(tag);
                          },
                        ),
                  ],
                ),
              ],
              if (canTranscribe || state.transcript.isNotEmpty) ...[
                if (canTranscribe && state.transcript.isEmpty)
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: state.busy ? null : _transcribe,
                    label: l10n.ideasGenerateTranscript,
                  )
                else if (!state.source!.hasCaptions)
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: cubit.toggleTranscriptEditing,
                    label: l10n.ideasEditTranscript,
                  ),
                if (state.editingTranscript && !state.source!.hasCaptions)
                  DivineTextField(
                    controller: _transcript,
                    labelText: l10n.ideasTranscript,
                    minLines: 2,
                    maxLines: 6,
                    onChanged: (value) {
                      cubit.editTranscript(value);
                      _saveTranscript(value);
                    },
                  ),
                if (canTranscribe)
                  Text(
                    l10n.ideasTranscriptionNotice,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
              ],
            ],
          ],
        );
      },
    );
  }
}
