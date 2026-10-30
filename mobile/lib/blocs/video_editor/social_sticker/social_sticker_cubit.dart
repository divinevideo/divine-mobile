// ABOUTME: Holds a social sticker while the creator sets it up: its look, the
// ABOUTME: person, hashtag, link or sound, and whether it can be placed.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';

part 'social_sticker_state.dart';

/// Sets up one social sticker in the social sticker sheet.
class SocialStickerCubit extends Cubit<SocialStickerState> {
  /// Starts from [initial]. [otherHashtags] are the tags the post carries
  /// besides this sticker's, which count toward its hashtag limit.
  /// [soundChoices] are the credits for the video's sounds a sound credit can
  /// switch between; one no longer in the video stays a choice.
  ///
  /// A mention of someone the creator cannot mention starts without them.
  SocialStickerCubit({
    required SocialStickerData initial,
    required ContentBlocklistRepository blocklistRepository,
    Set<String> otherHashtags = const {},
    List<SocialStickerData> soundChoices = const [],
  }) : _blocklistRepository = blocklistRepository,
       super(
         SocialStickerState(
           data: _canMention(blocklistRepository, initial.pubkey)
               ? initial
               : SocialStickerData(kind: initial.kind, style: initial.style),
           otherHashtags: otherHashtags,
           soundChoices: initial.kind != SocialStickerKind.soundCredit
               ? const []
               : [
                   if (!soundChoices.any(initial.isSameSound)) initial,
                   ...soundChoices,
                 ],
           personBlocked: !_canMention(blocklistRepository, initial.pubkey),
         ),
       );

  final ContentBlocklistRepository _blocklistRepository;

  /// Whether [pubkey], when there is one, can be mentioned: not someone the
  /// creator blocked, and not someone who blocked or muted them.
  static bool _canMention(
    ContentBlocklistRepository blocklistRepository,
    String? pubkey,
  ) =>
      pubkey == null ||
      (!blocklistRepository.isBlocked(pubkey) &&
          !blocklistRepository.hasBlockedUs(pubkey) &&
          !blocklistRepository.hasMutedUs(pubkey));

  /// Shows the sticker in [style].
  void styleChanged(InfoStickerStyle style) =>
      emit(state.copyWith(data: state.data.copyWith(style: style)));

  /// Mentions [profile], by their handle or, without one, by their name.
  ///
  /// Someone who cannot be mentioned leaves the sticker as it was and is
  /// flagged with [SocialStickerState.personBlocked].
  void personPicked(UserProfile profile) {
    if (!_canMention(_blocklistRepository, profile.pubkey)) {
      emit(state.copyWith(personBlocked: true));
      return;
    }
    emit(
      state.copyWith(
        data: SocialStickerData.mentionOf(profile, style: state.data.style),
        personBlocked: false,
      ),
    );
  }

  /// Shows [text] as the hashtag, the way it would be published.
  void hashtagChanged(String text) => emit(
    state.copyWith(
      data: SocialStickerData(
        kind: state.data.kind,
        style: state.data.style,
        hashtag: HashtagExtractor.normalizeVideoHashtag(text),
      ),
    ),
  );

  /// Points the link to [url] as typed, showing [title] when there is one.
  void linkChanged({required String url, required String title}) => emit(
    state.copyWith(
      data: state.data.withLink(url: url, title: title),
    ),
  );

  /// Credits [sound] instead, keeping the look and the line of lyrics.
  void soundPicked(SocialStickerData sound) =>
      emit(state.copyWith(data: state.data.withSound(sound)));

  /// Shows the sound credit as [design].
  void soundDesignChanged(SocialStickerSoundDesign design) => emit(
    state.copyWith(data: state.data.copyWith(soundDesign: design)),
  );

  /// Shows [text] as the line of lyrics under a sound credit, or none when
  /// it is blank.
  void lyricChanged(String text) =>
      emit(state.copyWith(data: state.data.withLyric(text)));
}
