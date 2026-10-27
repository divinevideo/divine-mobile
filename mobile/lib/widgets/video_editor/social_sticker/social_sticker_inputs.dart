// ABOUTME: The controls of the social sticker sheet: the person, the hashtag
// ABOUTME: with suggestions, the link, the sound and its design, and the look.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';

/// Opens the people search for a mention sticker and resolves with the
/// person picked, or `null` when the search was closed.
///
/// [viewerPubkey] is left out of the results: a creator cannot mention
/// themselves.
Future<UserProfile?> pickMentionedPerson(
  BuildContext context, {
  required String? viewerPubkey,
}) async {
  final picked = await showUserPickerSheet(
    context,
    filterMode: UserPickerFilterMode.allUsers,
    autoFocus: true,
    title: context.l10n.videoEditorSocialStickerMention,
    excludeViewerPubkey: viewerPubkey,
  );
  return picked?.firstOrNull;
}

/// The person a mention names, tapped to pick someone else.
class SocialStickerPersonRow extends ConsumerWidget {
  const SocialStickerPersonRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (name, personBlocked) = context.select(
      (SocialStickerCubit cubit) =>
          (cubit.state.data.name, cubit.state.personBlocked),
    );
    final l10n = context.l10n;
    Future<void> pick() async {
      final cubit = context.read<SocialStickerCubit>();
      final profile = await pickMentionedPerson(
        context,
        viewerPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
      );
      if (profile != null) cubit.personPicked(profile);
    }

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Material(
          type: .transparency,
          child: DivineListTile(
            icon: DivineIconName.user,
            title: name == null
                ? l10n.videoEditorSocialStickerChoosePerson
                : '@$name',
            subtitle: name == null
                ? null
                : l10n.videoEditorSocialStickerChoosePerson,
            onTap: pick,
          ),
        ),
        if (personBlocked)
          StickerSheetNote(
            text: l10n.videoMetadataCreatorCannotBeReferencedSnackbar,
            warning: true,
          )
        else
          StickerSheetNote(text: l10n.videoEditorSocialStickerMentionNote),
      ],
    );
  }
}

/// The hashtag a hashtag sticker shows, typed or picked from suggestions,
/// with what adding it does to the post's hashtags.
class SocialStickerHashtagField extends StatefulWidget {
  const SocialStickerHashtagField({this.autofocus = false, super.key});

  /// Whether the keyboard opens with the sheet, for a new sticker.
  final bool autofocus;

  @override
  State<SocialStickerHashtagField> createState() =>
      _SocialStickerHashtagFieldState();
}

class _SocialStickerHashtagFieldState extends State<SocialStickerHashtagField> {
  late final _controller = TextEditingController(
    text: context.read<SocialStickerCubit>().state.data.hashtag ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    context.read<SocialStickerCubit>().hashtagChanged(text);
    context.read<HashtagSearchBloc>().add(HashtagSearchQueryChanged(text));
  }

  void _picked(String hashtag) {
    _controller.value = TextEditingValue(
      text: hashtag,
      selection: TextSelection.collapsed(offset: hashtag.length),
    );
    context.read<SocialStickerCubit>().hashtagChanged(hashtag);
    context.read<HashtagSearchBloc>().add(const HashtagSearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    final (hashtag, isOverLimit) = context.select(
      (SocialStickerCubit cubit) =>
          (cubit.state.data.hashtag, cubit.state.isOverHashtagLimit),
    );
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            controller: _controller,
            labelText: l10n.videoEditorSocialStickerHashtagHint,
            prefixText: '#',
            autofocus: widget.autofocus,
            textInputAction: .done,
            textCapitalization: .none,
            autocorrect: false,
            // Capped without a counter, which would take the room the
            // suggestions need while the keyboard is up.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(
                HashtagExtractor.maxHashtagLength,
              ),
            ],
            onChanged: _changed,
          ),
        ),
        _HashtagSuggestions(current: hashtag, onPicked: _picked),
        if (isOverLimit)
          StickerSheetNote(
            text: l10n.videoMetadataTagsPickerTagLimitReached(
              HashtagExtractor.maxHashtagsPerVideo,
            ),
            warning: true,
          )
        else
          StickerSheetNote(text: l10n.videoEditorSocialStickerHashtagNote),
      ],
    );
  }
}

/// Hashtags that match what was typed, in the form they would be added.
class _HashtagSuggestions extends StatelessWidget {
  const _HashtagSuggestions({required this.current, required this.onPicked});

  final String? current;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final results = context.select(
      (HashtagSearchBloc bloc) => bloc.state.results,
    );
    final suggestions = results
        .map(HashtagExtractor.normalizeVideoHashtag)
        .nonNulls
        .where((hashtag) => hashtag != current)
        .toSet();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return StickerChipRow(
      children: [
        for (final hashtag in suggestions)
          StickerChoiceChip(
            label: '#$hashtag',
            selected: false,
            onTap: () => onPicked(hashtag),
          ),
      ],
    );
  }
}

/// The web address a link sticker points to and the short title it shows
/// instead of the domain, with whether the address can be used.
class SocialStickerLinkFields extends StatefulWidget {
  const SocialStickerLinkFields({this.autofocus = false, super.key});

  /// Whether the keyboard opens with the sheet, for a new sticker.
  final bool autofocus;

  @override
  State<SocialStickerLinkFields> createState() =>
      _SocialStickerLinkFieldsState();
}

class _SocialStickerLinkFieldsState extends State<SocialStickerLinkFields> {
  late final _url = TextEditingController(
    text: context.read<SocialStickerCubit>().state.data.url ?? '',
  );
  late final _title = TextEditingController(
    text: context.read<SocialStickerCubit>().state.data.linkTitle ?? '',
  );

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  void _changed(String _) => context.read<SocialStickerCubit>().linkChanged(
    url: _url.text,
    title: _title.text,
  );

  @override
  Widget build(BuildContext context) {
    final hasUrl = context.select(
      (SocialStickerCubit cubit) => cubit.state.data.url != null,
    );
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            controller: _url,
            labelText: l10n.videoEditorSocialStickerLinkUrlHint,
            autofocus: widget.autofocus,
            keyboardType: .url,
            textInputAction: .next,
            textCapitalization: .none,
            autocorrect: false,
            onChanged: _changed,
          ),
        ),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            controller: _title,
            labelText: l10n.videoEditorSocialStickerLinkTitleHint,
            textInputAction: .done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                SocialStickerData.maxLinkTitleLength,
              ),
            ],
            onChanged: _changed,
          ),
        ),
        // Typed but not an address yet: say so rather than leave the button
        // greyed out without a reason.
        if (!hasUrl && _url.text.trim().isNotEmpty)
          StickerSheetNote(
            text: l10n.videoEditorSocialStickerLinkInvalid,
            warning: true,
          )
        else
          StickerSheetNote(text: l10n.videoEditorSocialStickerLinkNote),
      ],
    );
  }
}

/// The sounds in the video a sound credit can credit, when there is more
/// than one.
class SocialStickerSoundChoice extends StatelessWidget {
  const SocialStickerSoundChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final (data, choices) = context.select(
      (SocialStickerCubit cubit) =>
          (cubit.state.data, cubit.state.soundChoices),
    );
    if (choices.length < 2) return const SizedBox.shrink();
    return StickerChipRow(
      children: [
        for (final sound in choices)
          StickerChoiceChip(
            label: [sound.soundTitle, sound.soundArtist].nonNulls.join(' · '),
            selected: sound.isSameSound(data),
            onTap: () => context.read<SocialStickerCubit>().soundPicked(sound),
          ),
      ],
    );
  }
}

/// A row of the designs a sound credit can take, each shown as the credit
/// in it.
class SocialStickerSoundDesignPicker extends StatelessWidget {
  const SocialStickerSoundDesignPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.select((SocialStickerCubit cubit) => cubit.state.data);
    final l10n = context.l10n;
    const designs = SocialStickerSoundDesign.values;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        itemCount: designs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final design = designs[index];
          return StickerChoiceTile(
            semanticLabel: l10n.socialStickerSoundDesignLabel(design),
            selected: design == data.soundDesign,
            dark: true,
            onTap: () =>
                context.read<SocialStickerCubit>().soundDesignChanged(design),
            child: FittedBox(
              child: SocialStickerView(
                data: data.copyWith(soundDesign: design),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// An optional line of lyrics under a sound credit.
class SocialStickerLyricField extends StatefulWidget {
  const SocialStickerLyricField({super.key});

  @override
  State<SocialStickerLyricField> createState() =>
      _SocialStickerLyricFieldState();
}

class _SocialStickerLyricFieldState extends State<SocialStickerLyricField> {
  late final _controller = TextEditingController(
    text: context.read<SocialStickerCubit>().state.data.lyric ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: DivineTextField(
        controller: _controller,
        labelText: context.l10n.videoEditorSocialStickerLyricHint,
        maxLength: SocialStickerData.maxLyricLength,
        textInputAction: .done,
        onChanged: context.read<SocialStickerCubit>().lyricChanged,
      ),
    );
  }
}

/// A row of the looks the sticker can take, each shown as the sticker in it.
class SocialStickerStylePicker extends StatelessWidget {
  const SocialStickerStylePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.select((SocialStickerCubit cubit) => cubit.state.data);
    final l10n = context.l10n;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        itemCount: InfoStickerStyle.pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final style = InfoStickerStyle.pills[index];
          return StickerChoiceTile(
            semanticLabel: l10n.infoStickerStyleLabel(style),
            selected: style == data.style,
            dark: true,
            onTap: () => context.read<SocialStickerCubit>().styleChanged(style),
            child: data.isComplete
                ? FittedBox(
                    child: SocialStickerView(data: data.copyWith(style: style)),
                  )
                : Text(
                    l10n.infoStickerStyleLabel(style),
                    style: VineTheme.bodySmallFont(color: VineTheme.whiteText),
                  ),
          );
        },
      ),
    );
  }
}
