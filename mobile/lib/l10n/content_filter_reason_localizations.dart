import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_moderation.dart';

extension ContentFilterReasonLocalizations on AppLocalizations {
  String reportReasonTitle(ContentFilterReason reason) {
    return switch (reason) {
      ContentFilterReason.spam => reportReasonSpam,
      ContentFilterReason.harassment => reportReasonHarassment,
      ContentFilterReason.violence => reportReasonViolence,
      ContentFilterReason.sexualContent => reportReasonSexualContent,
      ContentFilterReason.copyright => reportReasonCopyright,
      ContentFilterReason.falseInformation => reportReasonFalseInfo,
      ContentFilterReason.childSafety => reportReasonChildSafety,
      ContentFilterReason.csam => reportReasonCsam,
      ContentFilterReason.underageUser => reportReasonUnderageUser,
      ContentFilterReason.aiGenerated => reportReasonAiGenerated,
      ContentFilterReason.other => reportReasonOther,
    };
  }

  String reportReasonSubtitle(ContentFilterReason reason) {
    return switch (reason) {
      ContentFilterReason.spam => reportReasonSpamSubtitle,
      ContentFilterReason.harassment => reportReasonHarassmentSubtitle,
      ContentFilterReason.violence => reportReasonViolenceSubtitle,
      ContentFilterReason.sexualContent => reportReasonSexualContentSubtitle,
      ContentFilterReason.copyright => reportReasonCopyrightSubtitle,
      ContentFilterReason.falseInformation => reportReasonFalseInfoSubtitle,
      ContentFilterReason.childSafety => reportReasonChildSafetySubtitle,
      ContentFilterReason.csam => reportReasonCsamSubtitle,
      ContentFilterReason.underageUser => reportReasonUnderageUserSubtitle,
      ContentFilterReason.aiGenerated => reportReasonAiGeneratedSubtitle,
      ContentFilterReason.other => reportReasonOtherSubtitle,
    };
  }
}
