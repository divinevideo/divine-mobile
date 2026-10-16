// ABOUTME: Display names, input hints and proof instructions for the verify
// ABOUTME: flow. Brand names stay untranslated; the hints mirror the verifier.

import 'package:openvine/l10n/generated/app_localizations.dart';

/// Where to put the npub, and what to paste back, for [platform].
///
/// Every verifier reads a different surface — a gist's first file, a tweet's
/// text, a TikTok caption, a YouTube description, a Discord message our bot
/// can see — and none of that is guessable. The generic line is only a
/// fallback for a platform the verifier adds after this ships.
String verifyProofExplainer(AppLocalizations l10n, String platform) {
  return switch (platform.toLowerCase()) {
    'twitter' => l10n.verifyConnectProofExplainerTwitter,
    'bluesky' => l10n.verifyConnectProofExplainerBluesky,
    'tiktok' => l10n.verifyConnectProofExplainerTiktok,
    'youtube' => l10n.verifyConnectProofExplainerYoutube,
    'discord' => l10n.verifyConnectProofExplainerDiscord,
    'telegram' => l10n.verifyConnectProofExplainerTelegram,
    'mastodon' => l10n.verifyConnectProofExplainerMastodon,
    'github' => l10n.verifyConnectProofExplainerGithub,
    _ => l10n.verifyConnectProofExplainer,
  };
}

/// Label for the account field on [platform].
///
/// Telegram and YouTube verify the *channel* that published the proof — a
/// channel post's author is the channel itself — so asking for an "account
/// name" there invites the one answer that cannot work: the user's own handle.
String verifyIdentityFieldLabel(AppLocalizations l10n, String platform) {
  return switch (platform.toLowerCase()) {
    'telegram' || 'youtube' => l10n.verifyChannelLabel,
    _ => l10n.verifyIdentityLabel,
  };
}

/// Human-readable name for a NIP-39 platform key.
///
/// Brand names are not localized, so these live here rather than in the ARB
/// files. Falls back to the raw key: a platform the verifier adds later shows
/// up as itself instead of disappearing from the list.
String verifyPlatformLabel(String platform) {
  return switch (platform.toLowerCase()) {
    'github' => 'GitHub',
    'twitter' => 'Twitter / X',
    'mastodon' => 'Mastodon',
    'telegram' => 'Telegram',
    'bluesky' => 'Bluesky',
    'discord' => 'Discord',
    'youtube' => 'YouTube',
    'tiktok' => 'TikTok',
    _ => platform,
  };
}

/// Example of the account handle a platform expects.
///
/// Mirrors the placeholders in the verifier's own form
/// (`divine-identify-verification-service/src/index.ts`), so someone moving
/// between web and app is asked for the same thing. Discord departs from it:
/// the verifier's placeholder there is an English phrase, and these hints are
/// not translated. Names are reserved examples (`example`), never a name a
/// real person might own.
String verifyIdentityHint(String platform) {
  return switch (platform.toLowerCase()) {
    'github' => 'octocat',
    'twitter' => 'example',
    'mastodon' => 'mastodon.social/@example',
    'telegram' => 'mychannel',
    'bluesky' => 'example.bsky.social',
    'discord' => 'example',
    'youtube' => 'UC… or @channelhandle',
    'tiktok' => 'username',
    _ => '',
  };
}

/// Example of the proof a platform expects.
///
/// Account names follow [verifyIdentityHint]. The verifier's form shows no
/// example link for Bluesky or TikTok, so those two are built from it.
String verifyProofHint(String platform) {
  return switch (platform.toLowerCase()) {
    'github' => 'https://gist.github.com/octocat/abc123…',
    'twitter' => 'https://x.com/example/status/123…',
    'mastodon' => 'https://mastodon.social/@example/123…',
    'telegram' => 'https://t.me/mychannel/123',
    'bluesky' => 'https://bsky.app/profile/example.bsky.social/post/123…',
    'discord' => 'https://discord.com/channels/…',
    'youtube' => 'https://www.youtube.com/watch?v=…',
    'tiktok' => 'https://www.tiktok.com/@example/video/123…',
    _ => '',
  };
}
