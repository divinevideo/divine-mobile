import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Lets the creator offer the post's audio for reuse and edit the public
/// credit that ships with it.
///
/// Audio pulled from an external provider carries that provider's credit and
/// license instead, and drops the reuse toggle when the license forbids
/// derivatives.
class VideoMetadataAudioSharingSection extends ConsumerWidget {
  /// Creates the audio sharing section.
  const VideoMetadataAudioSharingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(videoEditorProvider);
    final sound = editorState.audioForAttribution;
    final external = sound?.externalSource;
    final derivativesAllowed = external?.license.allowsDerivatives ?? true;
    final allowAudioReuse = editorState.allowAudioReuse && derivativesAllowed;
    final needsAttribution =
        allowAudioReuse &&
        external == null &&
        editorState.audioShareAttribution == null;
    if (needsAttribution) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = ref.read(videoEditorProvider);
        final currentSound = current.audioForAttribution;
        if (!current.allowAudioReuse ||
            current.audioShareAttribution != null ||
            currentSound?.externalSource != null) {
          return;
        }
        ref
            .read(videoEditorProvider.notifier)
            .setAudioShareAttribution(_initialAttribution(ref, currentSound));
      });
    }

    void updateReuse(bool value) {
      final notifier = ref.read(videoEditorProvider.notifier);
      notifier.setAllowAudioReuse(value);
      if (!value ||
          external != null ||
          editorState.audioShareAttribution != null) {
        return;
      }
      notifier.setAudioShareAttribution(_initialAttribution(ref, sound));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: DivineSwitchTile(
            value: allowAudioReuse,
            title: context.l10n.soundAllowRemix,
            subtitle: derivativesAllowed
                ? context.l10n.videoMetadataAudioReuseSubtitle
                : context.l10n.soundCreditOnly,
            onChanged: derivativesAllowed ? updateReuse : null,
          ),
        ),
        AnimatedReveal(
          child: external != null
              ? _ProviderAudioCredit(sound: sound!)
              : allowAudioReuse
              ? _PublicAudioCreditEditor(
                  key: ValueKey(sound?.id ?? 'original-audio'),
                  sound: sound,
                )
              : null,
        ),
        AnimatedReveal(
          child:
              editorState.requiresPublicAudioAttribution &&
                  !editorState.hasValidPublicAudioAttribution
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    context.l10n.soundCreditRequired,
                    key: const Key('audio_credit_validation'),
                    style: VineTheme.bodySmallFont(color: VineTheme.error),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  AudioShareAttribution _initialAttribution(WidgetRef ref, AudioEvent? sound) {
    final pubkey = ref.read(authServiceProvider).currentPublicKeyHex ?? '';
    final profile = pubkey.isEmpty
        ? null
        : ref.read(userProfileReactiveProvider(pubkey)).value;
    final publisherName =
        profile?.bestDisplayName ??
        (pubkey.isEmpty ? '' : UserProfile.defaultDisplayNameFor(pubkey));
    final title = sound?.title?.trim();
    if (sound?.isLocalImport == true) {
      return AudioShareAttribution(
        title: title?.isNotEmpty == true ? title! : '',
        creatorName: '',
        publicTags: const [],
        confirmedOwnWork: false,
      );
    }
    // Deliberately not localized: this title is published into the audio
    // event, so translating it would make event data depend on the poster's
    // locale — a German poster's sound would read "Originalton" to every
    // viewer, whatever their own locale.
    return AudioShareAttribution.forOwnedSound(
      title: title?.isNotEmpty == true ? title! : 'Original sound',
      publisherName: publisherName,
      publisherPubkey: pubkey,
    );
  }
}

class _ProviderAudioCredit extends StatelessWidget {
  const _ProviderAudioCredit({required this.sound});

  final AudioEvent sound;

  @override
  Widget build(BuildContext context) {
    final external = sound.externalSource!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.soundPublicCredit,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
          Text(
            sound.title ?? external.providerName,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          if (external.creatorName case final creator?)
            Text(
              context.l10n.soundCreatorBy(creator),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          Text(
            external.license.name,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicAudioCreditEditor extends ConsumerStatefulWidget {
  const _PublicAudioCreditEditor({required this.sound, super.key});

  final AudioEvent? sound;

  @override
  ConsumerState<_PublicAudioCreditEditor> createState() =>
      _PublicAudioCreditEditorState();
}

class _PublicAudioCreditEditorState
    extends ConsumerState<_PublicAudioCreditEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _creatorController;
  late final TextEditingController _sourceController;
  late final TextEditingController _tagsController;

  AudioShareAttribution get _attribution =>
      ref.read(videoEditorProvider).audioShareAttribution ??
      AudioShareAttribution(
        title: widget.sound?.title ?? '',
        creatorName: '',
        publicTags: const [],
        confirmedOwnWork: false,
      );

  @override
  void initState() {
    super.initState();
    final attribution = _attribution;
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
    final current = _attribution;
    ref
        .read(videoEditorProvider.notifier)
        .setAudioShareAttribution(
          current.copyWith(
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
    final attribution = ref.watch(
      videoEditorProvider.select((state) => state.audioShareAttribution),
    );
    final ownWork = attribution?.confirmedOwnWork ?? false;
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
                _titleController.text.trim(),
                if (_creatorController.text.trim().isNotEmpty)
                  context.l10n.soundCreatorBy(_creatorController.text.trim()),
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
