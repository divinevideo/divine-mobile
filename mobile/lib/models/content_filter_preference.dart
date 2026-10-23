import 'package:openvine/models/content_label.dart';

/// User preference for how a content category should be handled in feeds.
enum ContentFilterPreference {
  /// Show content normally without any overlay.
  show,

  /// Show content with a blur overlay and "View Anyway" button.
  warn,

  /// Filter content completely from feeds (not visible at all).
  hide,
}

const Map<ContentLabel, ContentFilterPreference> contentFilterDefaults = {
  // Adult content stays hidden even after age verification; the user must
  // opt in per category via Content Filters.
  ContentLabel.nudity: ContentFilterPreference.hide,
  ContentLabel.sexual: ContentFilterPreference.hide,
  ContentLabel.drugs: ContentFilterPreference.hide,
  // Always-filtered categories are not user-configurable.
  ContentLabel.graphicMedia: ContentFilterPreference.hide,
  ContentLabel.violence: ContentFilterPreference.hide,
  ContentLabel.selfHarm: ContentFilterPreference.hide,
  ContentLabel.porn: ContentFilterPreference.hide,
  ContentLabel.hate: ContentFilterPreference.hide,
  ContentLabel.harassment: ContentFilterPreference.hide,
  ContentLabel.aiGenerated: ContentFilterPreference.hide,
  ContentLabel.deepfake: ContentFilterPreference.hide,
  ContentLabel.spam: ContentFilterPreference.hide,
  ContentLabel.scam: ContentFilterPreference.hide,
  // Visible non-adult categories start at warn.
  ContentLabel.alcohol: ContentFilterPreference.warn,
  ContentLabel.tobacco: ContentFilterPreference.warn,
  ContentLabel.gambling: ContentFilterPreference.warn,
  ContentLabel.profanity: ContentFilterPreference.warn,
  ContentLabel.flashingLights: ContentFilterPreference.warn,
  ContentLabel.spoiler: ContentFilterPreference.warn,
  ContentLabel.misleading: ContentFilterPreference.warn,
};
