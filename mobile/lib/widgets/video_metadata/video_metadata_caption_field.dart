import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/caption_mentions/caption_mentions_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';

/// Caption input with `@` mention autocomplete.
///
/// The picker is what makes a mention reliable: it records the pubkey the
/// author chose, so publishing tags that account even when the typed name is
/// ambiguous or the handle carries characters the text scanner would have to
/// guess at.
class VideoMetadataCaptionField extends ConsumerStatefulWidget {
  const VideoMetadataCaptionField({
    required this.controller,
    required this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  ConsumerState<VideoMetadataCaptionField> createState() =>
      _VideoMetadataCaptionFieldState();
}

class _VideoMetadataCaptionFieldState
    extends ConsumerState<VideoMetadataCaptionField> {
  // The repositories are read per search rather than captured here. That keeps
  // the cubit from holding a previous account's instances after a switch (so
  // no identity key is needed), and keeps a caption field renderable on a
  // screen where the repository layer is not reachable — every sibling input
  // in this form reads its repository on interaction too.
  late final CaptionMentionsCubit _cubit = CaptionMentionsCubit(
    profileRepositoryOf: () => ref.read(profileRepositoryProvider),
    candidatePubkeys: () => ref.read(followRepositoryProvider).followingPubkeys,
  );

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CaptionMentionsCubit>.value(
      value: _cubit,
      child: _CaptionFieldView(
        controller: widget.controller,
        focusNode: widget.focusNode,
      ),
    );
  }
}

class _CaptionFieldView extends ConsumerWidget {
  const _CaptionFieldView({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  void _onChanged(BuildContext context, WidgetRef ref, String value) {
    ref.read(videoEditorProvider.notifier).updateMetadata(description: value);
    unawaited(
      context.read<CaptionMentionsCubit>().search(
        activeMentionQuery(value, controller.selection.baseOffset),
      ),
    );
  }

  void _onSuggestionSelected(
    BuildContext context,
    WidgetRef ref,
    String pubkey,
    String displayName,
  ) {
    final insertion = applyMentionSelection(
      text: controller.text,
      cursor: controller.selection.baseOffset,
      display: displayName,
    );
    if (insertion == null) return;

    controller.text = insertion.text;
    controller.selection = TextSelection.collapsed(offset: insertion.selection);

    final notifier = ref.read(videoEditorProvider.notifier)
      ..updateMetadata(description: insertion.text);
    notifier.recordCaptionMention(
      CaptionMention(
        display: displayName,
        pubkey: pubkey,
        start: insertion.start,
        end: insertion.end,
      ),
    );

    context.read<CaptionMentionsCubit>().clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        Stack(
          children: [
            DivineTextField(
              controller: controller,
              labelText: context.l10n.videoMetadataDescriptionLabel,
              focusNode: focusNode,
              keyboardType: .multiline,
              textInputAction: .newline,
              primaryWhenFilled: true,
              minLines: 1,
              maxLines: 10,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  VideoEditorConstants.descriptionLimit,
                ),
              ],
              onChanged: (value) => _onChanged(context, ref, value),
            ),
            Positioned(
              // Align the counter to the field's content padding so a
              // future tweak to [DivineTextField.defaultContentPadding]
              // keeps it in sync. The -1 nudges the baseline up to match
              // the floating label.
              top: DivineTextField.defaultContentPadding.top - 1,
              right: DivineTextField.defaultContentPadding.right,
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: controller.text.isNotEmpty
                        ? Text(
                            '${controller.text.length}/'
                            '${VideoEditorConstants.descriptionLimit}',
                            style: VineTheme.labelSmallFont(
                              color: context.vineColors.onSurfaceMuted,
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        ),
        _CaptionMentionSuggestions(
          onSelect: (pubkey, displayName) =>
              _onSuggestionSelected(context, ref, pubkey, displayName),
        ),
      ],
    );
  }
}

/// Suggestion list, rendered inline under the caption rather than floating.
///
/// The metadata form scrolls, so an overlay anchored to the field would drift
/// away from it; an inline list stays put and pushes the fields below down.
class _CaptionMentionSuggestions extends StatelessWidget {
  const _CaptionMentionSuggestions({required this.onSelect});

  final void Function(String pubkey, String displayName) onSelect;

  @override
  Widget build(BuildContext context) {
    final suggestions = context.select(
      (CaptionMentionsCubit cubit) => cubit.state.suggestions,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MentionOverlay(suggestions: suggestions, onSelect: onSelect),
    );
  }
}
