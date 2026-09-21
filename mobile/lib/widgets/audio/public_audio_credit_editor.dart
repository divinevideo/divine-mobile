// ABOUTME: Inline editor for the public credit a reusable sound ships with.
// ABOUTME: Shared by the video publish screen and the standalone sound upload.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';

/// Edits the title, creator, ownership, source, and public hashtags of an
/// [AudioShareAttribution], and previews how the credit will read.
///
/// The text controllers are seeded once from [attribution] and then own the
/// typed text; every edit is handed back through [onChanged] as a full
/// attribution so the owner decides where it lives. Re-key the widget to
/// reseed it for a different sound.
class PublicAudioCreditEditor extends StatefulWidget {
  const PublicAudioCreditEditor({
    required this.attribution,
    required this.onChanged,
    super.key,
  });

  /// The credit as the owner currently holds it.
  final AudioShareAttribution attribution;

  /// Receives the edited credit on every change.
  final ValueChanged<AudioShareAttribution> onChanged;

  @override
  State<PublicAudioCreditEditor> createState() =>
      _PublicAudioCreditEditorState();
}

class _PublicAudioCreditEditorState extends State<PublicAudioCreditEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _creatorController;
  late final TextEditingController _sourceController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    final attribution = widget.attribution;
    _titleController = TextEditingController(text: attribution.title);
    _creatorController = TextEditingController(text: attribution.creatorName);
    _sourceController = TextEditingController(text: attribution.sourceUrl);
    _tagsController = TextEditingController(
      text: attribution.publicTags.map((tag) => '#$tag').join(' '),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _creatorController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _update({
    String? title,
    String? creatorName,
    String? sourceUrl,
    List<String>? publicTags,
    bool? confirmedOwnWork,
  }) {
    widget.onChanged(
      widget.attribution.copyWith(
        title: title,
        creatorName: creatorName,
        sourceUrl: sourceUrl,
        publicTags: publicTags,
        confirmedOwnWork: confirmedOwnWork,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownWork = widget.attribution.confirmedOwnWork;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const .fromLTRB(16, 16, 16, 0),
          child: Text(
            context.l10n.soundPublicCredit,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
        ),
        // Filled: these sit inside the section's own card, so an unfilled
        // field takes the card's color and reads as a label rather than an
        // input.
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            key: const Key('audio_credit_title'),
            controller: _titleController,
            labelText: context.l10n.soundCreditTitleLabel,
            filled: true,
            textInputAction: .next,
            onChanged: (value) => _update(title: value),
          ),
        ),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            key: const Key('audio_credit_creator'),
            controller: _creatorController,
            labelText: context.l10n.soundCreditCreatorLabel,
            filled: true,
            keyboardType: .name,
            textInputAction: .next,
            onChanged: (value) => _update(creatorName: value),
          ),
        ),
        // The source field carries its own top gap so that collapsing it
        // leaves the checkbox row a single [Column.spacing] away from the
        // hashtags field, not two.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: DivineCheckboxTile(
                value: ownWork,
                title: context.l10n.soundOwnWork,
                onChanged: (value) => _update(confirmedOwnWork: value),
              ),
            ),
            AnimatedReveal(
              child: ownWork
                  ? null
                  : Padding(
                      padding: const .fromLTRB(16, 8, 16, 0),
                      child: DivineTextField(
                        key: const Key('audio_credit_source'),
                        controller: _sourceController,
                        labelText: context.l10n.soundCreditSourceUrlLabel,
                        keyboardType: TextInputType.url,
                        filled: true,
                        autocorrect: false,
                        textInputAction: .next,
                        onChanged: (value) => _update(sourceUrl: value),
                      ),
                    ),
            ),
          ],
        ),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineTextField(
            key: const Key('audio_credit_tags'),
            controller: _tagsController,
            labelText: context.l10n.soundCreditPublicHashtagsLabel,
            filled: true,
            autocorrect: false,
            textInputAction: .done,
            onChanged: (value) =>
                _update(publicTags: value.split(RegExp(r'[,\s]+'))),
          ),
        ),
        Container(
          margin: const .symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: context.vineColors.outlineMuted),
            ),
          ),
          child: ListTile(
            contentPadding: const .symmetric(horizontal: 16),
            title: Text(
              context.l10n.soundSharedAs,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              [
                widget.attribution.title.trim(),
                if (widget.attribution.creatorName.trim().isNotEmpty)
                  context.l10n.soundCreatorBy(
                    widget.attribution.creatorName.trim(),
                  ),
              ].where((value) => value.isNotEmpty).join(' · '),
              key: const Key('audio_credit_preview'),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
