import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/audio/public_audio_credit_editor.dart';

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
              ? PublicAudioCreditEditor(
                  key: ValueKey(sound?.id ?? 'original-audio'),
                  attribution:
                      editorState.audioShareAttribution ??
                      AudioShareAttribution(
                        title: sound?.title ?? '',
                        creatorName: '',
                        publicTags: const [],
                        confirmedOwnWork: false,
                      ),
                  onChanged: ref
                      .read(videoEditorProvider.notifier)
                      .setAudioShareAttribution,
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
