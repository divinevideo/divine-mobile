// ABOUTME: The localized names of social sticker kinds and sound credit
// ABOUTME: designs, for the sticker sheets and the timeline.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';

extension SocialStickerLabels on AppLocalizations {
  /// What [kind] is called: "Mention", "Hashtag", "Link", "Sound",
  /// "Countdown", "Reply", "Poll", "Quiz" or "Slider".
  String socialStickerKindLabel(SocialStickerKind kind) => switch (kind) {
    SocialStickerKind.mention => videoEditorSocialStickerMention,
    SocialStickerKind.hashtag => videoEditorSocialStickerHashtag,
    SocialStickerKind.link => videoEditorSocialStickerLink,
    SocialStickerKind.soundCredit => videoEditorSocialStickerSoundCredit,
    SocialStickerKind.countdown => videoEditorSocialStickerCountdown,
    SocialStickerKind.reply => videoEditorSocialStickerReply,
    SocialStickerKind.poll => videoEditorSocialStickerPoll,
    SocialStickerKind.quiz => videoEditorSocialStickerQuiz,
    SocialStickerKind.slider => videoEditorSocialStickerSlider,
  };

  /// What [design] is called: "Note", "Record" and so on.
  String socialStickerSoundDesignLabel(SocialStickerSoundDesign design) =>
      switch (design) {
        SocialStickerSoundDesign.note => videoEditorSocialStickerSoundNote,
        SocialStickerSoundDesign.vinyl => videoEditorSocialStickerSoundVinyl,
        SocialStickerSoundDesign.cassette =>
          videoEditorSocialStickerSoundCassette,
        SocialStickerSoundDesign.equalizer =>
          videoEditorSocialStickerSoundEqualizer,
        SocialStickerSoundDesign.player => videoEditorSocialStickerSoundPlayer,
      };
}
