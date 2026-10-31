// ABOUTME: Holds a social sticker while the creator sets it up: its look, the
// ABOUTME: person, hashtag, link, sound, countdown, poll or question.

import 'package:clock/clock.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:poll_repository/poll_repository.dart' show Poll;

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
           data: canMention(blocklistRepository, initial.pubkey)
               ? initial
               : SocialStickerData(kind: initial.kind, style: initial.style),
           otherHashtags: otherHashtags,
           soundChoices: initial.kind != SocialStickerKind.soundCredit
               ? const []
               : [
                   if (!soundChoices.any(initial.isSameSound)) initial,
                   ...soundChoices,
                 ],
           personBlocked: !canMention(blocklistRepository, initial.pubkey),
         ),
       );

  final ContentBlocklistRepository _blocklistRepository;

  /// Whether [pubkey], when there is one, can be mentioned or replied to with
  /// a sticker: not someone the creator blocked, and not someone who blocked
  /// or muted them.
  static bool canMention(
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
    if (!canMention(_blocklistRepository, profile.pubkey)) {
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

  /// Shows [text] as the countdown's title.
  void countdownTitleChanged(String text) => emit(
    state.copyWith(data: state.data.copyWith(countdownTitle: text.trim())),
  );

  /// Counts down to [end], a wall-clock time of the phone.
  void countdownEndChanged(DateTime end) => emit(
    state.copyWith(data: state.data.copyWith(countdownEnd: end.toUtc())),
  );

  /// Asks [text] in the poll, quiz or slider.
  void pollQuestionChanged(String text) => emit(
    state.copyWith(data: state.data.copyWith(pollQuestion: text)),
  );

  /// Shows [text] as the answer at [index].
  void pollOptionChanged(int index, String text) {
    final options = [...state.data.pollOptions];
    if (index < 0 || index >= options.length) return;
    options[index] = text;
    emit(state.copyWith(data: state.data.copyWith(pollOptions: options)));
  }

  /// Adds an empty answer at the end, up to the most a poll can have.
  void pollOptionAdded() {
    final options = state.data.pollOptions;
    if (options.length >= Poll.maxOptions) return;
    emit(
      state.copyWith(
        data: state.data.copyWith(pollOptions: [...options, '']),
      ),
    );
  }

  /// Removes the answer at [index], down to the fewest a poll can have. A
  /// quiz's right answer stays the one it was, or becomes the first when it
  /// was the one removed.
  void pollOptionRemoved(int index) {
    final options = [...state.data.pollOptions];
    if (options.length <= Poll.minOptions ||
        index < 0 ||
        index >= options.length) {
      return;
    }
    options.removeAt(index);
    final answer = state.data.quizAnswer;
    emit(
      state.copyWith(
        data: state.data.copyWith(
          pollOptions: options,
          quizAnswer: answer == null
              ? null
              : answer == index
              ? 0
              : answer > index
              ? answer - 1
              : answer,
        ),
      ),
    );
  }

  /// Makes the answer at [index] a quiz's right one.
  void quizAnswerPicked(int index) {
    if (index < 0 || index >= state.data.pollOptions.length) return;
    emit(state.copyWith(data: state.data.copyWith(quizAnswer: index)));
  }

  /// Rates the slider with [emoji].
  void sliderEmojiPicked(String emoji) => emit(
    state.copyWith(data: state.data.copyWith(sliderEmoji: emoji)),
  );

  /// Asks [text] in a question, prompts it in an Add yours, or titles a
  /// replies sticker with it. An Add yours whose hashtag still follows its
  /// prompt, or has none, takes the new prompt's.
  void promptChanged(String text) {
    final data = state.data;
    final hashtag = data.hashtag ?? '';
    final followsPrompt =
        hashtag.isEmpty ||
        hashtag == SocialStickerData.hashtagForPrompt(data.prompt ?? '');
    emit(
      state.copyWith(
        data: data.kind == SocialStickerKind.addYours && followsPrompt
            ? data.copyWith(
                prompt: text,
                hashtag: SocialStickerData.hashtagForPrompt(text) ?? '',
              )
            : data.copyWith(prompt: text),
      ),
    );
  }

  /// Shares [text] among an Add yours's answers as their hashtag, the way it
  /// would be published.
  void promptHashtagChanged(String text) => emit(
    state.copyWith(
      data: state.data.copyWith(
        hashtag: HashtagExtractor.normalizeVideoHashtag(text) ?? '',
      ),
    ),
  );
}
