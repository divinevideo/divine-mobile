import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_cubit.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_providers.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_revision.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/ideas_transcript.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

/// The specific metadata fields the creator chose to replace.
enum IdeaField { title, description, both }

/// Injectable local-model dependency; constructed only when ideas are offered.
final publishingSuggestionsRepositoryProvider = Provider<SuggestionsRepository>(
  (ref) => SuggestionsRepository(client: NativeSuggestionsClient()),
);

/// Small optional suggestions inside the existing publishing form.
class PublishingIdeas extends ConsumerStatefulWidget {
  const PublishingIdeas({required this.onApply, super.key});
  final void Function(PublishingIdea idea, IdeaField field) onApply;

  @override
  ConsumerState<PublishingIdeas> createState() => _PublishingIdeasState();
}

class _PublishingIdeasState extends ConsumerState<PublishingIdeas> {
  late final _cubit = PublishingIdeasCubit(
    repository: ref.read(publishingSuggestionsRepositoryProvider),
  );
  final _transcript = TextEditingController();
  bool _expanded = false;
  bool _editingTranscript = false;
  int _selected = 0;
  String _revision = '';
  Object? _historyIdentity;
  Object? _clipsIdentity;
  Object? _soundIdentity;
  String _compositionRevision = '';
  String _language = '';
  String _deckLocale = '';
  List<PublishingIdea>? _deck;

  @override
  void dispose() {
    unawaited(_cubit.close());
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final editor = ref.read(videoEditorProvider);
    _selected = 0;
    final clip = editor.finalRenderedClip;
    await _cubit.generate(
      SuggestionRequest(
        language: _language,
        transcript: _transcript.text,
        existingTags: editor.tags,
      ),
      fallback: _deck ?? const [],
      loadFrames: clip == null || editor.isProcessing
          ? null
          : () => ref.read(publishingIdeasMediaProvider).frames(clip),
    );
  }

  Future<void> _transcribe() async {
    final clip = ref.read(videoEditorProvider).finalRenderedClip;
    if (clip == null) return;
    final revision = _revision;
    final text = await _cubit.transcribe(
      () => ref.read(publishingIdeasMediaProvider).transcript(clip, _language),
    );
    if (!mounted || text == null || revision != _revision) return;
    _transcript.text = text;
    _saveTranscript(text);
    setState(() => _editingTranscript = true);
  }

  void _saveTranscript(String text) {
    ref
        .read(videoEditorProvider.notifier)
        .updateIdeasTranscript(
          IdeasTranscript(revision: _revision, language: _language, text: text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(videoEditorProvider);
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
    final captions = editor.editorEditingParameters?.captionTrackFromMeta;
    final uiLanguage = Localizations.localeOf(context).toLanguageTag();
    final language = captions?.languageTag ?? uiLanguage;
    if (!identical(_historyIdentity, editor.editorEditingParameters) ||
        !identical(_clipsIdentity, clips) ||
        !identical(_soundIdentity, editor.selectedSound)) {
      _historyIdentity = editor.editorEditingParameters;
      _clipsIdentity = clips;
      _soundIdentity = editor.selectedSound;
      _compositionRevision = publishingIdeasRevision(
        editor.editorEditingParameters?.toMap() ?? {},
        clips.map((clip) => clip.toJson()).toList(),
        selectedSound:
            (editor.editorEditingParameters?.audioTracksFromMeta ?? []).isEmpty
            ? editor.selectedSound?.toJson()
            : null,
      );
    }
    final revision = _compositionRevision;
    final subtitleText = captions == null
        ? null
        : ([...captions.cues]..sort((a, b) => a.start.compareTo(b.start)))
              .map((cue) => cue.text)
              .join(' ');
    final source =
        '$revision|$language|$uiLanguage|${subtitleText ?? ''}|${editor.finalRenderedClip?.id}|${editor.isProcessing}';
    // Cubit is local and observed below; this never changes editor state in build.
    _cubit.setSource(source);
    if (_revision != revision || _language != language) {
      _revision = revision;
      _language = language;
      final saved = editor.ideasTranscript;
      _transcript.text =
          subtitleText ?? (saved?.revision == revision ? saved!.text : '');
      _selected = 0;
      _editingTranscript = false;
    } else if (subtitleText != null && !_editingTranscript) {
      _transcript.text = subtitleText;
    }
    final l10n = context.l10n;
    if (_deckLocale != uiLanguage) {
      _deckLocale = uiLanguage;
      _deck = null;
    }
    _deck ??= [
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
    return BlocBuilder<PublishingIdeasCubit, PublishingIdeasState>(
      bloc: _cubit,
      builder: (context, state) {
        final ideas = state.result?.ideas ?? const <PublishingIdea>[];
        final idea = ideas.isEmpty ? null : ideas[_selected % ideas.length];
        final canTranscribe =
            captions == null &&
            editor.finalRenderedClip != null &&
            !editor.isProcessing;
        return Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            DivineButton(
              type: DivineButtonType.link,
              size: DivineButtonSize.small,
              maxLines: 20,
              onPressed: () {
                setState(() => _expanded = !_expanded);
                if (_expanded) {
                  unawaited(_generate());
                } else {
                  _cubit.cancel();
                }
              },
              label: _expanded ? l10n.ideasHide : l10n.ideasNeedIdeas,
            ),
            if (_expanded) ...[
              Wrap(
                spacing: 8,
                children: [
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: state.busy ? null : _generate,
                    label: l10n.ideasFromVideo,
                  ),
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: () {
                      _selected = 0;
                      _cubit.surprise(_deck!);
                    },
                    label: l10n.ideasSurprise,
                  ),
                  if (state.busy)
                    DivineButton(
                      type: DivineButtonType.link,
                      size: DivineButtonSize.small,
                      maxLines: 20,
                      onPressed: _cubit.cancel,
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
                  onPressed: state.busy ? null : _cubit.prepare,
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
                        if (_selected + 1 < ideas.length) {
                          setState(() => _selected++);
                        } else if (state.result!.source ==
                            SuggestionSource.premade) {
                          _selected = 0;
                          _cubit.surprise(_deck!);
                        } else {
                          unawaited(_generate());
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
                        ActionChip(
                          label: Text('#$tag'),
                          onPressed: () {
                            final current = ref.read(videoEditorProvider);
                            ref
                                .read(videoEditorProvider.notifier)
                                .updateMetadata(tags: {...current.tags, tag});
                          },
                        ),
                  ],
                ),
              ],
              if (canTranscribe || _transcript.text.isNotEmpty) ...[
                if (canTranscribe && _transcript.text.isEmpty)
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: state.busy ? null : _transcribe,
                    label: l10n.ideasGenerateTranscript,
                  )
                else if (captions == null)
                  DivineButton(
                    type: DivineButtonType.link,
                    size: DivineButtonSize.small,
                    maxLines: 20,
                    onPressed: () => setState(
                      () => _editingTranscript = !_editingTranscript,
                    ),
                    label: l10n.ideasEditTranscript,
                  ),
                if (_editingTranscript && captions == null)
                  DivineTextField(
                    controller: _transcript,
                    labelText: l10n.ideasTranscript,
                    minLines: 2,
                    maxLines: 6,
                    onChanged: (value) {
                      _cubit.cancel();
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
